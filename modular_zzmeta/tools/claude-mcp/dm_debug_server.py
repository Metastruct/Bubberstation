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

import base64
import glob
import json
import os
import shutil
import socket
import struct
import subprocess
import time

from mcp.server import MCPServer
from mcp.server.mcpserver import Image

HOST = os.environ.get("DM_DEBUG_HOST", "127.0.0.1")
PORT = os.environ.get("DM_DEBUG_PORT")
KEY = os.environ.get("DM_DEBUG_KEY")
TIMEOUT = float(os.environ.get("DM_DEBUG_TIMEOUT", "90"))

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

    Returns the raw text response from the server (JSON-formatted).
    """
    if not PORT:
        raise TopicError("DM_DEBUG_PORT is not set")
    if not KEY:
        raise TopicError("DM_DEBUG_KEY is not set")

    topic = f"claude_debug=1&key={KEY}&format=json&q={query}"
    return _send_topic(HOST, int(PORT), topic, TIMEOUT)


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


if __name__ == "__main__":
    mcp.run()
