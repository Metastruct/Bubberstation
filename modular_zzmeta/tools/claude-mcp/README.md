# dm-debug MCP server

Lets Claude query and mutate a running DreamDaemon dev server directly over
`world.Topic()`, instead of always cold-booting a disposable instance to
check something. Talks to the `claude_debug` topic handler in
`code/datums/world_topic.dm`, which runs SDQL2 queries
(see `code/modules/admin/verbs/SDQL2/SDQL_2.dm` for syntax) with elevated
permissions.

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
   over large object sets can legitimately take that long.

4. Boot your dev DreamDaemon as usual. The `dm_debug_query` tool will now be
   available in Claude Code sessions in this repo.

## What it can't do

- Only one query per call (no `;`-separated batches) — keeps each call's
  blast radius auditable.
- Nothing here replaces booting a disposable instance to test code that
  isn't running on your dev server yet — this only inspects/mutates a
  server that's already up.
