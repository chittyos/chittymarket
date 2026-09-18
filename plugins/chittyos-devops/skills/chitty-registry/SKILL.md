---
name: chitty-registry
description: Query ChittyRegistry (registry.chitty.cc) for service catalog, tiers, domains, dependencies, and certification badges. Discovery before integration.
canon_uri: chittycanon://core/services/chittymarket#skills/chitty-registry
---

# ChittyOS Registry Skill

## Overview
Query and manage the ChittyOS service registry for service discovery and metadata.

## Usage
```
/registry [command] [args]
```

## Commands

| Command | Description |
|---------|-------------|
| `list` | List all registered services |
| `get [service]` | Get service details |
| `search [query]` | Search services by name/description |
| `tiers` | Show services grouped by tier |
| `status` | Show registration status of all services |

## Registry API

Base URL: `https://registry.chitty.cc`

> **`/api/services` does not exist and never did — it returns HTTP 404** with the server's
> own route list. Verified live 2026-09-18. The only KV-backed source of truth is
> **`/api/v1/tools`**.

### List Services — the only authoritative read
```bash
curl -s https://registry.chitty.cc/api/v1/tools | jq .
```

Each record carries `chitty_id`, `entity_type`, `subtype`, `name`, `description`, `version`,
`endpoints`, `certificate_ref`, `parent_chitty_id`, `metadata`, `compliance_score`,
`trust_score`.

### Get Service Details
```bash
curl -s https://registry.chitty.cc/api/v1/tools/{chitty_id} | jq .
```

### Search Services — filter the full list locally
```bash
curl -s https://registry.chitty.cc/api/v1/tools \
  | jq '[.tools[]? // .[]? | select(.name|test("QUERY";"i"))]'
```

> **Do NOT use `/api/v1/search`, `/api/v1/categories`, or `/api/v1/stats` for discovery.**
> Those three handlers return **hardcoded mock data**
> (`universal-registry-worker.js` → `searchRegistry()`), not live registry contents:
> `?q=chittyauth` returns 0 results while the service is registered and live. Filter
> `/api/v1/tools` yourself instead.

The registry is a **directory, not a gatekeeper**. New registrations are submitted to
`register.chitty.cc/api/v1/register` — this skill has no `register` verb, and registration
is a sensitive-intent mutation that routes through ChittyConnect.

### What the registry does and does not catalog

It catalogs **deployed services** — things with an endpoint and a health check. Every
`chittyagent-*` entry present is registered as `subtype: service` because it is a worker,
not because it is an agent definition.

**Agent/skill definitions are NOT ChittyRegistry artifacts.** A prompt definition projected
to Claude Code / Codex / OpenClaw has no endpoint to discover; it belongs in the
orchestrator KV discovery index (`agent:index` / `skill:index` at agent.chitty.cc), which is
a different registry with a different contract. Do not register one here.

## Local Registry CSV — REMOVED

The former fallback at `/Volumes/chitty/temp/systems-registry-import-v3.csv` **no longer
exists on any current host** (it was a macOS path) and must not be cited. **ChittyRegistry
is authoritative over any local snapshot.** If the API is unreachable, say so and treat the
result as unknown — do not substitute a stale file.

## Service Tiers

| Tier | Purpose | Services |
|------|---------|----------|
| 0 | Trust Anchors | ChittyID, ChittyTrust, ChittySchema |
| 1 | Core Identity | ChittyAuth, ChittyCert, ChittyRegister |
| 2 | Platform | ChittyConnect, ChittyRouter, ChittyAPI |
| 3 | Operational | ChittyMonitor, ChittyDiscovery, ChittyBeacon |
| 4 | Domain | ChittyEvidence, ChittyIntel, ChittyScore |
| 5 | Application | ChittyCases, ChittyPortal, ChittyDashboard |

## Service Metadata Schema

```json
{
  "id": "chittyid",
  "name": "ChittyID",
  "tier": 0,
  "domain": "id.chitty.cc",
  "repo": "CHITTYFOUNDATION/chittyid",
  "status": "live",
  "endpoints": {
    "health": "/health",
    "api": "/api/v1",
    "mcp": "/mcp"
  },
  "dependencies": []
}
```

## Cross-Reference

Use with other skills:
- `/health {service}` - Check if registered service is running
- `/deploy {service}` - Deploy registered service
