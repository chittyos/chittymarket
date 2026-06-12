---
name: cast
description: 'Route an intent through ch1tty/cast — the canonical orchestration entry point of the MCP hierarchy (ch1tty umbrella over ChittyMCP, Cloudflare MCP, GitHub MCP, Notion MCP, Neon MCP, etc.). Triggers on "/cast" or when the user wants to invoke ch1tty cast directly. Use ch1tty/cast for orchestration, intent-driven work, "I want to do X find the right tool", or cross-backend composition. Raw backend tools (mcp__claude_ai_ChittyMCP__*, raw Cloudflare/GitHub/Notion) bypass the hierarch — out of contract per ch1tty README. Cast loads the SessionCoordinator affinity + Alchemist pattern observation + focus-profile lens biasing.'
canon_uri: chittycanon://core/services/chittymarket#skills/cast
kind: skill
classification:
  - orchestration
  - mcp
runtimes:
  - claude-code
  - codex
plugin: chittyos-mcp
---

# /cast — Route an intent through the ch1tty hierarch

The user invoked `/cast` to send an intent through ch1tty's canonical cast entry. Treat the rest of the user's message as the natural-language intent.

## What to do

1. Read the user's arguments as the intent string.
2. Invoke `ch1tty/cast` via the available ch1tty MCP tool (`mcp__claude_ai_Ch1tty__cast` if connected; otherwise via `mcp__claude_ai_ChittyMCP__*` only as last-resort fallback with explicit caveat that this bypasses the hierarch).
3. If the cast result needs confirmation (`confirm: true` flow) or has multiple candidates, surface them to the user with the top match + alternates.
4. Execute the selected tool; return the result.

## Why /cast, not raw tools

The MCP hierarchy is:

```
ch1tty/cast  ─────► routes to the right backend
ch1tty/search ───► discovers candidates
ch1tty/execute ──► invokes a known namespaced tool
                       │
                       ├── ChittyMCP (mcp.chitty.cc, 167 tools)
                       ├── Cloudflare MCP
                       ├── GitHub MCP
                       ├── Notion MCP
                       ├── Neon MCP
                       └── future backends
```

Ch1tty's README contract: *"If the runtime exposes raw backend tools directly, the deployment is out of contract."* Reaching for `mcp__claude_ai_ChittyMCP__tasks_list` directly bypasses:
- **SessionCoordinator** affinity tracking (it observes which tools you compose)
- **Alchemist** cross-backend pattern recognition (it promotes recurring patterns into focused `apps/*-mcp` services)
- **Focus profiles** (finance / governance / design) which only bias cast/search ordering
- **Cross-backend composition** — only cast can chain GitHub + Notion + Neon in one intent

## Constraints on cast usage

- The intent should be specific enough for cast to resolve: "create a stripe invoice for X" is good; "do something with stripe" is too vague.
- For `confirm: true` casts, surface the plan to the user before executing if the operation is mutating or irreversible.
- If cast returns no match, fall back to `ch1tty/search` with the intent's keywords, then `ch1tty/execute` once a candidate is chosen — **not** to a raw backend tool.
- Only fall back to a raw backend tool (`mcp__claude_ai_ChittyMCP__*` etc.) if cast and search both genuinely fail to surface the right candidate. Note the fallback explicitly so the user knows the hierarch was bypassed.

## Examples

- `/cast pull the latest 5 closing-disclosure facts from evidence and write a Notion brief` — cross-backend, cast resolves the chain.
- `/cast show me all open chittyconnect issues` — cast routes to GitHub MCP via the github backend.
- `/cast triage today's incoming tasks from the durable board` — cast routes to chittyagent-tasks via ChittyMCP.
- `/cast what does the alchemist suggest for the governance focus this week?` — cast routes to the alchemist tools.

## When NOT to use /cast

- Single, known, well-defined raw tool call where you're absolutely certain of the tool name AND the work won't benefit from coordinator affinity / alchemist observation (e.g. a one-off `tasks_claim` with a known task_id). Even then, briefly note that you're bypassing the hierarch.
- Pure local file/git work — that's not an MCP-routable intent.

## See also

- Skill `chittyhelper` (`/helper`) — architectural navigator for "which service handles X?"
- Skill `chico` (`/chico`) — the ChittyConnect concierge for the credential lane.
- `nb-development-defaults` → "MCP Hierarchy — ch1tty is the umbrella" — the binding default rule.
- ch1tty repo: `docs/MCP_HOST_STANDARD.md`, `README.md` § Canonical Contract.
