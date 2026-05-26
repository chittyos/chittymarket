---
uri: chittycanon://docs/ops/policy/chittymarket-universal-projection-plan
namespace: chittycanon://docs/ops
type: policy
version: 0.1.0
status: DRAFT
registered_with: chittycanon://core/services/canon
title: "ChittyMarket Universal Projection — Migration Plan"
visibility: PUBLIC
---

# ChittyMarket Universal Projection — Migration Plan

**Status:** DRAFT. Resolves §2.4 (per `SINGLE-SOURCE-CONVENTIONS.md`): chittymarket as agent/model/platform-agnostic universal marketplace, with native projections per runtime.

## TL;DR

The architecture already exists. `plugins/chittyagent-dispatch/scripts/dispatch.sh` reads `canonical/<name>.md` and projects to claude-code agent, codex skill, and openclaw agent formats. 7 artifacts are canonicalized; ~25 are not. This document is the migration path to fully-canonical, with no per-runtime forks.

## Current state (2026-05-26)

### Implemented and working

- **`canonical/<name>.md`** — single source for any artifact opting into universal projection. Frontmatter declares `name`, `description: |`, `kind: agent`, `plugin: <home-plugin>`, `runtimes: [claude-code, codex, openclaw, ...]`, `classification: [...]`.
- **`plugins/chittyagent-dispatch/scripts/dispatch.sh sync [<name>]`** — projects every canonical (or one) into every declared runtime adapter's output location. Computes per-canonical SHA + per-target SHA, tracks them in `canonical/.dispatch-state/<name>.json`.
- **Adapters** at `plugins/chittyagent-dispatch/scripts/adapters/*.sh`:
  - `claude-code-agent.sh` → `plugins/<home-plugin>/agents/<name>.md`
  - `codex-skill.sh` → `plugins/<home-plugin>/codex-skills/<name>/SKILL.md`
  - `openclaw-agent.sh` → `plugins/<home-plugin>/openclaw-agents/<name>.yaml`
- **`plugins/chittyagent-dispatch/scripts/pre-commit-drift.sh`** — enforces no projection edits without canonical-source change.
- **`plugins/chittyagent-dispatch/scripts/hydrate-pointers.sh`** (PR #30) — pulls per-service-owned content (e.g. `chittyschema-overlord`) from external repos.

### Canonicalized (7)

| Canonical | Home plugin | Runtimes projected |
|---|---|---|
| `chittyagent-autobot` | `chittyagent-autobot` | claude-code |
| `chittyagent-dispatch` | `chittyagent-dispatch` | claude-code, codex, openclaw |
| `chittyagent-neon` | `chittyos-governance` | claude-code, codex |
| `chittyagent-canon` | `chittyos-core` | claude-code |
| `chittyagent-claude` | `chittyos-core` | claude-code |
| `chittyagent-connect` | `chittyos-core` | claude-code |
| `chittyagent-register` | `chittyos-core` | claude-code |

### Not yet canonicalized (the migration backlog)

**Agents (4 remaining)**:
- `chittyagent-chatgpt`, `chittyagent-cloudflare`, `chittyagent-notion` (chittyos-proxy-agents) — proxy-style, possibly thin enough to inline rather than canonicalize
- `chittyagent-schema` — pointer file; hydrated by hydrate-pointers.sh (intentionally stays as pointer)

**Skills (27 — full list)**:
- chittyagent-autobot: chitty-autonomy, chitty-autonomy-affirm, chitty-autonomy-cicd, chitty-autonomy-discover, chitty-autonomy-generate, chitty-autonomy-implement, chitty-autonomy-plan, chitty-autonomy-ship, chitty-autonomy-tidy (9)
- chittymarket-manager: market (1)
- chittyos-core: checkpoint, chitty-cleanup, chittycontext, chittyxl (4)
- chittyos-devops: chitty-deploy, chitty-health, chitty-pipelines, chitty-registry, chittyos-compliance, wrangler-audit (6)
- chittyos-governance: capability-governor, capability-registry-audit (2)
- chittyos-legal: dispute, docket, evidence-collect, evidence-egress, fact-governance (5)

**Hooks (12 in `chittyos-governance/hooks/hooks.json`)** — under-canonicalized; the hooks.json catalog could become `canonical/hooks/<name>.md` per hook.

**Commands** (slash commands) — only `chittyagent-autobot/commands/autonomy.md` exists currently; no canonical adapter yet.

**MCP configs** (in `plugins/chittyos-mcp/.mcp.json`, `plugins/neon-mcp/.mcp.json`) — could become `canonical/mcp/<name>.json`.

## Target end state

```
chittymarket/
  canonical/
    <agent-name>.md          # canonical agent definition (frontmatter + body)
    <skill-name>.md          # canonical skill definition
    hooks/
      <hook-name>.md         # canonical hook (matchers + script)
    commands/
      <command-name>.md      # canonical slash command
    mcp/
      <server-name>.json     # canonical MCP server config
    .dispatch-state/         # tracking SHAs

  plugins/<plugin>/
    .claude-plugin/plugin.json    # plugin manifest, deps
    agents/<name>.md              # PROJECTED claude-code agent
    skills/<name>/SKILL.md        # PROJECTED claude-code skill
    codex-skills/<name>/SKILL.md  # PROJECTED codex skill
    openclaw-agents/<name>.yaml   # PROJECTED openclaw agent
    chatgpt-gpts/<name>.json      # FUTURE: PROJECTED ChatGPT GPT config
    notion-agents/<name>.json     # FUTURE: PROJECTED Notion agent
```

Direct edits to `plugins/<plugin>/{agents,skills,...}` are blocked by the pre-commit drift hook. The only authored content lives in `canonical/`.

## Migration phases

### Phase A — Adapter coverage (1–2 PRs)

Add the missing adapters in `plugins/chittyagent-dispatch/scripts/adapters/`:

- **`claude-code-skill.sh`** → `plugins/<home-plugin>/skills/<name>/SKILL.md` (currently no skill projection exists; skills are authored directly)
- **`claude-code-hook.sh`** → entry in `plugins/chittyos-governance/hooks/hooks.json`
- **`claude-code-command.sh`** → `plugins/<home-plugin>/commands/<name>.md`
- **`mcp-config.sh`** → entry in `plugins/<host-plugin>/.mcp.json`
- **`chatgpt-gpt.sh`** → `plugins/<home-plugin>/chatgpt-gpts/<name>.json` (deferred; needs ChatGPT GPT schema)
- **`notion-agent.sh`** → `plugins/<home-plugin>/notion-agents/<name>.json` (deferred; needs Notion agent schema)

### Phase B — Canonicalize existing skills (3–5 PRs)

For each plugin with un-canonicalized skills:

1. For each `plugins/<plug>/skills/<name>/SKILL.md`:
   - Move content to `canonical/<name>.md`
   - Add frontmatter: `kind: skill`, `plugin: <plug>`, `runtimes: [claude-code]` (plus codex/openclaw if applicable)
2. Run `dispatch.sh sync <name>` to regenerate `plugins/<plug>/skills/<name>/SKILL.md`
3. Verify CI passes; pre-commit drift hook confirms canonical↔projection alignment.

Batch by plugin (~5 skills per PR):
- PR-B1: chittyos-core skills (4)
- PR-B2: chittyos-devops skills (6)
- PR-B3: chittyos-legal skills (5)
- PR-B4: chittyos-governance skills (2) + chittymarket-manager (1)
- PR-B5: chittyagent-autobot autonomy skills (9)

### Phase C — Canonicalize hooks (1 PR)

Migrate `plugins/chittyos-governance/hooks/hooks.json` entries into individual `canonical/hooks/<name>.md` files; add `hook` adapter that rebuilds the hooks.json.

### Phase D — Canonicalize remaining surfaces (1 PR each, optional)

- Slash commands (currently just `autonomy`)
- MCP server configs (currently `chittyos-mcp`, `neon-mcp`)

### Phase E — Lock the migration with CI (1 PR)

Once all artifacts are canonicalized:

- Add `scripts/lint-plugins.sh` rule: every `plugins/<plug>/{agents,skills,...}/<file>` must have a corresponding `canonical/<name>.md`. No exceptions except pointer files.
- The pre-commit drift hook already enforces this for staged files; the lint check enforces it for the whole tree.

After Phase E, no direct edits to projection paths are possible; chittymarket is fully canonical-driven.

## Cross-platform projection (the "make sense?" question)

User question (verbatim from §2.4):
> "expose a generalized/universal marketplace/plugins/tools and automatically translate that into native versioning for claude/claude-code, codex/chat, claw"

**Doable**: yes. The model is already in place — adapter scripts read a canonical file and emit per-runtime native format.

**Makes sense**: yes, for the runtimes we control. Every adapter we add eliminates one set of per-runtime forks. The cost is:

- One adapter script per runtime (~50–150 lines each based on `claude-code-agent.sh` as reference).
- Each canonical entry must declare `runtimes: [...]` listing which adapters to invoke; absent = not projected to that runtime.
- A new runtime takes one adapter PR; the entire canonical library projects to it automatically.

**Per-runtime native mappings** (proposed):

| Canonical kind | claude-code | codex | openclaw | chatgpt | notion |
|---|---|---|---|---|---|
| agent | `agents/<n>.md` | `codex-skills/<n>/SKILL.md` | `openclaw-agents/<n>.yaml` | `chatgpt-gpts/<n>.json` | `notion-agents/<n>.json` |
| skill | `skills/<n>/SKILL.md` | `codex-skills/<n>/SKILL.md` | n/a | n/a | n/a |
| hook | hooks.json entry | n/a | n/a | n/a | n/a |
| command | `commands/<n>.md` | n/a | n/a | n/a | n/a |
| mcp-server | `.mcp.json` entry | `.mcp.json` entry | n/a | n/a (proxy via Zapier) | n/a |

`n/a` cells mean the runtime doesn't have that artifact concept; the projector should warn (not error) if a canonical lists an n/a target.

## Risks

- **Adapter divergence**: each adapter is independently maintained. Schema changes to one runtime's native format (e.g. Claude Code agent frontmatter spec) require adapter updates. Mitigation: keep adapters simple, snapshot their fixture output in tests.
- **Lossy projection**: not every canonical field maps to every runtime. Adapters need to either pick a sensible default or error. Mitigation: validate `runtimes:` allowlist per artifact kind.
- **Big-bang risk**: phase B migrates 27 skills. If something goes wrong mid-PR, partial canonicalization is hard to roll back. Mitigation: batch by plugin, test each batch independently.

## Not in scope of this plan

- The `canonical/` schema itself — assumed to be the current chittyagent-neon-style frontmatter + body
- A `marketplace.json` (root inventory) regenerator — currently hand-maintained via `/market`; would benefit from a generator but separate concern
- Cross-repo per-service-ownership (§2.2) — handled by hydrate-pointers.sh
