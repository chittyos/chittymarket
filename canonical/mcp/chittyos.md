---
name: chittyos
canon_uri: chittycanon://core/services/chittymarket#mcp/chittyos
description: |-
  MCP server chittyos packaged by the chittyos-mcp plugin.
kind: mcp-server
plugin: chittyos-mcp
runtimes:
- claude-code
classification:
- mcp
- integration
mcp:
  command: /bin/sh
  args:
  - -lc
  - >-
    TOKEN="$(chitty-mcp-token chittymcp 2>/dev/null || true)"; if [ -n "$TOKEN" ]; then export MCP_AUTH_HEADER="Bearer $TOKEN"; fi; exec npx -y mcp-remote https://mcp.chitty.cc/mcp --header "CF-Access-Client-Id: $CF_ACCESS_CLIENT_ID" --header "CF-Access-Client-Secret: $CF_ACCESS_CLIENT_SECRET"
  env: {}
---

# chittyos MCP server

Packaged by the  plugin. Canonical source of the MCP server configuration that ships in .
