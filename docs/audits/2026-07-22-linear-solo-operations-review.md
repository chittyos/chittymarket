# Linear Solo Operations Capability Review

Date: 2026-07-22
Scope: all skills and plugin artifacts represented by `chittyos/chittymarket`, evaluated for ownership of Linear-based planning and execution for one human principal working with AI roles.

## Evidence base

- `.claude-plugin/marketplace.json` — native package surface
- `marketplace.json` — artifact inventory
- `canonical/skills/*.md` — canonical skill definitions
- `plugins/*/.claude-plugin/plugin.json` — bundled package contracts
- `capabilities.generated.json` — capability overlay
- `docs/audits/chittymarket-plugin-package-audit.json` — prior package disposition audit
- `docs/architecture/SINGLE-SOURCE-CONVENTIONS.md` — source precedence

## Inventory

| Layer | Before this change | After this change |
|---|---:|---:|
| Bundled plugin packages | 12 | 12 |
| External plugin packages | 4 | 4 |
| Cataloged plugin artifacts | 40 | 40 |
| Canonical skills | 31 | 32 |
| Cataloged skill artifacts | 18 | 19 |
| All cataloged capabilities | 105 | 106 |
| Capability-overlay coverage | 104/105 | 106/106 |

The native package layer, artifact inventory, and canonical skill layer are different projections. Counts must not be used interchangeably.

## Existing-first evaluation

| Capability | Existing job | Decision for Linear operations |
|---|---|---|
| `plugin-linear` | API/tool connector for Linear | Keep as the execution connector. It does not define operating doctrine. Do not duplicate it with a new connector or service. |
| `goal-creator` | Convert broad intent into a goal architecture and gated build pipeline | Keep. It owns goal formation, not ongoing tracker semantics, issue state, updates, or closure. |
| `chitty-autonomy*` / `chittyagent-autobot` | Draft, code-specific feature-to-PR state machine | Keep separate. It is too narrow for non-code work and too ceremonial for routine Linear operations. |
| `capability-governor` | Classify and govern marketplace capabilities | Keep. It decides placement; it should not become the daily work-management procedure. |
| `capability-registry-audit` | Produce capability disposition and migration records | Keep. It is a marketplace audit workflow, not a project control plane. |
| `skill-creator` | Author and project skills through ChittyMarket | Keep. It governs how this skill is created, not how Linear work is run. |
| `market` | Enable, disable, and inspect artifacts | Keep. It manages availability only. |
| `cast` | Route intent to MCP backends | Keep as a routing surface. It does not own work semantics. |
| `checkpoint`, `chittycontext`, `chittyxl` | Persist session state and memory | Keep separate. Session continuity is not project state. |
| `nb-development-defaults` | Broad operator-specific engineering defaults | Keep as an ambient overlay, but hold migration until its real source is moved into ChittyMarket. It is too broad and development-specific to own cross-domain Linear doctrine. |
| DevOps skills | Deploy, health, registry, pipeline, compliance, and Wrangler operations | Keep domain-specific. They may create or update Linear work through the shared control-plane skill. |
| Legal skills | Dispute, docket, evidence, custody, and fact governance | Keep in the Legal boundary. They may expose minimally descriptive Linear status and links but cannot move legal content into Linear. |
| External development/review plugins | Code generation, review, CI, browser, LSP, and documentation capabilities | Keep as executors or verifiers. None owns the human/AI work contract. |

## Disposition

Promote one new canonical skill: `linear-solo-operator`.

- Primary job: operate a Linear control plane for a single accountable human with AI execution capacity.
- Home plugin: `chittyos-core`.
- Runtime projections: Claude Code and Codex.
- Tool dependency: existing `plugin-linear` or another already-connected Linear surface.
- Footprint: reasoning procedure plus controlled write-capable connector.
- Evidentiary risk: medium business-record impact; legal details remain in Legal space.
- New infrastructure: none.

Do not create a new plugin, database, schema, team, project taxonomy, Linear workflow, label set, agent account, or service.

## Standard operating model

Use one human principal and five logical responsibilities: human principal, orchestrator, executor, verifier, and recorder. Treat AI roles as responsibilities, not coworkers or invented assignees. Preserve distinct execution and verification passes even when one model performs both.

Use Linear for outcome, priority, state, dependencies, decisions, gates, blockers, and evidence links. Keep code, long-form documents, and legal evidence in their existing canonical systems.

Use the loop:

`frame → plan → execute → verify → record → gate or close`

## Remaining marketplace findings

1. Fourteen preexisting canonical skills are still absent from `marketplace.json`, including autonomy phases, capability governance, `cast`, `chico`, and `evidence-egress`. This review does not silently add or enable them; reconcile them in a separate capability-inventory change.
2. `skill-nb-development-defaults` remains a local-home artifact rather than a ChittyMarket-owned canonical source. Its missing overlay record is repaired here, but source migration remains a separate decision.
3. `plugin-linear` is cataloged but disabled by default. Do not change that global default as a side effect of adding workflow doctrine; fail closed and request connection when no Linear surface is available.
4. Forty capability source links still point to local-home installation paths. They are warnings rather than CI failures, but they weaken portable provenance.
5. The repository-wide dispatch audit has a preexisting temporary-file bug when reprojecting MCP definitions. Direct projection works, while the audit wrapper opens an empty output file that the merge adapter then attempts to parse as JSON.

## Verification

- Plugin tests: pass
- Plugin lint and canonical/projection alignment: pass
- Capability schema: pass
- Capability provenance hashes: pass
- Overlay coverage: 106/106, no orphans
- Gated source-link freshness: pass
- New skill Claude/Codex projections: generated from the canonical source
