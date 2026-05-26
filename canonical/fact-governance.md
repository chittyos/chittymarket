---
name: fact-governance
description: Evidence fact governance for a specified case. Triggers on "fact", "evidence", "verify", "verification", case materials, dates/amounts/claims, or chittyevidence-db operations. REQUIRES an explicit `case` parameter — refuses to run without one. Manages fact lifecycle (draft→verified→locked), versioning, corrections, and Notion sync.
kind: skill
plugin: chittyos-legal
runtimes:
  - claude-code
classification:
  - legal
  - evidence
---

# Fact Governance — Evidence Pipeline

## Required: `case` parameter

This skill **requires** an explicit case identifier on every invocation. It MUST NOT default to any particular case.

Accept either:

- **`case_id`** — the chittyevidence-db case identifier (e.g. `arias-v-bianchi-2024d007847`)
- **`case_slug`** — a registered case slug (resolve via `evidence_cases` or the chittyrouter case registry)

If no `case` is specified, stop and ask the caller for one. Do not fall back to any previously-used case.

Every SQL example below uses `<case_id>` as a placeholder — substitute the resolved case at runtime. Do not paste literal case IDs.

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

## Operations

In every SQL below, `<case_id>` means the resolved case identifier for THIS invocation. Never paste a literal case string.

### Add Fact
```sql
INSERT INTO evidence_statement_of_facts (
  id, case_id, fact_number, fact_date, fact_text,
  exhibit_reference, document_id, source_quote,
  status, version, category, submitted_by, created_at, updated_at
) VALUES (
  'FACT-' || hex(randomblob(8)),
  ?,  -- <case_id>
  (SELECT COALESCE(MAX(fact_number), 0) + 1 FROM evidence_statement_of_facts WHERE case_id = ?),
  ?, ?, ?, ?, ?, 'draft', 1, ?, ?, datetime('now'), datetime('now')
);
```

### Verify Fact
```sql
UPDATE evidence_statement_of_facts 
SET status = 'verified', verified_by = ?, verified_at = datetime('now'), updated_at = datetime('now')
WHERE id = ? AND case_id = ? AND status = 'draft';
```

### Lock Fact
```sql
UPDATE evidence_statement_of_facts 
SET status = 'locked', updated_at = datetime('now')
WHERE id = ? AND case_id = ? AND status = 'verified';
```

### Correct Fact (creates new version)
1. Archive old: `UPDATE ... SET status = 'archived' WHERE id = ? AND case_id = ? AND status IN ('draft', 'verified')`
2. Insert new version with `supersedes_id` pointing to old, `version + 1`, status = 'draft', same `case_id`
3. Log to `evidence_correction_audit_log`

### Flag Dispute
```sql
UPDATE evidence_statement_of_facts 
SET status = 'disputed', has_conflict = 1, conflict_with_fact_id = ?, updated_at = datetime('now')
WHERE id = ? AND case_id = ?;
```

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
2. Check status before any UPDATE — locked facts are immutable.
3. Corrections create new versions — never UPDATE locked/verified fact_text.
4. Valid transitions only (see lifecycle table).
5. **Every write and read MUST include `case_id = ?` in its WHERE clause.** Cross-case leaks are the exact class of bug this skill must prevent.
6. On insert, verify `case_id` matches the resolved case from the invocation parameter — reject mismatches.

## Notion Sync

Notion Evidence Tracker lives under `ChittyLedger → <case workspace> → Evidence Tracker`. The target workspace is selected from the resolved case's Notion mapping (via case registry metadata or Notion Projects DB lookup by `case_slug`). Never write facts from case A into case B's Notion workspace.

- New D1 facts → Create Notion entry in the case's workspace
- Status changes → Update corresponding Notion entry (same workspace)
- Weekly reconciliation for drift — case-scoped

## Quick Reference

**Can I edit?**
- draft → YES
- verified → Correction only (new version)
- locked/archived/rejected → NO
- disputed → Notes only

**ID Formats:**
- Internal: `FACT-{hex}` (e.g., FACT-a1b2c3d4e5f6)
- Display: `{CAT}-{NUM}.{VER}` (e.g., CORP-001.1, TIME-042.2) — fact_number is scoped per-case

## Invocation Rejection

If invoked without a `case` parameter, the skill MUST:
1. Refuse to proceed.
2. Return: "fact-governance: no `case` specified — refusing to run. Provide `case_id=<id>` or `case_slug=<slug>`."
3. List the caller's currently-active cases so they can pick one.
