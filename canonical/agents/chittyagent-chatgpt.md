---
name: chittyagent-chatgpt
canon_uri: chittycanon://core/services/chittymarket#agents/chittyagent-chatgpt
description: Proxy to remote ChittyAgent ChatGPT integration service
kind: agent
plugin: chittyos-proxy-agents
runtimes:
  - claude-code
  - codex
  - openclaw
classification:
  - proxy
  - integration
overlay:
  title: ChatGPT Proxy Agent
  capability_group: connect
  execution_class: '@chitty/connectors'
  visibility: advanced
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
    mutation_risk: medium
  discovery:
    indexable: false
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
    job_to_be_done: generate
    environmental_footprint: write-capable
    evidentiary_risk: none
    advisory_disposition: hold
  canonical_version: 1.0.0
  group_assignment_source: name-rule
  runtime_exclusions: {}
  legacy_category: communication
---

# ChittyAgent ChatGPT

This agent proxies ChatGPT integration operations to the remote ChittyAgent service.

## Endpoint

```
https://agent.chitty.cc/api/chatgpt
```

## Usage

All ChatGPT integration operations should be forwarded to the remote ChittyAgent:

```bash
curl -X POST https://agent.chitty.cc/api/chatgpt \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $CHITTY_SERVICE_TOKEN" \
  -d '{
    "operation": "mcp|actions|plugins|troubleshoot",
    "payload": { ... }
  }'
```

## Capabilities

The remote agent handles:
- MCP Server development and configuration
- Custom GPT Actions design and implementation
- ChatGPT extensions and plugins
- Integration troubleshooting

## Authentication

Authenticate via ChittyAuth service token. The remote agent handles OpenAI API authentication internally.

## Example

```bash
# Design MCP server architecture
curl -X POST https://agent.chitty.cc/api/chatgpt \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $CHITTY_SERVICE_TOKEN" \
  -d '{
    "operation": "mcp",
    "action": "design",
    "payload": {"use_case": "database integration"}
  }'
```

Forward all ChatGPT integration requests to this endpoint. Do not execute OpenAI operations directly.
