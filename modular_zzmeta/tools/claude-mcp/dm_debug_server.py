"""
MCP server exposing a single tool, dm_debug_query, that runs a debug query
against a live, already-running DreamDaemon instance over world.Topic(),
using the claude_debug topic handler (see code/datums/world_topic.dm).

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
import glob
import json
import os
import shutil
import signal
import socket
import struct
import subprocess
import time
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

mcp = MCPServer("dm-debug")


class TopicError(RuntimeError):
    pass


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
      NOT reliably match - go through a scalar field instead. Ref literals
      passed as CALL *arguments* (e.g. `CALL foo([mob_123]) ON ...`) work
      fine; it's specifically WHERE-clause ref-equality that's flaky.
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

    topic = f"claude_debug=1&key={KEY}&format=json&q={query}"
    return _send_topic(HOST, int(PORT), topic, TIMEOUT)


@mcp.tool()
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

    deadline = time.time() + boot_timeout
    while time.time() < deadline:
        if proc.poll() is not None:
            log_f.close()
            with open(BOOT_LOG_FILE, "rb") as f:
                tail = f.read()[-4000:].decode(errors="replace")
            os.remove(BOOT_PID_FILE)
            raise TopicError(
                f"DreamDaemon exited early (code {proc.returncode}) before finishing boot. "
                f"Tail of boot.log:\n{tail}"
            )
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


@mcp.tool()
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
    mcp.run()
