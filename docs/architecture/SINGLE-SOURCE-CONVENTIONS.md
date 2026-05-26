---
uri: chittycanon://docs/ops/policy/chittymarket-single-source-conventions
namespace: chittycanon://docs/ops
type: policy
version: 0.1.0
status: DRAFT
registered_with: chittycanon://core/services/canon
title: "ChittyMarket Single-Source Conventions"
visibility: PUBLIC
---

# ChittyMarket Single-Source Conventions

**Status:** DRAFT. Captures the conventions in force on `feat/market-refactor-v2` (2026-05-26) and surfaces open architectural decisions that block "single source, single approach, cohesion."

## Why this document exists

A drift audit on 2026-05-26 found:

- Plugin manifest (`.claude-plugin/marketplace.json`) had silently drifted from `plugins/` source-of-truth for weeks. Fixed in #23.
- `chittyagent-autobot` shipped without canonical `.claude-plugin/plugin.json` for weeks. Fixed in #24.
- A skill's `SKILL.md` referenced 3 reference docs the plugin didn't ship. Fixed in #22.
- 5 agent files in `chittyos-core/` have filenames that don't match their `name:` slugs.
- 1 agent file is a "pointer stub" to an external repo; loader behavior is undocumented.
- Skills are auto-shipped to 3 disk locations (`~/.claude/skills/`, `~/.claude/plugins/.../skills/`, `ai-parity/portable/claude/skills/`) — drift inevitable.

Each was caught by manual audit. CI (#25) now catches the first three at PR time. This document codifies the rest.

## Layer 0 — What is a source of truth?

```
                     +---------------------------+
                     | canonical/<name>.md       |   v2 target — metadata + frontmatter
                     | (chittymarket repo)       |   for cross-runtime projection
                     +-------------+-------------+
                                   |
                                   | projected via chittyagent-dispatch into:
                                   |
        +--------------------------+---------------------------+
        |                          |                           |
        v                          v                           v
+-----------------+        +----------------+           +-----------------+
| plugins/<plug>/ |        | Codex skills   |           | OpenClaw agents |
| agents/<n>.md   |        | (~/.codex/...) |           | (~/.openclaw/.) |
| skills/<n>/...  |        +----------------+           +-----------------+
| (chittymarket)  |
+--------+--------+
         |
         | distributed via /plugin add or marketplace install to:
         v
+---------------------+
| ~/.claude/plugins/  |   chittymarket plugin install on the runtime host
| marketplaces/.../   |
+---------------------+
```

Source-of-truth precedence (highest first):

1. **Per-service-owned content** (declared via `owner_repo` + `prompt_source` frontmatter). The owning service's repo wins. Example: `chittyschema-overlord` → `CHITTYFOUNDATION/chittyschema/identity/agents/chittyschema-overlord.md`. Chittymarket keeps a pointer stub for marketplace discoverability.
2. **`canonical/<name>.md` in chittymarket.** v2 target for agents/skills not owned by another service. Currently populated for `chittyagent-autobot`, `chittyagent-dispatch`, `chittyagent-neon`. **Migration is mid-flight.**
3. **`plugins/<plugin>/{agents,skills,hooks,commands}/...`** in chittymarket. Pre-v2 source of truth and still authoritative for any artifact not yet migrated to `canonical/`.

Anything in `~/.claude/`, `~/.codex/`, `~/.openclaw/` is a **rendered output**, never a source. Editing in-place there is drift.

## Layer 1 — Settled conventions (enforced by CI)

| Rule | Enforced by | Status |
|---|---|---|
| Every plugin has `plugins/<plug>/.claude-plugin/plugin.json` with `name`, `version`, `description` | `scripts/lint-plugins.sh` via CI #25 | LIVE |
| Plugin dependencies (`requires`) resolve to other inline plugins | `scripts/lint-plugins.sh` via CI #25 | LIVE |
| `.claude-plugin/marketplace.json` matches `scripts/generate-marketplace.sh` output | manifest-idempotency check in CI #25 | LIVE |
| Every plugin in `plugins/` has a matching manifest entry | `scripts/test-plugins.sh` via CI #25 | LIVE |
| Skills use `SKILL.md` filename with header | `scripts/test-plugins.sh` via CI #25 | LIVE |
| Agent files have valid markdown frontmatter | `scripts/test-plugins.sh` via CI #25 | LIVE |
| Hooks defined in `chittyos-governance/hooks/hooks.json` parse | `scripts/test-plugins.sh` via CI #25 | LIVE |

## Layer 2 — Conventions in flight (decision required)

### 2.1 Agent file naming: filename vs slug

5 agent files in `chittyos-core/agents/` have filenames that do not match their `name:` slug:

| File | name (slug) |
|---|---|
| `chittyagent-canon.md` | `chittycanon-code-cardinal` |
| `chittyagent-claude.md` | `claude-integration-architect` |
| `chittyagent-connect.md` | `chittyconnect-concierge` |
| `chittyagent-register.md` | `chittyregister-compliance-sergeant` |
| `chittyagent-schema.md` | `chittyschema-overlord` |

Meanwhile `chittyos-proxy-agents/` and `chittyagent-{autobot,dispatch,neon}` all have filename == slug.

**v2 direction signal**: `canonical/chittyagent-autobot.md`, `canonical/chittyagent-neon.md`, `canonical/chittyagent-dispatch.md` are all `chittyagent-*` prefixed. PR #12 unified `chittyagent-neon-schema` → `chittyagent-neon` (filename matches slug).

**Decision required**: Which way to align?

- **(A) Rename files to slugs.** `chittyagent-canon.md` → `chittycanon-code-cardinal.md`. Preserves public API (slugs are what callers reference via `subagent_type:`). Breaks nothing externally. But abandons the `chittyagent-*` family-prefix convention that canonical/ favors.
- **(B) Rename slugs to family-prefix.** `chittycanon-code-cardinal` → `chittyagent-canon`. Aligns with canonical/ direction. **Breaks any code that uses `subagent_type: chittycanon-code-cardinal`** — those would all need updating. The published `~/.claude/plugins/marketplaces/chittymarket/plugins/chittyos-core/agents/*` files on every installed host would need re-fetching.
- **(C) Keep current divergence, codify both as valid.** Add CI rule: agent's frontmatter `name:` MUST match filename stem (allowing the role-slug option). Then *enforcing* convention going forward without forcing a rename pass.

**Recommendation**: (C) for stability + (A) on the next major release. Option B is breaking-change territory that should ride with another major bump.

### 2.2 Pointer files: hydration is undocumented

`chittyos-core/agents/chittyagent-schema.md` is a 41-line pointer to `CHITTYFOUNDATION/chittyschema/identity/agents/chittyschema-overlord.md` (379 lines). The pointer file's comment says:

> Loaders that hydrate plugin agents **should** resolve `prompt_source` (or `prompt_url` for raw fetch) to fetch the canonical prompt.

"Should" is forward-looking. **No loader in chittymarket currently performs this hydration.** When a user installs the plugin and invokes `chittyschema-overlord` via Claude Code's Task tool, Claude Code reads the 41-line pointer file directly — it does not fetch the canonical 379-line content from `CHITTYFOUNDATION/chittyschema`.

**Decision required**:

- **(A) Inline.** Replace the pointer with the canonical content. Single source goes back to chittymarket. Breaks the per-service-ownership pattern but works today.
- **(B) Implement the hydrator.** Build a `chittyagent-dispatch`-style projector that fetches `prompt_source` at install or invoke time. Aligns with per-service-ownership goal. Significant new code.
- **(C) Document as forward-looking and ship an inlined version in the interim.** The frontmatter pointer keeps the per-service-ownership intent; the body keeps an inlined copy until the hydrator exists. Sync via a CI job that runs against the source repo.

**Recommendation**: (C) for now. The per-service-ownership pattern is the right end state; (B) is the right implementation; until (B) lands, (C) keeps the agent functional without freezing the architectural decision.

### 2.3 Skills `name:` frontmatter field

Per the audit, 8 skills (in `chittymarket-manager`, `chittyos-core`, `chittyos-devops`) have no `name:` in their frontmatter — only `description:`. Other skills (`evidence-egress`, `capability-governor`, `wrangler-audit`, etc.) include `name:`.

Claude Code's skill loader uses the **dirname** as the slug; `name:` in skill frontmatter is decorative.

**Decision required**:

- **(A) Standardize on `name:` everywhere** (cohesion).
- **(B) Drop `name:` everywhere in skills** (less noise, dirname is enough).

**Recommendation**: (B). Skills are dir-rooted; `description:` is the only field actually consumed. Add a CI check that rejects `name:` in skill frontmatter (or warns).

### 2.4 The three-realm sprawl

Same artifact may currently live in:
- `chittymarket/plugins/<plugin>/skills/<name>/SKILL.md` (canonical for chittymarket)
- `~/.claude/plugins/marketplaces/chittymarket/plugins/<plugin>/skills/<name>/` (rendered install)
- `~/.claude/skills/<name>/` (freestanding pre-marketplace install — legacy)
- `ai-parity/portable/claude/skills/<name>/` (cross-machine sync canon)

**Decision required**: ai-parity vs chittymarket-as-source-of-truth.

**Recommendation**:
- Chittymarket is the **single source of truth** for plugin artifacts (skills/agents/hooks/MCP).
- `ai-parity/portable/claude/skills/` should be reduced to **only** items that are NOT shipped via chittymarket (raw `~/.claude/`-level configuration, settings.json templates, etc).
- `~/.claude/skills/<name>/` (freestanding) is **legacy and should be removed** once the corresponding plugin is installed via marketplace. The local-cleanup pass on chittymini-00 (2026-05-26 session) demonstrates this.
- `~/.claude/plugins/marketplaces/chittymarket/...` is the **only acceptable on-disk representation** of chittymarket plugin content on a host.

## Layer 3 — Auto-healing primitives (in flight / proposed)

Already shipped:

- **CI workflow** (`.github/workflows/validate-chittymarket.yml`, #25) — lint + test + manifest idempotency on every PR.

Proposed (would extend the workflow):

| Check | Purpose | Status |
|---|---|---|
| `agent_name_matches_filename` | Enforce 2.1 once decided | Pending decision |
| `pointer_source_fetchable` | Verify `prompt_source` URLs resolve | Pending 2.2 decision |
| `skill_no_redundant_name_field` | Enforce 2.3 once decided | Pending decision |
| `canonical_metadata_consistent` | Verify `canonical/<name>.md` matches the `plugins/.../<name>.md` it projects | Pending more canonical/ entries |
| `plugin_json_idempotent_with_top_level_metadata` | Catch the chittyagent-autobot-style duplicate manifest pattern | Could add now |

## How to use this document

- **Authoring a new plugin/agent/skill?** Follow Layer 1 (settled). Touch Layer 2 only after the relevant decision is made.
- **Adding a new convention?** Add it to Layer 1 only after CI enforces it. Decisions without CI rot.
- **Removing local drift?** Layer 0 source-of-truth precedence is the rule. Anything outside that lineage is dead weight.
