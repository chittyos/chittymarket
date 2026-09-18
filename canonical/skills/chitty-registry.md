---
name: chitty-registry
canon_uri: chittycanon://core/services/chittymarket#skills/chitty-registry
description: Query ChittyRegistry (registry.chitty.cc) for service catalog, tiers, domains, dependencies, and certification badges. Discovery before integration.
kind: skill
plugin: chittyos-devops
runtimes:
  - claude-code
  - codex
classification:
  - operations
  - deployment
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

ChittyRegistry is a **read-only directory** (tier 2). Registration is a separate
service: submit to `https://register.chitty.cc/api/v1/register`.
*register (verb, gatekeeper) ≠ registry (noun, directory).*

### List Services
```bash
curl -s https://registry.chitty.cc/api/v1/tools | jq '.tools[].name'
```

All entries currently carry `subtype: "service"`; `?category={subtype}` filters by
that field, so `?category=service` returns the full set and any other value returns
`[]`.

### Get Service Details
```bash
# By registry id (the record's `id` / `chitty_id` field)
curl -s https://registry.chitty.cc/api/v1/tools/{id} | jq .
```

### Search Services
There is **no working server-side search.** `/api/v1/search` returns hardcoded mock
data (shell-script paths from a stale 2025 file index) regardless of `q` — it will
report 0 results for services that are registered and live. Filter client-side:

```bash
curl -s https://registry.chitty.cc/api/v1/tools \
  | jq '.tools[] | select(.name|test("auth";"i"))'
```

Same caveat applies to `/api/v1/categories` and `/api/v1/stats` — both return
hardcoded constants, not live counts.

### Verify the Endpoint List
The worker self-documents on any unknown path:
```bash
curl -s https://registry.chitty.cc/api/nonexistent | jq '.availableEndpoints'
```

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

Records are **not** uniform — two registration generations coexist in KV. Do not
assume a field exists; check it. Neither shape carries `tier`, `repo`, or
`dependencies`, so the tier table above is hand-maintained doctrine, not API data.

Cloudflare-inventory backfill shape (e.g. `chittyid`):
```json
{
  "id": "did:chitty:foundation:chittyid",
  "did": "did:chitty:foundation:chittyid",
  "name": "chittyid",
  "hostname": "id.chitty.cc",
  "url": "https://id.chitty.cc",
  "version": "2.0.0",
  "category": "service",
  "subtype": "service",
  "endpoints": { "health": "/health", "status": "/api/v1/status" },
  "security": { "auth_required": true, "scopes": ["chitty:service:read"] },
  "metadata": { "runtime": "cloudflare-worker", "probed_health": {} },
  "registered_at": "2026-05-27T16:18:00Z"
}
```

Canonical self-registration shape (e.g. `openclaw`) — note `endpoints` is an
**array** here, not an object:
```json
{
  "chitty_id": "03-1-USA-0650-T-2606-1-24",
  "entity_type": "T",
  "subtype": "service",
  "name": "openclaw",
  "version": "1.0.0",
  "endpoints": ["http://127.0.0.1:18789/health"],
  "certificate_ref": null,
  "parent_chitty_id": null,
  "compliance_score": null,
  "trust_score": null,
  "status": null,
  "health": null,
  "registered_at": "2026-06-04T10:26:52.317Z"
}
```

Known data-quality gaps (verified 2026-07-25): 48 entries total; `entity_type` is
absent on 29 of them; `chittyagent-npm` appears twice — `POST /api/v1/tools` is not
idempotent, so never re-register to "fix" an entry.

## Cross-Reference

Use with other skills:
- `/health {service}` - Check if registered service is running
- `/deploy {service}` - Deploy registered service
