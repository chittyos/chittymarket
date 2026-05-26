---
name: evidence-collect
canon_uri: chittycanon://core/services/chittymarket#skills/evidence-collect
description: "Evidence collection and ingestion for a specified case. REQUIRES an explicit `case` parameter — refuses to run without one. Triggers on: downloading evidence, staging documents, collecting exhibits, pulling files from Google Drive, ALTA statements, closing disclosures, deeds, wire receipts, purchase contracts, mortgage documents, financial records, or any file retrieval for litigation purposes. Prevents ad-hoc file copying by enforcing the canonical pipeline."
kind: skill
plugin: chittyos-legal
runtimes:
  - claude-code
  - codex
classification:
  - legal
  - evidence
---

# Evidence Collection — Canonical Pipeline

## Required: `case` parameter

This skill **requires** an explicit case identifier on every invocation. It MUST NOT default to any previously-used case.

Accept either:

- **`case_id`** — the chittyevidence-db case identifier (e.g. `arias-v-bianchi-2024d007847`)
- **`case_slug`** — a registered case slug (e.g. `arias-v-bianchi`, `clarendon-1610`, `fox-hoa`); resolve via `evidence_cases` or the chittyrouter case registry

If no `case` is specified, stop and ask the caller for one. Do not fall back to "the last case we worked on" or any hardcoded default.

Every bucket path, local path, and SQL example below uses `<case_slug>` or `<case_id>` as a placeholder — substitute the resolved case at runtime. Do not paste literals.

## STOP. READ THIS FIRST.

**DO NOT manually copy, download, or stage evidence files.** There is already a full pipeline. Use it.

The #1 failure mode is creating yet another copy of documents that already exist in 6+ locations. Every manual `cp` or `rclone copy` to a random directory creates evidence sprawl and breaks chain of custody.

The #2 failure mode — historically observed — is attributing a document from case A to case B because the pipeline was run with a stale or hardcoded case default. Always re-resolve the case at invocation.

## Pre-Flight Checklist

Before downloading or staging ANY document, with the resolved case in hand:

1. **Check R2 first** — the document is probably already ingested for THIS case
2. **Check the Neon DB** — the fact may already be registered (scoped to `case_id = <case_id>`)
3. **If it's not in R2 for this case** — use the pipeline, not manual copies
4. **If you need a fact** — query the DB (scoped by `case_id`), don't re-extract from source
5. **Reject cross-case leaks** — if you find the doc only in a DIFFERENT case's folder, do NOT silently copy it over. Ask the caller whether the doc legitimately belongs to the new case.

## Architecture

```
Source (Drive remote for <case_slug>)    Local Files
         │                                    │
         └──────────┬─────────────────────────┘
                    │
                    ▼
            ┌──────────────┐
            │  00_inbox/   │  ← ALL documents for THIS case land here first
            └──────┬───────┘
                   │  bin/intake.py --case=<case_slug>
                   ▼
            ┌──────────────┐
            │ Case Folders │  ← Routed by keyword matching, scoped to case
            │ (02-10)      │
            └──────┬───────┘
                   │  bin/r2_import.py --case=<case_slug>
                   ▼
        ┌─────────────────────┐
        │  R2 Buckets         │
        │  quarantine → staging → signed │
        │  (all case-prefixed)           │
        └──────────┬──────────┘
                   │  ChittyEvidence Worker
                   ▼
        ┌─────────────────────┐
        │  Neon PostgreSQL    │
        │  verification.*    │
        │  evidence_statement_of_facts  (scoped to case_id)  │
        └──────────┬──────────┘
                   │  Notion sync (case's workspace)
                   ▼
        ┌─────────────────────┐
        │  Notion Facts Table │
        │  (case-specific)    │
        └─────────────────────┘
```

## R2 Buckets (Source of Truth)

Case documents live under a case-prefixed key within each bucket (e.g. `CASE_<CASE_NUMBER>/` or `<case_slug>/`). Never write to the bucket root without a case prefix.

| Bucket | Purpose | Status |
|--------|---------|--------|
| `chittyevidence-documents` | Canonical document store (staging/) | Active |
| `chittyevidence-pipeline` | Pipeline manifests & collections | Active |
| `chittyevidence-processed` | Post-processing output | Active |
| `legal-evidence-quarantine` | Incoming, unverified | Active |
| `legal-evidence-staging` | Processing in progress | Active |
| `legal-evidence-signed` | Verified + deduplicated | Active |
| `legal-evidence-originals` | Pristine originals | Active |
| `legal-evidence-working` | Scratch space | Active |

## Step 1: Check If Document Already Exists

```bash
# Search R2 for the document, scoped to the case
rclone ls r2:chittyevidence-documents/<case_slug>/ --include "*keyword*" 2>&1
rclone ls r2:legal-evidence-signed/<case_prefix>/ --include "*keyword*" 2>&1

# Check duplicates quarantine within this case
rclone ls r2:legal-evidence-signed/<case_prefix>/00_ADMIN/duplicates_quarantine/ --include "*keyword*" 2>&1
```

If found in this case's prefix → **STOP**. Use the existing copy.
If found in ANOTHER case's prefix → **STOP and ask the caller** whether it legitimately belongs here. Do not copy automatically.

## Step 2: Check If Fact Already Registered

Use the fact-governance skill to query Neon (always with `case_id = ?`):

```sql
SELECT id, fact_number, fact_text, exhibit_reference, status, category
FROM evidence_statement_of_facts
WHERE case_id = ?            -- resolved <case_id>
  AND (fact_text ILIKE '%keyword%' OR exhibit_reference ILIKE '%keyword%')
  AND status NOT IN ('archived', 'rejected')
ORDER BY fact_number;
```

If found → **STOP**. The fact is already in the system. Do not re-extract.

## Step 3: Ingest New Documents (If Genuinely New)

Pipelines pass the case slug/id into each script. Example paths below use `<case_slug>` and `<drive_remote>` placeholders — each case has its own drive remote name (e.g. `arias_v_bianchi:`, `clarendon_1610:`, `fox_hoa:`).

### Option A: From Drive → 00_inbox → intake.py

```bash
cd "<cases_root>/<case_slug>"
rclone copy "<drive_remote>:path/to/file.pdf" 00_inbox/
python3 bin/intake.py --case=<case_slug>
```

### Option B: From R2 → 00_inbox → intake.py

```bash
cd "<cases_root>/<case_slug>"
python3 bin/r2_import.py --case=<case_slug> --prefix '<vault_prefix>' --pattern '*.pdf' --recursive --dest 00_inbox
python3 bin/intake.py --case=<case_slug>
```

### Option C: Bulk from Drive URL list

```bash
cd "<cases_root>/<case_slug>"
python3 bin/rclone_import.py --case=<case_slug> --remote <drive_remote> --list google_drive_urls.txt
python3 bin/intake.py --case=<case_slug>
```

## Step 4: Register Facts

After documents are properly staged, use the fact-governance skill (which also requires `case` parameter) to register extracted facts. Every INSERT must bind the resolved `case_id`:

```sql
INSERT INTO evidence_statement_of_facts (
  id, case_id, fact_number, fact_date, fact_text,
  exhibit_reference, source_quote, status, version, category,
  submitted_by, created_at, updated_at
) VALUES (
  'FACT-' || hex(randomblob(8)),
  ?,  -- <case_id> — resolved at invocation
  (SELECT COALESCE(MAX(fact_number), 0) + 1 FROM evidence_statement_of_facts WHERE case_id = ?),
  ?, ?, ?, ?, 'draft', 1, ?,
  'claude-evidence-collect',
  datetime('now'), datetime('now')
);
```

## rclone Remotes Reference

Each case has its own drive remote. Add new cases to the case registry; never hardcode a remote here.

| Remote pattern | Access | Use For |
|----------------|--------|---------|
| `<case_slug>:` (Drive) | Google Drive shared | Source documents for that case |
| `r2:` | Cloudflare R2 | Canonical evidence store (all cases, case-prefixed keys) |
| `sd_<case_slug>:` (if applicable) | SD card archive | Offline backup per case |

## Case Directory Layout

Each case lives under its own slug-rooted directory:

```
<cases_root>/<case_slug>/
├── 00_inbox/              ← ALL incoming docs for THIS case land here
├── bin/
│   ├── intake.py          ← Routes inbox → case folders (case-aware)
│   ├── r2_import.py       ← Pulls from R2 (case-prefixed)
│   └── rclone_import.py   ← Pulls from Google Drive (case-specific remote)
├── 06_evidence/
│   ├── EVIDENCE_LOG.md
│   └── documents/         ← Only populated by intake.py
└── 07_exhibits/
    └── EXHIBIT_LIST.md
```

Never co-mingle files across case directories. If you discover a document apparently in the wrong case directory, halt and escalate — do not silently move.

## Anti-Patterns (Things That MUST NOT Happen)

1. **DO NOT** invoke this skill without a `case` parameter.
2. **DO NOT** `rclone copy` directly to `06_evidence/documents/` — use `00_inbox/` + `intake.py`.
3. **DO NOT** download the same document from multiple aggregation folders.
4. **DO NOT** create facts without `exhibit_reference`.
5. **DO NOT** state a date, amount, or fact that isn't in the source document — say "I don't have that".
6. **DO NOT** manually write EVIDENCE_LOG.md entries — `intake.py` handles this.
7. **DO NOT** write a document from case A into case B's evidence store. Cross-case contamination is the exact class of bug this skill must prevent.

## Case-Specific Evidence Data

Evidence data (verified property details, dates, amounts, party names, per-case aggregations) belongs in the case's evidence DB, NOT in this skill doc. Query `evidence_statement_of_facts` scoped to `case_id = ?` to retrieve verified facts for the resolved case.

Historical note: an earlier version of this skill embedded concrete Arias v. Bianchi property data and marriage date directly in the doc. That content has been removed — it lives in the `evidence_statement_of_facts` table, correctly scoped to `case_id = 'arias-v-bianchi-2024d007847'`, and should be queried per invocation.

## Invocation Rejection

If invoked without a `case` parameter, the skill MUST:
1. Refuse to proceed.
2. Return: "evidence-collect: no `case` specified — refusing to run. Provide `case_id=<id>` or `case_slug=<slug>`."
3. List the caller's currently-active cases so they can pick one.
