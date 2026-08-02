# Capability Audit — Decision Log

Append-only log of capability registry audits. One entry per audit per the
v0.2 runbook §6. Entries are emitted by the `capability-registry-audit`
skill.

---

## 2026-05-23 — Phase 1 overlay batch sweep

**Auditor:** capability-registry-audit (skill v1.0.0)
**Source:** `capabilities.generated.json` v1.1.0 (102 capabilities, generated 2026-05-11)
**Scope:** governance gates only — ontology coverage, non-repudiation gate, execution-class consistency.

### Findings

#### Pass — ontology coverage

- **0** capabilities missing primary P/L/T/E/A ontology mapping across all 10 capability groups.
- Quality gate §11 "Every artifact has one entity mapping" — **satisfied**.

#### Block — non-repudiation gate incomplete

**Update 2026-05-23 (later):** initial audit checked the `legal` group only and
flagged 5 records. Once the pre-commit drift hook's evidence-gate enforcement
landed, it found **8** violators total — 3 additional records outside the
`legal` group (`govern/fact-governance`, `ship/evidence-collection`,
`govern/block-governance-edits`). All 8 are now covered in
`docs/overrides/evidence-gate-overrides.json`.

All 8 capabilities declare `authority.non_repudiation_required: true` but
carry `authority.evidence_gate: null`:

| capability_id | exec_class | mutation_risk |
|---|---|---|
| `chittycanon://capability/legal/search-evidence-documents` | `@chitty/reasoning` | high |
| `chittycanon://capability/legal/dispute-manager` | `@chitty/connectors` | high |
| `chittycanon://capability/legal/court-docket` | `@chitty/connectors` | high |
| `chittycanon://capability/legal/legal-arsenal` | `@chitty/connectors` | high |
| `chittycanon://capability/legal/chittymcp-claude-ai` | `@chitty/reasoning` | high |
| `chittycanon://capability/govern/fact-governance` | `@chitty/reasoning` | high |
| `chittycanon://capability/ship/evidence-collection` | `@chitty/reasoning` | high |
| `chittycanon://capability/govern/block-governance-edits` | `@chitty/workspace` | high |

Runbook §11 non-repudiation gate requires hash + timestamp + source trail
**before activation**. The flag is asserted but the enforcement mechanism
(`evidence_gate`) is unspecified. Per runbook §3.3 (Gemini round-2 brief),
the gate must live somewhere concrete — inside the projection, inside Ch1tty
`execute`, or as pre-execute middleware.

**Disposition:** `hold` on portal exposure for all 5. Disposition becomes
`legal-only` once `evidence_gate` is populated with one of:

- `pre-execute-middleware` (Ch1tty `execute` enforces before tool invocation)
- `projection-internal` (the projection itself verifies + emits receipt)
- `legal-space-only` (only callable inside Legal space runtime)

**Migration required:** yes. Owner: governance + legal plugin owners.
**Next action:** populate `authority.evidence_gate` in the upstream generator
for all 5 legal capabilities, then re-run the overlay generator. Block
portal/projection emit until populated.
**Review date:** 2026-06-06 (2-week window).

#### Pass — capability group distribution

```
agent-runtime:  4
build:         29
connect:       22
govern:        15
internal:       3
legal:          5
local-lab:      5
market:         1
ship:          12
workspace:      6
total:        102
```

No anomalous bucket sizes; no orphan groups. `market` (1) is acceptable — it
is the manager projection only; ChittyMarket is a registry, not a workspace
of market-typed capabilities.

### Quality gate checklist (this audit)

- [x] Existing inventory was searched first.
- [x] Primary job-to-be-done per capability (inherited from overlay).
- [x] At least one P/L/T/E/A entity mapping — all 102 pass.
- [ ] Exactly one disposition per audited capability — **5 legal capabilities `hold`, 97 carry-forward `keep`**.
- [ ] Evidence-touching items routed to Legal space — **blocked on evidence_gate population**.
- [x] Platform variants tied to one canonical identity — overlay enforces via `capability_id`.
- [x] Dual-manifest drift check — pre-commit drift hook (#17) covers this on commit.
- [ ] Non-repudiation gate applied where required — **incomplete; 5 records**.
- [x] Decision log includes source links.

### Source links

- `capabilities.generated.json`
- `docs/architecture/CHITTYMARKET_CAPABILITY_ROUTER.md`
- `docs/capability-registry-audit-runbook.md` v0.2 §11
- `docs/gemini-strategy-v1-followup.md` §B.2

---

## 2026-08-02 — repo-hygiene-governance (proposed capability)

**Auditor:** capability-registry-audit (skill v1.0.0)
**Source:** operator request — "full git hygiene program incl. automation", ecosystem-wide
**Scope:** single proposed capability. Is it a duplicate, a composition, or genuinely new?

### Existing-first search (runbook §1 — all five performed)

| # | Source | Result |
|---|---|---|
| 1 | `capabilities.generated.json` (104) | **No repo/git-hygiene capability.** Nearest: `build/github`, `build/github-workflows`, `build/commit-commands` (connectors, not governance); `govern/neon-schema-drift` (drift detection — same *shape*, different subject: schema not repos) |
| 2 | `registry.chitty.cc/api/v1/tools` | Only `flow-hash-check`. No match |
| 3 | `marketplace.json` + `.claude-plugin/marketplace.json` | `plugin-github`, `plugin-github-workflows`, `skill-chitty-cleanup` (disk caches, not repos). No match |
| 4 | CHARTERs of adjacent workers | See boundary analysis below |
| 5 | Ch1tty `servers.json` / ChittyMCP | No registered repo-hygiene capability |

Runbook §1 uses `/api/services`; that path 404s on the deployed worker. Used `/api/v1/tools`, the only KV-backed source of truth. **Runbook correction needed.**

### Boundary analysis — why the adjacent capabilities are not this one

| Capability | Its job | Why not a duplicate |
|---|---|---|
| `chittyagent-git` | Read-only MCP over GitHub REST (`status`, `log`, `show`, `diff`, `list_branches`) | A **tool**, not a capability. Supplies observation; owns no rules, no remediation. CHARTER explicitly excludes writes |
| `chittyagent-ship` | Dev **session** wrap-up: preflight, brainstorm, checkpoint, cleanup, branch | Developer-triggered, single-repo, session-scoped. Hygiene is scheduled/event-triggered, fleet-scoped, no human by default. Different JTBD, different trigger, different cardinality |
| `chittyagent-cleaner` | **Disk** cleanup (Marie Kondo — files, caches, large files) | Filesystem, not repository. No overlap |
| `workers/shared/remediation-loop.ts` | Review→Evaluate→Remediate engine, Neon-authoritative, `LoopSubjectKind` includes `code_pr` | The **engine**, not a capability. Hygiene is a `LoopSubject` on it |
| `govern/neon-schema-drift` | Schema drift detection | Same governance shape, different subject. Sibling, not parent |
| `chittyagent-alchemist` | Deploy-time conformance scoring / `mcp-code-mode-ready` promotion | Scores services against the alchemize contract, not repos against hygiene rules. Also currently non-functional (CFDXN-126) |

### Classification (runbook §2)

- **A. Job-to-be-done:** `govern` — exactly one
- **B. Environmental footprint:** `write-capable` (observation read-only via chittyagent-git; remediation opens PRs)
- **C. Evidentiary risk:** `low` — findings persist to `event_ledger` but are not evidence-grade
- **D. Runtime projection:** `mcp-tool` primary, `skill` secondary (rules are reasoning; execution is tool-driven)
- **E. Entity mapping:** `T` primary (repository = Thing), `E` (commit / PR / finding = Event), `A` (gate verdict = Authority)

### Matrix walk (runbook §3)

1. *Already exists under another name?* — **No.** Nearest neighbours differ in subject (`neon-schema-drift`), scope+trigger (`ship`), or layer (`chittyagent-git`, `remediation-loop` are parts, not the whole)
2. *Only a platform adapter?* — No
3. *Genuinely new job-to-be-done?* — **Yes → `promote`**

Disposition is `promote`, **but the build is composition, not greenfield.** ~85% of the machinery exists. Only the ruleset and the write path are new. A greenfield implementation would be the anti-pattern this runbook exists to prevent.

### Output 1 — Taxonomy entry

```yaml
canonical_id: repo-hygiene-governance
capability_id: chittycanon://capability/govern/repo-hygiene-governance
display_name: Repository Hygiene Governance
job_to_be_done: govern
summary: >
  Continuously detect and remediate repository-hygiene defects across the
  ChittyOS fleet — tracked build artifacts, unignored output dirs, missing
  commit-message lint, absent local hook layer, stale branches, and CI gates
  that cannot fail.
entity_mapping: [T, E, A]
capability_group: govern
execution_class: "@chitty/connectors"
source_of_truth: chittyentity/workers/ (composition; no new worker at Phase 1)
environmental_footprint: write-capable
evidentiary_risk: low
canonical_version: 0.1.0
runtime_exclusions: []
allowed_projections: [claude-code, codex, mcp]
restricted_projections: [web-portal, legal-space]
non_repudiation_required: false
slim_mcp_hint: "repo hygiene — detect+remediate tracked artifacts, missing lint/hooks, stale branches, non-failing CI gates"
owner: unassigned
status: experimental
```

### Output 2 — Disposition decision

```yaml
decision_id: CAP-2026-08-02-001
date: 2026-08-02
capability_name: Repository Hygiene Governance
canonical_id: repo-hygiene-governance
decision: promote
rationale: >
  Matrix step 3. No existing capability carries this job-to-be-done. The
  adjacent artifacts are parts (chittyagent-git = observation,
  remediation-loop = engine) or differ in subject/scope/trigger
  (neon-schema-drift, ship, cleaner). Promote as a govern-group sibling of
  neon-schema-drift, built by composition over existing parts.
duplicates_found: []
migration_required: yes
next_action: >
  Register as a LoopSubject on remediation-loop (kind: code_pr) with
  chittyagent-git as the Reviewer source. Author the ruleset. Decide the
  write path — chittyagent-git CHARTER excludes writes by design.
review_date: 2026-09-02
```

### Output 3 — Migration queue item

```yaml
migration_item: CAP-MIG-2026-08-02-001
from_artifact: (none — new capability)
to_canonical_capability: chittycanon://capability/govern/repo-hygiene-governance
action: document
blocking_dependencies:
  - "chittyagent-git CHARTER excludes write operations — remediation needs an
     audited write surface. Either extend it (per its own 'separate audited PR'
     note) or route writes through chittyagent-ship, which already does branch
     management."
  - "CFDXN-126 — chittyagent-alchemist proposal persistence broken; do NOT
     build the learning half on it until fixed."
  - "capabilities.generated.json is generated — the new record requires an
     upstream generator change, not a hand edit."
risk_level: low
owner: unassigned
status: backlog
completion_evidence: (pending)
```

### Ruleset seed (the genuinely new part)

From the operator's own `nb-development-defaults` Review-and-Audit-Bias section plus defects found in `chittycan`:

| rule | detects | evidence it is real |
|---|---|---|
| tracked build artifact | `*.tgz`, `dist/`, `out/` committed | `chittycan-0.5.1.tgz` tracked in chittycan |
| unignored output dir | dirty tree from build output | `out/` untracked+unignored in chittycan |
| no commit-msg lint | conventional-commit history with no enforcement | chittycan: disciplined history, zero enforcement |
| no local hook layer | no husky/lefthook/pre-commit | chittycan has none; chittymarket's drift hook shows the value |
| non-failing CI gate | `continue-on-error: true` on a never-passing job; empty required-check list; test step exiting 0 on no tests; suite whose module never loaded | `chittycan#134`; `chittymarket#81` (check red on every PR = no signal) |
| deployed-without-source | `wrangler.toml` `main:` points at a path not in the repo | `chittyagent-can` — live at `can.chitty.cc`, no `src/` committed |

### Quality gate checklist (runbook §6)

- [x] Existing inventory searched first — all five sources
- [x] Exactly one primary job-to-be-done — `govern`
- [x] At least one P/L/T/E/A mapping — `[T, E, A]`
- [x] Exactly one disposition — `promote`
- [x] Evidence-touching items routed to Legal space — n/a, `evidentiary_risk: low`
- [x] High-privilege items not broadly exposed — `restricted_projections: [web-portal, legal-space]`
- [x] Platform variants tied to one canonical identity — single `capability_id`
- [x] Dual-manifest drift checked — no existing entry in either manifest
- [x] Non-repudiation gate — not required, `false` asserted explicitly
- [x] Retirement decisions include replacement/rollback — n/a, no retirement
- [x] Decision log includes source links

### Source links

- `chittyentity/workers/chittyagent-git/CHARTER.md`
- `chittyentity/workers/shared/remediation-loop.ts`
- `chittyentity/workers/chittyagent-ship/CHARTER.md`, `chittyagent-cleaner/CHARTER.md`
- `capabilities.generated.json` v1.1.0
- `chittyos/chittymarket#81` — non-idempotent generator (non-failing-gate exemplar)
- `chittyos/chittyentity#613` / CFDXN-126 — alchemist blocker
- CFDXN-127 — skill catalog drift (same audit session)
