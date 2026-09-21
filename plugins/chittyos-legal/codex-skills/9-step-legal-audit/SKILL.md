---
name: 9-step-legal-audit
description: Structured 9-step evidence audit for a specified legal matter — retrieval, chain verification, fact extraction, discrepancy detection, citation mapping, and evidentiary risk scoring. REQUIRES an explicit case parameter — refuses to run without one. Triggers on "audit evidence", "run legal audit", "check the record", "discrepancy log", "citation map", "risk score", "verify claims", "affidavit audit", "motion review", "evidence integrity check", or cross-checking financial claims against chittyevidence-db.
canon_uri: chittycanon://core/services/chittymarket#skills/9-step-legal-audit
---

# 9-Step Legal Audit

Structured audit workflow for ChittyOS legal cases. Produces three output artifacts:
- `audit_report.md` — narrative findings with citations
- `discrepancy_log.json` — machine-readable contradictions and fabricated data flags
- `citation_map.json` — evidence-to-claim mapping with confidence scores

## Required: `case` parameter

This skill **requires** an explicit case identifier on every invocation. It MUST NOT default to
any particular case, and MUST NOT infer one from session context, a prior invocation, or the
contents of the evidence bundle. If the invocation does not specify a case, stop and ask the
caller for one. Do not guess.

Accept either `case_id` (the chittyevidence-db identifier) or `case_slug` (a registered slug);
resolve a slug through the case registry, never through a skill-local default.

> Rationale: `evidence-collect` records the historically-observed #2 failure mode — attributing
> a document from case A to case B because the pipeline ran with a stale or hardcoded case
> default. Every output of this skill is stamped with the case it was invoked for; a defaulted
> case produces a plausibly-formed audit filed against the wrong matter.

Standard: `legal-operating-defaults` §8 (matter isolation), §14 (matter facts stay out of
reusable capability packages).

## Input Schema

```
case_id:              string   (chittyevidence-db case identifier; required)
case_slug:            string   (registered slug; alternative to case_id)
master_evidence_ids:  string[] (ChittyEvidence document IDs or R2 keys)
draft_doc:            string | null (path or text of motion/affidavit to audit; optional)
```

---

## The 9 Steps

Execute each step in sequence. Do not skip steps even if prior steps return sparse data — log
"no data found" rather than omitting. Use `chittymcp` tools throughout.

---

### Step 1 — Context Load

**Goal:** Establish the case record baseline.

- Call `chitty_neon_query` with:
  ```sql
  SELECT * FROM cases WHERE case_id = '<case_id>' LIMIT 1;
  ```
- If case row exists, extract: parties, jurisdiction, case_type, filing_date, status, attorney.
- If case row is missing, log `[WARN] Case not found in Neon — proceeding with evidence-only audit`.
- Record baseline in a local `audit_context` object (held in memory for subsequent steps).

---

### Step 2 — Evidence Retrieval

**Goal:** Load all documents referenced by `master_evidence_ids`.

- For each ID in `master_evidence_ids`:
  - Call `chitty_evidence_retrieve` with the ID.
  - If retrieval fails, attempt `chitty_evidence_search` using the ID as query string.
  - Log each retrieval result: `{id, title, source, date, status: "retrieved"|"missing"}`.
- Collect all retrieved docs into `evidence_bundle[]`.
- If any IDs resolve to nothing, flag as `MISSING_EVIDENCE` — do not abort; continue with available docs.

---

### Step 3 — Chain Verification

**Goal:** Confirm document integrity via ChittyChain/ChittyLedger.

- Call `chitty_ledger_verify` (or `chitty_evidence_verify`) for each doc in `evidence_bundle`.
- For each doc, record: `{id, hash_valid: bool, chain_intact: bool, tamper_flags: []}`.
- Any doc with `hash_valid = false` → flag `INTEGRITY_FAILURE` in `discrepancy_log`.
- Any doc with `chain_intact = false` → flag `CHAIN_BREAK`.
- Documents with integrity failures remain in the bundle but are tagged `[UNVERIFIED]` in all outputs.

---

### Step 4 — Classification

**Goal:** Categorize evidence by type to structure the audit.

Assign each doc in `evidence_bundle` one or more categories:

| Category | Examples |
|---|---|
| `FINANCIAL` | bank statements, ledgers, affidavits of income/expense |
| `PROCEDURAL` | docket entries, court orders, attorney correspondence |
| `PROPERTY` | leases, deeds, HOA records, inspection reports |
| `TESTIMONIAL` | declarations, depositions, sworn statements |
| `COMMUNICATIONS` | emails, texts, letters |
| `FABRICATED_FLAG` | any doc flagged in prior work as containing invented data |

- Classification can be multi-label.
- Use document title, metadata, and content snippet — do not hallucinate category if uncertain; use `UNCLASSIFIED`.

---

### Step 5 — Fact Extraction

**Goal:** Pull atomic facts from each evidence document.

- For each doc, call `chitty_ledger_facts` using the evidence ID.
- If `chitty_ledger_facts` returns empty, call `chitty_evidence_search` with key claim terms from the doc.
- Collect all returned facts into `fact_pool[]`.
- Each fact must carry: `{fact_id, claim_text, source_evidence_id, date_asserted, status}`.
- De-duplicate by `fact_id`. If duplicate `claim_text` exists with different `fact_id`, log as `DUPLICATE_FACT`.

---

### Step 6 — Discrepancy Detection

**Goal:** Surface contradictions, unsupported claims, and fabricated data.

Run the following checks against `fact_pool`:

#### 6a — Internal Contradictions
- For each pair of facts with overlapping subject matter, check if `claim_text` values are
  logically inconsistent (e.g., two different dollar amounts for the same expense, same date
  with conflicting event descriptions).
- Flag: `CONTRADICTION` with `{fact_id_a, fact_id_b, conflict_description}`.

#### 6b — Unsupported Claims
- If `draft_doc` is provided: extract factual assertions from it. For each assertion, attempt
  to match against `fact_pool`. If no match found, flag: `UNSUPPORTED_CLAIM` with
  `{assertion_text, source_location_in_draft}`.
- Call `chitty_fact_validate` for high-stakes claims (financial figures, dates, addresses).

#### 6c — Known Fabrication Markers
- Any doc classified `FABRICATED_FLAG` in Step 4: extract all facts from it and flag each as
  `FABRICATED_FACT` with chain-of-custody citation.
- Cross-check property addresses: if a fact references a property not in ChittyOS Property
  Registry, flag `UNREGISTERED_PROPERTY`.

#### 6d — Timestamp Anomalies
- Flag any fact with `date_asserted` post-dating the event it describes.
- Flag any document with filing date preceding its referenced events by implausible margins.

Accumulate all flags into `discrepancy_log[]`.

---

### Step 7 — Citation Mapping

**Goal:** Build a traceable map from claims to evidence sources.

- For each fact in `fact_pool` that is NOT flagged `FABRICATED_FACT`:
  - Create a citation entry: `{claim_id, claim_text, evidence_ids[], confidence}`.
  - `confidence` scoring:
    - `HIGH` — fact verified via ChittyChain (`hash_valid = true`) + corroborated by ≥2 docs
    - `MEDIUM` — single-source fact with valid hash
    - `LOW` — single-source with unverified hash or retrieved via search fallback
    - `DISPUTED` — contradicted by another fact in `fact_pool`
- If `draft_doc` provided: map each paragraph or numbered assertion to its supporting
  citation entry (or mark `NO_CITATION` if unsupported).
- Output as `citation_map.json`.

---

### Step 8 — Risk Scoring

**Goal:** Produce an overall evidentiary risk assessment.

Compute the following metrics:

| Metric | Formula |
|---|---|
| `evidence_coverage` | `retrieved / total_requested × 100` |
| `integrity_rate` | `chain_valid / retrieved × 100` |
| `citation_coverage` | `HIGH+MEDIUM citations / total facts × 100` |
| `discrepancy_rate` | `total_discrepancies / total_facts × 100` |
| `fabrication_flag_count` | count of `FABRICATED_FACT` flags |

Assign overall `risk_level`:
- `LOW` — coverage ≥ 80%, integrity ≥ 90%, discrepancy_rate < 10%, fabrication_flags = 0
- `MEDIUM` — any one metric outside LOW thresholds
- `HIGH` — fabrication_flags > 0, or integrity_rate < 70%, or discrepancy_rate > 25%
- `CRITICAL` — fabrication_flags > 3, or evidence_coverage < 50%

Include `risk_narrative` — 2–4 sentences explaining the primary risk drivers. This goes into
`audit_report.md` Executive Summary.

---

### Step 9 — Report Generation

**Goal:** Emit all three output artifacts.

#### `audit_report.md`

Use this exact structure:

```
# Legal Audit Report
**Case ID:** <case_id>
**Audit Date:** <ISO date>
**Risk Level:** <LOW|MEDIUM|HIGH|CRITICAL>

## Executive Summary
<risk_narrative from Step 8, 2–4 sentences>

## Evidence Inventory
| ID | Title | Category | Chain Valid | Status |
|---|---|---|---|---|
<one row per doc in evidence_bundle>

## Key Findings
### Verified Facts (<count>)
<bullet list of HIGH/MEDIUM citation facts>

### Discrepancies (<count>)
<bullet list of each flag type with counts and representative examples>

### Unsupported Claims in Draft (if draft_doc provided)
<bullet list of UNSUPPORTED_CLAIM flags>

## Risk Metrics
| Metric | Value |
|---|---|
<metrics table from Step 8>

## Recommendations
<3–5 actionable items, e.g. "Obtain missing evidence for IDs: [...]", "Remove or re-source fabricated claims", "Strengthen citation for paragraphs X–Y of motion">

## Audit Trail
Conducted by: ChittyOS 9-Step Legal Audit Skill
Source systems: Neon chittyevidence-db, ChittyChain (ChittyLedger), R2 evidence bucket
```

#### `discrepancy_log.json`

```json
{
  "case_id": "<case_id>",
  "audit_date": "<ISO datetime>",
  "total_flags": <n>,
  "flags": [
    {
      "flag_id": "DL-001",
      "type": "CONTRADICTION|UNSUPPORTED_CLAIM|FABRICATED_FACT|INTEGRITY_FAILURE|...",
      "severity": "HIGH|MEDIUM|LOW",
      "description": "<human-readable summary>",
      "evidence_ids": ["<id>", ...],
      "fact_ids": ["<id>", ...],
      "draft_location": "<paragraph/section if applicable, else null>"
    }
  ]
}
```

#### `citation_map.json`

```json
{
  "case_id": "<case_id>",
  "audit_date": "<ISO datetime>",
  "citations": [
    {
      "claim_id": "CM-001",
      "claim_text": "<claim>",
      "evidence_ids": ["<id>", ...],
      "confidence": "HIGH|MEDIUM|LOW|DISPUTED",
      "chain_verified": true,
      "draft_paragraph": "<ref or null>"
    }
  ],
  "uncited_claims": [
    {
      "draft_paragraph": "<ref>",
      "assertion_text": "<text>",
      "reason": "NO_CITATION|FABRICATED_SOURCE"
    }
  ]
}
```

---

## Output Delivery

- Write all three files to the Legal space working directory (do NOT write to Business space).
- Default output path: `./legal-audit-outputs/<case_id>-<YYYYMMDD>/`
- After writing, summarize findings in chat using this format:

```
Audit complete for <case_id>.
Risk Level: <level>
Evidence: <retrieved>/<requested> docs retrieved, <integrity_rate>% chain-verified
Discrepancies: <n> flags (<CRITICAL_count> critical, <HIGH_count> high)
Citation coverage: <citation_coverage>%
Outputs: audit_report.md | discrepancy_log.json | citation_map.json
```

---

## Error Handling

| Condition | Action |
|---|---|
| `chitty_neon_query` returns 0 rows | Log WARN, proceed evidence-only |
| `chitty_evidence_retrieve` fails for an ID | Try search fallback; if still fails, log MISSING_EVIDENCE |
| `chitty_ledger_verify` unavailable | Skip Step 3 integrity check; set `chain_verified = false` for all docs; note in report |
| `draft_doc` is null | Skip 6b and 6c draft checks; note "No draft document provided" in report |
| All evidence missing | Abort with error: "Cannot proceed — no evidence retrieved. Verify IDs and R2 access." |

---

## Tool Dependencies

Carried over from the pre-promotion definition's `compatibility` block, which is not part of the
canonical frontmatter contract:

- **chittymcp** — `chitty_neon_query`, `chitty_evidence_search`, `chitty_evidence_retrieve`,
  `chitty_evidence_verify`, `chitty_ledger_facts`, `chitty_ledger_evidence`,
  `chitty_ledger_verify`, `chitty_fact_validate`
- **Cloudflare Developer Platform** — R2 evidence bucket, read via `chitty_neon_query` proxy or
  a direct binding

If these are unavailable, halt and report the required tool names — do not simulate results.

## Security & Scope Guardrails

- **Read only** from: R2 evidence bucket, Neon, ChittyChain
- **Write only** to: Legal space (Legalink) output directory
- **Never** write to Business TeamSpace or cross-pollinate findings into Notion operational mirror without explicit user instruction
- **Never** include raw PII (SSNs, financial account numbers) in `citation_map.json` — reference by fact_id only
- All outputs must be labeled with `audit_date` and `case_id` to prevent cross-case contamination
- If MCP tools are unavailable, halt and report tool names required — do not simulate results
