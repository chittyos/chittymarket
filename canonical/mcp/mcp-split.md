---
name: mcp-split
canon_uri: chittycanon://core/services/chittymarket#mcp/mcp-split
description: Report on MCP config split
kind: mcp
classification:
  - report
runtimes: []
plugin: chittyos-core
---

# MCP Config Consolidation

Currently, MCP servers are split between two locations:
1. `~/.gemini/config/mcp_config.json` (7 servers)
2. `~/.claude/.mcp.json` (3 servers)

## Canonical Home
The canonical home for MCP server configurations should be `canonical/mcp/` within `chittymarket`.
Changes to MCP configs must be done via canonical definitions, and the `chittyagent-dispatch` hook will project the unified configuration to both `mcp_config.json` and `.mcp.json`.

## Consolidation Plan
1. **Extract**: Move the definitions from `~/.gemini/config/mcp_config.json` and `~/.claude/.mcp.json` into individual `canonical/mcp/<server-name>.md` (or `.json`) files.
2. **Dispatch**: Ensure the dispatch hook understands how to aggregate all `mcp` kind definitions and write to both `~/.gemini/config/mcp_config.json` and `~/.claude/.mcp.json`.
3. **Enforce**: Block manual edits to the local `mcp_config.json` or `.mcp.json` files via the dispatch hook.
