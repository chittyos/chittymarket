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
proxies: chittyagent-chatgpt (chittyentity/workers/chittyagent-chatgpt)
---

# ChittyAgent ChatGPT

This definition proxies ChatGPT integration work to the deployed
`chittyagent-chatgpt` worker. It is a definition (T); the worker it routes to is
the actor.

## Endpoint

```
https://agent.chitty.cc/chatgpt
```

Matches the worker's declared route `agent.chitty.cc/chatgpt/*`
(`wrangler.jsonc` → `env.production.routes`).

## Routes

Self-declared by the worker at `GET /chatgpt/`:

| Route | Method | Purpose |
|---|---|---|
| `/health` | GET | Health check |
| `/api/v1/status` | GET | ChittyRegister compliance status |
| `/openapi.json` | GET | OpenAPI 3.1.0 spec for ChatGPT Actions |
| `/mcp` | POST | MCP server design and implementation guidance |
| `/actions` | POST | Custom GPT Actions design and implementation |
| `/plugins` | POST | ChatGPT plugin operations |
| `/troubleshoot` | POST | Integration debugging |

The worker reports `system_class: chatgpt_integration_agent`,
`governance_class: III`.

There is **no** single dispatch route taking `{"operation": ...}`. Each concern
is its own path — post to the route that matches the work.

## Usage

```bash
curl -X POST https://agent.chitty.cc/chatgpt/actions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $CHITTY_SERVICE_TOKEN" \
  -d '{ }'
```

`/mcp` on this worker serves design guidance over HTTP POST. It is not the
streamable-HTTP MCP transport used by the other agent workers — do not send it
an `Mcp-Session-Id` handshake.

## Authentication

ChittyAuth service token. The worker holds the OpenAI credential internally;
never pass an OpenAI key here.

## Known state (verified 2026-09-04)

`/health` → `{"status":"ok","checks":{"mcp":"ok"}}`, version 1.0.0. Fully live.

Forward ChatGPT integration requests to this endpoint. Do not call the OpenAI API directly.
