---
name: fc-lease-compile
kind: skill
description: |
  Compile a FURNISHED-CONDOS.COM lease into a signature-ready, brand-compliant execution package with the
  Illinois / Chicago statutory inclusions verified against their official sources, optionally tagged for
  TurboTenant e-sign. Use for any new or renewed FC lease, when a statutory attachment or requirement changes
  (the weekly watcher files drift), or when a lease audit returns items to disposition.
  <example>
  user: "Compile the Swanson lease package for e-sign"
  assistant: "Running fc-lease-compile: check sources → restyle → rider → render → tag for TurboTenant →
  assemble → gates G1–G7 → deliver [DRAFT — owner review required]."
  </example>
canon_uri: chittycanon://core/services/chittymarket#skills/fc-lease-compile
canonical_capability_ref: chittycanon://capability/workspace/fc-lease-compile
plugin: furnished-condos
runtimes:
  - claude-code
  - codex
classification:
  - leasing
  - documents
  - compliance
  - furnished-condos
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
runtime_overrides:
  codex:
    references:
      - LEASE-COMPILE-PROCESS.md
overlay:
  title: FC Lease Compile — Illinois / Chicago execution package
  capability_group: workspace
  group_assignment_source: override
  execution_class: "@chitty/workspace"
  canonical_version: 1.1.0
  projection_version_policy: inherit-canonical
  ontology:
    primary:
      - E
      - T
    secondary:
      - P
      - L
  authority:
    requires_chittyid: true
    requires_case: false
    write_scope: session-scoped
    no_last_case_fallback: true
    non_repudiation_required: false
    evidence_gate: projection-internal
  execution:
    default_surface: local
    local_allowed: true
    context_cost: medium
    mutation_risk: low
  discovery:
    indexable: true
    session_index: summary
    ambient_by_intent: true
    verbs:
      - lease
      - compile
      - rlto
      - disclosures
      - e-sign
      - turbotenant
      - furnished-condos
    fallback_search: true
  auth_flow:
    mode: local-only
    stores_credentials_in: n/a
    fail_closed_if_unavailable: true
    requires_case_id: false
    no_fallback_last_case: true
  runtime_exclusions:
    openclaw:
      - write_requires_policy_elevation
  phase0_audit:
    job_to_be_done: compile
    environmental_footprint: write-capable
    evidentiary_risk: low
    advisory_disposition: local-only
  legacy_category: workspace
  deprecated_aliases: []
  visibility: recommended
  access: readwrite
  compatible_channels:
    - claude_code
    - codex
  source_links:
    - https://github.com/furnished-condos/ChittyPro-Compile/tree/feat/il-chicago-lease-attachment-registry
    - local://plugins/furnished-condos/skills/fc-lease-compile
---

# FC Lease Compile

Operator skill for turning a drafted FURNISHED-CONDOS.COM lease (DOCX, clause text final) into the execution
package: brand-compliant lease + Required Disclosures rider + the Illinois / Chicago statutory inclusions, in
the mandated order, verified, and — when the lease signs through TurboTenant — tagged for e-sign.
Implementation lives in `furnished-condos/ChittyPro-Compile` (`data/`, `scripts/`, `docs/LEASE-COMPILE-PROCESS.md`);
this skill is the operator contract. Everything outbound is **[DRAFT — owner review required]** until Nick approves.

## Upstream

- Design system: `house [f] home — Furnished-Condos.com Design System` tokens + Brand Guide v3 canonical `[ ƒ ]`
  master (`f-canonical-mark.svg`, sha256 `15ed8c0f…`). The mark is immutable — never redraw, recolor or crop.
- Attachment registry `data/il-chicago-lease-attachments.json` (sha256 / pages / placement / applies_when per source).
- Form geometry `data/esign-form-geometry.json` (sha256-guarded tag coordinates for the IDHR, EPA and IEMA forms).
- Weekly watcher (`fc-lease-attachment-watch` workflow) — refuse to assemble on unresolved drift.

## Procedure

1. **Check sources** — `python scripts/check_attachments.py --download attachments/` must exit 0. Drift (exit 2):
   read the new document, confirm the version string, `--update`, PR, re-run. Fetch errors (exit 3): use the
   TurboTenant / Domu embedded copies as fallback only, note provenance.
2. **Restyle** the lease DOCX (styles only; body text byte-for-byte unchanged): Inter 400/500/600, Brand Guide v3
   palette, hairline tables, canonical mark on page 1, eyebrow header, footer with page X of Y.
3. **Append the Required Disclosures rider**: attachment index + Landlord Disclosure Statement D1–D9
   (§ 5-12-090 agent identification, § 5-12-100 citations / actions / utility shut-offs, § 5-12-095 foreclosure,
   heating cost, 765 ILCS 705/25 flood template verbatim, lead, radon, recycling, receipt). Owner-fact fields are
   highlighted, never guessed.
4. **Second landlord signer** when required: `scripts/add_signer.py … --by "By: Sharon E. Jones, President, ARIBIA LLC"`.
5. **Render** DOCX → PDF (LibreOffice headless, Inter installed).
6. **Assemble** — `scripts/assemble_package.py` (print / wet-sign) and, for TurboTenant, `scripts/tag_esign.py`
   (Dropbox Sign text tags in the grammar TurboTenant's own leases carry; signer1 = Nicholas A. Bianchi,
   signer2 = tenant, signer3 = Sharon E. Jones). Order: IDHR Safe Homes summary first (nothing precedes it) →
   lease → Exhibit F (audit remediation) → RLTO summary → deposit-interest rider → CDPH bed-bug brochure →
   EPA lead pamphlet + lessor form (pre-1978) → IEMA radon guide + form.
7. **Gates** — G1 verbatim · G2 mark sha · G3 order / page-1 self-check · G4 visual · G5 TurboTenant audit
   dispositions (Exhibit F) · G6 tag invisibility + extractability · G7 TurboTenant test upload.
8. **Deliver** — execution package, e-sign package, lease-only PDF, DOCX sources, attachment zip, field map,
   `tt_lease_setup.<tenant>.json`; Linear issue with owner fields + deadlines; ChittyCAN session summary.

## Boundaries

- Never invent a statute, section number, document text or property fact — mark **[unverified]** and ask.
- Never send anything to a tenant, counterparty or TurboTenant recipient without recorded owner approval.
- Lakeside Loft only unless told otherwise; other portfolio units have different ownership chains.
- Counsel items carried forward: RLTO § 5-12-140 limits on indemnity/exculpation (Exhibit F16), § 5-12-100 vs an
  HOA possession action, flood D5 vs documented water-intrusion history, Rent Concessions Act treatment of the
  months-1–3 prepayment waiver.
