---
name: ch1tty-search
canon_uri: chittycanon://core/services/chittymarket#tools/ch1tty-search
description: |
  Search the Ch1tty tool registry. Returns matching tool names, descriptions,
  and input schemas for tools registered with the Ch1tty gateway (chitty.cc
  surface + upstream MCP servers). Use this BEFORE `ch1tty/execute` to
  discover the canonical namespaced tool id and required arguments.

  Read-only query; safe to call repeatedly. Open-world because it queries
  arbitrary upstream registries that the gateway is currently bridging.
kind: tool
plugin: ch1tty
runtimes:
  - claude-skills
  - chatgpt-apps
safety_class: read_only
world_class: open_world
visibility: public
target_visibility:
  - model
  - app
input_schema:
  type: object
  properties:
    query:
      type: string
      description: |
        Free-text search query matched against tool name, namespaced id,
        and description. Returns all tools whose metadata contains the
        query as a case-insensitive substring.
    limit:
      type: integer
      description: Maximum number of results to return.
      default: 20
      minimum: 1
      maximum: 100
  required:
    - query
  additionalProperties: false
output_schema:
  type: object
  properties:
    results:
      type: array
      items:
        type: object
        properties:
          name:
            type: string
            description: Namespaced tool id (e.g. `ch1tty/execute`, `serverId/toolName`).
          description:
            type: string
            description: Human-readable tool description.
          input_schema:
            type: object
            description: JSON Schema for the tool's input arguments.
        required:
          - name
          - description
          - input_schema
        additionalProperties: true
    truncated:
      type: boolean
      description: True when more matches existed than `limit` allowed.
  required:
    - results
  additionalProperties: false
file_params: []
---

# Ch1tty Search

Search the Ch1tty tool registry by free-text query. Returns tool names,
descriptions, and input schemas suitable for feeding directly into
`ch1tty/execute`.

## Usage

```
ch1tty-search { "query": "neon database" }
ch1tty-search { "query": "evidence", "limit": 5 }
```

## Why read_only

This tool only reads from in-memory registry state and upstream MCP server
metadata. No state mutation, no external writes. Mislabeling as
`DESTRUCTIVE` (the current production state — see
`reference_skill_platform_metadata.md`) forces user-approval gating on
every search, which kills the discoverability UX. This canonical projects
to `readOnlyHint: true, destructiveHint: false`.

## Why open_world

The registry aggregates tools from upstream MCP servers whose set is not
bounded — any registered server contributes its toolset. `openWorldHint: true`.
