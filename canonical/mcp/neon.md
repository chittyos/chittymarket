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
  - exec npx -y @neondatabase/mcp-server-neon start "$NEON_API_KEY"
  env:
    NEON_API_KEY: op://ChittyOS-Integrations/neon/api_key
---

# neon MCP server

Packaged by the  plugin. Canonical source of the MCP server configuration that ships in .
