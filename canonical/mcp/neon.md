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
overlay:
  title: Read and Write Neon Database
  capability_group: connect
  execution_class: '@chitty/connectors'
  visibility: recommended
  ontology:
    primary:
    - L
    secondary:
    - A
    - E
  authority:
    requires_chittyid: true
  execution:
    default_surface: ch1tty
    local_allowed: false
    context_cost: medium
    mutation_risk: low
  discovery:
    indexable: true
    session_index: hidden
    ambient_by_intent: false
    verbs:
    - connect
    - sync
    - fetch
    - register
    fallback_search: true
  auth_flow:
    mode: device-code
    stores_credentials_in: ChittyConnect
    fail_closed_if_unavailable: true
  phase0_audit:
    job_to_be_done: route
    environmental_footprint: network-service
    evidentiary_risk: none
    advisory_disposition: gateway
  canonical_version: 1.0.0
  group_assignment_source: name-rule
  runtime_exclusions: {}
  legacy_category: ecosystem
---

# neon MCP server

Packaged by the  plugin. Canonical source of the MCP server configuration that ships in .
