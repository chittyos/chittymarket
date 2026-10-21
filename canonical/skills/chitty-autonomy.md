---
name: chitty-autonomy
description: ChittyOS-canonical autonomous PR-driver. One-stop workflow that orchestrates Sovereignty → Discover → Brainstorm → Plan → Generate → Implement → Review → Tidy → CI/CD → Ship → Memory. Issues a SOVEREIGNTY.cert from ChittyCert at start; Pentad-aware (CHARTER+CHITTY+CLAUDE+SECURITY+AGENTS); enforces canonical pipelines (no rclone-bypass, no direct R2 writes); writes ChittyChronicle audit entries per phase. Triggered by `/autonomy <feature-request>` or by-hand invocation.
canonical_uri: chittycanon://skills/chitty-autonomy
status: DRAFT
sovereignty_cert_required: true
sovereignty_cert_issuer: chittycanon://core/services/chitty-cert
kind: skill
plugin: chittyagent-autobot
runtimes:
  - claude-code
  - codex
  - openclaw
  - universal
classification:
  - governance
  - autonomy
---

# Chitty Autonomy — Parent Orchestrator

## Purpose

Drive a feature request from one-line prompt to merged PR with full ChittyOS canonical compliance. This is the SUCCESSOR to the `structured-autonomy-{plan,generate,implement}` trio. It addresses three classes of defect in the original:

1. **Tool-syntax debt** (`#tool:runSubagent`, `#context7`, `ResizeMe` Windows references).
2. **Governance blindness** (no ChittyRegistry discovery, no canon citations, no `chittyagent-canon` review).
3. **No state machine** (three skills that don't compose; no failure recovery).

## Preflight (before Phase 0 — RUN THIS FIRST)

```bash
# Repo copy (source of truth):
#   plugins/chittyagent-autobot/skills/chitty-autonomy/scripts/preflight.sh
# Installed copy, when this skill is loaded from the runtime skills dir:
~/.claude/skills/chitty-autonomy/scripts/preflight.sh
```

Exit 0 = proceed. Non-zero = **stop and report**; do not start the pipeline.
Checks identity (and that it is entity type **P** — a synthetic agent is a
Person, never a Thing), continuity-substrate health, ChittyCert reachability,
and that the front-door contract has not moved.

This exists because on 2026-07-30 a run reached Phase 0 and died on an opaque
403, with three drifts behind it that no amount of reading the skill text would
have revealed. Catching it here costs seconds; catching it mid-pipeline wastes a
run and tempts an agent into routing around a governance gate.

## Sovereignty Affirmation (Phase 0 — MANDATORY)

Before any other work, the synthetic entity (this Claude context) MUST obtain a
Sovereignty Affirmation certificate from ChittyCert.

> **⚠ ChittyCert does NOT accept direct calls from synthetic agents.**
> `POST https://cert.chitty.cc/api/v1/issue` returns:
> *"Direct synthetic agent access prohibited. Route through the front door
> (mychitty Phase 0 continuity substrate). Use the MCP Orchestrator or run
> `can chitty whoami` / `can chitty authenticate-context` to acquire your
> identity binding."*
>
> **A 403 here means WRONG DOOR, not "this entity lacks authority."** Do not
> conclude you are unauthorized and stop — establish the identity binding via
> the front door and route issuance through the orchestrator.
>
> **Never resolve a cert token inline.** An earlier revision of
> `chitty-autonomy-affirm` used `op run` against 1Password. 1Password is
> **RETIRED**; credential resolution belongs to the ChittySecrets /
> ChittyConnect broker. Delegate to `chittyconnect-concierge` (`/chico`).
> Fail closed with `POLICY_BLOCKED_CHITTYCONNECT_UNAVAILABLE` rather than
> falling back to any inline path.

The cert request payload (issued via the front door, **not** POSTed directly to
`cert.chitty.cc`). The front door is the mychitty continuity substrate:

```
POST https://mychitty.com/api/v1/identity/api/v1/issue
{
  "type": "TRUST_CHAIN",
  "subject_chitty_id": "<P-Synthetic ChittyID for this session>",
  "subject_type": "P",
  "subject_status": "Operational",
  "purpose": "synthetic-entity-sovereignty-affirmation",
  "scope": {
    "feature": "<feature-name>",
    "branch": "<kebab-branch-name>",
    "repo": "<owner/repo>",
    "valid_until": "<iso, default +24h>"
  },
  "constraints": [
    "Cannot bypass canonical pipelines (POST /collect, /documents, /vault/ingest)",
    "Must cite chittycanon:// URIs when defining/validating entity types (P/L/T/E/A — all five)",
    "Must consult ChittyRegistry before scaffolding new services",
    "Must require Pentad (CHARTER, CHITTY, CLAUDE, SECURITY, AGENTS) for new services",
    "Must emit ChittyChronicle audit entry per phase boundary"
  ],
  "ledger_anchor": "chittycanon://core/services/chittychronicle"
}
```

Response payload is persisted to `chittycontext/structured-autonomy/<feature>/SOVEREIGNTY.cert` and referenced by `cert_id` in every subsequent phase output. If issuance fails, abort the whole workflow — **the agent does not act without affirmation**.

> **Note:** The `TRUST_CHAIN` tier is the closest existing fit. A formal `SOVEREIGNTY_AFFIRMATION` tier should be proposed to the ChittyCert charter as a follow-up issue.

## Phase Pipeline

| # | Phase | Skill | Output |
|---|---|---|---|
| 0 | Sovereignty | `chitty-autonomy-affirm` | `SOVEREIGNTY.cert` (signed by ChittyCert) |
| 1 | Discover | `chitty-autonomy-discover` | `chittycontext/.../discovery.md` (registry + Pentad reads) |
| 2 | Brainstorm | `superpowers:brainstorming` (delegated) | conversation context |
| 3 | Plan | `chitty-autonomy-plan` | `plan.md` with [NEEDS_CLARIFICATION] markers enforced |
| 4 | Generate | `chitty-autonomy-generate` | `implementation.md` with copy-paste TDD-aware code |
| 5 | Implement | `chitty-autonomy-implement` | committed code, format/lint inline |
| 6 | Review | delegate to `chittyagent-canon` + `code-reviewer` + `silent-failure-hunter` + `comment-analyzer` | review report |
| 7 | **`separated_review` (REQUIRED)** | `scripts/adversarial-review.sh` (from `nb-development-defaults`), or `chittyagent-olmec` | `separated_review.json` receipt; **hard gate** to Ship |
| 8 | Tidy | `chitty-autonomy-tidy` | branch-cleanup, format, lint, chitty-cleanup invocation |
| 9 | CI/CD | `chitty-autonomy-cicd` | `.github/workflows/`, wrangler deploy targets, secrets scaffold |
| 10 | Ship | `chitty-autonomy-ship` | PR created/auto-merged, ChittyRegistry update, Notion sync |
| 11 | Memory | inline | feedback/project memory written; ChittyChronicle finalize entry |

### `separated_review` is a hard gate, and why it is not phase 6

Phase 6's reviewers run **in-process, on the same host, in the maker's own
context**. That makes them a linting tier, not an adversarial one: an agent
cannot adversarially review its own diff, and a reviewer sharing the maker's
context tends to share its blind spot. `nb-development-defaults` grants the
execute-now licence on *separated* review — different agent, fresh context,
ideally a different model — and **withdraws** it when that reviewer is not in the
path. Phase 6 alone does not satisfy it, so phase 6 no longer gates: this phase
does.

**This gate is a state transition, not a paragraph.** A phase that exists only as
a row in a table is documentation of a control, not the control — a driver whose
transition logic reads `implement → review → tidy` is unaffected by prose. So:

- `ship` is **unreachable** unless `state.json` records `separated_review` with a
  receipt that passes every check below. A run whose `phase` moves from `review`
  to `tidy`, `cicd` or `ship` is **invalid** and must be rejected, not resumed.
- The phase has exactly one identifier — `separated_review` — in the table, the
  enum, and `phase_history`. No alias, no ordinal suffix: an identifier that
  differs between the table and the enum is joined by nothing, so an ordinal
  iterator silently has no row for it.

#### The receipt, and why an exit code is not enough

The phase writes `separated_review.json` beside `state.json`, and Ship verifies
it. An exit code cannot carry this, because the dangerous outcome is not an
error — it is a reviewer that **ran and returned nothing**, which to a caller
testing `exit 0` is indistinguishable from a clean pass. An under-powered
reviewer fails exactly this way, and that is how the whole mechanism becomes
theatre while still appearing in the pipeline.

```json
{
  "run_status": "ran_adequate | ran_inconclusive | did_not_run",
  "reviewer": { "model": "<id>", "host": "<separated host>" },
  "implementer": { "model": "<id>", "host": "<host>" },
  "coverage": { "diff_lines_sent": 0, "prompt_bytes": 0 },
  "findings": [ { "id": "", "severity": "critical|high|medium|low",
                  "state": "confirmed|refuted|fixed|risk_accepted",
                  "reason": "" } ]
}
```

Ship proceeds only when **all** hold:

1. `run_status` is `ran_adequate`. `did_not_run` and `ran_inconclusive` both mean
   the gate is **open**. A review that could not run is reported as *not
   performed*, never as "no findings" — the dispatch script's non-zero exits
   (unreachable reviewer, failed model call) map here, and so does a zero exit
   that returned no findings without coverage evidence.
2. `reviewer.model` **and** `reviewer.host` both differ from `implementer`'s.
   This is what makes separation *attestable* rather than asserted; without it,
   phase 6's own report can be relabelled to satisfy this phase, which is the
   path of least resistance and defeats the whole gate.
3. `coverage` is non-zero and consistent with the diff actually under review. A
   receipt claiming adequacy over zero bytes is `ran_inconclusive`.
4. **No finding with severity `critical` or `high` is left `confirmed`.** Each
   must be `fixed` or explicitly `risk_accepted` by the operator, recorded with a
   reason. Deferral to an issue is available for `medium` and `low` only — a
   severity floor exists precisely so "deliberately deferred" cannot be used to
   ship a confirmed critical within the letter of the rules.

#### Conduct

- **Runs before Ship.** A review landing after the merge is a record, not a gate.
- **Findings are triaged in writing**, each confirmed, refuted, fixed or
  risk-accepted with its reason. A refutation cites primary source, not
  recollection: a search that found nothing is evidence about the search, and a
  refutation built on one can be wrong while reading as rigorous.
- **Every confirmed fix is mutation-tested** — break what it guards and watch the
  alarm fire. A guard never seen to fail is decoration.
- **Two rounds maximum**, subject to the severity floor above. The cap limits
  iteration, never the floor.
- **Judgement, never an under-powered model.** Width and tier are independent
  axes; review absorbs wrong answers instead of catching them downstream.

#### Cost, bounded explicitly

One capable-model review **per PR**, not per phase and not per round: rounds
reuse the same lane, and the two-round cap bounds it at two calls. Dispatch to a
separated host draws on a different quota pool than the orchestrating session,
so the spend does not land in the caller's budget. Where the diff is empty the
phase records `did_not_run` with that reason and no model call is made. These
bounds are stated because a control mandated on every run, with a tier
requirement attached, is a recurring cost and the capability that imposes it owes
the number.

Scheduling and durable state for the loop belong to the existing durable task
board and scheduler capabilities. Do **not** stand up a new worker or cron for
it: they exist, and a new recurring line item is governed by `startup-mode`.

## State Machine

State persisted at `chittycontext/structured-autonomy/<feature>/state.json`:
```json
{
  "feature": "<name>",
  "branch": "<kebab>",
  "cert_id": "<chittycert-issued-id>",
  "phase": "discover|plan|generate|implement|review|separated_review|tidy|cicd|ship|memory|done",
  "phase_order": ["discover","plan","generate","implement","review",
                  "separated_review","tidy","cicd","ship","memory","done"],
  "gates": { "ship": { "requires": "separated_review", "receipt": "separated_review.json" } },
  "started_at": "<iso>",
  "phase_history": [
    { "phase": "affirm", "completed_at": "<iso>", "chronicle_entry": "<id>" }
  ]
}
```

Survives session restarts. On re-invocation, parent reads state and resumes at `phase + 1`.

## Product-Level Enforcement (NOT Claude Code hooks)

- **ChittyChronicle** entry per phase boundary (`chittycanon://docs/audit/<feature>/<phase>`).
- **ChittyRegistry** register/update on Phase 9 for new services.
- **ChittyCert verify** call at start of phases 5, 8, 9 (sanity check the affirmation is still valid).
- **Canonical-URI cite** in generated code: `// @canon: chittycanon://...`.
- **Pentad presence check** for new services via Phase 9 ship gate (refuses to ship without all five).

## Inputs

- Argument: `<feature-request>` (free-form natural-language description)
- Optional flags:
  - `--tdd` — force test-driven path through Phases 4-5
  - `--service <name>` — scaffold a new ChittyOS service (full Pentad)
  - `--resume` — re-enter the state machine at last incomplete phase
  - `--skip-discover` (REQUIRES justification stored in cert metadata)

## Failure Modes

- **Cert refused or expired** → abort; emit ChittyChronicle `affirmation_denied` entry; report to user.
- **[NEEDS_CLARIFICATION] still present at Phase 4 entry** → return to Phase 3, request clarification.
- **Hookify rule pattern detected in generated code** (e.g., `rclone copy` to evidence buckets) → return to Phase 4 with corrective instruction.
- **Pentad incomplete on a NEW service at Phase 9** → block ship; loop back to Phase 5.
- **Test failure at Phase 5** → invoke `superpowers:systematic-debugging`; do not advance.

## Hand-off Discipline

The parent skill ONLY orchestrates. Each phase is a child skill or delegated agent. The parent does not write code, run tests, or execute git commands directly — it picks the next phase, invokes the correct skill, captures output, and updates state.
