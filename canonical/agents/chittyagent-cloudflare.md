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
proxies: chittyagent-cloudflare (chittyentity/workers/chittyagent-cloudflare)
---

# ChittyAgent Cloudflare

This definition proxies Cloudflare operations to the deployed
`chittyagent-cloudflare` worker. It is a definition (T); the worker it routes to
is the actor.

## Endpoint

```
https://agent.chitty.cc/cloudflare
```

Matches the worker's declared route `agent.chitty.cc/cloudflare/*`
(`wrangler.jsonc` → `env.production.routes`).

## Routes

| Route | Purpose |
|---|---|
| `/health` | Health + per-account reachability |
| `/api/v1/status` | ChittyRegister compliance status |
| `/workers/list` | List Workers |
| `/kv/list` | List KV namespaces |
| `/r2/list`, `/r2/inventory`, `/r2/inventory/all`, `/r2/create` | R2 buckets |
| `/dns/zones` | DNS zones |
| `/domains/list`, `/sync/domains` | Domains |
| `/cf-api` | Generic Cloudflare API passthrough |
| `/mcp` | MCP transport |

## Capabilities

The worker reports exactly: **`workers`, `kv`, `r2`, `dns`, `domains`**.

Pages, D1, WAF, Durable Objects, Queues, and Workers AI are **not** served by
this agent. A previous revision of this document listed them; that was not
backed by the deployment. Route those elsewhere.

## Accounts

Multi-account. `/health` reports per-account reachability for `chittycorp`,
`digitaldossier`, and `furnishedcondos`.

## Usage

```bash
curl -s https://agent.chitty.cc/cloudflare/workers/list \
  -H "Authorization: Bearer $CHITTY_SERVICE_TOKEN"
```

Each concern is its own path. There is no single dispatch route taking
`{"operation": ..., "action": ...}`.

## Authentication

ChittyAuth service token. The worker holds Cloudflare API credentials
internally; never pass a Cloudflare key or `X-Auth-Key` here.

## Known state (verified 2026-09-04)

- `/health` → `status: degraded`.
- `GET /cloudflare/` → **403 `"Missing CHITTY_AUTH_SERVICE_TOKEN in env"`** — the
  worker's own outbound service credential is absent from its environment.
- Account reachability: `chittycorp` reachable; `digitaldossier` and
  `furnishedcondos` both fail with `"Unknown X-Auth-Key or X-Auth-Email"`.

Two of three accounts and the service token are credential faults, not routing
faults. Repair routes through ChittyConnect (`/chico`), not through this
definition.

Note: `cloudflare.chitty.cc` returns **522**. It is a stale hostname with no
worker behind it — not this service. Use the path form above.

Forward Cloudflare requests to this endpoint. Do not call the Cloudflare API directly.
