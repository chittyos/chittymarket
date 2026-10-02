---
name: doctype-checks
description: Per-document-type intake checks for legal evidence. Given a document, identify its type and run every check that type requires, emitting an explicit result for each — pass, fail, or unknown — so nothing is silently skipped. Runs BEFORE a fact is drafted, upstream of fact-governance's draft/verified/locked lifecycle. Triggers on "check this document", "what should I verify here", "intake checks", "doctype checks", "is this executed", "which balance", "entered or draft", or any first read of a new instrument, statement, order, or export.
canon_uri: chittycanon://core/services/chittymarket#skills/doctype-checks
---

# Document-Type Intake Checks

A checklist is cheaper than a retraction. This skill holds, per document type, the checks that
experience says get missed — so they are run from a list rather than re-derived under time
pressure each time a document is opened.

## Scope and position

This runs at **intake**, before any fact is asserted. It is upstream of `fact-governance`,
which owns the `draft → verified → locked` lifecycle of a fact that already exists. A document
passes through these checks first; only then is a fact drafted from it.

It carries **no matter-specific facts** and never will, per `legal-operating-defaults`. Each
check is an error class, not an anecdote.

## The output contract

For every check in the applicable block, emit one line:

| result | meaning |
|---|---|
| `PASS` | checked against the document, satisfied |
| `FAIL` | checked against the document, not satisfied |
| `UNKNOWN` | could not be determined from what was read — say what is missing |

**`UNKNOWN` is a valid result and must be stated.** Omitting a check is not. A silently dropped
check reads as a pass, which is the failure mode this skill exists to prevent.

Each check is tagged:

- **`[mechanical]`** — scriptable without reading the document. A validator can decide it.
- **`[attest]`** — requires reading the document. No validator can decide it; the enforcement
  is that an explicit result is *required*, not that it is automated.

Do not describe the `[attest]` set as automated coverage.

## Cross-cutting — run on every document

- `[mechanical]` Every exhibit ID cited resolves in the exhibit index. No dangling IDs.
- `[mechanical]` Citations match the required form: `[EXHIBIT ID | document name | date | page/¶]`.
  On a corpus written before the standard was adopted this fires on everything; decide once
  whether the standard is retroactive and record the decision, rather than reporting the whole
  package as defective on every run.
- `[attest]` Entity names appear in full in assertive prose, never shortened or bare. Quoted
  source text, trade names, document titles and filenames are exempt and must not be rewritten
  to satisfy this. This was tried as a mechanical check and withdrawn: on a real corpus every
  hit was a legitimate exemption, because a pattern match cannot tell a party reference from a
  brand, a caption, or the other side's own words.
- `[mechanical]` Pages actually read equals the document's page count. A partial read cannot
  support a negative finding. Decidable only if the extraction manifest records per-document
  read coverage, not just page count. Where it records only page count, the honest result is
  `UNKNOWN` — do not report it as a pass.
- `[attest]` Before reporting that something is absent, the whole document was read to the end,
  and it was the right document. Report the negative as a negative — "no X was located in Y" —
  rather than converting it into an affirmative claim about the world.
- `[attest]` AI work product — summaries, trackers, prior memos — is a navigation aid and never
  a fact source. Any citation resting on one is flagged, not promoted.
- `[attest]` Analysis is kept distinguishable from documentary fact. "The instrument conveys
  title" is analysis; "the instrument recites a conveyance dated <date>" is a documentary fact.

## Recorded instrument — deed, quitclaim, mortgage, release

- `[mechanical]` Filename or document text containing `DRAFT`, `UNSIGNED`, `UNEXECUTED`, or
  `never recorded` sets status to draft. A draft is not evidence of a conveyance.
  Scope the check to the *assertion*, not to proximity: a draft marker appearing alongside
  conveyance language is correct usage when the sentence denies the conveyance ("unexecuted
  quitclaim — title remains in the grantor"). Flag only where the instrument is relied on
  affirmatively. Proximity alone was tried and produced only false positives.
- `[mechanical]` A recorder's document number is present and transcribed digit-by-digit from the
  stamp. Two readings that differ by one digit are a discrepancy to resolve, not a typo to pick
  between.
- `[attest]` Executed: a signature appears on the instrument itself, not on a cover sheet,
  transmittal, or exhibit wrapper.
- `[attest]` Recorded: a recorder's stamp or certified recording page is present. Possession of
  a copy is not recording. Execution is not recording.
- `[attest]` Grantor and grantee named exactly as written. Any marital or capacity recital is
  quoted verbatim rather than characterized.
- `[attest]` Execution date and recording date reported separately, never collapsed.
- `[attest]` Collateral or security language is not reported as a perfected lien absent a
  recorded security instrument.

## Bank or financial statement

- `[attest]` Name which balance measure is being used — opening, ending, or available — and use
  the same measure across every account in a comparison. These diverge, and the divergence has
  changed conclusions by orders of magnitude.
- `[attest]` Institution and account last-four identified; statement period stated.
- `[attest]` Every page read, including trailing pages that are images rather than text. A PDF
  with an audit trail often carries its substance on the pages that do not extract.
- `[attest]` A transfer in is not income, and not a payment by the account holder, until its
  source is identified. Characterize the counterparty only after reading the source leg.
- `[attest]` Before characterizing any payment, read at least one statement period earlier. The
  explanation for a transaction is frequently in the prior period.
- `[attest]` Balances reported as of a stated date from a live summary, not carried forward from
  an earlier figure.

## Settlement or closing statement — ALTA, CD, HUD-1

- `[attest]` Name the column. Borrower cash-to-close, seller net proceeds, and total
  disbursements are three different numbers in three different columns.
- `[attest]` Net proceeds tied to a disbursement instrument — check or wire number — not read
  off a summary line.
- `[attest]` Payoff figures distinguished from principal balance.

## Court order or judgment

- `[attest]` Entered versus proposed: a judge's signature and a clerk's entry stamp are both
  present. A proposed order in the file is not an entered order, and an entered order is not a
  draft — mistaking either direction inverts the analysis.
- `[attest]` Every numbered paragraph enumerated, including subparagraphs. Obligations extracted
  with the deadline computation shown, and the computation rule pulled from its source rather
  than from memory.
- `[attest]` Where a deadline admits more than one reading, present every reading for counsel to
  select. Do not pick the operative date.

## Platform export — property management, e-signature, document portals

- `[attest]` A platform role label is not a legal status. Name the instrument that creates the
  relationship; a payer field is not a tenancy.
- `[attest]` Use native per-record panels, not a derived dashboard or aggregate export. Derived
  views mis-attribute records, including to unresolved template placeholders.
- `[attest]` Access events distinguished: viewed, downloaded, and executed are three events with
  three timestamps.

## Foreign instrument

- `[attest]` A promise to convey is distinguished from a conveyance. Both translate loosely and
  are not interchangeable.
- `[attest]` Encumbrance status taken from the jurisdiction's own title certificate, with the
  property's registry identifier cited.
- `[attest]` Any currency conversion states rate, date, and source. Two figures that differ only
  because the rate was left unstated are not a contradiction — reconcile before logging one.
- `[attest]` A ledger total is decomposed before it is characterized. Cost advanced by the owner
  is not revenue owed to the owner.

## Entity governance — operating agreement, shareholder agreement, bylaws

- `[attest]` Quote the operative section and confirm the section exists at the cited number.
  Citations to sections that are not in the executed document are a recurring failure.
- `[attest]` Read what a clause actually does. A waiver of partition or receivership is not an
  asset shield, and a provision may cut against the position it was cited for.
- `[attest]` Count executed versions and amendments. Where a cap table or split has been amended
  more than once, say which version governs and why.
- `[attest]` Where a provision governs removal, forfeiture, or expulsion: quote the provision,
  quote the notice or act said to invoke it, and enumerate which elements are met and which are
  not. Reach no conclusion the enumeration does not support, in either direction.

## Exercised against a real corpus

The mechanical subset was run against a 76-document package on 2026-10-02. Results, which are
the reason four of the checks above now read differently:

| check | outcome |
|---|---|
| exhibit IDs resolve | **true positive** — 4 cited IDs with no index entry, one carrying a pin-cited substantive proposition |
| recorder doc numbers | **true positive** — two readings of one number differing by a single digit, both in circulation |
| citation format | fired on all 251 citations; a standard-adoption question, not 251 defects |
| pages read vs count | undecidable — manifest records page count, not read coverage |
| draft markers | **all false positives** — rule rewritten |
| entity names in full | **all false positives** — reclassified to `[attest]` |

Two of six mechanical checks produced findings. A check that cannot distinguish a party
reference from a brand name, or correct usage from misuse, is worse than no check: it trains
the reader to skim the output.

## Status

Seed corpus, derived from the error history of a single matter. These are the checks that were
observed to fail in practice, not a survey of document types — treat the list as incomplete and
extend it when a new class of miss is found. Document types absent here have no block yet.

Related memories point here rather than restating these rules: `entity-names-never-shortened`,
`platform-labels-are-not-legal-status`, `read-to-the-end-before-reporting-a-negative`,
`assert-only-what-was-checked`, `state-the-negative-dont-flip-the-burden`.
