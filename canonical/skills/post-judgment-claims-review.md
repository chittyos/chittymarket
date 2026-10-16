---
name: post-judgment-claims-review
canon_uri: chittycanon://core/services/chittymarket#skills/post-judgment-claims-review
description: "Affirmative-claims review for an owner or defendant entity after an association, landlord, lender, or collection-counsel action has gone to judgment or payoff. Assembles the record as a non-destructive inventory, reconciles ledger ↔ complaint ↔ judgment ↔ payments to the cent, runs a sourced deep-research memo on candidate claims (restitution and contract, statutory records and fine-process rights, fiduciary duty, FDCPA / state consumer and collection statutes, abuse of process), computes post-judgment and limitations deadlines, and remediates any draft demand or refund letter as a new version. Use it whenever someone asks 'can I counter-sue', 'what claims do I have', 'did they overcharge me', 'they collected more than the judgment', or wants a refund or demand letter after a judgment has been entered or paid. Not for pre-judgment work: intake and tracking belong to dispute, claim-versus-record audits to 9-step-legal-audit. Needs the matter named (a unit, address or case number is enough); only steps that touch an evidence store, a fact table or a tracker need a registered case. Runs under legal-operating-defaults."
kind: skill
plugin: chittyos-legal
runtimes:
  - claude-code
  - codex
classification:
  - legal
  - evidence
canonical_capability_ref: "chittycanon://capability/legal/post-judgment-claims-review"
overlay:
  title: "Post-Judgment Claims Review"
  capability_group: "legal"
  group_assignment_source: "override"
  execution_class: "@chitty/reasoning"
  canonical_version: "1.0.0"
  projection_version_policy: "inherit-canonical"
  ontology:
    primary:
      - "P"
      - "E"
      - "T"
    secondary:
      - "L"
      - "A"
  authority:
    requires_chittyid: true
    requires_case: true
    write_scope: "case-scoped"
    no_last_case_fallback: true
    non_repudiation_required: true
    evidence_gate: "legal-space-only"
  execution:
    default_surface: "ch1tty"
    local_allowed: true
    context_cost: "high"
    mutation_risk: "high"
  discovery:
    indexable: true
    session_index: "hidden"
    ambient_by_intent: false
    verbs:
      - "counterclaim"
      - "overpayment"
      - "refund"
      - "demand"
      - "judgment"
    fallback_search: true
  auth_flow:
    mode: "existing-session"
    stores_credentials_in: "ChittyConnect"
    fail_closed_if_unavailable: true
    requires_case_id: true
    no_fallback_last_case: true
  runtime_exclusions:
    openclaw:
      - "write_requires_policy_elevation"
  phase0_audit:
    job_to_be_done: "resolve"
    environmental_footprint: "write-capable"
    evidentiary_risk: "legal-grade"
    advisory_disposition: "legal-only"
  legacy_category: "legal"
  deprecated_aliases:
    - "skill-post-judgment-claims-review"
  visibility: "recommended"
  access: "readwrite"
---

# Post-Judgment Claims Review

A repeatable procedure, not a legal opinion. It produces research and work product for the owner and
its counsel; every decision that needs a law license stays with counsel, and nothing it produces is
transmitted outside the engagement by the agent. `legal-operating-defaults` binds throughout — read it
first if it is not already loaded.

## Matter identifier — two tiers

Every stage is scoped to one explicit matter. Which identifier a stage needs depends on what it touches:

- **Reasoning on supplied facts (Stages 0–5)** is scoped by the label the operator used for the matter — a unit, an address, a case or file number. If the operator gave none, ask for one in a single line before Stage 2 and stop there; never invent a label and never infer "the last case." When the case is not registered, say so at the top of the output and list what registration needs (identity, slug, parties), then carry on. All work product from these stages goes to the operator as files and to the matter's shared store as it is written (legal-operating-defaults §11.2–§11.3). The shared store is a document location the operator names (a matter folder, a project), not an evidence store; if none has been named yet, list it with the registration needs and deliver files meanwhile. Nothing stays only on the compute node.
- **Anything that touches the evidence store, the fact table, the tracker or the index** — the Stage 1 handoff to `evidence-collect`, fact registration through `fact-governance`, tracker entries keyed to the case, index queries — needs a registered `case_id` or `case_slug`, resolved the way `evidence-collect` and `fact-governance` resolve it. Without one, write what the handoff would be and mark it held.

The frame is the isolation boundary for the reasoning stages: one frame per matter, and nothing crosses between frames. Withholding the reconciliation or the letter because no case is registered yet is the wrong failure — the registration gate protects stores, not arithmetic. The frontmatter flags `authority.requires_case`, `auth_flow.requires_case_id` and `fail_closed_if_unavailable` describe this store-touching tier; a router that applied them to the whole capability would reinstate the gate this section replaces.

## Why this exists

The same failure recurs after a judgment is paid: the owner wants to "counter-sue," the record is
scattered across mailboxes, drive folders, portals and counsel's files, the numbers disagree by a few
hundred dollars nobody can explain, and the first draft letter cites the wrong statute section. The
procedure below forces evidence before assertion, arithmetic before argument, and verification before
a letter goes out.

## Stage 0 — Frame the matter (facts as allegations)

Write a matter frame before any research. Keep it compact — one line per item; the label on each line
(Given / Derived / Unknown, or "allegation") carries more weight than prose:

- The matter label the operator used, and every rendering of the case number seen in the record (court caption, portal, counsel's files) — record all of them; they will differ.
- Parties and roles (owner entity, association or creditor, managing agent, collection counsel, defense counsel).
- Governing instruments by section (declaration, rules, lease, note) with the exact language relied on, quoted.
- The judgment: date, amounts by category, possession terms, any stay and its conditions, entry basis (after trial / by agreement / default) — mark the entry basis **unknown** until the signed order is read; an OCR of a form does not establish which box was checked.
- Payment events with amounts, channel, timestamps, and any written protest or reservation of rights, with proof of delivery.
- The owner's account of events, labeled as allegations with dates.

Isolation rule: one frame per matter. When the same counsel or the same parties appear in a second
matter (another unit, another building), keep a separate frame and never let a document, order or
date from one leak into the other. A document titled "agreed order" is attributed to a matter only by
its caption, not by who sent it. With two matters in one request, write both frames first (so nothing
leaks), then finish the matter that carries the money question before starting the other's long-form
artifacts.

## Stage 1 — Record inventory (non-destructive)

Build a manifest, not a copy. Metadata only: source, id, thread/file id, URL, date sent or modified,
document date (unknown unless stated on the instrument), from/to/cc, subject or title, attachment
names, matter tag, category, in-scope flag, notes.

- Query the mailbox by counterpart domains, by the association/agent addresses, by case numbers and file numbers, by instrument names (notice of violation, demand, receipt), and the owner's own outbound letters (`in:sent`). Query the drive by file number, case number, counterpart name, and instrument titles.
- Tag matter mechanically (digit-boundary matching on case, file and unit identifiers; when the matter has no number yet, tag by the operator's label and say so), so the tagging is reproducible; hand-retag only with a note saying why.
- Privileged counterparties (defense counsel, other counsel) are **counted, never listed as rows**. Platform notices that match only by street address (leasing sites, booking sites) are tagged out of scope.
- Record coverage: every query, page, and count; and a gaps list of the instruments the frame says should exist but were not found. "Not found" is a finding; "absent" requires completed paging.
- Proportional to the record: when the operator supplied the record in the request and there is no mailbox or drive to search, the manifest is a short table of those items plus the gaps list — do not pad coverage.
- Operational: mail search pages are large. Split the sweep across fresh agents, cap the pages each one fetches, and parse saved result files with scripts rather than reading them into context.

The manifest's drive rows are the input to `evidence-collect` Option C (bulk from Drive URL list). Mail rows have no direct ingestion route: export each message or attachment to the case's drive location through the governed mail-to-drive export path first, record the export on the manifest row, and only then does it enter through Option C. Do not copy bytes, stage files, or ingest anything without a registered case; that is the pipeline's job, with custody.

## Stage 2 — Reconcile to the cent

Lay out, with a source for every number: the amount demanded in the complaint and its components; the ledger balance at filing and on the judgment date; the judgment by category; every posting after the judgment date (assessment, utility pass-through, late fee, counsel invoice, post-judgment interest, costs); every payment, credit, and prior partial tender with its disposition (accepted, returned, held). Reconcile three pairs — complaint ↔ ledger at filing, ledger at judgment ↔ judgment, payment ↔ judgment plus post-judgment postings — then decompose the payment:

```
paid − judgment = Δ
Δ = (pre-judgment excess) + (post-judgment accruals owed) + (post-judgment fees contested) + (late fees)
```

The test is an exact-cent fit. If the decomposition does not close to the cent, a posting is missing
or misread — find it before writing a demand: the first ask, to counsel or to the creditor, is for the
posting detail that closes the gap, never whether to demand the unexplained amount. Label each line: judgment / owed under the instruments / owed by statute (post-judgment interest) / contested (pre-judgment, not awarded → merger) / contested (post-judgment, no order). A late fee is
judged by its own posting date and rule, not by an earlier dispute.

## Stage 3 — Research, then verify what the draft will cite

Launch extended research with an abstracted fact pattern — roles instead of names; no case numbers, addresses, account or invoice numbers, exact amounts, or dates beyond what the legal question needs (rounded figures and relative timing suffice) — and a law-only brief. Sending the frame itself to an outside research service is a transmission under legal-operating-defaults §9 and requires the operator's explicit authorization. The brief asks for: primary sources, pin
cites, every conclusion labeled `[Established law — cited]`, `[Contested or unsettled]`, or
`[Depends on unverified fact]`, and a list of citations the researcher could not verify. Ask for, at
minimum: post-judgment procedure (motion, appeal, sanctions, and vacatur windows; what a separate
action may still raise; preclusion, including for agreed orders), statutory rights against the
creditor (records, fine process, fiduciary duty, fee-shifting in both directions), federal and state
collection statutes (who is a "consumer," what is a "debt," the purpose-and-timing test, the attorney
exemption), common-law tort and restitution theories (favorable-termination and "process" elements;
the voluntary-payment doctrine and its duress and protest exceptions), limitations for each, and a
viability table.

Then verify, in session, every authority the deliverable will actually cite: cases through a court
database (citation, court, date), statutes through an official source. Record what could not be
re-fetched and label it. A research memo is derived material; it does not verify itself.

## Stage 4 — Viability and deadlines

Two tables, dates first:

1. **Deadlines** — each post-judgment clock (days from entry) and each limitations period (years from accrual, with the accrual date used). Every computed date carries its trigger, the rule relied on, and the counting convention, and is marked `computed (draft)` until confirmed against the governing order (legal-operating-defaults §14); where a computed date has passed, say so plainly as `computed — passed`.
2. **Claims** — claim, defendant, viability (strong / plausible / weak / not available), the single biggest obstacle, evidence needed, forum, fee-shifting exposure.

State the gaps: unverified facts the table depends on, contradictions between sources, and the one
open fact that most changes the answer.

## Stage 5 — Remediate the draft

- Corrections are **versions**: write vN+1 and keep a revision log as a separate internal artifact — never inside the transmittable copy — listing each change, its source, and its label, with prior notes retained. Never overwrite.
- Strip internal strategy from the transmittable copy; it lives in the log.
- Convert assertions nobody can source into requests ("please confirm in writing that…").
- Address money demands to the party that holds the money; address statutory records requests to the statutory addressee; copy counsel of record.
- Name records with particularity (invoice numbers, amounts, posting dates) and state the statutory response window.
- Put proof of delivery of any protest or reservation of rights in the letter (tracking number, recipients, timestamp).

## Stage 6 — Deliver and register

- Deliverables (memo, letter vN+1, inventory, counsel note) go to the matter's shared store as they are written, and to the operator as files.
- Work items go to the tracker with identifiers only — no case facts beyond what identifies the matter. Without a registered case, the tracker entries are written as a held handoff listing what would be filed.
- The note to counsel is short: facts, numbers, the specific ask. Do not argue law to counsel.
- Short pieces first: write the operator's answers and the counsel note as soon as the reconciliation stands; the long-form artifacts follow. If the run stops before the checklist is complete, the index says what was not written — nothing references a file that does not exist.
- Transmission to any outside party is the operator's act, after counsel's read. The agent never sends.

## Anti-patterns

- Stating a fact about the matter with no source read in session.
- Treating an OCR snippet, a filename, or a prior summary as the instrument.
- Letting a second matter's order, date, or counsel remark migrate into this one.
- Treating a research memo's citation list as verified.
- Writing a demand before the reconciliation closes to the cent.
- Embedding any matter's facts, parties, amounts, or case numbers in this skill or its projections (`check-matter-leak` enforces it).

## Outputs checklist

- [ ] Registration status stated at the top; registration needs listed if the case is not registered
- [ ] Matter frame (facts as allegations, instruments quoted, case-number variants)
- [ ] Inventory manifest with coverage and gaps
- [ ] Cent-exact reconciliation with sources
- [ ] Research memo with labels and unverified-citation list
- [ ] Deadlines table and claims table
- [ ] Letter vN+1 with revision log; counsel note
- [ ] Index of deliverables that says what was not written
- [ ] Tracker entries, or the held handoff; nothing transmitted
