---
uri: chittycanon://docs/ops/policy/chittymarket-universal-projection-plan
namespace: chittycanon://docs/ops
type: policy
version: 1.0.0
status: PENDING
registered_with: chittycanon://core/services/canon
certifier: chittycanon://core/services/chittycertify
title: "ChittyMarket Universal Projection — Migration Plan"
visibility: PUBLIC
---

# ChittyMarket Universal Projection — Migration Plan

**Status:** PENDING (awaiting certification) — migration substantially complete (2026-06-10). Resolves §2.4 (per `SINGLE-SOURCE-CONVENTIONS.md`): chittymarket as agent/model/platform-agnostic universal marketplace, with native projections per runtime.

## TL;DR

The architecture exists and the migration is essentially done. `plugins/chittyagent-dispatch/scripts/dispatch.sh` reads `canonical/<kind>/<name>.md` and projects to claude-code agent/skill/hook/mcp, codex skill, openclaw agent, and claude-skills tool formats. **46 artifacts are canonicalized** (12 agents, 29 skills, 1 command, 2 mcp, 2 tools); the remaining surfaces are pointer-by-design (`chittyagent-schema`, hookify-rule hooks) and not projectable. `lint-plugins.sh` enforces projection↔canonical alignment tree-wide; the repo reconciles clean. What remains is optional hardening, not backlog.

## Current state (2026-06-10)

### Implemented and working

- **`canonical/<name>.md`** — single source for any artifact opting into universal projection. Frontmatter declares `name`, `description: |`, `kind: agent`, `plugin: <home-plugin>`, `runtimes: [claude-code, codex, openclaw, ...]`, `classification: [...]`.
- **`plugins/chittyagent-dispatch/scripts/dispatch.sh sync [<name>]`** — projects every canonical (or one) into every declared runtime adapter's output location. Computes per-canonical SHA + per-target SHA, tracks them in `canonical/.dispatch-state/<name>.json`.
- **Adapters** at `plugins/chittyagent-dispatch/scripts/adapters/*.sh` — all seven present:
  - `claude-code-agent.sh` → `plugins/<home-plugin>/agents/<name>.md`
  - `claude-code-hook.sh` → `plugins/<home-plugin>/hooks/hooks.json`
  - `claude-code-mcp.sh` → `plugins/<home-plugin>/.mcp.json`
  - `claude-skills.sh` → `plugins/<home-plugin>/claude-skills/<name>.json`
  - `codex-skill.sh` → `plugins/<home-plugin>/codex-skills/<name>/SKILL.md`
  - `openclaw-agent.sh` → `plugins/<home-plugin>/openclaw-agents/<name>.yaml`
  - `chatgpt-apps.sh` → ChatGPT Apps SDK projection
- **`plugins/chittyagent-dispatch/scripts/pre-commit-drift.sh`** — enforces no projection edits without canonical-source change.
- **`plugins/chittyagent-dispatch/scripts/hydrate-pointers.sh`** (PR #30) — pulls per-service-owned content (e.g. `chittyschema-overlord`) from external repos.
- **`scripts/lint-plugins.sh`** — tree-wide projection↔canonical alignment check (Phase E lock); pointer files (`chittyagent-schema`) are explicitly exempted.

### Canonicalized (46)

Single sources live under `canonical/<kind>/<name>.md`. Current inventory:

| Kind | Count | Location |
|---|---|---|
| agents | 12 | `canonical/agents/` |
| skills | 29 | `canonical/skills/` |
| commands | 1 | `canonical/commands/` (`autonomy`) |
| mcp | 2 | `canonical/mcp/` (`chittyos`, `neon`) |
| tools | 2 | `canonical/tools/` (`ch1tty-search`, `ch1tty-fetch`) |

Every plugin agent and skill now projects from a canonical source; the proxy agents (`chittyagent-chatgpt`, `chittyagent-cloudflare`, `chittyagent-notion`) were canonicalized rather than inlined.

### Pointer-by-design (not canonicalized — intentional)

- **`chittyagent-schema`** — pointer file hydrated from the owning service repo by `hydrate-pointers.sh`. Lint exempts it.
- **Governance hooks** — `chittyos-governance/hooks/hooks.json` is a thin stub that delegates to hookify rules in `~/.claude/hooks/hookify.*.local.md`. There are no projectable hook bodies here, so there is nothing to move into `canonical/hooks/`. The `claude-code-hook.sh` adapter exists for any future plugin that authors real hook bodies, but the governance hooks remain a pointer to the hookify-rule system. (This supersedes the original Phase C, which assumed twelve canonicalizable hook entries.)

## Target end state

```
chittymarket/
  canonical/
    agents/
      <agent-name>.md        # canonical agent definition (frontmatter + body)
    skills/
      <skill-name>.md        # canonical skill definition
    commands/
      <command-name>.md      # canonical slash command
    mcp/
      <server-name>.md       # canonical MCP server config
    tools/
      <tool-name>.md         # canonical tool definition
    .dispatch-state/         # tracking SHAs, per kind-subdir

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

## Migration phases — status

The migration as originally scoped is complete. Status as of 2026-06-10:

| Phase | Scope | Status |
|---|---|---|
| A | Adapter coverage (skill, hook, command/mcp, claude-skills, chatgpt) | ✅ Done — all seven adapters present in `adapters/`. The command/mcp surfaces are covered by `claude-code-mcp.sh` + the `claude-code:mcp-server` runtime map; commands project via the kind-subdir loop. |
| B | Canonicalize all skills | ✅ Done — 29 skills under `canonical/skills/`, including all 9 autobot autonomy skills, the chittyos-core/devops/legal/governance sets, and `market`. |
| C | Canonicalize hooks | ⛔ Moot — governance hooks are a hookify-rule pointer, not projectable bodies (see *Pointer-by-design* above). No work to do; reclassified, not deferred. |
| D | Remaining surfaces (commands, mcp) | ✅ Done — `autonomy` command + `chittyos`/`neon` mcp configs are canonicalized. |
| E | CI lock | ✅ Done — `lint-plugins.sh` enforces tree-wide projection↔canonical alignment; pre-commit drift hook enforces per-staged-file. Pointer files exempted. |

**Net:** chittymarket is canonical-driven. The only authored content lives in `canonical/`; direct edits to projection paths are blocked by the pre-commit drift hook and flagged by `lint-plugins.sh`.

### Optional hardening (not blocking)

- **`reconcile` / `audit` dispatch modes** are currently stubs (`dispatch.sh audit` prints `STUB. Will emit canonical×runtime sync matrix.`). Implementing the audit matrix would give a single-command drift report beyond what `lint-plugins.sh` covers.
- **New deferred runtimes** (Notion agents, full ChatGPT GPT configs) take one adapter PR each when their native schemas are pinned; the canonical library projects to them automatically once the adapter lands.

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
- **Drift on hand-edit**: the durable risk now that migration is done is someone editing a projected file directly instead of its canonical source. Mitigation: the pre-commit drift hook blocks staged projection edits, and `lint-plugins.sh` flags tree-wide misalignment in CI.

## Not in scope of this plan

- The `canonical/` schema itself — assumed to be the current chittyagent-neon-style frontmatter + body
- A `marketplace.json` (root inventory) regenerator — currently hand-maintained via `/market`; would benefit from a generator but separate concern
- Cross-repo per-service-ownership (§2.2) — handled by hydrate-pointers.sh
