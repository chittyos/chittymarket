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
canonical_capability_ref: "chittycanon://capability/connect/read-and-write-neon-database"
overlay:
  title: "Read and Write Neon Database"
  capability_group: "connect"
  group_assignment_source: "name-rule"
  execution_class: "@chitty/connectors"
  canonical_version: "1.0.0"
  projection_version_policy: "inherit-canonical"
  ontology:
    primary:
      - "L"
    secondary:
      - "A"
      - "E"
  authority:
    requires_chittyid: true
  execution:
    default_surface: "ch1tty"
    local_allowed: false
    context_cost: "medium"
    mutation_risk: "low"
  discovery:
    indexable: true
    session_index: "hidden"
    ambient_by_intent: false
    verbs:
      - "connect"
      - "sync"
      - "fetch"
      - "register"
    fallback_search: true
  auth_flow:
    mode: "device-code"
    stores_credentials_in: "ChittyConnect"
    fail_closed_if_unavailable: true
  runtime_exclusions: {}
  phase0_audit:
    job_to_be_done: "route"
    environmental_footprint: "network-service"
    evidentiary_risk: "none"
    advisory_disposition: "gateway"
  legacy_category: "ecosystem"
  deprecated_aliases:
    - "neon"
  visibility: "recommended"
  access: "readwrite"
  compatible_channels:
  - claude_code
  - claude_ai
  - claude_desktop
  - chatgpt
  - codex
  - openclaw
  source_links:
  - ch1tty://servers/neon
---

# neon MCP server

Packaged by the  plugin. Canonical source of the MCP server configuration that ships in .
