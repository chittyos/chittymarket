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
## 2026-09-21 — `chittycounsel`: unmanaged matter-bound clone (out-of-tree)

**Auditor:** capability-governor, invoked during the `legal-operating-defaults` existing-first search (PR #115)
**Scope:** one artifact, out-of-tree. Not a sweep.
**Disposition:** `merge` (into governed capabilities) + `retire` (the out-of-tree bundle). **Blocking finding attached.**

### What it is

`chittycounsel` — a 330-line "Virtual General Counsel" orchestrator with three embedded
sub-skills (1,087 lines total), found during existing-first discovery. It does not exist in
`canonical/`, has no `canon_uri`, no dispatch state, and no `.dispatch-state` sentinel. It is
distributed as part of a Claude Desktop remote plugin bundle, entirely outside the ChittyMarket
canonical → dispatch lane.

**Distribution, stated precisely (corrected 2026-09-21):** this is **one uploaded artifact, not 34
installs.** `~/.claude/remote/plugins/*/skills/chittycounsel` holds 32 directories whose `SKILL.md`
and `subskills/fact-governance.md` are byte-identical (single MD5 across all 32) — per-session
remote-plugin sync caches of one upload generation. The two other paths a naive `find` returns are
not skills: a git worktree of the unrelated `chittycounsel` **Worker** repo, and an entity
checkpoint directory. The earlier "34 copies on this host" was a true file count and a misleading
distribution claim; the blast radius is one uploaded skill, re-synced, not 34 independent installs.

The upload sits alongside `chittybiz`, `chittyxl`, and `nb-development-defaults` in the same
bundle — i.e. **the bundle owner is the operator**, not a third party.

### Blocking finding — matter-isolation defect (HIGH)

The bundle's embedded `subskills/fact-governance.md` **hardcodes a live matter into its
fact-mint and fact-query SQL** (`:12`, `:75`, `:112` — a literal `case_id` string in the INSERT
and in a bare `WHERE case_id = '<literal>'`).

The INSERT is the worse half, and worse than first described. Its `fact_number` subquery *is*
parameterized — `(SELECT COALESCE(MAX(fact_number),0)+1 FROM evidence_statement_of_facts WHERE
case_id = ?)` — while the `case_id` column it writes is the hardcoded literal. So a fact minted
with an explicitly-supplied case receives a fact number correctly scoped to *that* case and is
then stored under the hardcoded one. The result is not an obvious failure: it is a
plausibly-numbered fact filed to the wrong matter, which survives a glance at the row.

The governed `canonical/skills/fact-governance.md` states the opposite, twice:

> `:4` — "REQUIRES an explicit `case` parameter — refuses to run without one."
> `:19` — "This skill **requires** an explicit case identifier on every invocation. It MUST NOT
> default to any particular case."

And `canonical/skills/evidence-collect.md:36` records why that rule exists:

> "The #2 failure mode — historically observed — is attributing a document from case A to case
> B because the pipeline was run with a stale or hardcoded case default."

The out-of-tree clone is that failure mode, shipped. It is a divergent second definition of a
governed capability (153 lines vs the canonical's 199) whose divergence is precisely the safety
property the canonical was written to enforce. This is not a documentation-tidiness finding.

### Secondary findings

- **Matter data in a distributed definition.** The parent `SKILL.md` names a live matter and
  legal entity in 5 places, including the `description` frontmatter — which means the caption
  is loaded into the trigger surface of every session that has the bundle installed.
- **Unmanaged duplication.** Two further sub-skills (`9-step-legal-audit`,
  `cook-county-casesearch`) exist only here. `legal-operating-defaults` names both as routing
  targets and correctly caveats them as Desktop-bundle-only, not marketplace-resolvable.
- **No provenance.** No `canon_uri`, no §16 overlay record, no content hash, no dispatch sentinel.
  Drift against it is undetectable by `dispatch.sh reconcile` because nothing points at it.

### Decision

1. **Immediate:** the hardcoded `case_id` literals are a matter-isolation defect and should be
   removed from the bundle regardless of what happens to the rest of the disposition. Nothing
   downstream should mint or query facts against a defaulted case.
2. **Merge:** `9-step-legal-audit` and `cook-county-casesearch` are genuine capabilities with no
   canonical home. Promote to `canonical/skills/` under `chittyos-legal`, matter-agnostic, and
   dispatch them. `legal-operating-defaults` already routes to both by name.
3. **Retire:** the embedded `fact-governance` duplicate. The canonical one is authoritative and
   strictly safer.
4. **Reshape:** whatever remains of the orchestrator is matter-bound by construction. A governed
   successor must take the matter as a parameter. `chittyagent-paralegal` (PR pending) already
   occupies most of this job for counsel-support work and is matter-agnostic by design.

### Standard applied

`legal-operating-defaults` §8 (matter isolation — "a capability that requires a matter
identifier must refuse to run without one; no defaulting to the active case") and §15
(matter facts stay out of reusable capability packages).

**Not done in this entry:** nothing was edited, and no cache copy should be — they re-sync from
the upload, and editing local client config is forbidden by the centralized-registration rule.

**Who can act, corrected:** the bundle owner is the operator, so nothing here is blocked on a
third party. But there is no local source for the upload — every on-host copy is a cache, and
`CHITTYOS/chittycounsel` is the Worker service, not the skill. The corrected bundle therefore
lands in this repo as its durable home, and the one step that cannot be automated is the
operator re-uploading it (or removing `chittycounsel` from their skills). Until that step runs,
the defective definition remains live in every session with the bundle installed.

---

## 2026-09-21 — matter leakage in governed definitions: scrub + CI gate

**Auditor:** capability-governor, continuing from the `chittycounsel` audit (#117) and its
promotion PR (#118)
**Scope:** `canonical/`, `plugins/`, `docs/` — in-tree, governed definitions
**Disposition:** `fix` + `enforce`. 13 source hits scrubbed; a gate added so the class cannot
recur silently.

### The finding

#117 filed an out-of-tree bundle for hardcoding a live matter. The same class was already
in-tree, in the governed skills themselves: a concrete matter appeared as a caveated "worked
example" in four canonical skills and one research doc, and propagated to every projection.

The caveats were real and well-intentioned — *"Only as an illustration of the shape — do NOT
use this as a default"*. They satisfy `legal-operating-defaults` §8, which prohibits defaulting
to a case. They do not satisfy §15, which keeps matter facts out of reusable capability
packages at all. A capability package is published; a caption in it is published with it,
regardless of how it is labelled.

### Why a gate and not another sweep

This is the **third** recorded removal of the same class:

1. `evidence-collect.md:222` carries a historical note saying one matter's property data and
   marriage date were removed from the doc — and, until this entry, that note ended by quoting
   the matter's `case_id` literal. The note about removing matter data contained matter data.
2. `fact-governance.md` was rewritten with `<case_id>` placeholder discipline in every SQL
   block, and still carried a concrete `case_id` beside the field description at `:23`.
3. `#116` removed a live case caption from a published override rationale.

Each fix was correct and each time the class came back, because the recurring idiom is not
carelessness — it is an author wanting a concrete-looking value next to a `case_*` field so the
reader has something to look at. A sweep does not survive the next author. A gate does.

### The gate — `scripts/check-matter-leak.py`

Wired into `Validate ChittyMarket` between lint and test. Fails the build on any hit.

**It never learns which matters are real.** A denylist naming real matters would itself be
matter data, published in a public repo — the defect it is meant to prevent. Instead:

| Rule | Catches |
|------|---------|
| case-number shape | `YYYY<div><digits>`, case-insensitive, any separator, with or without a `case_` prefix |
| party-slug shape | `x-v-y` / `x_v_y` |
| caption shape | `<Surname> v. <Surname>`, unless the line also carries a reporter citation (published case law, not a live matter) |
| concrete example beside a case field | any value offered *after* an example marker (`e.g.`, `default`, `--case`) on a line naming a `case_*` field, unless drawn from the synthetic placeholder vocabulary |

The fourth rule is what catches matters whose slug shape is indistinguishable from an ordinary
one — a property address, an HOA name. It does not ask whether the value is real; it requires
that examples beside a case field be placeholders. The placeholder vocabulary contains only
format tokens and bracketed names, so it is safe to publish.

Positioning matters: only tokens *after* the example marker are considered, so the field being
described is not mistaken for the example. Report mode (`--report`) and ref scanning
(`--ref origin/main`) exist so the rules can be tuned against real history before they gate.

### Evidence

- Gate on `origin/main`: **37 hits** (13 source + 24 propagated into projections).
- Gate on this branch: **clean**.

### Deliberately deferred

A registry-backed check — resolving committed text against the live case registry — would catch
matters of *any* shape. It needs database credentials in CI, which is sensitive-intent routing
and the operator's call, not a unilateral one. Every recurrence observed so far is caught by
shape + context, so it is a follow-up, not a gap in this one.

### Related

- `chittyos/chittymarket#116` — live case caption in a published override rationale (same class)
- `chittyos/chittymarket#117` — the out-of-tree bundle that surfaced this
- `chittyos/chittymarket#118` — `9-step-legal-audit` promoted, scrubbed and guarded


---

## 2026-10-02 — `gauntlet` workflow promoted from chittyentity

**Auditor:** capability-registry-audit (runbook v0.2), run by the session that opened this PR
**Source:** `CHITTYOS/chittyentity` origin/main `.claude/workflows/gauntlet.js` (586 lines),
`.claude/agents/gauntlet-runner.md`, `docs/design/gauntlet-as-agent-workflow.md`; string-args
fix from chittyentity PR #736 (`fix/gauntlet-string-args-loud`).

### Disposition: **promote**

| Field | Value |
|-------|-------|
| canonical_id | `chittycanon://capability/build/gauntlet` |
| artifact | `workflow-gauntlet` (new `workflow` kind), canonical `canonical/workflows/gauntlet.md` |
| projection | `plugins/chittyos-core/workflows/gauntlet.js` → `Workflow({name: "chittyos-core:gauntlet"})` |
| entity mapping | **E** primary (a verification run is an occurrence in time), **T** secondary (the artifact under test) |
| environmental footprint | write-capable (the implementer role edits the target and its corpus) |
| evidentiary risk | low |
| owner | chittymarket / `chittyos-core` |
| access | write |
| visibility | advanced, `enabled: false` (new compiled artifacts are disabled by default) |

### Overlap check

No existing capability overlaps. `adversarial-review.sh` is a single-pass review of one diff.
The gauntlet is a multi-role loop (contest, generate, trace, mandate audit, then feeder against a
separated implementer until dry, then an independent verifier) against a runner and a fixture
corpus. Different job, different shape.

### Changes made at promotion

- #736 folded in: string `args` are parsed, objects pass through, malformed JSON and non-object
  shapes throw without echoing input. Empty args or a missing target/runner return
  `{started: false, reason, next}`.
- Every `agent()` call carries an explicit `model` (binding rule: an omitted model is a bug).
  Six judgment roles default to `opus`; the generator defaults to `sonnet` because its output is
  checked downstream. `args.models` overrides per role.
- `args.dryRun: true` returns the validated config and agent budget (`4 + 2*maxRounds + 1`, 17 at
  defaults) without dispatching. That makes the capability cheap to prove callable.

### Companion agent: `chittyagent-gauntlet` (HOLD)

`gauntlet-runner` is renamed to `chittyagent-gauntlet` (canonical agents are `chittyagent-*`; the
tier-2 design reserves the same name for a future remote worker). It projects to claude-code,
codex, and openclaw. It carries **no** capability identity, because the one capability id is
bound to the workflow and ids are unique. It therefore stays **HOLD** in market-reconcile: it
ships in the plugin, but it has no `marketplace.json` or overlay record. Minting a separate id for
it is a ChittyCanon decision and is not taken here.

### Retirement

The chittyentity copies (`.claude/workflows/gauntlet.js`, `.claude/agents/gauntlet-runner.md`)
are retired once this lands (design doc open question 2). Removing them is a chittyentity PR and
is not part of this change.
