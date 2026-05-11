# Gemini Deep Think — ChittyMarket Refactor Strategy v1

Source: response to `docs/refactor-prompt.md`. Captured verbatim for record.

---

## Executive Summary

- **Pivot to "Canonical Capabilities"**: The marketplace stops listing "skills"
  or "MCP servers." It lists unified *Capabilities* that dynamically resolve
  into runtime-specific *Projections* (Claude Code, ChatGPT, OpenClaw).
- **Execution Boundary Taxonomy**: Group artifacts strictly by *where they run*
  (Local FS vs. Cloud) and *context cost* (Ambient vs. Heavy), matching how
  LLMs allocate resources.
- **Aggressive Gateway Consolidation**: Kill all local plugins for SaaS proxies
  (Notion, Cloudflare, ChatGPT). External APIs belong exclusively in the Ch1tty
  aggregator to enforce centralized auth.
- **Slim-MCP for Heavy Reasoning**: Complex, episodic tasks (Legal, DevOps
  audits, Autobot) default to Ch1tty's `search`/`execute` pattern to drastically
  protect local context windows.
- **Automated Legacy Support**: The rigid `.claude-plugin/marketplace.json`
  becomes a read-only build artifact compiled dynamically from the canonical
  registry, fulfilling the `/plugin add` constraint without manual
  dual-authoring.

---

## 1. Proposed Taxonomy: Execution Boundary & Cognitive Load

Group by two axes: **Filesystem Dependency** and **Context Weight**.

- **`@chitty/workspace`** *(Local Filesystem, High Privilege)*
  Codebase mutations, local git hooks, builds. Cannot run on web.
  *Maps from:* `chitty-deploy`, `chitty-pipelines`, `chitty-health`, local
  `wrangler-audit`.

- **`@chitty/ambient`** *(Ambient Context, Core Primitives)*
  High-frequency, fundamental OS awareness (P/L/T/E/A).
  *Maps from:* `chittycontext`, `checkpoint`, `chittyid`. Pre-loaded via
  ChittyMCP.

- **`@chitty/connectors`** *(Cloud APIs, Medium Context)*
  Stateless SaaS proxies. Routed strictly through Ch1tty aggregator.
  *Maps from:* `chittyos-proxy-agents` (Notion, Cloudflare, ChatGPT),
  `neon-mcp`.

- **`@chitty/reasoning`** *(Episodic, Massive Context)*
  Multi-step autonomous workflows. Loaded strictly on-demand via slim-MCP.
  *Maps from:* `chittyos-legal` (docket, dispute, evidence),
  `chittyagent-autobot` (merged), `chittyos-governance`.

---

## 2. Artifact Taxonomy Across Channels

Separate **Logical Capability** from **Runtime Projection**. UI/`/market`
surfaces a single Canonical Capability; deployment negotiates silently.

```json
{
  "id": "@chitty/connectors/neon-manager",
  "name": "Neon Database Governance",
  "canonical_source": "canonical/chittyagent-neon.md",
  "ontology_tags": ["Environment", "Trust"],
  "projections": {
    "claude-code": { "type": "ch1tty-backend", "tool_id": "neon_query" },
    "chatgpt":     { "type": "openapi-action", "endpoint": "ch1tty.com/mcp/neon" },
    "openclaw":    { "type": "agent", "path": "openclaw-agents/chittyagent-neon.yaml" }
  }
}
```

---

## 3. Per-Channel UX Matrix

| Channel         | Install & Discovery UX           | Marketplace Surface         | Excluded Artifacts                  |
| --------------- | -------------------------------- | --------------------------- | ----------------------------------- |
| Claude Code     | `/market add <capability>`       | CLI Interactive Prompt      | Pure server-side web hooks          |
| Claude.ai Web   | Toggle via Ch1tty Web Portal     | `ch1tty.com` Portal         | `@chitty/workspace` (no FS)         |
| Claude Desktop  | Deep link from Portal + Extension| Portal + Desktop App        | Background daemons                  |
| ChatGPT         | Custom GPT Action Config         | OAuth to Ch1tty Portal      | `@chitty/workspace`, daemons        |
| Codex / App     | Background daemon sync           | OS Daemon UI                | Claude-specific native UI plugins   |
| OpenClaw        | `dispatch add <capability>`      | CLI / Dispatch Orchestrator | Channel-specific UI proxies         |

---

## 4. Decision Tree: Where should a new capability live?

1. **Modifies local files / executes local binaries?** → Local Plugin/Skill (`@chitty/workspace`).
2. **Core ecosystem function needed constantly (Identity, MemoryCloude, Trust)?** → ChittyMCP Tool (pre-loaded).
3. **3rd-party SaaS or Database integration?** → Ch1tty Backend (centralized, zero local install).
4. **Complex multi-step reasoning workflow?** → Ch1tty Backend via slim-MCP (`search`/`execute`).

---

## 5. Migration Plan

- **Phase 1 — Canonical Metadata Unification (Low Risk)**: rewrite master
  `marketplace.json` into projection format. GitHub Action compiles legacy
  `.claude-plugin/marketplace.json` from the master.
- **Phase 2 — Ch1tty Consolidation (Medium Risk)**: migrate Notion, Cloudflare,
  ChatGPT, Neon proxies into Ch1tty backends.
- **Phase 3 — Thin-Client Marketplace (Medium Risk)**: refactor
  `chittymarket-manager` `/market` skill to detect host env and pull/register
  correct projection.
- **Phase 4 — The Great Pruning (High Impact)**: execute the kill list.

---

## 6. Kill List

1. **KILL** `chittyos-proxy-agents` as local plugins. Demote to server-side `@chitty/connectors`.
2. **KILL** standalone `chittyos-mcp` & `neon-mcp` local wrappers. Fold into Ch1tty.
3. **DEMOTE** `chittyos-legal` and `chittyos-governance` to `@chitty/reasoning`, discoverable only via slim-MCP `search`.
4. **MERGE** `chittyagent-autobot` skills. Bundle the 8 fragmented autonomy skills under one canonical agent projection.

---

## 7. Risks and Tradeoffs

- **Invisible Tool Hallucination**: slim-MCP saves tokens but requires the LLM
  to guess a search is needed. Missed keywords → false "I can't do that."
- **Offline Degradation**: air-gapped OpenClaw users lose proxy/remote tools
  unless they run a local Ch1tty replica.
- **Fragmentation of Expectation**: a capability installed via portal that
  doesn't work on web (no FS) — need UX badging like "CLI Only."

---

## Open Questions (answered separately — see `gemini-strategy-v1-followup.md`)

1. Slim-MCP discovery tolerance / cheat-sheet injection.
2. Versioning drift across projections.
3. Local CLI auth bridging for `/market add <connector>`.
