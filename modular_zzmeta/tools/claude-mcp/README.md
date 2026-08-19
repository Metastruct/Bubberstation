# dm-debug MCP server

Lets Claude query, mutate, and visually inspect a running DreamDaemon dev
server directly over `world.Topic()`, instead of always cold-booting a
disposable instance to check something — and, when there isn't one running
yet, boot and tear down a disposable one itself. Talks to the `claude_debug`
topic handler in `code/datums/world_topic.dm` and
`modular_zzmeta/modules/claude_debug/code/claude_debug.dm`. Also has eight
tools that bypass `world.Topic()` entirely and drive tgui's embedded browser
directly over the Chrome DevTools Protocol. Nineteen tools total.

**`dm_debug_find`/`get_var`/`set_var`/`call_proc` vs `dm_debug_query`:** the
find/get_var/set_var/call_proc family is newer and bypasses SDQL2's own
parser entirely for the common find-an-object/read-a-var/write-a-var/
call-a-proc case — real handles instead of SDQL2's fragile `{0x...}`/`[...]`
ref-literal syntax, and a thrown error can't poison later calls the way it
can with SDQL2's `CALL`. **Prefer these for anything that isn't genuinely a
freeform WHERE-filtered search** — reach for `dm_debug_query` only when you
need SDQL2's own WHERE-clause power directly (`dm_debug_find`'s `where` param
covers most of that already) or a statement type these four don't cover
(`UPDATE`/`DELETE` on a whole matched set at once, `explain`).

- `dm_debug_boot_server(map="runtimestation", boot_timeout=180.0)` — boots a
  disposable DreamDaemon in this checkout on `DM_DEBUG_PORT` and blocks until
  it's ready for `dm_debug_query` (or raises with the boot log tail if it
  died or timed out first). Automates what used to be a slow, error-prone
  manual dance: `mkdir` the log dir, drop a map into `data/next_map.json`,
  launch, poll the log for readiness. Waits for `Game start took` specifically,
  not just `Initializations complete` — those are different points in boot
  (subsystems loaded vs. the round itself finished starting/`RUNLEVEL_GAME`),
  and the gap matters: round-dependent systems (confirmed live for the
  liquids subsystem and some status-effect-driven behavior) don't work
  correctly until the round has actually started, not merely once subsystems
  are done loading. Defaults to the small `runtimestation` debug map (~11k
  lines vs. 100k+ for a production station) for noticeably faster boots and
  snappier queries — though the persistent world save data (lavaland
  dwellers, monkeys, morgue occupants) loads regardless of map, so don't
  assume a fresh boot means zero pre-existing `/mob/living/carbon/human`
  objects. **Always pair with
  `dm_debug_stop_server`** — this writes real state (`data/next_map.json`)
  in the live checkout that would otherwise hijack the user's own next real
  boot's map choice.
- `dm_debug_stop_server()` — kills the tracked disposable boot and removes
  everything it left behind (`data/next_map.json`, its log directory). Safe
  to call speculatively even if nothing is tracked as running.
- `dm_debug_query(query)` — runs SDQL2 queries (see
  `code/modules/admin/verbs/SDQL2/SDQL_2.dm` for syntax) with elevated
  permissions. Returns the JSON-formatted text response, including any
  object refs (e.g. `[0x20008be]`) in a SELECT's `select_text`. The tool's
  own docstring has a full "Tips" section learned against a real dev
  server — the short version: scope to the narrowest type + a WHERE clause
  (never a bare `/mob`, and even a filtered `/turf` can time out — reach a
  turf via a mob's `loc` instead), compare scalar fields in WHERE rather
  than ref literals or `locate()` (`self.name == "..."`, not
  `self == [mob_123]` or `WHERE loc == locate(x,y,z)`) — **`[...]` is
  *always* a list literal in SDQL, never a ref, anywhere in a query, not
  just in WHERE; passing one as a CALL argument builds a list and hands it
  to the proc instead of the real object, which can throw and poison every
  CALL for the rest of the session. Reach a nested object by chaining a
  proc call as its own MAP step instead (`MAP get_organ_slot("tail")`,
  confirmed live), never via a constructed ref literal.** (The tool now
  rejects a query containing `[word_123]`/`{word_123}` before sending it,
  for exactly this shape of mistake — see `_REF_LOOKALIKE_RE` in
  `dm_debug_server.py`.) Keep each WHERE to
  one condition (`&&`/`and` between a comparator and another comparator
  evaluates left-to-right with no precedence and silently gives wrong
  matches), avoid parens inside quoted string filters (silently matches
  nothing), don't trust a CALL's `count` as a success signal (it's normally
  0 even on a successful call — verify with a follow-up SELECT/MAP), and
  remember `/datum/component/*` types are selectable/callable too while
  `/client` is not.
- `dm_debug_find(type_path, where="", limit=25)` — the SELECT-equivalent of
  `dm_debug_query`, but hands out a short-lived handle (e.g. `"h5"`) per
  match instead of rendering results to text. Reuses SDQL2's own
  tokenizer/WHERE-clause evaluator (same syntax, same scoping advice: scope
  the type as narrowly as you can, one condition per WHERE), but only its
  search machinery — never `Execute()`, so no result-serialization or CALL
  dispatch path is ever touched. Handles are weakref-backed (never keep an
  object alive) and evicted oldest-first past ~1000 live handles.
- `dm_debug_get_var(handle, var)` — reads one var off a handle, returned as
  a tagged JSON value (`{"t": "num"/"text"/"path"/"ref"/"list"/"null", ...}`)
  — a `"ref"` value is itself a fresh handle, so nested objects (e.g. a
  mob's `loc`, or `hud_used.inventory_slots`) chain naturally without ever
  needing a ref literal.
- `dm_debug_set_var(handle, var, value_type, value="")` — writes one var.
  `value_type` is `null`/`num`/`text`/`path`/`ref` (the last two: a DM type
  path as text, or another handle string).
- `dm_debug_call_proc(handle, proc, args="[]")` — calls a named proc on a
  handle with real argument values (a JSON array; `{"ref": "h5"}` and
  `{"path": "/datum/..."}` for object/type-path args, plain JSON
  string/number/null otherwise). A thrown error inside the proc comes back
  as a normal exception with the real DM message — it can't poison later
  calls, since this never touches SDQL2's `CALL` dispatch at all.
  Live-verified against a real connected player's mob: reading
  `hud_used.inventory_slots` and a slot's `screen_loc`/`slot_id`, and
  calling `set_species()` + `regenerate_icons()` to actually change a live
  character's species — this reaches native BYOND HUD/inventory-slot state
  that the `tgui_*`/CDP tools below can't see at all (they're tgui-only).
  Caveat found live: `/mob/living/carbon/human/dummy/consistent` ("Test
  Dummy") objects are used codebase-wide as short-lived icon-generation
  throwaways (character preview, manifest portraits, antag setup previews)
  that can vanish moments after a `dm_debug_find` mints a handle for one —
  a stale-handle error there is the tool correctly reporting a real
  deletion, not a bug. Find a real named mob instead if that happens.
- `dm_debug_find_log(log_name="runtime")` — finds the newest matching
  `<log_name>.log` under `data/logs/` (recursive, since a real dev server's
  log directory is timestamped/round-numbered with no fixed path — see
  `SetupLogs()` in `code/game/world.dm`) so you can `tail -f` it directly
  (background Bash + the Monitor tool) for a live-updating feed of server
  output, instead of adding temporary debug prints and recompiling/
  rebooting to see them. Defaults to `"runtime"`, DreamDaemon's own native
  RUNTIME:/error log.
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

4. Boot your dev DreamDaemon as usual — or call `dm_debug_boot_server` to
   have Claude boot a disposable one itself. Either way, all nineteen tools
   will now be available in Claude Code sessions in this repo — except the
   eight `tgui_*` ones, which additionally need the one-time setup in
   [`webview2-debugging.md`](webview2-debugging.md) done first.

## What it can't do

- Only one query per call (no `;`-separated batches) — keeps each call's
  blast radius auditable.
- `dm_debug_boot_server` only starts a fresh disposable instance from
  whatever's already compiled to `tgstation.dmb` in this checkout — it does
  not compile for you, so run `tools/build/build.sh dm` (or with
  `--skip-icon-cutter` for plain code changes) first if you've changed code
  since the last build.
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
