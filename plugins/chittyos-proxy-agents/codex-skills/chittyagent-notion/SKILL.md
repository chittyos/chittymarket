---
name: chittyagent-notion
description: Proxy to remote ChittyAgent Notion service for registry database operations
canon_uri: chittycanon://core/services/chittymarket#agents/chittyagent-notion
proxies: chittyagent-notion (chittyentity/workers/chittyagent-notion)
---

# ChittyAgent Notion

This definition proxies Notion registry operations to the deployed
`chittyagent-notion` worker. It is a definition (T); the worker it routes to is
the actor.

## Endpoint

```
https://agent.chitty.cc/notion
```

Matches the worker's declared route `agent.chitty.cc/notion/*`
(`wrangler.jsonc` → `env.production.routes`). MCP is at `/notion/mcp`
(streamable HTTP; requires an `Mcp-Session-Id` header).

## Routes

| Route | Method | Purpose |
|---|---|---|
| `/health` | GET | Health + per-registry token reachability |
| `/api/v1/status` | GET | ChittyRegister compliance status |
| `/query` | POST | Query a registry |
| `/execute` | POST | Create / update / archive |
| `/registries` | GET | List registries with `database_id` |
| `/blocks`, `/update-page-content`, `/page/{id}/blocks` | POST | Page content |
| `/bulk`, `/run-now`, `/sync-domains`, `/sync/status`, `/sync/health` | — | Sync |
| `/discover`, `/audit`, `/manifest`, `/governance` | — | Introspection |
| `/webhook` | POST | Webhook receiver |
| `/refresh-cache` | POST | Clear `data_source_id` cache |

## Query

`registry` **or** `database_id` is required.

```bash
curl -X POST https://agent.chitty.cc/notion/query \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $CHITTY_SERVICE_TOKEN" \
  -d '{"registry": "service", "filter": {...}, "page_size": 100}'
```

Optional: `filter`, `sorts`, `page_size` (default 100). Returns `registry`,
`database_id`, `data_source_id`, `count`, `results`, `has_more`.

## Execute

`action` is required, plus `registry` **or** `database_id`.

```bash
curl -X POST https://agent.chitty.cc/notion/execute \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $CHITTY_SERVICE_TOKEN" \
  -d '{"action": "create", "registry": "service", "properties": { }}'
```

`action: create` passes a **triage gate**. An unclassified create returns
`{"deferred": true, "triage": {...}}` instead of writing — it is not an error.
Use a registered registry name, or `triage_override: true` to bypass.

## Registries

`domain`, `service`, `systems`, `github`, `legal`, `authority`, `asset`,
`context`, `document`, `central` — confirmed live via `GET /registries`.

## Authentication

ChittyAuth service token. The worker holds the Notion credential internally;
never pass a Notion token here.

## Known state (verified 2026-09-04)

`/health` reports `status: degraded`, `mode: EXECUTION_ONLY`. The worker's own
Notion token returns **401 — "API token is invalid"**, so every registry read
currently fails upstream. The route and contract are live; the credential is
not. Credential repair routes through ChittyConnect (`/chico`), not through
this definition.

Forward Notion registry requests to this endpoint. Do not call the Notion API directly.
