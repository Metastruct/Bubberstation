# Enabling WebView2 remote debugging (for tgui inspection)

BYOND's embedded browser (the window that renders tgui interfaces, chat, and
the stat panel) is Microsoft Edge WebView2 — a real Chromium browser, not a
custom or inaccessible engine. With remote debugging enabled, you get full
Chrome DevTools Protocol (CDP) access: live DOM reads, computed styles, and
real click/input simulation, all scriptable, independent of any browser
extension or `claude-in-chrome`-style tooling.

This only needs doing once per machine. It survives BYOND updates (it's a
Windows/WebView2-level setting, not a BYOND one) but is specific to *this*
Wine prefix if you're on Linux.

## Windows

Add a registry value under:

```
HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Edge\WebView2\AdditionalBrowserArguments
```

Value name: `dreamseeker.exe` (the actual game client — `byond.exe`, the
pager, shares the same browser process once this is set, so one value
covers both). Value type: `REG_SZ`. Value data: `--remote-debugging-port=9222`
(pick any free port).

**Must be `HKEY_LOCAL_MACHINE`, not `HKEY_CURRENT_USER`.** Both the env var
below and the HKCU registry path are documented alternatives, but neither
worked in testing (see the Linux/Wine section for why — the same caveat
likely applies on real Windows too, since `Software\Policies\...` paths are
Group Policy paths, normally read through a policy cache, not a live
registry read).

## Linux (Wine/Lutris)

Tested working on a Lutris + GE-Proton setup. `wine reg add` needs the
correct `WINEPREFIX` and the actual wine binary for whichever runner version
the game uses — using the wrong one silently writes to the wrong prefix.

**Find the right prefix and wine binary for a Lutris-managed game:**

```bash
# 1. Find the game's Lutris config path
sqlite3 ~/.local/share/lutris/pga.db \
  "SELECT configpath, runner FROM games WHERE name LIKE '%BYOND%';"
# -> e.g. "byond-1784230174", "wine"

# 2. Find and read that config for the actual prefix + runner version
find ~/.local/share/lutris/games -iname "byond-1784230174*"
# game.prefix in that YAML = your WINEPREFIX
# wine.version (e.g. "GE-Proton11-1") names the runner, not a path

# 3. Find the actual wine binary for that runner version
find ~/.local/share/Steam/compatibilitytools.d/GE-Proton11-1 -iname wine
```

**Write the registry key (adjust prefix/wine path to what you found above):**

```bash
export WINEPREFIX=/home/techbot/Games/byond
WINE=/home/techbot/.local/share/Steam/compatibilitytools.d/GE-Proton11-1/files/bin/wine

$WINE reg add "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Edge\WebView2\AdditionalBrowserArguments" \
  /v "byond.exe" /t REG_SZ /d "--remote-debugging-port=9222" /f
$WINE reg add "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Edge\WebView2\AdditionalBrowserArguments" \
  /v "dreamseeker.exe" /t REG_SZ /d "--remote-debugging-port=9222" /f
```

Both value names are added since it isn't obvious in advance which one
WebView2's policy lookup keys off — in practice both `byond.exe` and
`dreamseeker.exe` targets end up on the same debug port regardless, so this
costs nothing extra to be safe.

**What did NOT work, so you don't waste time re-trying it:**
- `WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS` environment variable (Lutris
  per-game `system: env:`, or any other way of setting it) — confirmed via
  `/proc/<pid>/environ` that the variable *does* reach the actual Wine
  process correctly, but the resulting WebView2 process never launches with
  the flag regardless. WebView2 is documented to ignore this env var for
  processes it considers "elevated" — plausibly Wine reports elevation
  differently than real Windows.
- The exact same registry key, but under `HKEY_CURRENT_USER` instead of
  `HKEY_LOCAL_MACHINE`. Written and confirmed present via `wine reg query`,
  but never took effect. Real Windows Group Policy (which is what
  `Software\Policies\...` represents) is normally read through a policy
  cache maintained by the Group Policy Client service, not a live registry
  read — Wine doesn't emulate that service, so HKCU values under this
  specific path may just never be read at all, regardless of correctness.

## Using it

After relaunching BYOND with the key in place:

```bash
curl http://localhost:9222/json
```

This lists every debuggable target (each with a `webSocketDebuggerUrl`).
Both the pager (`byond.exe`) and game client (`dreamseeker.exe`) share the
same port — tell them apart by `title`/`url`:
- Pager: `pagerhome.html`, `byond.com/rsc/ad.html`
- Game client: `browseroutput.html` (chat panel), `statbrowser.html` (stat
  panel), `tgui_say.html`, `typing_indicator.html`, `validate_assets.html`,
  `Tooltip`

From there, any CDP client works — e.g. Python's `websockets` library,
connecting to the target's `webSocketDebuggerUrl` and sending JSON-RPC
CDP commands (`Runtime.evaluate` for DOM reads, `Input.dispatchMouseEvent`
for real click simulation). Not yet wrapped into a `dm_debug_server.py`
tool — see that file's TODOs / project memory for status.
