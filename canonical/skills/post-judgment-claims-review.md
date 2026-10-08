---
name: post-judgment-claims-review
canon_uri: chittycanon://core/services/chittymarket#skills/post-judgment-claims-review
description: "Affirmative-claims review for an owner or defendant entity after an association, landlord, lender, or collection-counsel action has gone to judgment or payoff. Assembles the record as a non-destructive inventory, reconciles ledger ↔ complaint ↔ judgment ↔ payments to the cent, runs a sourced deep-research memo on candidate claims (restitution and contract, statutory records and fine-process rights, fiduciary duty, FDCPA / state consumer and collection statutes, abuse of process), computes post-judgment and limitations deadlines, and remediates any draft demand or refund letter as a new version. Use it whenever someone asks 'can I counter-sue', 'what claims do I have', 'did they overcharge me', 'they collected more than the judgment', or wants a refund or demand letter after paying off a judgment — even when they only say 'review my case'. Requires an explicit case parameter and runs under legal-operating-defaults."
kind: skill
plugin: chittyos-legal
runtimes:
  - claude-code
  - codex
classification:
  - legal
  - evidence
---

# Post-Judgment Claims Review

A repeatable procedure, not a legal opinion. It produces research and work product for the owner and
its counsel; every decision that needs a law license stays with counsel, and nothing it produces is
transmitted outside the engagement by the agent. `legal-operating-defaults` binds throughout — read it
first if it is not already loaded.

## Required: `case` parameter

Refuse to run without an explicit matter identifier (`case_id` or `case_slug`, resolved the same way
`evidence-collect` and `fact-governance` resolve it). Never default to "the last case." If no case is
registered yet, say so, list what registration needs (identity, slug, parties), and run only Stage 0
and Stage 1 — both are non-destructive and do not write to any store.

## Why this exists

The same failure recurs after a judgment is paid: the owner wants to "counter-sue," the record is
scattered across mailboxes, drive folders, portals and counsel's files, the numbers disagree by a few
hundred dollars nobody can explain, and the first draft letter cites the wrong statute section. The
procedure below forces evidence before assertion, arithmetic before argument, and verification before
a letter goes out.

## Stage 0 — Frame the matter (facts as allegations)

Write a matter frame before any research:

- Parties and roles (owner entity, association or creditor, managing agent, collection counsel, defense counsel).
- Every rendering of the case number seen in the record (court caption, portal, counsel's files) — record all of them; they will differ.
- Governing instruments by section (declaration, rules, lease, note) with the exact language relied on, quoted.
- The judgment: date, amounts by category, possession terms, any stay and its conditions, entry basis (after trial / by agreement / default) — mark the entry basis **unknown** until the signed order is read; an OCR of a form does not establish which box was checked.
- Payment events with amounts, channel, timestamps, and any written protest or reservation of rights, with proof of delivery.
- The owner's account of events, labeled as allegations with dates.

Isolation rule: one frame per matter. When the same counsel or the same parties appear in a second
matter (another unit, another building), keep a separate frame and never let a document, order or
date from one leak into the other. A document titled "agreed order" is attributed to a matter only by
its caption, not by who sent it.

## Stage 1 — Record inventory (non-destructive)

Build a manifest, not a copy. Metadata only: source, id, thread/file id, URL, date sent or modified,
document date (unknown unless stated on the instrument), from/to/cc, subject or title, attachment
names, matter tag, category, in-scope flag, notes.

- Query the mailbox by counterpart domains, by the association/agent addresses, by case numbers and file numbers, by instrument names (notice of violation, demand, receipt), and the owner's own outbound letters (`in:sent`). Query the drive by file number, case number, counterpart name, and instrument titles.
- Tag matter mechanically (digit-boundary matching on identifiers), so the tagging is reproducible; hand-retag only with a note saying why.
- Privileged counterparties (defense counsel, other counsel) are **counted, never listed as rows**. Platform notices that match only by street address (leasing sites, booking sites) are tagged out of scope.
- Record coverage: every query, page, and count; and a gaps list of the instruments the frame says should exist but were not found. "Not found" is a finding; "absent" requires completed paging.
- Operational: mail search results run ~12k tokens per page of 25; split the sweep across fresh agents at ~6 pages each and parse saved result files with scripts rather than reading them into context.

The manifest is the input to `evidence-collect` (its bulk-from-URL-list option). Do not copy bytes,
stage files, or ingest anything without a registered case; that is the pipeline's job, with custody.

## Stage 2 — Reconcile to the cent

Lay out, with a source for every number: the ledger balance on the judgment date; the judgment by
category; every posting after the judgment date (assessment, utility pass-through, late fee, counsel
invoice); every payment. Then decompose the payment:

```
paid − judgment = Δ
Δ = (pre-judgment excess) + (post-judgment accruals owed) + (post-judgment fees contested) + (late fees)
```

The test is an exact-cent fit. If the decomposition does not close to the cent, a posting is missing
or misread — find it before writing a demand. Label each line: judgment / owed under the instruments /
contested (pre-judgment, not awarded → merger) / contested (post-judgment, no order). A late fee is
judged by its own posting date and rule, not by an earlier dispute.

## Stage 3 — Research, then verify what the draft will cite

Launch extended research with the frame as allegations and a law-only brief: primary sources, pin
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

1. **Deadlines** — each post-judgment clock (days from entry), each limitations period (years from accrual, and the accrual date used), with "expired" stated plainly where it has.
2. **Claims** — claim, defendant, viability (strong / plausible / weak / not available), the single biggest obstacle, evidence needed, forum, fee-shifting exposure.

State the gaps: unverified facts the table depends on, contradictions between sources, and the one
open fact that most changes the answer.

## Stage 5 — Remediate the draft

- Corrections are **versions**: write vN+1 with a revision log that lists each change, its source, and its label; keep the prior notes visible. Never overwrite.
- Strip internal strategy from the transmittable copy; it lives in the log.
- Convert assertions nobody can source into requests ("please confirm in writing that…").
- Address money demands to the party that holds the money; address statutory records requests to the statutory addressee; copy counsel of record.
- Name records with particularity (invoice numbers, amounts, posting dates) and state the statutory response window.
- Put proof of delivery of any protest or reservation of rights in the letter (tracking number, recipients, timestamp).

## Stage 6 — Deliver and register

- Deliverables (memo, letter vN+1, inventory, counsel note) go to the matter's shared store as they are written, and to the operator as files.
- Work items go to the tracker with identifiers only — no case facts beyond what identifies the matter.
- The note to counsel is short: facts, numbers, the specific ask. Do not argue law to counsel.
- Transmission to any outside party is the operator's act, after counsel's read. The agent never sends.

## Anti-patterns

- Stating a fact about the matter with no source read in session.
- Treating an OCR snippet, a filename, or a prior summary as the instrument.
- Letting a second matter's order, date, or counsel remark migrate into this one.
- Treating a research memo's citation list as verified.
- Writing a demand before the reconciliation closes to the cent.
- Embedding any matter's facts, parties, amounts, or case numbers in this skill or its projections (`check-matter-leak` enforces it).

## Outputs checklist

- [ ] Matter frame (facts as allegations, instruments quoted, case-number variants)
- [ ] Inventory manifest with coverage and gaps
- [ ] Cent-exact reconciliation with sources
- [ ] Research memo with labels and unverified-citation list
- [ ] Deadlines table and claims table
- [ ] Letter vN+1 with revision log; counsel note
- [ ] Tracker entries; nothing transmitted
