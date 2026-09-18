---
name: chitty-registry
canon_uri: chittycanon://core/services/chittymarket#skills/chitty-registry
description: Read-only discovery against ChittyRegistry (registry.chitty.cc) via GET /api/v1/tools — the service catalog with per-record trust and compliance scores, certificate refs and endpoints. Discovery before integration. Does not register, update or delete; there is no tier, domain or dependency field to query.
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
**Read-only** discovery against the ChittyOS service registry. This skill queries; it does
not register, update, or delete. Registration is a sensitive-intent mutation submitted to
`register.chitty.cc` and routed through ChittyConnect — not performed here.

## Usage
```
/registry [command] [args]
```

## Commands

| Command | Description |
|---------|-------------|
| `list` | List all registered services — `GET /api/v1/tools` |
| `get [chitty_id]` | Get one record — `GET /api/v1/tools/{chitty_id}` |
| `search [query]` | Fetch the full list and filter it **locally**; the server's `/api/v1/search` is unusable (see below) |
| `status` | Report each record's own `status`/`compliance_score`/`trust_score` fields — **not** `/api/v1/stats`, which is unusable |

**`tiers` has been removed.** There is no `tier` field on any registry record, so there is
nothing to group by — see "Service Tiers" below.

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

## Service Tiers — conceptual only, NOT a registry field

The tier model (0 Trust Anchors → 5 Application) is an architectural convention described in
the operator's CLAUDE.md. **It is not a field on any registry record and cannot be queried.**
Verified live 2026-09-18: no record in `/api/v1/tools` carries `tier`.

Earlier revisions of this file printed a tier→services table. It has been removed because it
was hand-maintained lore presented as catalog: it listed services that are **not registered
at all** (ChittyTrust, ChittyConnect, ChittyRouter, ChittyMonitor, ChittyScore, ChittyCases,
ChittyPortal, ChittyDashboard were all absent from the live 49), and it dropped ChittyCertify,
which the operator's CLAUDE.md places in Tier 1. **Do not reintroduce a services-by-tier
table here.** If you need the tier of a service, cite CLAUDE.md or the service's own
compliance triad — never this file, and never the registry.

## Service Metadata Schema — read from the live API

**Verified against all 49 live records, 2026-09-18.** Response shape is
`{"success": true, "tools": [...]}`. Each record carries:

`chitty_id`, `entity_type`, `subtype`, `name`, `description`, `version`, `endpoints`,
`certificate_ref`, `parent_chitty_id`, `metadata`, `compliance_score`, `trust_score`

Two traps, both of which previous revisions of this file got wrong by publishing an invented
example record:

- **There is no `tier`, `domain`, `repo`, or `dependencies` field.** Zero of 49 records carry
  any of them. Filtering on `.tier` returns nothing and reads as "unregistered".
- **`endpoints` is an ARRAY of absolute URLs**, not an object of paths. `.endpoints.health`
  does not exist; the identifier field is `chitty_id`, not `id`.

Read the shape from the API rather than from any example — including this one. Several
records are incomplete in production (missing `chitty_id`, `entity_type` and scores), so
absence of a field on one record is not evidence about the schema.


## Cross-Reference

Use with other skills:
- `/health {service}` - Check if registered service is running
- `/deploy {service}` - Deploy registered service
