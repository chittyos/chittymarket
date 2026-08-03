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
  - 'TOKEN="$(chitty-mcp-token chittymcp 2>/dev/null || true)"; if [ -n "$TOKEN" ]; then export MCP_AUTH_HEADER="Bearer $TOKEN"; fi; exec npx -y mcp-remote https://mcp.chitty.cc/mcp --header "CF-Access-Client-Id: $CF_ACCESS_CLIENT_ID" --header "CF-Access-Client-Secret: $CF_ACCESS_CLIENT_SECRET"'
  env: {}
overlay:
  title: ChittyOS MCP Gateway
  capability_group: connect
  group_assignment_source: category
  execution_class: '@chitty/connectors'
  visibility: advanced
  legacy_category: ecosystem
  canonical_version: 1.0.0
  ontology:
    primary:
    - T
    secondary:
    - E
  authority:
    requires_chittyid: true
  execution:
    default_surface: ch1tty
    local_allowed: false
    context_cost: medium
    mutation_risk: medium
  discovery:
    indexable: true
    session_index: hidden
    ambient_by_intent: false
    verbs:
    - chittyos
    - mcp
    - integration
    fallback_search: true
  auth_flow:
    mode: service-token
    stores_credentials_in: ChittyConnect
    fail_closed_if_unavailable: true
  phase0_audit:
    job_to_be_done: route
    environmental_footprint: write-capable
    evidentiary_risk: none
    advisory_disposition: route
  runtime_exclusions: {}
---

# chittyos MCP server

Packaged by the  plugin. Canonical source of the MCP server configuration that ships in .
