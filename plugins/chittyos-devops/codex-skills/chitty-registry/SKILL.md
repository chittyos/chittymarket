---
name: chitty-registry
description: Read-only discovery against ChittyRegistry (registry.chitty.cc) via GET /api/v1/tools — the service catalog with per-record trust and compliance scores, certificate refs and endpoints. Discovery before integration. Does not register, update or delete; there is no tier, domain or dependency field to query.
canon_uri: chittycanon://core/services/chittymarket#skills/chitty-registry
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

**Record shape varies — see "Service Metadata Schema — TWO shapes" below before writing any
filter.** Only 20 of 49 records carry `chitty_id`, `entity_type`, `certificate_ref`,
`compliance_score` and `trust_score`; the other 29 are keyed on `id`/`did` and carry a
different field set. Seven fields are common to all 49.

### Get Service Details
```bash
curl -s https://registry.chitty.cc/api/v1/tools/{chitty_id} | jq .
```

### Search Services — filter the full list locally
```bash
curl -s https://registry.chitty.cc/api/v1/tools \
  | jq '[.tools[] | select((.name // "") | test("QUERY";"i"))]'
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

## Service Metadata Schema — TWO shapes, read from the live API

**Verified 2026-09-18 by pulling all 49 records and taking the field union.** Response shape
is `{"success": true, "count": N, "tools": [...]}`.

> ⚠️ **A previous revision of this file claimed `endpoints` is always an array and the
> identifier is always `chitty_id`. That was wrong for the majority of the catalog**, and it
> carried a verification date, which made it more likely to be trusted. It was written from a
> sample and reported as if from the whole. Both claims are corrected below.

**The registry holds two disjoint record shapes.** Neither is "incomplete"; they are
different, and code that assumes one silently drops the other.

| | Shape A — governed | Shape B — health-registered |
|---|---|---|
| Count (of 49) | **20** | **29** |
| Identifier | `chitty_id` | `id` (plus `did`) |
| `endpoints` | **array** of absolute URLs | **object** |
| Fields only on this shape | `certificate_ref`, `chitty_id`, `compliance_score`, `entity_type`, `health`, `last_health_check`, `last_health_error`, `parent_chitty_id`, `status`, `trust_score`, `updated_at` | `category`, `did`, `hostname`, `id`, `registration_source`, `schema`, `security`, `url` |

Shared by all 49 (the true intersection, computed — **7 fields**, not five):
`description`, `endpoints`, `metadata`, `name`, `registered_at`, `subtype`, `version` — note `endpoints` is shared in name only, differing in type.

> ⚠️ **An earlier revision of this table put `health`, `last_health_check`,
> `last_health_error` and `updated_at` on Shape B. They are Shape A fields — 20/20 on A and
> **zero** on B — and `registered_at`/`subtype` are shared, not distinctive. That table was
> written from impression after the data had already been computed. The rows above are
> generated from the live field union; regenerate them rather than editing by hand.**

**The full field union across the catalog is 26 keys:**
`category`, `certificate_ref`, `chitty_id`, `compliance_score`, `description`, `did`,
`endpoints`, `entity_type`, `health`, `hostname`, `id`, `last_health_check`,
`last_health_error`, `metadata`, `name`, `parent_chitty_id`, `registered_at`,
`registration_source`, `schema`, `security`, `status`, `subtype`, `trust_score`,
`updated_at`, `url`, `version`.

**Consequences for the commands above:**
- `get` by `chitty_id` reaches only the 20 Shape-A records. For Shape B, match on `id`.
- Never key on `endpoints.health` *or* on `endpoints[0]` without first checking the type.
- `status`, `compliance_score`, `trust_score` **and `health`** exist on **Shape A only**.
  Shape B has no health *status* field at all — its liveness locator is the `health` **path
  string** inside its `endpoints` object, which must be fetched, not read.

**Fields that exist on NO record** (0 of 49), despite appearing in older documentation:
`tier`, `domain`, `repo`, `dependencies`.

**Duplicates exist** — `chittyagent-npm` appears twice. The two records carry **distinct
`chitty_id`s** and each resolves individually, so the registry does disambiguate them by id;
what it offers no way to determine is **which of the two is current**.

Read the shape from the API, not from any example — this table included. Take a field union
across the whole response before assuming a schema; that is the mistake this section exists
to record.

## Cross-Reference

Use with other skills:
- `/health {service}` - Check if registered service is running
- `/deploy {service}` - Deploy registered service
