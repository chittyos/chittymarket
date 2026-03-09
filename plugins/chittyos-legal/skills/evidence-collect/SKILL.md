---
name: evidence-collect
description: "Evidence collection and ingestion for Arias v. Bianchi. MANDATORY first step before touching any case document. Triggers on: downloading evidence, staging documents, collecting exhibits, pulling files from Google Drive for the case, ALTA statements, closing disclosures, deeds, wire receipts, purchase contracts, mortgage documents, financial records, or any file retrieval for litigation purposes. Prevents ad-hoc file copying by enforcing the canonical pipeline."
---

# Evidence Collection — Canonical Pipeline

## STOP. READ THIS FIRST.

**DO NOT manually copy, download, or stage evidence files.** There is already a full pipeline. Use it.

The #1 failure mode is creating yet another copy of documents that already exist in 6+ locations. Every manual `cp` or `rclone copy` to a random directory creates evidence sprawl and breaks chain of custody.

## Pre-Flight Checklist

Before downloading or staging ANY document:

1. **Check R2 first** — the document is probably already ingested
2. **Check the Neon DB** — the fact may already be registered
3. **If it's not in R2** — use the pipeline, not manual copies
4. **If you need a fact** — query the DB, don't re-extract from source

## Architecture

```
Google Drive (arias_v_bianchi:)     Local Files
         │                              │
         └──────────┬───────────────────┘
                    │
                    ▼
            ┌──────────────┐
            │  00_inbox/   │  ← ALL documents land here first
            └──────┬───────┘
                   │  bin/intake.py
                   ▼
            ┌──────────────┐
            │ Case Folders │  ← Routed by keyword matching
            │ (02-10)      │
            └──────┬───────┘
                   │  bin/r2_import.py (or direct upload)
                   ▼
        ┌─────────────────────┐
        │  R2 Buckets         │
        │  quarantine → staging → signed │
        └──────────┬──────────┘
                   │  ChittyEvidence Worker
                   ▼
        ┌─────────────────────┐
        │  Neon PostgreSQL    │
        │  verification.*    │
        │  evidence_statement_of_facts │
        └──────────┬──────────┘
                   │  Notion sync
                   ▼
        ┌─────────────────────┐
        │  Notion Facts Table │
        └─────────────────────┘
```

## R2 Buckets (Source of Truth)

| Bucket | Purpose | Status |
|--------|---------|--------|
| `chittyevidence-documents` | Canonical document store (staging/) | Active |
| `chittyevidence-pipeline` | Pipeline manifests & collections | Active |
| `chittyevidence-processed` | Post-processing output | Active |
| `legal-evidence-quarantine` | Incoming, unverified | Active |
| `legal-evidence-staging` | Processing in progress | Active |
| `legal-evidence-signed` | Verified + deduplicated (CASE_2024D007847/) | Active |
| `legal-evidence-originals` | Pristine originals | Active |
| `legal-evidence-working` | Scratch space | Active |

## Step 1: Check If Document Already Exists

```bash
# Search R2 for the document
rclone ls r2:chittyevidence-documents --include "*keyword*" 2>&1
rclone ls r2:legal-evidence-signed --include "*keyword*" 2>&1

# Check duplicates quarantine (already caught duplicates go here)
rclone ls r2:legal-evidence-signed/CASE_2024D007847/00_ADMIN/duplicates_quarantine/ --include "*keyword*" 2>&1
```

If found → **STOP**. Use the existing copy. Do not download another.

## Step 2: Check If Fact Already Registered

Use the fact-governance skill to query Neon:

```sql
SELECT id, fact_number, fact_text, exhibit_reference, status, category
FROM evidence_statement_of_facts
WHERE case_id = 'arias-v-bianchi-2024d007847'
  AND (fact_text ILIKE '%keyword%' OR exhibit_reference ILIKE '%keyword%')
  AND status NOT IN ('archived', 'rejected')
ORDER BY fact_number;
```

If found → **STOP**. The fact is already in the system. Do not re-extract.

## Step 3: Ingest New Documents (If Genuinely New)

### Option A: From Google Drive → 00_inbox → intake.py

```bash
# Import specific files to inbox
cd /Users/nb/Desktop/organized/Legal/cases/arias_v_bianchi
rclone copy "arias_v_bianchi:path/to/file.pdf" 00_inbox/

# Route all inbox files to proper directories
python3 bin/intake.py
```

### Option B: From R2 → 00_inbox → intake.py

```bash
cd /Users/nb/Desktop/organized/Legal/cases/arias_v_bianchi
python3 bin/r2_import.py --prefix 'chittyos-data/VAULT/LITIGATION/ARIAS_V_BIANCHI' --pattern '*.pdf' --recursive --dest 00_inbox
python3 bin/intake.py
```

### Option C: Bulk from Google Drive URL list

```bash
cd /Users/nb/Desktop/organized/Legal/cases/arias_v_bianchi
python3 bin/rclone_import.py --remote arias_v_bianchi --list google_drive_urls.txt
python3 bin/intake.py
```

## Step 4: Register Facts

After documents are properly staged, use the fact-governance skill to register extracted facts:

```sql
INSERT INTO evidence_statement_of_facts (
  id, case_id, fact_number, fact_date, fact_text,
  exhibit_reference, source_quote, status, version, category,
  submitted_by, created_at, updated_at
) VALUES (
  'FACT-' || hex(randomblob(8)),
  'arias-v-bianchi-2024d007847',
  (SELECT COALESCE(MAX(fact_number), 0) + 1 FROM evidence_statement_of_facts),
  '2019-11-22',
  'Purchase price of 541 W Addison St #3S was $202,000',
  'Closing Disclosure 12/23/2019 (USAA)',
  'Sale Price: $202,000.00',
  'draft', 1, 'PROP',
  'claude-evidence-collect',
  datetime('now'), datetime('now')
);
```

## rclone Remotes Reference

| Remote | Access | Use For |
|--------|--------|---------|
| `arias_v_bianchi:` | Google Drive shared | Source documents |
| `r2:` | Cloudflare R2 | Canonical evidence store |
| `sd_arias_v_bianchi:` | SD card archive | Offline backup |

## Case Directory

```
/Users/nb/Desktop/organized/Legal/cases/arias_v_bianchi/
├── 00_inbox/          ← ALL incoming docs land here
├── bin/
│   ├── intake.py      ← Routes inbox → case folders
│   ├── r2_import.py   ← Pulls from R2
│   └── rclone_import.py ← Pulls from Google Drive
├── 06_evidence/
│   ├── EVIDENCE_LOG.md
│   └── documents/     ← Only populated by intake.py
└── 07_exhibits/
    └── EXHIBIT_LIST.md
```

## Known Document Aggregations on Google Drive (DO NOT CREATE MORE)

| Path | What It Is | Status |
|------|-----------|--------|
| `STRONGSUIT_UPLOAD_2026-01-22/` | StrongSuit litigation platform upload | Latest |
| `NEW_COUNSEL_COMPLETE_EVIDENCE_PACKAGE_2025-10-27/` | New attorney handoff package | Complete |
| `FROM_MYDRIVE/Arias_Dispute/TOTAL RECALL Litigation Vault/` | Original personal drive | Legacy |
| `_DECAYING_ARCHIVE_DELETE_AFTER_2025-11-04/` | Deprecated archive | Expired |
| Root-level files | Misc uploads | Unorganized |

**These all contain overlapping copies of the same ~50 core documents. DO NOT download from all of them.**

## Anti-Patterns (Things That MUST NOT Happen)

1. **DO NOT** `rclone copy` directly to `06_evidence/documents/` — use `00_inbox/` + `intake.py`
2. **DO NOT** download the same document from multiple aggregation folders
3. **DO NOT** create facts without `exhibit_reference`
4. **DO NOT** state a date, amount, or fact that isn't in the source document — say "I don't have that"
5. **DO NOT** manually write EVIDENCE_LOG.md entries — `intake.py` handles this
6. **DO NOT** fabricate dates (marriage date is 12/30/2022 per Marriage Certificate, Exhibit A-2)

## Verified Property Data (from source documents, 2026-02-06)

| Property | Price | Closing | Source | Category |
|----------|-------|---------|--------|----------|
| 541 W Addison #3S | $202,000 | 11/22/2019 | Closing Disclosure (USAA) | Pre-marital |
| 550 W Surf #504 | $237,500 | 4/26/2022 | ALTA Statement + Closing Disclosure (SoFi) | Pre-marital |
| 550 W Surf #211 | $100,000 | ~7/2022 | Purchase Contract (DocuSign) + Wire $96,059.14 | Pre-marital |

Marriage date: **12/30/2022** — all three properties pre-marital.
