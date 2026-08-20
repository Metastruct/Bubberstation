"""
MCP server for debugging a live, already-running DreamDaemon instance over
world.Topic(), using the claude_debug topic handler (see
code/datums/world_topic.dm and modular_zzmeta/modules/claude_debug/code/).

dm_debug_query runs raw SDQL2 (the in-game admin query language) for
freeform exploration. dm_debug_find/get_var/set_var/call_proc are a newer,
narrower set that bypass SDQL2's parser entirely for the common
find-an-object/read-a-var/write-a-var/call-a-proc case, backed by real
handles instead of SDQL2's fragile ref-literal syntax - prefer these for
anything that isn't genuinely a freeform WHERE-filtered search.

Connection details come from environment variables, not tool arguments, so
the server's secret key never has to pass through the model's context:
  DM_DEBUG_HOST  - defaults to 127.0.0.1 (the debug handler only accepts
                   loopback callers anyway, see the handler's addr check)
  DM_DEBUG_PORT  - required, the world.port of the target DreamDaemon
  DM_DEBUG_KEY   - required, must match CLAUDE_DEBUG_KEY in config/comms.txt
  DM_DEBUG_TIMEOUT - optional, seconds, defaults to 90 (SDQL queries against
                   large object sets can legitimately take tens of seconds)
"""

import asyncio
import base64
import functools
import glob
import itertools
import json
import logging
import logging.handlers
import os
import re
import shutil
import signal
import socket
import struct
import subprocess
import time
import urllib.parse
import urllib.request

import websockets
from mcp.server import MCPServer
from mcp.server.mcpserver import Image

HOST = os.environ.get("DM_DEBUG_HOST", "127.0.0.1")
PORT = os.environ.get("DM_DEBUG_PORT")
KEY = os.environ.get("DM_DEBUG_KEY")
TIMEOUT = float(os.environ.get("DM_DEBUG_TIMEOUT", "90"))

# Repo root, derived from this file's location (modular_zzmeta/tools/claude-mcp/)
# rather than hardcoded, so this still works if the checkout ever moves.
REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
DMB_PATH = os.path.join(REPO_ROOT, "tgstation.dmb")
BOOT_STATE_DIR = os.path.join(REPO_ROOT, "data", "logs", "claude_debug_boot")
BOOT_PID_FILE = os.path.join(BOOT_STATE_DIR, "pid")
BOOT_LOG_FILE = os.path.join(BOOT_STATE_DIR, "boot.log")
NEXT_MAP_FILE = os.path.join(REPO_ROOT, "data", "next_map.json")

# This process's own debug log - separate from the DreamDaemon logs under
# data/logs/ that dm_debug_find_log searches. The MCP framework normally logs
# nothing at all for a tool call (see _handle_call_tool in
# mcp/server/mcpserver/server.py - a raised exception just becomes a
# CallToolResult(is_error=True) with no log line anywhere), and even what it
# does log via logging.basicConfig only goes to this process's own stderr,
# which isn't reachable after the fact. Every tool call/result/exception is
# logged here instead (see _logged_tool below) so a failure can be diagnosed
# by tailing a file instead of re-triggering it blind. Rotated (5MB x3) since
# this is a long-lived dev process that can accumulate a lot of SDQL traffic
# over weeks.
CLAUDE_MCP_LOG_DIR = os.path.join(REPO_ROOT, "data", "logs", "claude_mcp")
CLAUDE_MCP_LOG_FILE = os.path.join(CLAUDE_MCP_LOG_DIR, "dm_debug_server.log")

# CDP (Chrome DevTools Protocol) access into tgui's embedded WebView2 browser.
# Separate from the DM_DEBUG_* config above - doesn't go through world.Topic()
# at all, talks directly to the browser. Needs the one-time setup described in
# webview2-debugging.md before any of this works (nothing here can detect or
# fix a missing setup, it'll just fail to connect).
CDP_HOST = os.environ.get("TGUI_CDP_HOST", "127.0.0.1")
CDP_PORT = int(os.environ.get("TGUI_CDP_PORT", "9222"))

# Candidate BYOND screenshots folders, same shape as the cache-folder search in
# tgui/packages/tgui-dev-server/reloader.ts (Windows/Wine/Lutris/Steam/WSL), just
# pointed at "screenshots" instead of "cache" - they're sibling folders under
# .../Documents/BYOND/.
HOME = os.path.expanduser("~")
SCREENSHOT_DIR_PATTERNS = [
    os.environ.get("BYOND_SCREENSHOTS"),
    f"{HOME}/*/BYOND/screenshots",
    f"{HOME}/.wine/drive_c/users/*/*/BYOND/screenshots",
    f"{HOME}/Games/byond/drive_c/users/*/*/BYOND/screenshots",
    "/mnt/c/Users/*/*/BYOND/screenshots",
]

mcp = MCPServer("dm-debug", log_level="DEBUG")

# MCPServer(..., log_level="DEBUG") already ran logging.basicConfig() (see
# configure_logging() in mcp/server/mcpserver/utilities/logging.py), which
# attaches a stderr handler to the root logger and sets its level - a second
# basicConfig call is a no-op once handlers exist, so add the file handler
# directly instead of trying to reconfigure via basicConfig again.
os.makedirs(CLAUDE_MCP_LOG_DIR, exist_ok=True)
_file_handler = logging.handlers.RotatingFileHandler(
    CLAUDE_MCP_LOG_FILE, maxBytes=5_000_000, backupCount=3
)
_file_handler.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(message)s"))
logging.getLogger().addHandler(_file_handler)

logger = logging.getLogger("dm_debug_server")
logger.info(
    "dm_debug_server starting: pid=%s port=%s key_set=%s timeout=%s cdp=%s:%s repo_root=%s",
    os.getpid(), PORT, bool(KEY), TIMEOUT, CDP_HOST, CDP_PORT, REPO_ROOT,
)


class TopicError(RuntimeError):
    pass


_call_ids = itertools.count(1)
_MAX_LOGGED_VALUE = 600  # chars - SDQL results/args can be huge, keep the log readable


def _truncate(text: str) -> str:
    text = str(text)
    if len(text) <= _MAX_LOGGED_VALUE:
        return text
    return text[:_MAX_LOGGED_VALUE] + f"... ({len(text)} chars total)"


def _safe_result_repr(value) -> str:
    # Image (from mcp.server.mcpserver) carries raw PNG bytes - never dump those
    # into a text log, just note the size.
    data = getattr(value, "data", None)
    fmt = getattr(value, "format", None)
    if data is not None and fmt is not None:
        return f"<Image format={fmt} bytes={len(data)}>"
    return _truncate(repr(value))


def _logged_tool(fn):
    """Wrap an @mcp.tool() function so every call, its result/exception, and
    timing land in CLAUDE_MCP_LOG_FILE - see the comment on that constant for
    why this exists. Never logs DM_DEBUG_KEY (env-only, never a tool arg, so
    there's nothing to redact from args/kwargs here).
    """

    @functools.wraps(fn)
    def wrapper(*args, **kwargs):
        call_id = next(_call_ids)
        arg_repr = ", ".join(
            [repr(a) for a in args] + [f"{k}={v!r}" for k, v in kwargs.items()]
        )
        logger.info("#%d %s(%s) called", call_id, fn.__name__, _truncate(arg_repr))
        start = time.monotonic()
        try:
            result = fn(*args, **kwargs)
        except Exception:
            logger.exception(
                "#%d %s raised after %.2fs", call_id, fn.__name__, time.monotonic() - start
            )
            raise
        logger.info(
            "#%d %s -> %s (%.2fs)",
            call_id, fn.__name__, _safe_result_repr(result), time.monotonic() - start,
        )
        return result

    return wrapper


# Matches a bracket/brace whose entire content is a single bareword ending in digits, e.g.
# "[mob_2990]" or "{mob_2990}" - the exact shape of a REF()-printed DF_USE_TAG label (see
# code/__HELPERS/ref.dm) copy-pasted from a prior SELECT's href output. In SDQL, [...] is
# always a list literal (never a ref) and {...} wants a hex number specifically (see
# SDQL_2_parser.dm's own grammar comment), so either form here builds/parses to something
# other than the object the caller meant - confirmed live to corrupt CALL state for the rest
# of the session when the malformed value reached a proc expecting a real object. Deliberately
# doesn't match legitimate list literals with more than one element ("[name, self.owner]") or
# a bracketed var name with no trailing digits ("[current_wag_frame]").
_REF_LOOKALIKE_RE = re.compile(r"[\[{]\s*[A-Za-z][A-Za-z0-9]*_[0-9]+\s*[\]}]")


def _send_topic(host: str, port: int, topic: str, timeout: float) -> str:
    """Send a raw BYOND world.Topic() request and return the decoded text response.

    Wire format (reverse-engineered and verified live against this repo's
    DreamDaemon build, not documented by BYOND):
      request  = 0x00 0x83 + 2-byte big-endian length (bytes from offset 4
                 onward) + 5 zero padding bytes + topic string + trailing 0x00
      response = 5-byte header (0x00 0x83 + 2-byte BE length + 1 type byte)
                 + payload. Type 0x06 = text, 0x2a = little-endian float32,
                 0x00 with zero-length payload = null (proc returned nothing).
    """
    if not topic.startswith("?"):
        topic = "?" + topic
    body = topic.encode("utf-8") + b"\x00"
    length = len(body) + 5
    header = b"\x00\x83" + struct.pack(">H", length) + b"\x00\x00\x00\x00\x00"
    packet = header + body

    with socket.create_connection((host, port), timeout=timeout) as s:
        s.settimeout(timeout)
        s.sendall(packet)

        resp_header = b""
        while len(resp_header) < 5:
            chunk = s.recv(5 - len(resp_header))
            if not chunk:
                raise TopicError(
                    f"connection closed while reading response header, got {resp_header!r}"
                )
            resp_header += chunk

        resp_len = struct.unpack(">H", resp_header[2:4])[0]
        data_type = resp_header[4]

        payload = b""
        remaining = resp_len - 1
        while len(payload) < remaining:
            chunk = s.recv(remaining - len(payload))
            if not chunk:
                break
            payload += chunk

    if data_type == 0x06:
        return payload.rstrip(b"\x00").decode("utf-8", errors="replace")
    if data_type == 0x2A:
        return str(struct.unpack("<f", payload[:4])[0])
    if data_type == 0x00 and not payload:
        return ""
    raise TopicError(f"unrecognized response type byte {hex(data_type)}, payload={payload!r}")


@mcp.tool()
@_logged_tool
def dm_debug_query(query: str) -> str:
    """Run a read/write debug query against the live DreamDaemon dev server.

    `query` is SDQL2 syntax (SELECT/UPDATE/CALL/DELETE), the same language
    used by the in-game admin SDQL2 tool. Runs with elevated (superuser)
    permissions on the target server, gated only by the shared key and a
    loopback-only check on the server side, so only point this at a
    server you control, never a live/production one shared with other
    people. Examples:
      SELECT /obj/machinery/door WHERE z == 2
      UPDATE /mob/living/carbon/human SET name = "test"
      CALL forceMove(locate(1,1,1)) ON /mob/living/carbon/human

    Tips (learned the hard way against a real dev server):
    - Always scope the type as narrowly as you can (e.g.
      /mob/living/carbon/human, not the bare /mob - which walks every mob,
      ghosts and NPCs included, and is visibly slower) and add a WHERE
      clause. Never SELECT/CALL/DELETE an unfiltered broad type just to
      eyeball the results.
    - WHERE compares scalar fields reliably (name, type, numeric/text vars,
      including dotted paths like `self.name == "..."`). Comparing a var to
      a bracketed ref literal in WHERE (e.g. `WHERE self == [mob_123]`) does
      NOT reliably match - go through a scalar field instead.
    - CORRECTION, confirmed live and cost a real corrupted-CALL-state
      incident: `[thing]` square brackets are ALWAYS SDQL's list-literal
      syntax (`MAP [name, self.owner]` builds a 2-element list; a bare
      `[mob_123]` builds a 1-element list containing whatever bareword
      "mob_123" evaluates to, almost always null) - it is NEVER a ref
      literal, as an argument or anywhere else. The real ref-literal syntax
      is `{0x...}` (curly braces, a hex number only per the grammar) - but
      most mobs/atoms in this codebase have `DF_USE_TAG` set, so `REF()`
      prints a friendly tag like `mob_2990` instead of raw hex in SELECT
      output, and that tag is NOT valid inside `{...}` either (parser wants
      a hex number specifically). Net effect: there is currently no reliable
      way to construct a ref literal for a DF_USE_TAG'd object from SELECT
      output. Don't try - `CALL foo([mob_123]) ON ...` will silently build a
      list and hand it to `foo()` instead of the mob, which can throw inside
      the target proc and poison every CALL for the rest of the session (see
      the parse-error note below - a thrown runtime error does the same
      thing, not just parse errors). Instead, reach the target by chaining
      from something already selectable: `SELECT /mob/... WHERE ckey == "..."
      MAP get_organ_slot("tail")` (confirmed live) walks "current object" to
      that proc's return value, so the rest of the query (a further MAP, or
      wrapping in `[...]` for display) operates on the real object with zero
      ref-literal needed. This composes: `MAP get_organ_slot("tail") MAP
      bodypart_overlay MAP [some_var]` chains three hops deep reliably.
    - A proc call used as a WHOLE MAP step (`MAP get_organ_slot("tail")`)
      reliably invokes it and changes "current object" to the return value -
      confirmed live. The SAME call embedded *inside* a bracketed display
      list (`MAP [icon_exists(a, b)]`) does NOT reliably evaluate - it came
      back `NULL` in testing even though the bare-MAP-step form works fine.
      If you need a proc's return value for display, give it its own MAP
      step first, then wrap just the resulting scalar in `[...]` afterward
      (`MAP some_proc(...) MAP [self]`), rather than nesting the call inside
      a list literal.
    - Components are selectable/callable too, not just atoms - e.g.
      `SELECT /datum/component/interactable WHERE self.name == "..."` or
      `CALL some_proc(...) ON /datum/component/some_type WHERE ...` reaches
      component-only procs that the owning atom doesn't expose directly.
    - /client is NOT a selectable SDQL type (always returns empty) - to
      find a connected player's mob, use
      `SELECT /mob/living/carbon/human WHERE client != null` (or narrow
      further with a name/ckey if you already know it).
    - DELETE calls qdel() under the hood - a deleted object's `loc` goes
      null (shows as "nonexistent location" in a follow-up SELECT) rather
      than the object vanishing from query results entirely.
    - Config file edits (e.g. CLAUDE_DEBUG_KEY in config/comms.txt) are not
      reliably picked up by the in-game "Reload Configuration" admin verb -
      a full DreamDaemon restart is the dependable way to apply them.
    - A `SELECT /datum/some/type` that returns
      {"error":"Parse error, check the query syntax"} can simply mean that
      type isn't compiled into the CURRENTLY RUNNING build - not a real
      syntax problem. Confirmed live: a brand-new .dm file's type gave this
      exact generic error because its #include line was actually missing
      from tgstation.dme (compiled fine, but the type genuinely didn't
      exist), which looked identical to a query-syntax bug and cost real
      debugging time. Before assuming your query is wrong, grep
      tgstation.dme for the file's #include line, especially for a type from
      a file added earlier the same session - "it compiled with 0 errors
      before" does not guarantee every intended #include line is still
      present (see the missing-#include write-up in project memory).
    - If a query ever returns a "Parse error", OR a CALL throws a runtime
      error inside the proc it invoked (e.g. from a bad argument - check the
      server's runtime.log, dm_debug_query itself won't surface it), treat
      every CALL for the rest of that session with suspicion afterward.
      Confirmed live BOTH ways: after either kind of failure, subsequent
      CALLs silently resolved their proc name to null server-side (visible
      in runtime.log as "SDQL function blocking(<obj>, null, ...)")
      regardless of what proc was actually requested, with no error
      surfaced back through dm_debug_query - the call just quietly did
      nothing. Not root-caused. UPDATE/SELECT keep working fine on the same
      connection even after this - it's specifically CALL that's affected.
      The reliable fix is a fresh server process: dm_debug_stop_server +
      dm_debug_boot_server for a disposable instance, or ask the user to
      restart if you're on their own dev server - don't keep debugging CALL
      behavior on a connection that already hit either kind of failure.
    - For CALL queries specifically, the returned "count" is NOT a
      success/match indicator - it's frequently 0 even when the call matched
      objects and ran successfully (Execute() only populates the
      select_refs/select_text that "count" reflects for SELECT queries).
      Never treat count==0 from a CALL as "nothing matched" or "it failed" -
      verify with a separate follow-up SELECT/MAP instead.
    - WHERE clauses combining a comparator with a boolean operator (e.g.
      `WHERE loc.x == 110 && loc.y == 79`) are evaluated by a flat,
      left-to-right pass with NO operator precedence between comparators and
      &&/||/and/or - confirmed live to silently produce wrong matches (not a
      parse error) rather than the "both conditions must hold" you'd expect.
      Stick to a single condition per WHERE, or pick one already-unique
      scalar field, rather than combining conditions with &&/and.
    - A quoted string literal containing parentheses (e.g.
      `WHERE name == "the monkey (905)"`) fails to match anything, silently
      (no parse error, just zero results) - confirmed live. Don't filter on
      names/text that may contain parens; use a numeric/unique field instead,
      or rename the object first (e.g. `CALL SetName(...) ON ...`) then
      filter on the new plain name.
    - `locate(x,y,z)` used as a WHERE comparison value (e.g.
      `WHERE loc == locate(110,79,2)`) does not resolve to the real turf -
      confirmed live it actually matched objects whose loc is null instead
      (as if locate() had evaluated to null). Don't use locate() inside a
      WHERE comparison; reach a specific turf via a mob's `loc` var chain
      (`MAP loc`, `MAP loc.someturfvar`) instead.
    - Bare `/turf` (or other whole-map-scale types) SELECTs, even with a
      WHERE filter, can time out - SDQL2 fetches every object of the type
      across the ENTIRE loaded world (all z-levels, including lavaland/ruin/
      space z-levels that exist regardless of which map was booted) before
      applying WHERE. Prefer reaching a specific turf via a mob already in
      hand (`SELECT /mob/... WHERE ... MAP loc` or `MAP loc.somevar`) over a
      direct `/turf` SELECT.
    - A MAP expression referencing a var name that doesn't actually exist on
      the object (e.g. guessing a mob has `var/wet_stacks` when the real var
      is on an attached status-effect datum, not the mob itself) fails
      silently - you get back a technically-200 response with an empty/
      truncated select_text instead of a clear "unknown var" error. If a MAP
      query comes back empty for a var you were confident should have a
      value, first double check the var actually exists on that exact type
      by grepping its source `.dm` file, before concluding the underlying
      game state is wrong.
    - This dev world always carries persistent-world content (lavaland
      dwellers, virology/genetics monkeys, morgue body bags) regardless of
      which map is booted, dating from disk-persisted saves under
      data/npc_saves and data/player_saves - don't assume a fresh boot means
      zero pre-existing /mob/living/carbon/human objects. Note also that
      those monkeys ARE /mob/living/carbon/human under the hood (monkey is
      just another species), so `SELECT /mob/living/carbon/human` picks them
      up too - no separate monkey type needed to test on one.

    Returns the raw text response from the server (JSON-formatted).
    """
    if not PORT:
        raise TopicError("DM_DEBUG_PORT is not set")
    if not KEY:
        raise TopicError("DM_DEBUG_KEY is not set")

    lookalike = _REF_LOOKALIKE_RE.search(query)
    if lookalike:
        raise TopicError(
            f"Query rejected before sending: {lookalike.group()!r} looks like a ref tag "
            "(e.g. copied from a prior SELECT's href output, such as \"mob_2990\") wrapped "
            "in brackets/braces. In SDQL, [...] is ALWAYS a list literal (never a ref) and "
            "{...} wants a hex number specifically - neither parses to the object you mean, "
            "and handing the result to a proc expecting a real object can throw and poison "
            "every CALL for the rest of the session. Reach the target instead by chaining a "
            'proc call as its own MAP step, e.g. SELECT /mob/... WHERE ckey == "..." MAP '
            "get_organ_slot(\"tail\") - see this tool's own docstring for more. If this match "
            "is a false positive (a real list literal that happens to look like a tag), "
            "rephrase the query so the bracketed content isn't a single word_number token."
        )

    topic = f"claude_debug=1&key={KEY}&format=json&q={query}"
    return _send_topic(HOST, int(PORT), topic, TIMEOUT)


@mcp.tool()
@_logged_tool
def dm_debug_boot_server(map: str = "runtimestation", boot_timeout: float = 180.0) -> str:
    """Boot a disposable DreamDaemon instance in THIS checkout, for live
    testing via dm_debug_query - and block until it's ready (or timed out).

    Automates the whole manual recipe (this used to be done by hand every
    time: mkdir the log dir, write data/next_map.json, launch DreamDaemon,
    poll the boot log for readiness, and separately remember to clean
    everything up afterward - error-prone and slow enough in practice that a
    real test session previously let the disposable server hit a too-short
    shell `timeout` mid-investigation and die).

    Waits specifically for "Game start took" in the boot log, NOT just
    "Initializations complete" - those are two different points in boot and
    the gap matters. "Initializations complete" only means the subsystems
    have finished loading; the round itself (SSticker's setup, runlevel
    transitioning to RUNLEVEL_GAME) happens after that and logs "Game start
    took Ns" once it's done. Confirmed live: round-dependent systems (the
    liquids subsystem, some status-effect-driven behavior) did not work
    correctly when exercised in the gap between those two log lines, only
    after "Game start took" appeared. An earlier version of this tool waited
    for "Initializations complete" alone, which worked by accident in manual
    testing only because enough real time passed between boot and the first
    query for the round to finish starting anyway.

    Also forces the round to start immediately rather than sitting through
    the normal ~120s pregame lobby countdown (config/config.txt's
    LOBBY_COUNTDOWN) - flips SSticker.start_immediately (the same var the
    in-game "Start Now" admin verb sets) as soon as world.Topic() answers,
    which is well before that. Doesn't touch config.txt at all, so this has
    no effect on the user's own real server.

    Boots on DM_DEBUG_PORT (the same port dm_debug_query already targets),
    so no extra config is needed - just call this, then start calling
    dm_debug_query once it returns success.

    `map` defaults to "runtimestation" - the small debug/CI map (~11k line
    .dmm vs. 100k+ for a production station map), which boots noticeably
    faster and keeps SELECT-heavy queries snappier. Must be a name under
    _maps/ with a matching _maps/map_files/**/<map>.dmm (e.g.
    "runtimestation_minimal" is even smaller; "deltastation" etc. for a
    full production map if you specifically need one). Note: even the
    smallest debug map still carries the full persistent-world save data
    (lavaland dwellers, monkeys, morgue occupants) - "smaller" cuts the
    station's own footprint, not the persistent content layered on top.

    IMPORTANT - this writes real, live state in the checkout for as long as
    the server is running: data/next_map.json (which map boots next) and a
    data/logs/claude_debug_boot/ directory. ALWAYS call dm_debug_stop_server
    when done testing, even if you hit an error partway through - it is the
    only thing that removes next_map.json again, and leaving it in place
    would silently hijack the map choice of the user's own next real
    DreamDaemon boot in this checkout, not just yours.

    Only one boot at a time is tracked (a second call while one is already
    running raises rather than launching a duplicate) - call
    dm_debug_stop_server first if you need to switch maps.
    """
    if not PORT:
        raise TopicError("DM_DEBUG_PORT is not set")
    if not os.path.exists(DMB_PATH):
        raise TopicError(f"{DMB_PATH} doesn't exist - compile first (tools/build/build.sh dm).")

    map_json = os.path.join(REPO_ROOT, "_maps", f"{map}.json")
    if not os.path.exists(map_json):
        raise TopicError(f"No _maps/{map}.json - check the map name (e.g. 'runtimestation').")

    if os.path.exists(BOOT_PID_FILE):
        with open(BOOT_PID_FILE) as f:
            old_pid = f.read().strip()
        raise TopicError(
            f"A boot is already tracked (pid {old_pid}). Call dm_debug_stop_server first "
            "- only one disposable boot is tracked at a time."
        )

    os.makedirs(BOOT_STATE_DIR, exist_ok=True)
    shutil.copy(map_json, NEXT_MAP_FILE)

    log_f = open(BOOT_LOG_FILE, "wb")
    proc = subprocess.Popen(
        [
            "DreamDaemon", DMB_PATH, str(int(PORT)),
            "-trusted", "-verbose", "-close",
            "-params", "log-directory=claude_debug_boot",
        ],
        cwd=REPO_ROOT,
        stdout=log_f,
        stderr=subprocess.STDOUT,
        start_new_session=True,  # own process group, so stop can kill it precisely
    )
    with open(BOOT_PID_FILE, "w") as f:
        f.write(str(proc.pid))

    # Best-effort: skip the ~120s LOBBY_COUNTDOWN (config/config.txt) by flipping
    # SSticker.start_immediately as soon as world.Topic() answers - which is
    # reachable well before "Initializations complete"/"Game start took" show up
    # in the log, since Topic() is a low-level engine hook independent of
    # subsystem readiness. This is the same var the in-game "Start Now" admin
    # verb sets (code/modules/admin/verbs/server.dm:125) - never touches
    # config.txt, so it can't affect the user's own real server. Retried every
    # poll iteration (cheap, and the topic handler genuinely isn't up in the
    # first second or so) until it succeeds once.
    forced_immediate_start = not KEY

    start_time = time.time()
    logger.info("dm_debug_boot_server: launched pid=%s map=%r, polling boot.log", proc.pid, map)
    deadline = start_time + boot_timeout
    last_progress_log = 0.0
    while time.time() < deadline:
        # This loop runs inside a single _logged_tool call that can legitimately
        # block for minutes, so its own entry/exit log lines alone would leave a
        # long silent gap on a slow boot - log progress periodically so tailing
        # the log live actually shows something moving, not just a hang.
        if time.time() - last_progress_log > 10:
            logger.info(
                "dm_debug_boot_server: still waiting, %.0fs elapsed, alive=%s",
                time.time() - start_time, proc.poll() is None,
            )
            last_progress_log = time.time()
        if proc.poll() is not None:
            log_f.close()
            with open(BOOT_LOG_FILE, "rb") as f:
                tail = f.read()[-4000:].decode(errors="replace")
            os.remove(BOOT_PID_FILE)
            raise TopicError(
                f"DreamDaemon exited early (code {proc.returncode}) before finishing boot. "
                f"Tail of boot.log:\n{tail}"
            )
        if not forced_immediate_start:
            try:
                _send_topic(
                    HOST, int(PORT),
                    f"claude_debug=1&key={KEY}&format=json&q="
                    "UPDATE /datum/controller/subsystem/ticker SET start_immediately = TRUE",
                    5,
                )
                forced_immediate_start = True
            except Exception:
                pass
        with open(BOOT_LOG_FILE, "rb") as f:
            content = f.read().decode(errors="replace")
        if "Game start took" in content:
            return (
                f"Booted on port {PORT} with map={map!r} (pid {proc.pid}), round started. "
                "dm_debug_query is ready to use. Remember to call "
                "dm_debug_stop_server when done."
            )
        time.sleep(1)

    raise TopicError(
        f"Still not ready after {boot_timeout}s. It may just need more time (a full "
        "production map's Atoms/Lighting subsystems alone can take 20-40s) - call "
        "dm_debug_stop_server if you want to give up, or just keep calling "
        "dm_debug_query anyway (it'll simply connection-refuse until actually ready)."
    )


@mcp.tool()
@_logged_tool
def dm_debug_stop_server() -> str:
    """Stop the disposable DreamDaemon instance started by dm_debug_boot_server,
    and clean up everything it left behind: kills the process (group),
    removes data/next_map.json (restoring normal map rotation for the next
    real boot in this checkout), and removes its data/logs/claude_debug_boot/
    directory.

    Safe to call even if nothing is currently tracked as booted (e.g. after
    a crash) - it no-ops the process-kill step but still clears
    next_map.json/the log dir if they happen to be present, since those are
    the parts that actually matter to get rid of.
    """
    killed = False
    if os.path.exists(BOOT_PID_FILE):
        with open(BOOT_PID_FILE) as f:
            pid = int(f.read().strip())
        try:
            os.killpg(pid, signal.SIGKILL)
            killed = True
        except ProcessLookupError:
            pass
        os.remove(BOOT_PID_FILE)

    if os.path.exists(NEXT_MAP_FILE):
        os.remove(NEXT_MAP_FILE)
    if os.path.isdir(BOOT_STATE_DIR):
        shutil.rmtree(BOOT_STATE_DIR)

    return "Stopped and cleaned up." if killed else "Nothing was tracked as running; cleaned up any leftover state anyway."


def _topic_param(value) -> str:
    """Percent-encode a value for inclusion in a claude_debug Topic() string.

    Unlike dm_debug_query's raw `q=` (SDQL text, which the DM side happens to
    tolerate unencoded), these newer params routinely carry JSON payloads
    that can contain a literal '&'/'='/'%'. Always encode so params2list()
    (DM's URL-decoding query-string parser, see world/Topic() in
    code/game/world.dm) reconstructs the exact original text.
    """
    return urllib.parse.quote(str(value), safe="")


def _claude_debug_call(**params) -> dict:
    """Shared transport for the bespoke (non-SDQL2) claude_debug branches:
    find/get_var/set_var/call_proc. See
    modular_zzmeta/modules/claude_debug/code/claude_debug.dm for the DM
    side. Raises TopicError with the DM-side error text on failure.
    """
    if not PORT:
        raise TopicError("DM_DEBUG_PORT is not set")
    if not KEY:
        raise TopicError("DM_DEBUG_KEY is not set")
    parts = ["claude_debug=1", f"key={KEY}", "format=json"]
    for name, value in params.items():
        if value is None:
            continue
        parts.append(f"{name}={_topic_param(value)}")
    raw = _send_topic(HOST, int(PORT), "&".join(parts), TIMEOUT)
    parsed = json.loads(raw)
    if "error" in parsed:
        raise TopicError(parsed["error"])
    return parsed


@mcp.tool()
@_logged_tool
def dm_debug_find(type_path: str, where: str = "", limit: int = 25) -> str:
    """Find live objects by type (+ optional SDQL WHERE filter) and get back
    real handles you can pass to dm_debug_get_var/dm_debug_set_var/
    dm_debug_call_proc - no ref-literal syntax needed.

    This is the SELECT-equivalent of dm_debug_query, but instead of
    rendering results to text (where SDQL2's {0x...}/[...] ref-literal
    syntax can't represent a DF_USE_TAG'd object you got back), it hands out
    a short-lived handle string (e.g. "h5") per match. Reuses the exact same
    tokenizer/WHERE-clause evaluator as dm_debug_query under the hood, so
    the same WHERE syntax and scoping advice applies: scope the type as
    narrowly as you can, one condition per WHERE (no &&/AND chaining - see
    dm_debug_query's own docstring for the full list of WHERE gotchas, which
    still apply here since `where` reuses the same parser).

    `limit` caps how many matches get a handle minted and returned (default
    25, hard cap 200) - the response's "total" field is the real match count
    even when truncated.

    Handles are held via weakref (never keep an object alive) and are
    evicted oldest-first past ~1000 live handles in the same server
    session, or resolve to nothing once the underlying object is deleted -
    either way a stale handle just fails cleanly with "Handle not found or
    object no longer exists", never a crash.

    Example: dm_debug_find("/mob/living/carbon/human", 'ckey == "techbot121"')

    Returns raw JSON text: {"total": N, "returned": N, "matches": [{"handle":
    "h5", "type": "/mob/living/carbon/human", "repr": "..."}]}

    Caveat, root-caused: "Test Dummy" (/mob/living/carbon/human/dummy/
    consistent) objects can fail to resolve their handle on the very next
    call ("Handle not found or object no longer exists") even with no
    delay, while ordinary named NPCs resolve reliably. This is correct
    behavior, not a bug: this type is used codebase-wide as a short-lived
    throwaway helper for icon generation (character preview, crew manifest
    portraits, antagonist setup previews - see
    code/__HELPERS/dynamic_human_icon_gen.dm,
    code/modules/antagonists/*/*.dm, code/modules/client/preferences/
    middleware/species.dm), created via a plain `new()` and torn down again
    moments later on its own schedule, unrelated to anything a caller does.
    A weakref to one going stale within moments is the tool correctly
    reporting a real deletion. If this happens, just re-run find() and use
    the freshly minted handle - or better, find() a real named mob instead
    if you don't specifically need to inspect one of these transient
    objects.
    """
    result = _claude_debug_call(find=type_path, where=where or None, limit=limit)
    return json.dumps(result, indent=2)


@mcp.tool()
@_logged_tool
def dm_debug_get_var(handle: str, var: str) -> str:
    """Read one var off a handle returned by dm_debug_find (or nested inside
    a prior dm_debug_get_var/dm_debug_call_proc result's "ref" value).

    Returns raw JSON text: {"ok": true, "value": {"t": "...", "v": ...}}.
    `value`'s "t" tag is one of: "null", "num", "text", "path", "ref" (a
    fresh handle for a nested object, plus "type"/"repr" fields), or "list"
    (a "v" array of further tagged values; assoc entries come back as
    {"k": ..., "v": ...} pairs instead of a bare value). Lists deeper than 3
    levels or longer than 200 items are truncated and marked
    "truncated": true.
    """
    result = _claude_debug_call(get_var=handle, var=var)
    return json.dumps(result, indent=2)


@mcp.tool()
@_logged_tool
def dm_debug_set_var(handle: str, var: str, value_type: str, value: str = "") -> str:
    """Write one var on a handle returned by dm_debug_find.

    `value_type` is one of "null" (`value` ignored), "num", "text", "path"
    (a DM type path as text, e.g. "/obj/item/gun/energy"), or "ref" (a
    handle string from a prior dm_debug_find/dm_debug_get_var/
    dm_debug_call_proc call - pass its "handle" or "v" string). `value` is
    the literal text/number/path-text/handle to use.

    Example: dm_debug_set_var("h5", "name", "text", "test dummy")

    Returns raw JSON text: {"ok": true} or raises with the DM-side error
    text (e.g. "No such var on this object") on failure.
    """
    if value_type == "null":
        encoded = {"t": "null"}
    elif value_type == "num":
        encoded = {"t": "num", "v": float(value)}
    elif value_type in ("text", "path", "ref"):
        encoded = {"t": value_type, "v": value}
    else:
        raise TopicError(f"Unknown value_type {value_type!r}, expected null/num/text/path/ref")
    result = _claude_debug_call(set_var=handle, var=var, value=json.dumps(encoded))
    return json.dumps(result, indent=2)


@mcp.tool()
@_logged_tool
def dm_debug_call_proc(handle: str, proc: str, args: str = "[]") -> str:
    """Call a named proc on a handle returned by dm_debug_find, with real
    argument values instead of string-interpolated SDQL syntax - no
    ref-literal ambiguity, and a thrown error inside the proc can't poison
    anything else (this bypasses SDQL2's CALL dispatch entirely, unlike
    dm_debug_query's `CALL ... ON ...`).

    `args` is a JSON array, one element per positional arg, e.g.
    '["some text", 5, null]'. Two special forms:
      - {"ref": "h5"} passes the real object behind handle "h5" (from a
        prior dm_debug_find/dm_debug_get_var/dm_debug_call_proc call).
      - {"path": "/datum/greyscale_config/sneakers"} passes a real DM type
        path, not the literal text of it - required whenever a proc expects
        an actual path argument (a plain JSON string there throws inside
        the proc instead, e.g. GetColoredIconByType()'s own ispath()
        check).
    Plain JSON strings/numbers/null pass through as DM text/num/null.

    Example: dm_debug_call_proc("h2", "GetColoredIconByType",
      '[{"path": "/datum/greyscale_config/sneakers"}, "#a1b2c3#d4e5f6"]')

    Returns raw JSON text: {"ok": true, "result": {"t": "...", "v": ...}}
    (same value encoding as dm_debug_get_var), or raises with the real
    thrown DM exception text on failure, not a generic error.
    """
    try:
        raw_args = json.loads(args)
    except json.JSONDecodeError as e:
        raise TopicError(f"args is not valid JSON: {e}")
    if not isinstance(raw_args, list):
        raise TopicError("args must be a JSON array")

    encoded_args = []
    for a in raw_args:
        if isinstance(a, dict) and "ref" in a:
            encoded_args.append({"t": "ref", "v": a["ref"]})
        elif isinstance(a, dict) and "path" in a:
            encoded_args.append({"t": "path", "v": a["path"]})
        elif a is None:
            encoded_args.append({"t": "null"})
        elif isinstance(a, (int, float)):
            encoded_args.append({"t": "num", "v": a})
        elif isinstance(a, str):
            encoded_args.append({"t": "text", "v": a})
        else:
            raise TopicError(f"Unsupported arg value: {a!r}")

    result = _claude_debug_call(call_proc=handle, proc=proc, args=json.dumps(encoded_args))
    return json.dumps(result, indent=2)


def _find_log_path(log_name: str) -> str:
    """Newest data/logs/**/<log_name>.log, or raises if none exists yet.
    Shared by dm_debug_find_log (one-shot lookup) and dm_debug_listen
    (polls this repeatedly since the file may not exist yet at call time).
    """
    pattern = os.path.join(REPO_ROOT, "data", "logs", "**", f"{log_name}.log")
    candidates = glob.glob(pattern, recursive=True)
    if not candidates:
        raise TopicError(
            f"No {log_name}.log found under data/logs/ - is a server running/has it logged anything yet?"
        )
    return max(candidates, key=os.path.getmtime)


@mcp.tool()
@_logged_tool
def dm_debug_find_log(log_name: str = "runtime") -> str:
    """Find the newest matching DreamDaemon log file under this checkout's
    data/logs/ tree, so you can tail it directly (e.g. `tail -f <path>` in a
    background Bash call + the Monitor tool, for a live-updating feed of
    server output). For watching ad-hoc debug prints specifically as they
    happen (e.g. chasing a race condition), dm_debug_listen below is usually
    more convenient - it does the polling and new-line extraction for you.

    Every DreamDaemon boot writes its own freshly timestamped/round-numbered
    directory (data/logs/YYYY/MM/DD/round-<id>/, see SetupLogs() in
    code/game/world.dm) with no fixed path - dm_debug_boot_server's own
    disposable instance is the one exception (fixed at
    data/logs/claude_debug_boot/). This searches all of data/logs/
    recursively for `<log_name>.log` and returns whichever match was
    modified most recently, so it works the same way whether you're
    tailing the disposable boot tool's server or one you started yourself
    (e.g. `tools/build/build.sh server`).

    `log_name` defaults to "runtime" - the engine's own RUNTIME:/error log,
    written natively by DreamDaemon itself (not by any code/ proc), which
    is almost always what you want for live debugging.

    Returns the file's path as plain text, or raises if nothing matches -
    check a server is actually running and has logged anything yet.
    """
    return _find_log_path(log_name)


@mcp.tool()
@_logged_tool
def dm_debug_listen(log_name: str = "debug", pattern: str = "", duration: float = 30.0) -> str:
    """Block for `duration` seconds and report every NEW line appended to a
    data/logs/**/<log_name>.log file during that window - built for chasing
    race conditions: drop a temporary debug line at each suspected point in
    the DM code, trigger the scenario, and get back exactly which lines
    fired, in what real order, with real timestamps - instead of guessing
    from a scrollback tail or adding a print and hoping you catch it.

    The natural pairing is `logger.Log(LOG_CATEGORY_DEBUG, "some tag: [var]")`
    (see code/modules/logging/log_holder.dm, code/__DEFINES/logging.dm) at
    each point you're suspicious of - it needs no category/config setup,
    always writes to human-readable `debug.log` (LOG_CATEGORY_DEBUG, config
    flag `log_as_human_readable` defaults TRUE - see
    code/controllers/configuration/entries/general.dm) with a real
    timestamp per line, and several unrelated subsystems (asset/job/lua/tts/
    mapping debug logging) funnel into that same file too - use a distinct
    tag string per debug line and pass it as `pattern` to cut the noise down
    to just yours. `log_world("...")` is the other common one-liner (see
    code/__HELPERS/logging/debug.dm) but writes to the DD engine's own
    `dd.log`/`runtime.log` instead - pass `log_name="runtime"` if you used
    that one.

    IMPORTANT: DM is not hot-reloadable like tgui - a newly added debug line
    only takes effect after tools/build/build.sh dm (--skip-icon-cutter for
    plain code changes) AND a fresh boot (dm_debug_stop_server +
    dm_debug_boot_server, or ask the user to restart their own server).
    Adding the line alone, without recompiling/rebooting, produces nothing
    for this tool to see.

    Starts reading from the file's CURRENT end (like `tail -f`, not `cat`) -
    already-logged history before this call is never included, so old noise
    from before you started investigating doesn't drown the new lines. If
    the file doesn't exist yet (nothing in that category has logged this
    round), keeps polling for it to appear for the full duration rather than
    failing immediately.

    `pattern` (optional): a plain case-insensitive substring - only lines
    containing it are returned. Leave empty to see every new line in the
    file, matched or not (useful the first time, to see the file's actual
    format/volume before narrowing down).

    Reload/retrigger the suspected race while this is running - it blocks
    for the full duration either way. Call it again for another window;
    there's no cap on how many times.

    Returns the matched lines (newline-joined, in file order = real
    chronological order), or a message noting how many total new lines
    appeared but didn't match `pattern` (so you can tell "nothing happened
    yet" apart from "it happened but under a different tag than you
    expected").
    """
    deadline = time.time() + duration
    matched: list[str] = []
    total_new_lines = 0

    # Start offset depends on whether the file already existed the moment this
    # call began: if it did, skip straight to its current size (tail -f-style -
    # don't replay old history). If it didn't, the file appearing at all during
    # the poll below means it was created fresh by this round's own logging
    # sometime after this call started - read it from byte 0 in that case, since
    # nothing in it can predate this call. Getting this backwards (always
    # seeking to "current end" only once found) loses exactly the first line(s)
    # whenever file-creation and this tool's poll land in the same ~0.3s window.
    try:
        path = _find_log_path(log_name)
        start_offset = os.path.getsize(path)
    except TopicError:
        path = None
        start_offset = 0
        while path is None and time.time() < deadline:
            time.sleep(0.3)
            try:
                path = _find_log_path(log_name)
            except TopicError:
                continue
        if path is None:
            raise TopicError(
                f"No {log_name}.log ever appeared under data/logs/ during {duration}s - "
                "is a server running, and has anything actually logged to that category yet?"
            )

    pattern_lower = pattern.lower()
    with open(path, "rb") as f:
        f.seek(start_offset)
        offset = f.tell()
        while time.time() < deadline:
            f.seek(offset)
            chunk = f.read()
            if chunk:
                offset = f.tell()
                lines = chunk.decode(errors="replace").splitlines()
                total_new_lines += len(lines)
                matched.extend(line for line in lines if not pattern_lower or pattern_lower in line.lower())
            time.sleep(0.3)

    if matched:
        return "\n".join(matched)
    if total_new_lines:
        return (
            f"{total_new_lines} new line(s) appeared in {path} during {duration}s, "
            f"but none matched pattern {pattern!r}."
        )
    return f"No new lines appeared in {path} during {duration}s."


def _run_check(name: str, cmd: list[str], stdin_path: str | None = None, timeout: float = 60.0) -> dict:
    """Run one CI-lint subprocess in REPO_ROOT and capture its outcome.
    Shared by dm_debug_run_linters for every check except dreamchecker, which
    needs bespoke handling (see that tool - its exit code isn't trustworthy).
    """
    start = time.monotonic()
    stdin_data = None
    if stdin_path:
        with open(os.path.join(REPO_ROOT, stdin_path), "rb") as f:
            stdin_data = f.read()
    try:
        result = subprocess.run(
            cmd, cwd=REPO_ROOT, input=stdin_data,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout,
        )
        return {
            "name": name, "ok": result.returncode == 0, "exit_code": result.returncode,
            "duration": time.monotonic() - start, "output": result.stdout.decode(errors="replace"),
        }
    except subprocess.TimeoutExpired as e:
        output = (e.output or b"").decode(errors="replace") + f"\n[TIMED OUT after {timeout}s]"
        return {"name": name, "ok": False, "exit_code": None, "duration": time.monotonic() - start, "output": output}
    except FileNotFoundError as e:
        return {"name": name, "ok": False, "exit_code": None, "duration": time.monotonic() - start, "output": str(e)}


def _format_check_result(r: dict) -> str:
    status = "OK  " if r["ok"] else ("SKIP" if r["ok"] is None else "FAIL")
    line = f"[{status}] {r['name']} ({r['duration']:.1f}s)"
    if "diagnostic_count" in r:
        line += f" - {r['diagnostic_count']} diagnostic(s)" if r["diagnostic_count"] is not None else " - count unparseable"
    if r["ok"] is not True:
        tail = r["output"][-3000:]
        line += f"\n{tail}"
    return line


@mcp.tool()
@_logged_tool
def dm_debug_run_linters(run_dreamchecker: bool = True, run_icon_cutter: bool = False, run_tgui_lint: bool = False) -> str:
    """Run the locally-runnable subset of .github/workflows/run_linters.yml
    (see the checklist this was built from) and report a pass/fail summary -
    a clean `tools/build/build.sh dm` compile alone does NOT catch everything
    CI checks (include ordering, unhandled local #defines, trait
    registration completeness, dreamchecker's stricter static typing). Two
    real incidents motivated this: an out-of-order #include that compiled
    fine but failed CI, and a feature whose files were missing 3 of 5
    #include lines entirely - compiled clean, ran with zero errors, and
    silently did nothing all session because none of its code was actually
    linked in. Run this after any nontrivial DM change (new files, new
    #include lines, new #defines outside __DEFINES/, trait additions) before
    calling the work done, not just a compile.

    Always runs (in order): check_genesis.sh (genesis_call.dme unchanged),
    check_grep.sh (misc grep-based style rules), ticked_file_enforcement.py
    against BOTH schemas (tgstation.dme and
    code/modules/unit_tests/_unit_tests.dm - every .dm/.dmf file needs
    exactly one #include, in strict alphabetical order; this is the check
    that catches both real incidents above), define_sanity.check (every
    local #define outside __DEFINES/__HELPERS/_globalvars needs a matching
    #undef in the same file), trait_validity.check (trait
    registration/declaration consistency), check_filedirs.sh (File DIR must
    not be ticked in tgstation.dme), and dmi.test (every .dmi parses).

    `run_dreamchecker=True` (default) additionally runs dreamchecker - a
    static-type checker stricter than the DM compiler itself, catching
    things like a weakly-typed asset-datum return where the compiler accepts
    a proc call but dreamchecker flags "requires static type". Not a
    pass/fail gate here: dreamchecker's own exit code is NOT trustworthy
    (confirmed live - it returns 0 even for a rejected/unknown argument), so
    this instead confirms the run was real by checking for its own "Parsing
    tgstation.dme..." progress line, and separately reports the "Found N
    diagnostics" count. That count is NOT necessarily caused by your
    change - this codebase can carry pre-existing diagnostics on a clean
    checkout with no relevant changes at all (confirmed live: 147 on an
    unmodified tree at the time this tool was built). Skip re-litigating
    every diagnostic; check whether any reported file:line falls inside
    something you actually touched this session before treating it as a
    real regression. If `dreamchecker` isn't on PATH, this is reported as
    skipped (not a failure) with the install command
    (`bash tools/ci/install_spaceman_dmm.sh dreamchecker`, then symlink onto
    PATH - see the project's own linter-checklist notes for why a bare
    missing-binary case can otherwise look identical to a false "clean"
    pass).

    `run_icon_cutter`/`run_tgui_lint` (both default False, opt in) run
    icon_cutter.check and `build.sh --ci lint tgui-test` - only relevant if
    icon templates or tgui/ files changed respectively, and slower, so not
    run by default.

    Deliberately NEVER runs (do not add these): check_changelogs.sh (NOT
    read-only despite the name - confirmed live it actually deleted a real
    committed changelog fragment and merged it elsewhere, meant only for an
    actual release pipeline), check_misc.sh (hard-fails immediately in this
    environment, PHP isn't installed - not a real signal here), the OpenDream
    DMCompiler (not installed, needs a separate .NET download), or the map
    checks (mapmerge2/maplint - only relevant when .dmm files changed, out
    of scope for a generic post-change lint pass).

    Returns one line per check: `[OK]`/`[FAIL]`/`[SKIP]`, its duration, and
    (only when not a clean OK) up to 3000 chars of its own output tail.
    """
    checks = [
        _run_check("check_genesis", ["bash", "tools/ci/check_genesis.sh"], timeout=30),
        _run_check("check_grep", ["bash", "tools/ci/check_grep.sh"], timeout=60),
        _run_check(
            "ticked_file_enforcement (tgstation.dme)",
            ["tools/bootstrap/python", "tools/ticked_file_enforcement/ticked_file_enforcement.py"],
            stdin_path="tools/ticked_file_enforcement/schemas/tgstation_dme.json", timeout=30,
        ),
        _run_check(
            "ticked_file_enforcement (unit_tests)",
            ["tools/bootstrap/python", "tools/ticked_file_enforcement/ticked_file_enforcement.py"],
            stdin_path="tools/ticked_file_enforcement/schemas/unit_tests.json", timeout=30,
        ),
        _run_check("define_sanity", ["tools/bootstrap/python", "-m", "tools.define_sanity.check"], timeout=60),
        _run_check("trait_validity", ["tools/bootstrap/python", "-m", "tools.trait_validity.check"], timeout=60),
        _run_check("check_filedirs", ["bash", "tools/ci/check_filedirs.sh", "tgstation.dme"], timeout=30),
        _run_check("dmi.test", ["tools/bootstrap/python", "-m", "dmi.test"], timeout=90),
    ]

    if run_icon_cutter:
        checks.append(_run_check("icon_cutter.check", ["tools/bootstrap/python", "-m", "tools.icon_cutter.check"], timeout=90))
    if run_tgui_lint:
        checks.append(_run_check("tgui lint", ["tools/build/build.sh", "--ci", "lint", "tgui-test"], timeout=300))

    if run_dreamchecker:
        if not shutil.which("dreamchecker"):
            checks.append({
                "name": "dreamchecker", "ok": None, "duration": 0.0,
                "output": "not found on PATH - install via "
                          "'bash tools/ci/install_spaceman_dmm.sh dreamchecker' then symlink onto PATH.",
            })
        else:
            start = time.monotonic()
            try:
                result = subprocess.run(
                    ["dreamchecker"], cwd=REPO_ROOT,
                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=300,
                )
                output = result.stdout.decode(errors="replace")
            except subprocess.TimeoutExpired as e:
                output = (e.output or b"").decode(errors="replace") + "\n[TIMED OUT after 300s]"
            ran_for_real = "Parsing tgstation.dme" in output
            match = re.search(r"Found (\d+) diagnostics?", output)
            checks.append({
                "name": "dreamchecker", "ok": ran_for_real,
                "diagnostic_count": int(match.group(1)) if match else None,
                "duration": time.monotonic() - start, "output": output,
            })

    lines = [_format_check_result(r) for r in checks]
    total_time = sum(r["duration"] for r in checks)
    failed = [r["name"] for r in checks if r["ok"] is False]
    summary = (
        f"{len(checks) - len(failed)}/{len(checks)} checks passed ({total_time:.1f}s total)"
        + (f" - FAILED: {', '.join(failed)}" if failed else "")
    )
    return summary + "\n\n" + "\n".join(lines)


@mcp.tool()
@_logged_tool
def dm_debug_render_atom(ref: str) -> Image:
    """Render a single atom's current flattened appearance as a PNG.

    `ref` is a BYOND object ref as printed by SDQL SELECT results, e.g.
    "[mob_3085]" from a `dm_debug_query` SELECT call. Renders the target's
    own sprite (icon + overlays like worn clothing), via getFlatIcon() -
    NOT client HUD (screen objects are never part of an atom's appearance)
    and NOT surrounding tiles (this flattens only the one target atom).
    """
    if not PORT:
        raise TopicError("DM_DEBUG_PORT is not set")
    if not KEY:
        raise TopicError("DM_DEBUG_KEY is not set")

    topic = f"claude_debug=1&key={KEY}&format=json&render_ref={ref}"
    raw = _send_topic(HOST, int(PORT), topic, TIMEOUT)
    parsed = json.loads(raw)
    if "error" in parsed:
        raise TopicError(parsed["error"])
    return Image(data=base64.b64decode(parsed["icon_base64"]), format="png")


def _find_screenshot_dir() -> str:
    for pattern in SCREENSHOT_DIR_PATTERNS:
        if not pattern:
            continue
        matches = glob.glob(pattern)
        if matches:
            return matches[0]
    raise TopicError(
        "Couldn't find a BYOND screenshots folder in any of the usual spots. "
        "Set BYOND_SCREENSHOTS to the exact path if yours is somewhere unusual."
    )


@mcp.tool()
@_logged_tool
def dm_debug_latest_screenshot(max_age_seconds: int = 120) -> Image:
    """Read back your most recent BYOND client screenshot (the F2 hotkey).

    Doesn't take the screenshot itself - BYOND's screenshot capture is a
    native client-engine hotkey with no scriptable trigger, and Wayland
    generally blocks synthetic input into other windows anyway. Press F2
    in your BYOND client yourself first, then call this.

    Raises if the newest screenshot is older than `max_age_seconds` (default
    120s), so you don't silently get shown a stale screenshot from an
    earlier session instead of what you actually just pressed F2 for.
    """
    screenshot_dir = _find_screenshot_dir()
    files = glob.glob(os.path.join(screenshot_dir, "*.png"))
    if not files:
        raise TopicError(f"No screenshots found in {screenshot_dir}")

    newest = max(files, key=os.path.getmtime)
    age = time.time() - os.path.getmtime(newest)
    if age > max_age_seconds:
        raise TopicError(
            f"Newest screenshot ({os.path.basename(newest)}) is {int(age)}s old, "
            f"older than max_age_seconds={max_age_seconds}. Press F2 in your BYOND "
            "client and try again."
        )

    with open(newest, "rb") as f:
        return Image(data=f.read(), format="png")


def _get_byond_window_geometry():
    """Best-effort lookup of the BYOND client window's on-screen (x, y, w, h).

    Returns None if it can't be determined. Callers MUST treat None as "give
    up", never as "fall back to capturing the whole screen" - an unscoped
    capture exposes every other window on the desktop (verified directly:
    a plain `grim` with no geometry grabbed a private chat app and this very
    terminal in one test). This only has a real implementation for Hyprland
    (via `hyprctl clients -j`, matched by window title); it is NOT a general
    Wayland/X11 solution. `BYOND_WINDOW_GEOMETRY` (format "X,Y WxH", same as
    grim's -g flag) is the portable escape hatch for every other setup.
    """
    override = os.environ.get("BYOND_WINDOW_GEOMETRY")
    if override:
        pos, size = override.split(" ")
        x, y = (int(v) for v in pos.split(","))
        w, h = (int(v) for v in size.split("x"))
        return x, y, w, h

    if shutil.which("hyprctl"):
        try:
            clients = json.loads(
                subprocess.check_output(["hyprctl", "clients", "-j"], timeout=5)
            )
            for c in clients:
                title = c.get("title", "")
                window_class = c.get("class", "")
                if "space station" in title.lower() or "byond" in window_class.lower():
                    x, y = c["at"]
                    w, h = c["size"]
                    return x, y, w, h
        except Exception:
            pass

    return None


@mcp.tool()
@_logged_tool
def dm_debug_screenshot_full_window() -> Image:
    """LAST RESORT: OS-level screenshot of the entire BYOND client window,
    including the sidebar (menu tabs, stat panel tabs, chat log) that
    `dm_debug_latest_screenshot` (BYOND's own F2 hotkey) does NOT capture -
    F2 only grabs the map viewport.

    Prefer `dm_debug_latest_screenshot` whenever the map view alone is
    enough; only reach for this when the sidebar/chat/stat panel itself is
    what needs inspecting.

    Not portable. Currently only works when `grim` is installed AND either
    (a) the compositor is Hyprland (auto-detects the window via `hyprctl`),
    or (b) `BYOND_WINDOW_GEOMETRY` is set manually (format "X,Y WxH", e.g.
    "1960,59 2486x1345" - get this from your compositor's own window-info
    tool). Raises clearly, and never silently captures the whole screen, if
    neither applies - an unscoped screenshot would expose every other
    window on the desktop, not just BYOND.
    """
    if not shutil.which("grim"):
        raise TopicError(
            "grim is not installed. This tool only supports Wayland compositors "
            "with grim available; there is no fallback for X11 or other "
            "screenshot tools."
        )

    geometry = _get_byond_window_geometry()
    if not geometry:
        raise TopicError(
            "Couldn't determine the BYOND window's geometry (only Hyprland "
            "auto-detection is implemented). Set BYOND_WINDOW_GEOMETRY manually, "
            "e.g. \"1960,59 2486x1345\" (X,Y WxH, same format as grim's -g flag)."
        )
    x, y, w, h = geometry

    result = subprocess.run(
        ["grim", "-g", f"{x},{y} {w}x{h}", "-"],
        capture_output=True,
        timeout=10,
    )
    if result.returncode != 0:
        raise TopicError(f"grim failed: {result.stderr.decode(errors='replace')}")

    return Image(data=result.stdout, format="png")


def _cdp_list_targets() -> list[dict]:
    url = f"http://{CDP_HOST}:{CDP_PORT}/json"
    try:
        with urllib.request.urlopen(url, timeout=5) as resp:
            return json.loads(resp.read())
    except Exception as e:
        raise TopicError(
            f"Couldn't reach the CDP endpoint at {url} ({e}). Remote debugging is "
            "probably not set up yet - see webview2-debugging.md for the one-time "
            "setup this needs (a Wine/Windows registry key, not something this "
            "tool can fix on its own)."
        )


def _resolve_target(name: str) -> dict:
    """Resolve `name` to a single CDP target: exact id match first, else a
    case-insensitive substring match against url/title. Raises clearly on zero
    or multiple matches rather than guessing."""
    targets = _cdp_list_targets()
    for t in targets:
        if t.get("id") == name:
            return t

    name_lower = name.lower()
    matches = [
        t for t in targets
        if name_lower in t.get("url", "").lower() or name_lower in t.get("title", "").lower()
    ]
    if not matches:
        available = "\n".join(f"  {t.get('title')} ({t.get('url')})" for t in targets)
        raise TopicError(f"No CDP target matched '{name}'. Available targets:\n{available}")
    if len(matches) > 1:
        titles = ", ".join(t.get("title", "?") for t in matches)
        raise TopicError(f"'{name}' matched multiple targets ({titles}) - be more specific.")
    return matches[0]


async def _cdp_send(ws_url: str, method: str, params: dict) -> dict:
    async with websockets.connect(ws_url, max_size=None) as ws:
        await ws.send(json.dumps({"id": 1, "method": method, "params": params}))
        while True:
            raw = await ws.recv()
            data = json.loads(raw)
            if data.get("id") == 1:
                return data


@mcp.tool()
@_logged_tool
def tgui_list_targets() -> str:
    """List debuggable tgui/pager browser targets over the Chrome DevTools
    Protocol (CDP) - separate from and unrelated to the SDQL/world.Topic()
    tools above, this talks directly to the embedded WebView2 browser.

    Requires the one-time remote-debugging setup in webview2-debugging.md;
    raises a clear error pointing there if it's not done yet.

    Both the pager (byond.exe) and game client (dreamseeker.exe) share the
    same debug port - tell them apart by title/url. Known game-client
    targets: browseroutput.html (chat panel), statbrowser.html (stat panel),
    tgui_say.html, typing_indicator.html, validate_assets.html, Tooltip.
    Pager targets: pagerhome.html, byond.com/rsc/ad.html.

    Returns JSON with each target's title, url, and id (pass the id, or any
    unique substring of its title/url, as `target` to tgui_eval/tgui_click).
    """
    targets = _cdp_list_targets()
    simplified = [{"id": t.get("id"), "title": t.get("title"), "url": t.get("url")} for t in targets]
    return json.dumps(simplified, indent=2)


@mcp.tool()
@_logged_tool
def tgui_find_window(query: str) -> str:
    """Find which open tgui window is which, by content rather than title.

    Most tgui interfaces (crafting menus, vending machines, any UI opened
    via browse() during normal gameplay - not the fixed chat/stat/say ones)
    show up in tgui_list_targets as generic, indistinguishable names like
    "tgui-window-1.html", "tgui-window-2.html" - the title/url alone can't
    tell you which one is, say, a supply request console versus an audio
    browser. This checks each open target's actual rendered text for `query`
    (case-insensitive substring, e.g. "supply request console") and returns
    the ones that match, with their id/title/url ready to pass to the other
    tgui_* tools as `target`.

    Slower than tgui_list_targets (queries every open target one at a time)
    - use tgui_list_targets first if you already know which target you want
    by its title/url.
    """
    targets = _cdp_list_targets()
    query_lower = query.lower()

    async def _check_all():
        matches = []
        for t in targets:
            try:
                result = await _cdp_send(t["webSocketDebuggerUrl"], "Runtime.evaluate", {
                    "expression": "document.body ? document.body.textContent.slice(0, 300) : ''",
                    "returnByValue": True,
                })
                text = result.get("result", {}).get("result", {}).get("value") or ""
            except Exception:
                continue
            if query_lower in text.lower():
                matches.append({
                    "id": t.get("id"), "title": t.get("title"), "url": t.get("url"),
                    "textSnippet": text[:150],
                })
        return matches

    matches = asyncio.run(_check_all())
    if not matches:
        return f"No open tgui window's content matched {query!r}."
    return json.dumps(matches, indent=2)


@mcp.tool()
@_logged_tool
def tgui_eval(target: str, expression: str) -> str:
    """Evaluate JavaScript in a live tgui browser target and return the result.

    `target` is a CDP target id from tgui_list_targets, or any unique
    substring of its title/url (e.g. "browseroutput" for the chat panel).
    `expression` is evaluated directly (not wrapped in a function) - for
    anything beyond a single expression, wrap it yourself:
    "(() => { ...; return x; })()".

    Read-only by convention but not enforced - this can execute arbitrary JS
    in the live page, including calling app functions or mutating state.
    Only point this at your own dev client.
    """
    t = _resolve_target(target)
    result = asyncio.run(_cdp_send(
        t["webSocketDebuggerUrl"], "Runtime.evaluate",
        {"expression": expression, "returnByValue": True},
    ))
    return json.dumps(result, indent=2)


@mcp.tool()
@_logged_tool
def tgui_click(target: str, x: float, y: float) -> str:
    """Dispatch a real mouse click at (x, y) in a live tgui browser target.

    `target` is a CDP target id from tgui_list_targets, or any unique
    substring of its title/url. Coordinates are CSS pixels relative to the
    target's own viewport (use tgui_eval with
    "el.getBoundingClientRect()" on the element first to find them).

    This is a genuine Input.dispatchMouseEvent, not a JS .click() call - it
    goes through the same input pipeline a real user's click would.
    """
    t = _resolve_target(target)
    ws_url = t["webSocketDebuggerUrl"]

    async def _click():
        async with websockets.connect(ws_url, max_size=None) as ws:
            for i, event_type in enumerate(("mousePressed", "mouseReleased"), start=1):
                await ws.send(json.dumps({
                    "id": i,
                    "method": "Input.dispatchMouseEvent",
                    "params": {"type": event_type, "x": x, "y": y, "button": "left", "clickCount": 1},
                }))
                while True:
                    raw = await ws.recv()
                    data = json.loads(raw)
                    if data.get("id") == i:
                        break

    asyncio.run(_click())
    return f"Clicked ({x}, {y}) on {t.get('title')}"


@mcp.tool()
@_logged_tool
def tgui_type(target: str, x: float, y: float, text: str) -> str:
    """Click a text field/textarea at (x, y) and type `text` into it via real
    keyboard events (Input.dispatchKeyEvent, one keyDown+keyUp per character)
    - not a JS value assignment, so it goes through the same input pipeline a
    real user typing would, including triggering React's onChange handlers.

    `target` is a CDP target id from tgui_list_targets, or any unique
    substring of its title/url. Coordinates are CSS pixels relative to the
    target's own viewport (find them via tgui_eval +
    getBoundingClientRect() on the field first).

    Does not press Enter or otherwise submit - only types into the field.
    """
    t = _resolve_target(target)
    ws_url = t["webSocketDebuggerUrl"]

    async def _type():
        async with websockets.connect(ws_url, max_size=None) as ws:
            next_id = 0

            async def send(method, params):
                nonlocal next_id
                next_id += 1
                await ws.send(json.dumps({"id": next_id, "method": method, "params": params}))
                while True:
                    raw = await ws.recv()
                    data = json.loads(raw)
                    if data.get("id") == next_id:
                        return data

            await send("Input.dispatchMouseEvent", {"type": "mousePressed", "x": x, "y": y, "button": "left", "clickCount": 1})
            await send("Input.dispatchMouseEvent", {"type": "mouseReleased", "x": x, "y": y, "button": "left", "clickCount": 1})
            for ch in text:
                await send("Input.dispatchKeyEvent", {"type": "keyDown", "text": ch})
                await send("Input.dispatchKeyEvent", {"type": "keyUp", "text": ch})

    asyncio.run(_type())
    return f"Typed {text!r} into ({x}, {y}) on {t.get('title')}"


@mcp.tool()
@_logged_tool
def tgui_screenshot(target: str) -> Image:
    """Screenshot exactly one tgui target's rendered content as a PNG - not
    the whole BYOND window, just this one panel's own viewport. No window
    manager or OS-level tooling involved at all (unlike
    dm_debug_screenshot_full_window), so this works the same on any platform
    once CDP access is set up.

    `target` is a CDP target id from tgui_list_targets, or any unique
    substring of its title/url.
    """
    t = _resolve_target(target)
    result = asyncio.run(_cdp_send(t["webSocketDebuggerUrl"], "Page.captureScreenshot", {"format": "png"}))
    data = result.get("result", {}).get("data")
    if not data:
        raise TopicError(f"Page.captureScreenshot returned no data: {json.dumps(result)}")
    return Image(data=base64.b64decode(data), format="png")


@mcp.tool()
@_logged_tool
def tgui_watch(target: str, duration: float = 5.0) -> str:
    """Watch a tgui target for `duration` seconds and report what happened:
    console output (console.log/warn/error), uncaught JS exceptions, browser
    resource-load log entries, and any failed (4xx/5xx or network-level
    failed) HTTP requests. Useful for catching intermittent bugs in the act -
    reload the panel or interact with it while this is running.

    `target` is a CDP target id from tgui_list_targets, or any unique
    substring of its title/url. Blocks for the full duration.
    """
    t = _resolve_target(target)
    ws_url = t["webSocketDebuggerUrl"]

    async def _watch():
        async with websockets.connect(ws_url, max_size=None) as ws:
            next_id = 0

            async def send(method, params=None):
                nonlocal next_id
                next_id += 1
                await ws.send(json.dumps({"id": next_id, "method": method, "params": params or {}}))

            await send("Runtime.enable")
            await send("Network.enable")
            await send("Log.enable")

            lines = []
            try:
                async with asyncio.timeout(duration):
                    while True:
                        raw = await ws.recv()
                        data = json.loads(raw)
                        method = data.get("method")
                        params = data.get("params", {})
                        if method == "Runtime.consoleAPICalled":
                            args = [a.get("value") or a.get("description") for a in params.get("args", [])]
                            lines.append(f"[console.{params.get('type')}] {args}")
                        elif method == "Runtime.exceptionThrown":
                            desc = params.get("exceptionDetails", {})
                            exc = desc.get("exception", {}).get("description", "")
                            lines.append(f"[EXCEPTION] {desc.get('text')} {exc}")
                        elif method == "Log.entryAdded":
                            entry = params.get("entry", {})
                            lines.append(f"[log/{entry.get('level')}] {entry.get('text')}")
                        elif method == "Network.responseReceived":
                            resp = params.get("response", {})
                            status = resp.get("status")
                            if status and status >= 400:
                                lines.append(f"[HTTP {status}] {resp.get('url')}")
                        elif method == "Network.loadingFailed":
                            lines.append(f"[network failed] {params.get('type')} {params.get('errorText')}")
            except TimeoutError:
                pass
            return lines

    lines = asyncio.run(_watch())
    if not lines:
        return f"No console/log/network events on {t.get('title')} during {duration}s."
    return "\n".join(lines)


# Shared by tgui_react_props: finds a DOM node's React Fiber, then walks up
# ancestors (fibers, not DOM elements - a single DOM element is often many
# component layers deep). Safe-serializes values (functions/DOM nodes/React
# elements/circular refs all become plain markers instead of crashing
# JSON.stringify) since fiber props regularly contain all of those.
_REACT_WALK_JS = """
(() => {
  const el = document.querySelector(%(selector)s);
  if (!el) return JSON.stringify({found: false, reason: "no element matches selector"});
  const fiberKey = Object.keys(el).find(k => k.startsWith('__reactFiber$'));
  if (!fiberKey) return JSON.stringify({found: true, hasFiber: false});

  const seen = new WeakSet();
  const safe = (key, value) => {
    if (typeof value === 'function') return '[Function]';
    if (value instanceof Node) return '[DOMNode ' + value.nodeName + ']';
    if (value && typeof value === 'object') {
      if (value.$$typeof) return '[ReactElement]';
      if (seen.has(value)) return '[Circular]';
      seen.add(value);
    }
    return value;
  };

  const propName = %(prop_name)s;
  let fiber = el[fiberKey];

  if (propName) {
    for (let i = 0; i < %(max_depth)s && fiber; i++) {
      if (fiber.memoizedProps && fiber.memoizedProps[propName] !== undefined) {
        return JSON.stringify({
          found: true, hasFiber: true, propFound: true, depth: i,
          value: fiber.memoizedProps[propName],
        }, safe);
      }
      fiber = fiber.return;
    }
    return JSON.stringify({found: true, hasFiber: true, propFound: false});
  }

  const chain = [];
  for (let i = 0; i < %(max_depth)s && fiber; i++) {
    if (fiber.memoizedProps) {
      const t = fiber.type;
      chain.push({
        depth: i,
        componentType: t ? (t.name || t.displayName || String(t).slice(0, 40)) : String(fiber.tag),
        propKeys: Object.keys(fiber.memoizedProps),
      });
    }
    fiber = fiber.return;
  }
  return JSON.stringify({found: true, hasFiber: true, chain}, safe);
})()
"""


@mcp.tool()
@_logged_tool
def tgui_react_props(target: str, selector: str, prop_name: str = "", max_depth: int = 15) -> str:
    """Inspect a live React component's actual props/state by walking up the
    Fiber tree from a DOM element - a lighter, scriptable alternative to
    React DevTools for when you already know roughly which element you care
    about (find it first via tgui_eval + querySelector/getBoundingClientRect).

    A single DOM node is usually wrapped by several component layers, so a
    prop you want (e.g. the data an icon/button/row was actually rendered
    with) often isn't on the element itself but on an ancestor - this walks
    up from the element and either:
      - with `prop_name` set: returns the value of the first ancestor
        component that has that exact prop name, plus how many levels up it
        was found. This is the fast path once you know the prop name.
      - with `prop_name` empty (default): returns each ancestor's component
        type and prop *names* (not values) up to `max_depth` levels, so you
        can see what's available before drilling into a specific one.

    `target` is a CDP target id from tgui_list_targets, or any unique
    substring of its title/url. `selector` is any CSS selector
    (document.querySelector semantics - matches the first element only).

    This is exactly the technique that found a real lootpanel bug during
    development: an item's spinner-forever icon turned out to be rendered
    from a component prop with icon/icon_state both null, even though the
    underlying game object's actual icon was fine - the bug was in
    lootpanel's own data serialization, not asset loading.
    """
    t = _resolve_target(target)
    expr = _REACT_WALK_JS % {
        "selector": json.dumps(selector),
        "prop_name": json.dumps(prop_name),
        "max_depth": int(max_depth),
    }
    result = asyncio.run(_cdp_send(t["webSocketDebuggerUrl"], "Runtime.evaluate", {"expression": expr, "returnByValue": True}))
    return json.dumps(result, indent=2)


if __name__ == "__main__":
    logger.info("dm_debug_server entering stdio run loop")
    try:
        mcp.run()
    except KeyboardInterrupt:
        logger.info("dm_debug_server stopped (KeyboardInterrupt)")
    except Exception:
        logger.exception("dm_debug_server crashed")
        raise
    else:
        logger.info("dm_debug_server stdio run loop exited cleanly")
