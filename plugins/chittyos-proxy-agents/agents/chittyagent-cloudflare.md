---
name: chittyagent-cloudflare
description: Proxy to remote ChittyAgent Cloudflare service for infrastructure operations
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
  -H "Authorization: Bearer ${CHITTYAUTH_ISSUED_CLOUDFLARE_TOKEN:-${CHITTY_CLOUDFLARE_TOKEN:-$CHITTY_SERVICE_TOKEN}}" \
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

Authenticate via ChittyAuth-issued service token. The remote agent handles Cloudflare API authentication internally.

Token precedence:
1. `CHITTYAUTH_ISSUED_CLOUDFLARE_TOKEN` (preferred)
2. `CHITTY_CLOUDFLARE_TOKEN` (legacy fallback)
3. `CHITTY_SERVICE_TOKEN` (generic fallback)

## Example

```bash
# Deploy a worker
curl -X POST https://agent.chitty.cc/api/cloudflare \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${CHITTYAUTH_ISSUED_CLOUDFLARE_TOKEN:-${CHITTY_CLOUDFLARE_TOKEN:-$CHITTY_SERVICE_TOKEN}}" \
  -d '{
    "operation": "workers",
    "action": "deploy",
    "payload": {"name": "my-worker", "code": "..."}
  }'
```

Forward all Cloudflare requests to this endpoint. Do not execute Cloudflare API calls directly.
