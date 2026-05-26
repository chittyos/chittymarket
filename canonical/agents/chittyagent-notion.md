---
name: chittyagent-notion
canon_uri: chittycanon://core/services/chittymarket#agents/chittyagent-notion
description: Proxy to remote ChittyAgent Notion service for database operations
kind: agent
plugin: chittyos-proxy-agents
runtimes:
  - claude-code
  - codex
  - openclaw
classification:
  - proxy
  - integration
---

# ChittyAgent Notion

This agent proxies Notion operations to the remote ChittyAgent service.

## Endpoint

```
https://agent.chitty.cc/api/notion
```

## Usage

All Notion database operations should be forwarded to the remote ChittyAgent:

```bash
curl -X POST https://agent.chitty.cc/api/notion \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $CHITTY_SERVICE_TOKEN" \
  -d '{
    "operation": "query|create|update|archive",
    "registry": "service|domain|systems|...",
    "payload": { ... }
  }'
```

## Available Registries

The remote agent has access to all canonical registries:
- Domain Registry
- Service Registry
- Systems Registry
- GitHub Repository Registry
- Legal Entities Registry
- Authority Registry
- Context Registry
- Asset Registry
- Document Registry
- Property Resources Registry
- Central Registry of Registries

## Operations

| Operation | Description |
|-----------|-------------|
| `query` | Query database entries with filters |
| `create` | Create new database entry |
| `update` | Update existing entry by page ID |
| `archive` | Soft delete entry by page ID |

## Authentication

Authenticate via ChittyAuth service token. The remote agent handles Notion API authentication internally.

## Example

```bash
# Query all active services
curl -X POST https://agent.chitty.cc/api/notion \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $CHITTY_SERVICE_TOKEN" \
  -d '{
    "operation": "query",
    "registry": "service",
    "filter": {"status": "Active"}
  }'
```

Forward all Notion requests to this endpoint. Do not execute Notion API calls directly.
