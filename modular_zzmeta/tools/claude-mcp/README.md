# dm-debug MCP server

Lets Claude query, mutate, and visually inspect a running DreamDaemon dev
server directly over `world.Topic()`, instead of always cold-booting a
disposable instance to check something. Talks to the `claude_debug` topic
handler in `code/datums/world_topic.dm`. Four tools:

- `dm_debug_query(query)` — runs SDQL2 queries (see
  `code/modules/admin/verbs/SDQL2/SDQL_2.dm` for syntax) with elevated
  permissions. Returns the JSON-formatted text response, including any
  object refs (e.g. `[0x20008be]`) in a SELECT's `select_text`.
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
   box.

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

4. Boot your dev DreamDaemon as usual. All four tools will now be available
   in Claude Code sessions in this repo.

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
