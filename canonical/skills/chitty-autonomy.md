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

## Sovereignty Affirmation (Phase 0 — MANDATORY)

Before any other work, the synthetic entity (this Claude context) MUST request a Sovereignty Affirmation certificate from ChittyCert.

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
| 6 | Review | delegate to `chittyagent-canon` + `code-reviewer` + `silent-failure-hunter` + `comment-analyzer` | review report; gate to next phase |
| 7 | Tidy | `chitty-autonomy-tidy` | branch-cleanup, format, lint, chitty-cleanup invocation |
| 8 | CI/CD | `chitty-autonomy-cicd` | `.github/workflows/`, wrangler deploy targets, secrets scaffold |
| 9 | Ship | `chitty-autonomy-ship` | PR created/auto-merged, ChittyRegistry update, Notion sync |
| 10 | Memory | inline | feedback/project memory written; ChittyChronicle finalize entry |

## State Machine

State persisted at `chittycontext/structured-autonomy/<feature>/state.json`:
```json
{
  "feature": "<name>",
  "branch": "<kebab>",
  "cert_id": "<chittycert-issued-id>",
  "phase": "discover|plan|generate|implement|review|tidy|cicd|ship|memory|done",
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
