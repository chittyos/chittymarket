---
name: chittyagent-cloudflare
canon_uri: chittycanon://core/services/chittymarket#agents/chittyagent-cloudflare
description: Proxy to remote ChittyAgent Cloudflare service for infrastructure operations
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
  title: Cloudflare Proxy Agent
  capability_group: agent-runtime
  execution_class: '@chitty/connectors'
  visibility: recommended
  ontology:
    primary:
    - P
    secondary:
    - T
    - E
    - A
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
    - dispatch
    - project
    fallback_search: true
  auth_flow:
    mode: service-token
    stores_credentials_in: ChittyConnect
    fail_closed_if_unavailable: true
  phase0_audit:
    job_to_be_done: generate
    environmental_footprint: network-service
    evidentiary_risk: none
    advisory_disposition: gateway
  canonical_version: 1.0.0
  group_assignment_source: name-rule
  runtime_exclusions:
    claude_ai:
    - advanced_mode_only
    chatgpt:
    - advanced_mode_only
  legacy_category: ecosystem
---

# ChittyAgent Cloudflare

This agent proxies Cloudflare operations to the remote ChittyAgent service.

## Endpoint

```
https://agent.chitty.cc/api/cloudflare
```

## Usage

All Cloudflare operations should be forwarded to the remote ChittyAgent:

```bash
curl -X POST https://agent.chitty.cc/api/cloudflare \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $CHITTY_SERVICE_TOKEN" \
  -d '{
    "operation": "workers|pages|r2|d1|kv|dns|...",
    "action": "deploy|configure|query|...",
    "payload": { ... }
  }'
```

## Capabilities

The remote agent handles:
- Workers deployment and management
- Pages deployment and configuration
- R2 object storage operations
- D1 database operations
- KV namespace management
- DNS and zone configuration
- WAF and security settings
- Durable Objects
- Queues and Workers AI

## Authentication

Authenticate via ChittyAuth service token. The remote agent handles Cloudflare API authentication internally.

## Example

```bash
# Deploy a worker
curl -X POST https://agent.chitty.cc/api/cloudflare \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $CHITTY_SERVICE_TOKEN" \
  -d '{
    "operation": "workers",
    "action": "deploy",
    "payload": {"name": "my-worker", "code": "..."}
  }'
```

Forward all Cloudflare requests to this endpoint. Do not execute Cloudflare API calls directly.
