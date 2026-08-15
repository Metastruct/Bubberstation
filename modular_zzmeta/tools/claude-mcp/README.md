# dm-debug MCP server

Lets Claude query, mutate, and visually inspect a running DreamDaemon dev
server directly over `world.Topic()`, instead of always cold-booting a
disposable instance to check something. Talks to the `claude_debug` topic
handler in `code/datums/world_topic.dm`. Also has eight tools that bypass
`world.Topic()` entirely and drive tgui's embedded browser directly over the
Chrome DevTools Protocol. Twelve tools total:

- `dm_debug_query(query)` — runs SDQL2 queries (see
  `code/modules/admin/verbs/SDQL2/SDQL_2.dm` for syntax) with elevated
  permissions. Returns the JSON-formatted text response, including any
  object refs (e.g. `[0x20008be]`) in a SELECT's `select_text`. The tool's
  own docstring has a full "Tips" section learned against a real dev
  server — the short version: scope to the narrowest type + a WHERE clause
  (never a bare `/mob`), compare scalar fields in WHERE rather than ref
  literals (`self.name == "..."`, not `self == [mob_123]`), and remember
  `/datum/component/*` types are selectable/callable too while `/client`
  is not.
- `dm_debug_render_atom(ref)` — flattens one atom's current sprite (icon +
  overlays, via `getFlatIcon()`) to a PNG and returns it as an image, given
  a ref from a prior `dm_debug_query` SELECT. Separate from the query path
  because SDQL2's `CALL` discards proc return values, so there's no way to
  get image data back out through a query alone.
- `dm_debug_latest_screenshot(max_age_seconds=120)` — reads back your most
  recent BYOND client screenshot (the F2 hotkey). Doesn't trigger the
  screenshot itself — that's a native client-engine hotkey with no
  scriptable trigger, and Wayland blocks synthetic input into other windows
  anyway — press F2 yourself first, then call this. Errors out if the
  newest screenshot is older than `max_age_seconds`, so you don't get shown
  a stale one from an earlier session by mistake. Doesn't talk to
  DreamDaemon at all, so it works even if your dev server isn't up.
  F2 only captures the map viewport — it does **not** include the sidebar
  (menu tabs, stat panel tabs, chat log). Use the next tool for that.
- `dm_debug_screenshot_full_window()` — **last resort.** OS-level screenshot
  of the whole BYOND client window, sidebar included. Not portable: needs
  `grim` installed, and either Hyprland (auto-detects the window) or a
  manual `BYOND_WINDOW_GEOMETRY` override for any other compositor. Prefer
  `dm_debug_latest_screenshot` whenever the map alone is enough — reach for
  this only when the sidebar/chat/stat panel itself needs inspecting. Never
  falls back to capturing the whole screen if it can't find the BYOND
  window specifically — an early unscoped test of this confirmed a plain,
  ungeometried screenshot pulls in every other open window too (a private
  chat app, this very terminal), so the tool raises instead of guessing.

**The rest bypass `world.Topic()` entirely** and talk directly to tgui's
embedded WebView2 browser over the Chrome DevTools Protocol (CDP). Needs a
one-time setup — see [`webview2-debugging.md`](webview2-debugging.md) — that
these tools can't detect or do for you; they'll just fail to connect with a
clear error if it's missing.

**These are client-scoped, not server-scoped** — CDP attaches to your local
BYOND client's browser process directly, entirely independent of which
server that client happens to be connected to (unlike `dm_debug_*`, which is
inherently tied to whatever DreamDaemon is on `DM_DEBUG_PORT`). That cuts
both ways: it'll work against a remote/production session just as well as a
local dev one, but that also means `tgui_click` there dispatches a real
click with real, consequential in-game effects — not a moot local test
action. Be deliberate about what you're connected to before using it.

- `tgui_list_targets()` — lists every debuggable browser target (the pager
  and the game client share one debug port, distinguishable by title/url —
  see the doc above for known target names). Returns each target's `id`,
  `title`, `url`. Most gameplay interfaces (crafting menus, vending
  machines, anything opened via `browse()`) show up here as generic,
  indistinguishable names like `tgui-window-1.html` — use the next tool to
  tell them apart.
- `tgui_find_window(query)` — finds which open target is which by content,
  not title. Checks each open target's actual rendered text for `query`
  (case-insensitive substring, e.g. `"supply request console"`) and returns
  the matches with their id/title/url. Slower than `tgui_list_targets`
  (queries every open target) — use that first if you already know the
  target by title/url.
- `tgui_eval(target, expression)` — evaluates JavaScript in a live target and
  returns the result. `target` is an id from `tgui_list_targets`, or any
  unique substring of its title/url (e.g. `"browseroutput"`). Real DOM
  access — read chat content, computed styles, `getBoundingClientRect()`,
  anything. Not access-controlled beyond the CDP port itself being local.
- `tgui_click(target, x, y)` — dispatches a genuine
  `Input.dispatchMouseEvent` click at CSS-pixel coordinates in a target
  (relative to its own viewport) — goes through the same input pipeline a
  real click would, not a JS `.click()` call. Find coordinates first via
  `tgui_eval` and `getBoundingClientRect()`.
- `tgui_type(target, x, y, text)` — clicks (x, y) then types `text` via real
  `Input.dispatchKeyEvent` events, one per character — goes through React's
  normal input handling, not a raw value assignment. Doesn't submit
  (no Enter keypress) — only types into the field.
- `tgui_screenshot(target)` — PNG of exactly one target's own rendered
  content, no window manager or OS-level tooling involved at all (unlike
  `dm_debug_screenshot_full_window`) — works identically on any platform once
  CDP access is set up.
- `tgui_watch(target, duration=5.0)` — blocks for `duration` seconds and
  reports everything that happened on a target: console output, uncaught JS
  exceptions, browser resource-load log entries, and failed/4xx/5xx network
  requests. Reload or interact with the panel while it's running to catch
  something intermittent in the act — this is what actually found a real bug
  during this tool's own development: a "blank white chat" symptom traced to
  the panel's bootstrap script silently failing to fire `Byond.loadJs`/
  `loadCss` on some reconnects, with no crash or visible error at all.
- `tgui_react_props(target, selector, prop_name="", max_depth=15)` — inspect
  a live React component's actual props by walking up the Fiber tree from a
  DOM element (find the element first via `tgui_eval` +
  `document.querySelector`/`getBoundingClientRect`). A DOM node is usually
  wrapped by several component layers, so the prop you want often isn't on
  the element itself:
  - `prop_name` set: returns the value of the first ancestor component that
    has that exact prop, and how many levels up it was found.
  - `prop_name` empty (default): returns each ancestor's component type and
    prop *names* only, so you can see what's available before drilling in.

  This is exactly what found a real lootpanel bug during development: an
  item stuck on the loading spinner forever turned out to be rendered from
  a component prop with `icon`/`icon_state` both `null`, even though the
  underlying game object's actual icon was completely fine (confirmed via
  `dm_debug_query`) — the bug was in lootpanel's own data serialization for
  complex-icon items, not asset loading or a stale hash.

**Only point this at your own local dev server, never a shared or live one.**
The endpoint grants superuser SDQL access (arbitrary var get/set and proc
calls via `UPDATE`/`CALL`), gated only by a shared key and a loopback-only
check on the caller's address.

## Setup

1. Set a real key in your local `config/comms.txt` (not the default, at
   least 7 characters):

   ```
   CLAUDE_DEBUG_KEY your_own_secret_here
   ```

   Leave it commented out (the default) on anything other than your own dev
   box. If you change this on a server that's already running, use a full
   DreamDaemon restart to apply it — the in-game "Reload Configuration"
   admin verb was tested directly and did not reliably pick up the new key.

2. Create the venv and install dependencies (only needs doing once):

   ```
   cd modular_zzmeta/tools/claude-mcp
   python3 -m venv venv
   ./venv/bin/pip install -r requirements.txt
   ```

3. Register the server with Claude Code, pointing at your dev server's port
   and the key from step 1. Either add this to a `.mcp.json` (project-local,
   don't commit it since it contains your key), or run `claude mcp add`:

   ```json
   {
     "mcpServers": {
       "dm-debug": {
         "command": "/absolute/path/to/modular_zzmeta/tools/claude-mcp/venv/bin/python",
         "args": ["/absolute/path/to/modular_zzmeta/tools/claude-mcp/dm_debug_server.py"],
         "env": {
           "DM_DEBUG_PORT": "1337",
           "DM_DEBUG_KEY": "your_own_secret_here"
         }
       }
     }
   }
   ```

   `DM_DEBUG_HOST` defaults to `127.0.0.1` (the handler rejects non-loopback
   callers anyway). `DM_DEBUG_TIMEOUT` defaults to 90 seconds — SDQL queries
   over large object sets can legitimately take that long. `BYOND_SCREENSHOTS`
   overrides the auto-detected screenshots folder if yours isn't found
   automatically (checks the usual Windows/Wine/Lutris/Steam/WSL spots).
   `BYOND_WINDOW_GEOMETRY` (format `"X,Y WxH"`, e.g. `"1960,59 2486x1345"`)
   is only needed for `dm_debug_screenshot_full_window` on a non-Hyprland
   compositor — get the values from your compositor's own window-info tool.
   `TGUI_CDP_HOST`/`TGUI_CDP_PORT` (default `127.0.0.1`/`9222`) only matter
   for the eight `tgui_*` tools, and only if you set up remote debugging on
   a port other than 9222.

4. Boot your dev DreamDaemon as usual. All twelve tools will now be
   available in Claude Code sessions in this repo — except the eight
   `tgui_*` ones, which additionally need the one-time setup in
   [`webview2-debugging.md`](webview2-debugging.md) done first.

## What it can't do

- Only one query per call (no `;`-separated batches) — keeps each call's
  blast radius auditable.
- Nothing here replaces booting a disposable instance to test code that
  isn't running on your dev server yet — this only inspects/mutates a
  server that's already up.
- `dm_debug_render_atom` renders one atom's own sprite only — no client HUD
  (screen objects aren't part of an atom's appearance), no surrounding
  tiles/map.
- `dm_debug_latest_screenshot` can't trigger the screenshot for you — you
  have to press F2 yourself, this only reads the result back.
- The `tgui_*` tools need remote debugging enabled first (see
  `webview2-debugging.md`) — there's no fallback or auto-setup, they just
  fail to connect until that's done.
- `tgui_click`/`tgui_type` need coordinates you already know (from
  `tgui_eval` + `getBoundingClientRect()`) — there's no "find and click this
  button by text" convenience yet.
- No viewport-resize tool, deliberately. `Emulation.setDeviceMetricsOverride`
  was tested directly against the raw CDP connection and works, but
  `clearDeviceMetricsOverride` didn't reliably restore the real size — only
  a full `Page.reload()` fixed it, which risks re-triggering the bootstrap
  bug mentioned above. `tgui_eval` can't reach this anyway (it only sends
  `Runtime.evaluate`, not arbitrary CDP methods) — not worth wrapping into a
  tool given the risk to a live session; if you need it, use `_cdp_send`
  from a throwaway script and be ready to `Page.reload()` immediately after.
