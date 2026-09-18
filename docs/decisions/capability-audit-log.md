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

---

## 2026-09-18 — Five-artifact governance pass, with three overrides of the computed disposition

**Auditor:** capability-governor (skill v1.0.0)
**Source:** `scripts/batch_audit.py` over five candidate artifacts, then re-derived by hand against `references/decision-matrix.md`
**Machine-readable logs:** `docs/decisions/logs/dec_20260918_*.json` (all five pass `scripts/validate_decision_log.py`)

### Why three dispositions were overridden

`scripts/audit_artifact.py` assigns `environmental_footprint` by **keyword match** on the
artifact description (`FOOTPRINT_RULES`), then routes footprint → disposition. For
`admin-system(5)` the trigger words include `secret`, `auth`, `config`, `token`, `deploy`.

Any description of a secret-**detection** tool therefore scores `admin-system(5)` and routes
to `local-only`, regardless of what the tool does. The matrix defines footprint 5 as
*"changes auth, secrets, config, infra, deployment, or policy"* — a scanner changes none of
them. The script is a lossy implementation of the matrix, and where the two disagree on an
artifact whose description carries the wrong trigger words, **the matrix controls**.

Two further artifacts were documentation links with no implementing artifact at all. The
script classified prose, because prose was all it was given. The skill's own core rule covers
this: *"If source data is insufficient, return `hold` with the missing evidence."*

| artifact | computed | recorded | axis actually in dispute |
|---|---|---|---|
| Repo secret-leak gate | `local-only` | **`promote`** | footprint `admin-system(5)` → `network-service(3)` |
| R2 SQL query execution | `hold` | `hold` *(accepted)* | footprint `write-capable(2)` → `network-service(3)`; disposition unchanged |
| Evidence preservation catalog | `legal-only` | `legal-only` *(accepted)* | none — axes substantively correct here |
| Cloudflare Workflows | `gateway` | **`hold`** | no artifact exists to expose |
| WAF leaked-credentials detection | `local-only` | **`hold`** | footprint 5 upheld; `local-only` still wrong for an edge-evaluated detection |

### Correction to an earlier claim in this session

The evidence preservation catalog was characterized mid-session as an **ownerless empty
scaffold**. That was wrong, and live verification overturned it before anything was written.
It is owned and wired end to end:

- `chittyevidence-db` binds `PRESERVATION_STREAM`, `COLLECTION_STREAM`, `SOURCE_CANONICAL_STREAM`
- pipeline `chittyevidence_preservation` runs `INSERT INTO chittyevidence_preservation_iceberg SELECT * FROM chittyevidence_preservation_stream`
- R2 Data Catalog `7b59ebb2-…` is `status: active`, `credential_status: present`
- bucket `chittyevidence-pipeline` holds 1867 objects / ~112 MiB
- real implementing code with tests (`pre-filter-transform.test.ts`, `pipeline-e2e.test.ts`, `collection-handler.test.ts`)

The initial repo grep missed it because it searched for the Iceberg **table name**, which
exists only in the sink config; the code refers to the **binding name**.

### Findings — evidence preservation path

#### Block — fail-open on a custody path (latent)

`CHITTYOS/chittyevidence-db/src/index.ts:2507`

```js
if (result.qualified.length > 0 && env.PRESERVATION_STREAM) {
  await env.PRESERVATION_STREAM.send(result.qualified);
}
```

The batch is then marked processed **unconditionally** at `:2517`. If the binding is absent,
qualified evidence is silently dropped, the batch is recorded as done, and there is no retry
and no error. Same fail-open class as `chittyconnect`'s `getCredential` fallback.

**The binding is present in production today, so this is latent, not active.**

#### Block — structured custody payload written to an undrained stream

`src/index.ts:2930` writes a 13-field custody payload (`content_hash`, `r2_key`,
`ingested_at`, `is_duplicate`) to `SOURCE_CANONICAL_STREAM`. That stream exists and is
worker-bound, but has **no pipeline and no sink** on the account. Those writes are accepted
and drained nowhere.

#### Block — schema unfit for a legal-grade table

The preservation stream carries the **Pipelines unstructured default**: a single required
field `value` of type `json`, `unstructured: true`. Every structured field lands in one opaque
column, so the table cannot be queried by `content_hash` or timestamp without JSON
extraction.

In mitigation, `snapshot_expiration: disabled` is the correct posture for a custody table.
But `compaction: enabled` at a 128 MB target rewrites underlying data files — which is exactly
why a documented `custody_policy` is a required gate artifact and not paperwork.

### Findings — adjacent, found during verification

#### Block — `canon_publish` pipeline targets a bucket that does not exist

Sink `canon_publish_sink` is configured with `bucket: "chittyos-events"`, path `canon/`.
That bucket is **not among the account's 28 R2 buckets**. The pipeline also has no
worker-bound producer.

#### Note — `/accounts/{id}/pipelines` is the legacy endpoint

It returns `[]` while `/accounts/{id}/pipelines/v1/pipelines` returns 4. Reading the legacy
path produces a false "no pipelines configured" conclusion. This audit initially made that
error and caught it by checking both.

### Quality gates

- [x] Exactly one primary disposition per artifact — 5/5
- [x] Exactly one primary job-to-be-done per artifact — 5/5
- [x] Overrides carry recorded rationale naming the disputed axis — 3/3
- [x] Existing-first search before `promote` — `capabilities.generated.json` (106 capabilities) has no secret-scanning capability
- [x] Non-repudiation gate — `legal-only` asserted for the preservation catalog; `source_links` now supplied
- [ ] **`hash_policy`, `timestamp_policy`, `custody_policy` — still absent.** Capability remains gated, not active.
- [x] Decision logs include source links — 5/5, validator-enforced
- [x] Retirement decisions include replacement/rollback — n/a, no retirement recorded
- [x] Live state pulled, not inferred — all Cloudflare facts re-verified 2026-09-18

### Migration queue

| item | artifact | action | risk | status |
|---|---|---|---|---|
| `mig_20260918_secret-leak-gate` | chittyconnect PR #309 | document + propagate | low | active |
| `mig_20260918_preservation-failopen` | `chittyevidence-db/src/index.ts:2507` | restrict (fail closed) | legal-grade | backlog |
| `mig_20260918_source-canonical-undrained` | `chittyevidence_source_canonical_stream` | reroute or retire | legal-grade | backlog |
| `mig_20260918_preservation-schema` | `chittyevidence_preservation_stream` | **operator decision** — re-schema or retire | legal-grade | blocked |
| `mig_20260918_canon-publish-bucket` | `canon_publish_sink` | reroute or retire | low | backlog |

**Review date:** 2026-10-02
