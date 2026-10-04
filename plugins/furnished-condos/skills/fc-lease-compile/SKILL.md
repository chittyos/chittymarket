---
name: fc-lease-compile
description: |
  Compile a FURNISHED-CONDOS.COM lease from a lease *record* (intake + screening + unit registry + policy) into a
  signature-ready, brand-compliant execution package with the Illinois / Chicago statutory inclusions verified
  against their official sources, tagged for TurboTenant e-sign, plus its projections (TurboTenant setup, ledger
  charges, chronicle entry, de-identified analytics row). Use for any new, renewed or amended FC lease, for a
  lifecycle instrument (extension, MTM conversion, cancellation, transfer MOU), when a statutory attachment or
  requirement changes (the weekly watcher files drift), or when a lease audit returns items to disposition.
  <example>
  user: "Compile the Lakeside Loft annual lease package for e-sign"
  assistant: "Running fc-lease-compile: build the lease record → validate → decision tree D1–D8 → compile DOCX +
  projections → check sources → tag for TurboTenant → assemble → gates G1–G8 → deliver [DRAFT — owner review required]."
  </example>
model: sonnet
color: amber
tools:
- Read
- Write
- Edit
- Bash
- Glob
- Grep
- WebFetch
- WebSearch
- mcp__Linear__*
- mcp__Google_Drive__*
canon_uri: chittycanon://core/services/chittymarket#skills/fc-lease-compile
---

# FC Lease Compile

Operator skill for turning a **lease record** into the execution package: brand-compliant lease + Required Disclosures
rider + the Illinois / Chicago statutory inclusions, in the mandated order, verified, tagged for TurboTenant e-sign, and
the projections every downstream system consumes. The lease is a record (`data/lease-field-model.yaml`, 235 fields);
the DOCX/PDF, the TurboTenant setup, the ledger charges, the chronicle entry and the de-identified analytics row are
projections of it — nothing is authored in the document first, nothing is re-typed downstream.
Implementation lives in `furnished-condos/ChittyPro-Compile` (`data/`, `scripts/`, `docs/`); this skill is the operator
contract. Everything outbound is **[DRAFT — owner review required]** until Nick approves.

## Upstream

- Products / units / policy: `data/lease-products.yaml` (DIRECT_MIDTERM 1–6 months at C211 / VILLAVISTA; DIRECT_ANNUAL
  12 months at ADDISON3S per HOA Rule 22.8; LIFECYCLE instruments; EXCEPTION), Lease & Billing Policy 2026-04 constants,
  landlord signers (signer1 Managing Director, signer3 President; tenant signer2; co-signer signer4).
- Field model `data/lease-field-model.yaml` → `scripts/field_model_to_schema.py` (JSON Schema, regenerated on demand;
  `--stats` for the counts). Decision tree `data/lease-decision-tree.yaml` D1–D8, evaluated by `scripts/lease_rules.py`.
- Clause library `data/clause-library/` (75 clauses: CORE, RENT, TERM, BILLING, FEES, UTIL, RULES, OPS, DISC, CONCESSION,
  PARTIES, EXCEPTION, lifecycle/LIFE.*). Clause ids are stable; the document numbers itself.
- Design system: `house [f] home — Furnished-Condos.com Design System` tokens + Brand Guide v3 canonical `[ ƒ ]`
  master (`assets/f-canonical-mark.svg`, sha256 `15ed8c0f…`). The mark is immutable — never redraw, recolor or crop.
- Attachment registry `data/il-chicago-lease-attachments.json` (sha256 / pages / placement / applies_when per source);
  form geometry `data/esign-form-geometry.json`; weekly watcher (`fc-lease-attachment-watch`) — refuse to assemble on
  unresolved drift.

## Procedure

1. **Build the record** — start from `examples/lease-record.*.json`; fill `owner_intake` fields from the owner, `tt_application`
   and `screening` fields from the TurboTenant application and report (650+ / 3× income → `screening.outcome: pass`;
   guarantor → `guarantor_path`; below threshold → `month_ahead`), `lease.agreement_date` explicitly (never the compile
   date). Unit-registry and policy fields are filled by the compiler; do not re-type them.
2. **Validate** — `python3 scripts/validate_lease_record.py --record R.json` (exit 0 standard · 3 exception · 2 invalid ·
   4 rule_error). Exit 3 means the tree refused: a sub-12-month term at ADDISON3S, < 30 nights, > 6 months non-annual,
   installments, stepped rent / owner-shared period. Route to the owner; compile only from an approved `EXCEPTION.*`
   clause set with `exception.kind` + `exception.approved_by` recorded.
3. **Compile** — `python3 scripts/compile_lease.py --record R.json --out DIR` → `lease.docx`, `decision_trace.json`,
   `record.resolved.json`, `rent_schedule.json`, `tt_lease_setup.json`, `ledger_charges.json`, `chronicle_entry.json`,
   `feature_store_row.json` (no names / contacts), `compile_report.md`. Read the report: counsel gates, drift /
   overrides (`prov.overrides` rows need reason + approver; drift_count 0 is the standard), schedule reconciliation.
4. **Check sources** — `python scripts/check_attachments.py --download attachments/` must exit 0. Drift (exit 2): read
   the new document, confirm the version string, `--update`, PR, re-run. Fetch errors (exit 3): embedded copies as
   fallback only, note provenance.
5. **Render** DOCX → PDF (LibreOffice headless, Inter installed). Legacy path for a lease drafted as a DOCX outside the
   compiler: restyle (styles only, body text byte-for-byte unchanged), append the rider, `scripts/add_signer.py` for the
   second landlord signer — then continue below.
6. **Assemble** — `scripts/assemble_package.py` (print / wet-sign) and `scripts/tag_esign.py` for TurboTenant (Dropbox
   Sign text tags in the grammar TurboTenant's own leases carry; tag count must equal `esign.tag_count_expected`).
   Order: IDHR Safe Homes summary first (nothing precedes it) → lease → Exhibit F → RLTO summary → deposit-interest
   rider → CDPH bed-bug brochure → EPA lead pamphlet + lessor form (pre-1978 or year_built unknown) → IEMA radon guide
   + form → HOA rules.
7. **Gates** — G1 verbatim · G2 mark sha · G3 order / page-1 self-check · G4 visual · G5 TurboTenant audit dispositions
   (Exhibit F) · G6 tag invisibility + extractability · G7 TurboTenant test upload · **G8 record gates**: schedule total
   == months × total rent (less half-month) + fees; every `trace.requires` field present; counsel gates listed in the
   report are open items, not silently passed.
8. **Deliver** — execution package, e-sign package, lease-only PDF, DOCX sources, attachment zip, `tt_lease_setup.json`,
   `ledger_charges.json`, `chronicle_entry.json`; Linear issue with owner fields + deadlines; ChittyCAN session summary.
   TurboTenant upload, ledger posting and chronicle write happen only after recorded owner approval.

## Boundaries

- Never invent a statute, section number, document text or property fact — mark **[unverified]** and ask.
- Never send anything to a tenant, counterparty or TurboTenant recipient without recorded owner approval.
- Never type a value the record already carries into TurboTenant, a spreadsheet or the document by hand; fix the record.
- No tenant names in repository files — examples use synthetic tenants; identified records stay with the lease records.
- Lakeside Loft (ADDISON3S) and City Studio (C211) only unless told otherwise; other units have different ownership chains.
- Counsel gates carried by the tree (do not compile past them as if resolved): cleaning / move-out fee (compiles at $0
  until `cleaning_fee_confirmed_by_counsel`), prepaid rent held > 6 months (every DIRECT_ANNUAL standard lease),
  early-termination default, narrow indemnity (F16), dispute-resolution choice, fee-free payment alternative, Rent
  Concession Act disclosure for any concession; flood D5 vs documented water-intrusion history.

## Proposed companion (not yet a workflow)

Weekly **drift report** — overrides and exceptions per week from `prov.overrides` / `EXCEPTION.md`, alongside the
attachment watcher; a recurring exception is a candidate for a new governed option. Governor loop before any store.
