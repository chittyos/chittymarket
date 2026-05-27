---
name: ch1tty-fetch
canon_uri: chittycanon://core/services/chittymarket#tools/ch1tty-fetch
description: |
  Fetch the full definition for a single tool from the Ch1tty tool registry
  by its namespaced id (e.g. `serverId/toolName`). Returns the canonical
  tool record including title, prose, source URL, and optional metadata.

  This is the companion fetch tool to `ch1tty-search` and together they
  form the search+fetch pair required for ChatGPT Apps SDK
  "company knowledge" connector eligibility (Business/Enterprise/Edu).

  Read-only lookup; safe to call repeatedly. Open-world because tool ids
  resolve through arbitrary upstream MCP servers bridged by the gateway.
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
    id:
      type: string
      description: |
        Tool identifier (`serverId/toolName`) returned by `ch1tty-search`.
        Treated as opaque by the gateway; resolves to a registered tool.
  required:
    - id
  additionalProperties: false
output_schema:
  type: object
  properties:
    id:
      type: string
      description: The same tool id that was requested.
    title:
      type: string
      description: Human-readable tool title (typically the tool name).
    text:
      type: string
      description: |
        Full prose description / documentation body for the tool, suitable
        for the ChatGPT "company knowledge" connector to display and embed.
    url:
      type: string
      description: |
        Canonical URL pointing back to the source of truth for this tool
        (e.g. its entry in the Ch1tty registry or upstream catalog).
    metadata:
      type: object
      description: |
        Optional opaque object carrying additional context (input_schema,
        safety_class, world_class, upstream server id, version, etc.).
        Consumers MAY ignore unknown fields.
      additionalProperties: true
  required:
    - id
    - title
    - text
    - url
  additionalProperties: false
file_params: []
---

# Ch1tty Fetch

Fetch the full registry record for a single tool by its namespaced id.

## Usage

```
ch1tty-fetch { "id": "ch1tty/execute" }
ch1tty-fetch { "id": "neon/run_sql" }
```

## Why this exists

ChatGPT Apps SDK requires a `search` + `fetch` tool pair with MCP-spec
shapes for the "company knowledge" connector path (Business / Enterprise /
Edu). `ch1tty-search` returns `{ results: [{ id, title, url }] }`; this
tool completes the pair by resolving a single `id` into the full
`{ id, title, text, url, metadata? }` record.

## Why read_only

Pure registry lookup — no state mutation, no external writes. Projects to
`readOnlyHint: true, destructiveHint: false` on both the Claude Skills
descriptor and the ChatGPT Apps descriptor.

## Why open_world

The tool id space spans every upstream MCP server bridged by the gateway.
The set is unbounded; `openWorldHint: true`.
