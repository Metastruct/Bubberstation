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

import os
import socket
import struct

from mcp.server import MCPServer

HOST = os.environ.get("DM_DEBUG_HOST", "127.0.0.1")
PORT = os.environ.get("DM_DEBUG_PORT")
KEY = os.environ.get("DM_DEBUG_KEY")
TIMEOUT = float(os.environ.get("DM_DEBUG_TIMEOUT", "90"))

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


if __name__ == "__main__":
    mcp.run()
