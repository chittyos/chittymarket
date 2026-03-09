---
name: fact-governance
description: Evidence fact governance for Arias v. Bianchi case. Triggers on "fact", "evidence", "verify", "verification", case materials, dates/amounts/claims, or chittyevidence-db operations. Manages fact lifecycle (draft→verified→locked), versioning, corrections, and Notion sync.
---

# Fact Governance — Arias v. Bianchi Evidence Pipeline

## Database Integration

- **Database:** chittyevidence-db
- **ID:** f486fed7-cba9-47d2-93fb-ca11d90ca084
- **Case ID:** arias-v-bianchi-2024d007847
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

### Add Fact
```sql
INSERT INTO evidence_statement_of_facts (
  id, case_id, fact_number, fact_date, fact_text,
  exhibit_reference, document_id, source_quote,
  status, version, category, submitted_by, created_at, updated_at
) VALUES (
  'FACT-' || hex(randomblob(8)),
  'arias-v-bianchi-2024d007847',
  (SELECT COALESCE(MAX(fact_number), 0) + 1 FROM evidence_statement_of_facts WHERE case_id = ?),
  ?, ?, ?, ?, ?, 'draft', 1, ?, ?, datetime('now'), datetime('now')
);
```

### Verify Fact
```sql
UPDATE evidence_statement_of_facts 
SET status = 'verified', verified_by = ?, verified_at = datetime('now'), updated_at = datetime('now')
WHERE id = ? AND status = 'draft';
```

### Lock Fact
```sql
UPDATE evidence_statement_of_facts 
SET status = 'locked', updated_at = datetime('now')
WHERE id = ? AND status = 'verified';
```

### Correct Fact (creates new version)
1. Archive old: `UPDATE ... SET status = 'archived' WHERE id = ? AND status IN ('draft', 'verified')`
2. Insert new version with `supersedes_id` pointing to old, `version + 1`, status = 'draft'
3. Log to `evidence_correction_audit_log`

### Flag Dispute
```sql
UPDATE evidence_statement_of_facts 
SET status = 'disputed', has_conflict = 1, conflict_with_fact_id = ?, updated_at = datetime('now')
WHERE id = ?;
```

## Query Helpers

```sql
-- All active facts for case
SELECT * FROM evidence_statement_of_facts 
WHERE case_id = 'arias-v-bianchi-2024d007847'
  AND status NOT IN ('archived', 'rejected')
ORDER BY category, fact_number;

-- Pending review
SELECT * FROM evidence_statement_of_facts WHERE status = 'draft' ORDER BY created_at;

-- Fact history
WITH RECURSIVE fact_history AS (
  SELECT * FROM evidence_statement_of_facts WHERE id = ?
  UNION ALL
  SELECT f.* FROM evidence_statement_of_facts f
  JOIN fact_history h ON f.id = h.supersedes_id
)
SELECT * FROM fact_history ORDER BY version DESC;
```

## Validation Rules

1. `exhibit_reference` is **REQUIRED** — every fact needs a source
2. Check status before any UPDATE — locked facts are immutable
3. Corrections create new versions — never UPDATE locked/verified fact_text
4. Valid transitions only (see lifecycle table)

## Notion Sync

Syncs with Notion Evidence Tracker (ChittyLedger → Arias v Bianchi → Evidence Tracker):
- New D1 facts → Create Notion entry
- Status changes → Update Notion status
- Weekly reconciliation for drift

## Quick Reference

**Can I edit?**
- draft → YES
- verified → Correction only (new version)
- locked/archived/rejected → NO
- disputed → Notes only

**ID Formats:**
- Internal: `FACT-{hex}` (e.g., FACT-a1b2c3d4e5f6)
- Display: `{CAT}-{NUM}.{VER}` (e.g., CORP-001.1, TIME-042.2)
