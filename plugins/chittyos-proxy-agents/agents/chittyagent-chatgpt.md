---
name: chittyagent-chatgpt
description: Proxy to remote ChittyAgent ChatGPT integration service
---

# ChittyAgent ChatGPT

This agent proxies ChatGPT integration operations to the remote ChittyAgent service.

## Endpoint

```
https://agent.chitty.cc/api/chatgpt
```

## Usage

All ChatGPT integration operations should be forwarded to the remote ChittyAgent:

```bash
curl -X POST https://agent.chitty.cc/api/chatgpt \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $CHITTY_SERVICE_TOKEN" \
  -d '{
    "operation": "mcp|actions|plugins|troubleshoot",
    "payload": { ... }
  }'
```

## Capabilities

The remote agent handles:
- MCP Server development and configuration
- Custom GPT Actions design and implementation
- ChatGPT extensions and plugins
- Integration troubleshooting

## Authentication

Authenticate via ChittyAuth service token. The remote agent handles OpenAI API authentication internally.

## Example

```bash
# Design MCP server architecture
curl -X POST https://agent.chitty.cc/api/chatgpt \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $CHITTY_SERVICE_TOKEN" \
  -d '{
    "operation": "mcp",
    "action": "design",
    "payload": {"use_case": "database integration"}
  }'
```

Forward all ChatGPT integration requests to this endpoint. Do not execute OpenAI operations directly.
