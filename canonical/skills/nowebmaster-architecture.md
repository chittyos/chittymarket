---
name: nowebmaster-architecture
canon_uri: chittycanon://core/services/chittymarket#skills/nowebmaster-architecture
description: |
  Full architecture specification and 6-stage dynamic capability lifecycle pipeline for nowebmaster / webmastrai / GORE.
kind: skill
plugin: nowebmaster
runtimes:
  - claude-code
  - codex
classification:
  - architecture
  - capability-lifecycle
---

# nowebmaster Architecture & Substrate Specification

## 1. Executive Summary & Vision

**nowebmaster** (working names: *webmastrai*, *GORE — Global Omni Repository Endpoint*) is a universal capability lifecycle engine and automated webmaster.

It normalizes rotted content, incoherence, and contradictory facts across web surfaces, and acts as a provider-agnostic mold compiler for AI surfaces (OpenAI Plugins, Custom GPTs, Claude Skills, Gemini Gems, CF MCP Portals, ChittyOS Skins).

---

## 2. The 6-Stage Dynamic Nutrient Pipeline

```
STAGE 1         STAGE 2         STAGE 3         STAGE 4         STAGE 5         STAGE 6
INGEST      →   COMPOST     →   STORE       →   REASSEMBLE  →   HOT-LOAD    →   VERIFY
Raw Material    Elemental       Canonical       Provider        Live API        Health check
(URLs/Docs)     Nutrients       Atoms (D1)      Molds           Activation      & Rollback
```

### Stage 1: Ingest
- Accepts raw web URLs, OpenAPI specs, REST docs, markdown, PDFs, or tool definitions.
- Interfaces via Firecrawl AI Scraper (`chittyscrape/src/targets/firecrawl.ts`) feeding `DriveIngestWorkflow.ts` (`chittystorage`).

### Stage 2: Compost (Atomization)
- Breaks composite inputs into elemental reusable nutrients (tool specs, claims, prompts, auth credentials, knowledge chunks).
- Preserves atomicity: an item is elemental when further decomposition destroys meaning.

### Stage 3: Canonical Nutrient Store
- Stores atoms canonically in Cloudflare D1 (`chittyevidence-db`) using `wm_*` tables:
  - `wm_pages`: Scraped web page metadata and content hashes.
  - `wm_claims`: Extracted factual claims.
  - `wm_contradictions`: Cross-source divergence & contradiction scores.
  - `wm_flags`: User-submitted incoherence reports.
  - `wm_rewards`: User point economy transactions.

### Stage 4: Reassemble
- Selects canonical atoms and packs them into provider-native composite bundles ("skins") using provider-specific templates.

### Stage 5: Hot Load
- Pushes assembled bundles to provider registration APIs dynamically without manual steps or downtime:
  - CF MCP Portal: `POST /accounts/{id}/mcp/servers`
  - OpenAI Responses API: `{ type: "mcp", server_url }`
  - Custom GPTs: OpenAPI 3.1 Actions
  - Claude Skills: `.well-known/skills/index.json`

### Stage 6: Verify & Rollback
- Executes automated post-activation health checks. On failure, triggers immediate automatic rollback to the prior working bundle version.

---

## 3. Worker Substrate & Placement

- **Host VM:** `chittyserv-vm` (`100.86.86.0`) under `/home/ubuntu/projects/github.com/CHITTYOS/`
- **Worker Package:** `chittyentity/workers/chittyagent-webmaster`
- **DO Class:** `WebmasterAgent` extending `McpAgent<Env>`
