---
name: neon
canon_uri: chittycanon://core/services/chittymarket#mcp/neon
description: |-
  MCP server neon packaged by the neon-mcp plugin.
kind: mcp-server
plugin: neon-mcp
runtimes:
- claude-code
classification:
- mcp
- integration
mcp:
  command: /bin/sh
  args:
  - -lc
  - case "$NEON_API_KEY" in ""|*://*) echo "POLICY_BLOCKED_CREDENTIAL_UNRESOLVED: neon-mcp NEON_API_KEY is an unresolved broker reference, not a token. Route through ChittyConnect (/chico). Refusing to start." >&2; exit 78;; esac; exec npx -y @neondatabase/mcp-server-neon start "$NEON_API_KEY"
  env:
    NEON_API_KEY: chittysecrets://NEON_API_KEY
---

# neon MCP server

Packaged by the  plugin. Canonical source of the MCP server configuration that ships in .
