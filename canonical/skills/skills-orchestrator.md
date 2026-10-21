---
name: skills-orchestrator
canon_uri: chittycanon://core/services/chittymarket#skills/skills-orchestrator
description: |
  Universal skill and agent router. Searches, discovers, and executes any skill or agent in the ChittyOS ecosystem via the orchestrator MCP at orchestrator.agent.chitty.cc/mcp.
kind: skill
classification:
  - orchestration
  - mcp
runtimes:
  - claude-code
  - codex
plugin: chittyos-core
canonical_capability_ref: "chittycanon://capability/workspace/skills-orchestrator"
overlay:
  title: "Skills Orchestrator"
  capability_group: "workspace"
  group_assignment_source: "override"
  execution_class: "@chitty/connectors"
  canonical_version: "1.0.0"
  projection_version_policy: "inherit-canonical"
  ontology:
    primary:
      - "P"
    secondary:
      - "E"
      - "T"
  authority:
    requires_chittyid: true
  execution:
    default_surface: "local"
    local_allowed: true
    context_cost: "low"
    mutation_risk: "low"
  discovery:
    indexable: true
    session_index: "hidden"
    ambient_by_intent: false
    verbs:
      - "search"
      - "discover"
      - "execute"
    fallback_search: true
  auth_flow:
    mode: "local-only"
    stores_credentials_in: "n/a"
    fail_closed_if_unavailable: false
  runtime_exclusions: {}
  phase0_audit:
    job_to_be_done: "generate"
    environmental_footprint: "write-capable"
    evidentiary_risk: "none"
    advisory_disposition: "skill"
  legacy_category: "ecosystem"
  deprecated_aliases: []
  visibility: "recommended"
  access: "readwrite"
  compatible_channels:
  - claude_code
  - codex
---

# Skills Orchestrator

Universal entry point for discovering and executing skills and agents across the ChittyOS ecosystem. Routes through the `chittyagent-orchestrator` MCP server at `orchestrator.agent.chitty.cc/mcp`.

## How It Works

This skill replaces per-skill local definitions. Instead of each skill containing its own logic, the orchestrator MCP server holds the index of **50 skills** and **18 agents** with fuzzy search, capability matching, and execution routing.

## Usage

### Search for a skill
When the user describes what they want to do, call `skill_search` on the orchestrator MCP:

```
Tool: skill_search
Args: { "query": "{user's intent}" }
```

### Search for an agent
When the user needs an agent for a task:

```
Tool: agent_search
Args: { "query": "{user's intent}" }
```

### Execute a skill
Once the right skill is found:

```
Tool: skill_execute
Args: { "skill_id": "{skill_id}", "args": { ... } }
```

### Execute an agent action
Once the right agent is found:

```
Tool: agent_execute
Args: { "agent": "{agent_id}", "action": "{action}", "payload": { ... } }
```

### List everything
```
Tool: skill_list    → 50 skills across 14 categories
Tool: agent_list    → 18 agents with binding status
```

## MCP Endpoint

All tools are on the orchestrator MCP server:
- **URL**: `https://orchestrator.agent.chitty.cc/mcp`
- **Protocol**: MCP (Streamable HTTP + SSE)
- **Auth**: Bearer token or Cloudflare Access

## Categories

### Skills (50)

| Category | Count | Examples |
|----------|-------|---------|
| chittyos-core | 5 | checkpoint, chittycontext, chittyxl, new-session |
| chittyos-devops | 8 | deploy, health, compliance, wrangler-audit, branch-cleanup |
| chittyos-legal | 5 | fact-governance, docket, evidence-collect, dispute, pipeline-submit |
| chittyos-finance | 1 | mercury-finance |
| workflow | 4 | ship, market, machine-management |
| claude-official | 7 | code-review, frontend-design, hookify, plugin-dev |
| pr-review-toolkit | 1 | review-pr |
| commit-commands | 3 | commit, commit-push-pr, clean-gone |
| feature-dev | 1 | feature-dev |
| chittycommand-alpha | 9 | dispute-strategy, cashflow-planner, obligation-tracker |
| connectors | 3 | discord, telegram, imessage |
| mcp-server-dev | 1 | build-mcp-server |

### Agents (18)

| Agent | Domain | Capabilities |
|-------|--------|-------------|
| orchestrator | orchestrator.agent.chitty.cc | Agent routing, provisioning, skill orchestration |
| cloudflare | cloudflare.agent.chitty.cc | DNS, Workers, KV, R2 management |
| notion | notion.agent.chitty.cc | Notion CRUD, webhooks, indexing |
| finance | finance.agent.chitty.cc | Mercury banking, transactions, cash flow |
| dispute | dispute.agent.chitty.cc | Dispute lifecycle management |
| ship | ship.agent.chitty.cc | Dev wrap-up, brainstorming, checkpointing |
| notes | notes.agent.chitty.cc | Apple Notes RAG search |
| storage | storage.agent.chitty.cc | Document storage, R2, legal holds |
| tasks | tasks.chitty.cc | Inter-agent task queue |
| helper | helper.agent.chitty.cc | Architectural navigation |
| canon | canon.agent.chitty.cc | URI validation, canonicalization |
| scrape | scrape.agent.chitty.cc | Web scraping job orchestration |
| resolve | resolve.agent.chitty.cc | Error triage and resolution |
| cleaner | cleaner.agent.chitty.cc | Disk cleanup and optimization |
| chatgpt | chatgpt.agent.chitty.cc | ChatGPT integration guidance |
| imessage | imessage.agent.chitty.cc | iMessage data sync |
| ch1tty | tty.agent.chitty.cc | Universal MCP gateway |
| ui | agent.chitty.cc | Chat UI with WebSocket streaming |

## Routing Logic

The orchestrator determines execution mode per skill:

- **mcp**: Delegates to the skill's MCP server endpoint (e.g., `connect.chitty.cc/mcp`)
- **agent**: Routes to an agent worker via service binding with focal trust gating
- **local**: Returns instructions for the client to execute locally (e.g., Claude Code `/command`)

## Model Agnostic

This orchestrator works from any MCP client — Claude Code, Claude Desktop, ChatGPT, Gemini, or custom apps. The same 50 skills and 18 agents are available everywhere through `orchestrator.agent.chitty.cc/mcp`.
