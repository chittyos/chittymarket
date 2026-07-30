---
name: cross-surface-hotloading
canon_uri: chittycanon://core/services/chittymarket#skills/cross-surface-hotloading
description: |
  Rules and runbook for projecting canonical atoms across OpenAI, Claude, Gemini, and Cloudflare surfaces.
kind: skill
plugin: nowebmaster
runtimes:
  - claude-code
  - codex
classification:
  - deployment
  - provider-projection
---

# Cross-Surface Hot-Loading Runbook

## 1. Provider Molds & Reassembly Specs

| Target Surface | Reassembly Mold | Transport / Auth | Deployment API |
| :--- | :--- | :--- | :--- |
| **OpenAI Responses API** | `{ type: "mcp", server_url, allowed_tools }` | Streamable HTTP + Bearer Token | `POST /v1/responses` |
| **Custom GPTs** | OpenAPI 3.1 Schema + GPT Actions | REST + OAuth / API Key | ChatGPT GPT Builder API |
| **Claude Skills** | `.well-known/skills/index.json` + MCP refs | Streamable HTTP MCP | Claude MCP Settings Sync |
| **Gemini Gems / Extensions** | Vertex Extension Manifest + Function Declarations | Function Calling REST | Vertex AI Agent Builder API |
| **Cloudflare MCP Portal** | Server Registration + ZT Access Policy | Streamable HTTP + ZT OAuth | `POST /accounts/{id}/mcp/servers` |
| **ChittyOS Skins** | Skill Bundle (Tools + Prompts + Auth Keys) | Internal McpAgent Router | `registry.chitty.cc/api/v1/tools` |

---

## 2. Compiler Pipeline Sequence

```
Canonical Atom Store (D1 wm_* tables + TypeBox/Zod schemas)
           │
           ▼
  OpenAPI 3.1 Spec Generator (Source of truth contract)
           │
  ┌────────┼───────────────────────┬───────────────────────┐
  ▼        ▼                       ▼                       ▼
OpenAI   Custom GPT            Claude Skill          CF MCP Portal
Plugin   Actions Spec          Manifest Index        Server Reg
```

---

## 3. Surface-Specific Rules

### Rule A: OpenAI Responses API (`type: "mcp"`)
- Tool definitions are lazy-loaded via `defer_loading: true`.
- Authentication passes via `authorization: "Bearer <token>"`.
- Server must expose `GET/POST /mcp` implementing Streamable HTTP transport and JSON-RPC 2.0.

### Rule B: Custom GPT Actions
- Requires OpenAPI 3.0/3.1 JSON/YAML spec.
- Operates over standard REST endpoints (not raw MCP).
- Naming convention: operation IDs must be `snake_case` (e.g., `webmaster_harvest`).

### Rule C: Claude Skills
- Registered via `.well-known/skills/index.json`.
- Integrates multiple MCP server refs into a unified portable skill package.
- Respects open Agent Skills standard (Dec 2025).

### Rule D: Cloudflare Zero Trust MCP Portal
- Serves as the authentication middleware between LLM clients and worker isolates.
- Registration payload posts to `https://mcp-portal.chitty.cc/mcp`.
