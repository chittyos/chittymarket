---
name: fact-governance
canon_uri: chittycanon://core/services/chittymarket#skills/fact-governance
description: Evidence fact governance for a specified case. Triggers on "fact", "evidence", "verify", "verification", case materials, dates/amounts/claims, or chittyevidence-db operations. REQUIRES an explicit `case` parameter — refuses to run without one. Manages fact lifecycle (draft→verified→locked), versioning, corrections, and governed downstream projections.
kind: skill
plugin: chittyos-legal
runtimes:
  - claude-code
  - codex
classification:
  - legal
  - evidence
canonical_capability_ref: "chittycanon://capability/govern/fact-governance"
overlay:
  title: "Fact Governance"
  capability_group: "govern"
  group_assignment_source: "name-rule"
  execution_class: "@chitty/reasoning"
  canonical_version: "1.1.0"
  projection_version_policy: "inherit-canonical"
  ontology:
    primary:
      - "A"
    secondary:
      - "P"
      - "E"
      - "T"
  authority:
    requires_chittyid: true
    requires_governance_authority: true
    non_repudiation_required: true
    evidence_gate: "projection-internal"
  execution:
    default_surface: "ch1tty"
    local_allowed: false
    context_cost: "high"
    mutation_risk: "high"
  discovery:
    indexable: true
    session_index: "hidden"
    ambient_by_intent: false
    verbs:
      - "govern"
      - "audit"
      - "validate"
      - "certify"
      - "enforce"
    fallback_search: true
  auth_flow:
    mode: "service-token"
    stores_credentials_in: "ChittyConnect"
    fail_closed_if_unavailable: true
  runtime_exclusions: {}
  phase0_audit:
    job_to_be_done: "generate"
    environmental_footprint: "forensic-legal-grade"
    evidentiary_risk: "legal-grade"
    advisory_disposition: "legal-only"
  legacy_category: "legal"
  deprecated_aliases:
    - "skill-fact-governance"
  visibility: "recommended"
  access: "readwrite"
  compatible_channels:
  - claude_code
  - claude_ai
  - claude_desktop
  - chatgpt
  - codex
  - openclaw
  source_links:
  - local://~/.claude/skills/fact-governance
---

# Fact Governance — Evidence Pipeline

## Required: `case` parameter

This skill **requires** an explicit case identifier on every invocation. It MUST NOT default to any particular case.

Accept either:

- **`case_id`** — the chittyevidence-db case identifier, shape `case_<...>`
- **`case_slug`** — a registered case slug (resolve via `evidence_cases` or the chittyrouter case registry)

If no `case` is specified, stop and ask the caller for one. Do not fall back to any previously-used case.

Resolve the case for each invocation. Read-only SQL examples use placeholders; mutation paths use the resolved case in the authenticated service request. Never reuse a case by default.

## Database Integration

- **Database:** chittyevidence-db
- **ID:** f486fed7-cba9-47d2-93fb-ca11d90ca084
- **Case ID:** provided per invocation (never hardcoded)
- **Table:** evidence_statement_of_facts

### Schema

```sql
evidence_statement_of_facts (
  id TEXT PRIMARY KEY,
  case_id TEXT,
  fact_number INTEGER NOT NULL,
  fact_date TEXT,
  fact_text TEXT NOT NULL,
  exhibit_reference TEXT NOT NULL,  -- REQUIRED
  document_id TEXT,
  source_quote TEXT,
  has_conflict INTEGER DEFAULT 0,
  conflict_with_fact_id TEXT,
  created_at TEXT,
  status TEXT DEFAULT 'draft',      -- draft|verified|locked|disputed|archived|rejected
  version INTEGER DEFAULT 1,
  category TEXT,                    -- CORP|PROP|TIME|FIN|CONT|PROC|ADM|EVID
  verified_by TEXT,
  verified_at TEXT,
  supersedes_id TEXT,
  updated_at TEXT,
  submitted_by TEXT
)
```

### Related Tables

- `evidence_correction_queue` — Corrections workflow
- `evidence_correction_audit_log` — Audit trail
- `evidence_review_queue` — Review workflow
- `evidence_provenance_records` — State tracking
- `evidence_chain_of_custody` — Chain of custody

## Status Lifecycle

| Status | Can Edit | Transitions To |
|--------|----------|----------------|
| draft | Yes | verified, rejected, disputed |
| verified | Correction only | locked, disputed, archived |
| locked | Never | (immutable) |
| disputed | Notes only | draft, verified |
| archived | Never | (immutable) |
| rejected | Never | (immutable) |

## Categories

| Code | Name |
|------|------|
| CORP | Corporate (LLC, membership, governance) |
| PROP | Property (real estate, deeds) |
| TIME | Timeline (dated events) |
| FIN | Financial (amounts, transactions) |
| CONT | Contradiction (claim vs counter-evidence) |
| PROC | Procedural (docket, filings, orders) |
| ADM | Admission (party statements) |
| EVID | Evidence (document existence/location) |

## Governed runtime operations (CFDXN-193)

Use the existing ChittyConnect broker to invoke the ChittyEvidence service. The
runtime must authenticate the acting ChittyID, require write/admin authority and
an active case grant, and compare that actor with the stored producer on every
lifecycle write. A service credential without an authenticated acting identity is
insufficient. Never supply `verified_by`, `submitted_by`, an actor header, or a
newly invented identity as a substitute for authenticated caller context.

These operations depend on the CFDXN-193 service implementation being deployed
and verified. If the broker, authenticated identity, runtime route, or required
schema is unavailable, **refuse the mutation**. Do not fall back to direct D1 SQL,
a model's assurance, a local cache, or another service's fact table.

### Read before mutation

Use `GET /facts/cases/{caseId}/enriched` within the caller's authorized matter to
retrieve canonical fact IDs, current statuses, source versions, producer
provenance, and source links. Treat an unresolved producer as a blocker; do not
backfill it with the reviewer, document uploader, or a guessed name.

### Create a sourced draft

Invoke `POST /legal/cases/{caseId}/facts` with `factNumber`, `factText`, and
`exhibitReference`; optional fields are `factDate`, `documentId`, and `sourceQuote`.
The runtime assigns the returned record ID, records the authenticated producer,
and creates only `draft` status. Use the returned ID as opaque; do not mint a
record ID locally. This operation is not independent verification.

### Change lifecycle status

Invoke `POST /legal/cases/{caseId}/facts/{factId}/status` with:

```json
{
  "status": "verified",
  "expectedStatus": "draft",
  "expectedVersion": 1
}
```

The values above illustrate the payload shape. Populate expected status/version
from the actual authorized read and use only the transitions in the lifecycle
table. A dispute additionally requires `conflictWithFactId` pointing to another
fact in the same case. Locking uses `status: "locked"` from verified status;
archiving uses `status: "archived"` from verified status. Rejection and a return
from disputed to draft require the same independent actor check.

On **every** invocation the acting actor must differ from the pre-existing fact's
stored producer. Merely naming a different verifier in JSON has no effect.
A conflict response requires a fresh read and renewed evaluation; never retry
blindly. `version` is the source/content revision, so these preconditions compare
present state and do not prove that no intervening status changes occurred.

### Supersede a verified or archived fact

Invoke `POST /legal/cases/{caseId}/facts/{factId}/supersede` with
`expectedStatus` (`verified` or `archived`), `expectedVersion`, `factText`, and
`exhibitReference`; optional fields are `factDate`, `documentId`, and `sourceQuote`.

The runtime compares the acting actor with the **superseded fact's producer**,
then atomically creates the replacement draft and ensures the source is archived.
The new draft points to that archived source through `supersedes_id`, increments
the source revision, and records its own producer as the current actor. That
actor cannot subsequently verify the draft they just produced. Do not split this
operation into separate archive/insert SQL. Locked and rejected facts cannot be
superseded through this operation, and no direct text-edit endpoint is implied.

### Pending candidates and audit evidence

AI confidence never establishes independent verification. Legacy
`evidence_pending_facts` rows lack authoritative producer lineage, so their
approval and rejection paths remain blocked. A sourced canonical draft requires
an independently established authoring decision; do not relabel a candidate's
reviewer as its historical producer.

A successful status-transition or supersession response includes `actorSeparation`
with the acting actor,
stored producer, source fact ID, case, source version/status, and check time.
Retain that evidence with the actual Chronicle receipt. `chronicle: null` means
the database mutation may have committed without a durable audit receipt; report
that state explicitly, do not retry blindly, and do not call it audited.

**COR admission remains blocked** until the deployed runtime, Chico authorization,
required durable Chronicle evidence, and CFDXN-195 validator gates are verified.
A merged draft specification, generated skill projection, or local test pass does
not activate an epistemic entry. Direct database administration is outside this
guarded service path and is not an approved fallback for this skill.

## Query Helpers

Every query is case-scoped via `case_id = ?`. Never omit it.

```sql
-- All active facts for the resolved case
SELECT * FROM evidence_statement_of_facts 
WHERE case_id = ?
  AND status NOT IN ('archived', 'rejected')
ORDER BY category, fact_number;

-- Pending review within the resolved case
SELECT * FROM evidence_statement_of_facts 
WHERE case_id = ? AND status = 'draft' 
ORDER BY created_at;

-- Fact history (within the resolved case)
WITH RECURSIVE fact_history AS (
  SELECT * FROM evidence_statement_of_facts WHERE id = ? AND case_id = ?
  UNION ALL
  SELECT f.* FROM evidence_statement_of_facts f
  JOIN fact_history h ON f.id = h.supersedes_id AND f.case_id = h.case_id
)
SELECT * FROM fact_history ORDER BY version DESC;
```

## Validation Rules

1. `exhibit_reference` is **REQUIRED** — every fact needs a source.
2. Check current status through the authorized read; locked facts remain immutable.
3. Corrections use the guarded supersession operation; never rewrite locked/verified fact text.
4. Valid transitions only (see lifecycle table).
5. Every operation is case-scoped; read-only SQL must include `case_id = ?`. Lifecycle mutations must use the authenticated case-scoped runtime and cannot fall back to SQL.
6. The created draft must belong to the invocation case. The runtime must validate linked documents and conflict facts within that same case.
7. Every lifecycle write, including a superseding draft, requires the runtime producer comparison. Unresolved producer identity fails closed.

## Downstream projection sync

`chittyevidence-db` is authoritative for the factual lifecycle. Human-facing trackers, Sheets, dashboards, document stores, and other matter workspaces are **projections**, not alternate fact authorities.

- Resolve the matter's designated projection target from governed matter metadata; never hard-code a vendor or workspace.
- New or changed facts may be projected only after the authoritative D1 write succeeds.
- Every projected row carries the canonical fact ID, version, lifecycle status, and source/document identity needed to reconcile it back to D1.
- Reconcile by canonical fact ID + version and report drift; never promote a projection's value back into D1 merely because it differs.
- A projection failure does not roll back or silently downgrade the authoritative fact record. Record the projection failure and retry through the governed sync path.
- Legacy Notion mappings are compatibility metadata only. They are not a default target and MUST NOT be used unless the matter explicitly designates that surface.
- Every projection operation remains case-scoped; never copy facts between matters.

## Quick Reference

**Can I edit?**
- draft → authoring changes require a supported governed operation; no direct SQL edit
- verified → Correction only (new version)
- locked/archived/rejected → NO
- disputed → Notes only

**ID Formats:**
- Internal: preserve the opaque ID returned by the authoritative service, including legacy `FACT-…` identifiers
- Display: `{CAT}-{NUM}.{VER}` (e.g., CORP-001.1, TIME-042.2) — fact_number is scoped per-case

## Invocation Rejection

If invoked without a `case` parameter, the skill MUST:
1. Refuse to proceed.
2. Return: "fact-governance: no `case` specified — refusing to run. Provide `case_id=<id>` or `case_slug=<slug>`."
3. List the caller's currently-active cases so they can pick one.

