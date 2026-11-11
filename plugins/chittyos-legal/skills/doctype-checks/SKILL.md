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
- **`[blocked]`** — would be mechanical, but the input it needs does not exist yet. Excluded
  from the runnable subset and named here so it is not mistaken for coverage.

Do not describe the `[attest]` set as automated coverage.

## Cross-cutting — run on every document

- `[mechanical]` Every exhibit ID cited resolves in the exhibit index. No dangling IDs.
- `[mechanical]` Citations match the required form: `[EXHIBIT ID | document name | date | page/¶]`.
  The matter's exhibit index carries a `citation_standard_adopted:` date in its front matter;
  that date is the authority. A citation in a document written **before** it emits
  `PASS (pre-adoption)` — a real, visible result, never a suppressed line. A citation written
  **after** it emits `PASS` or `FAIL` normally. If the index carries no such date, emit
  `UNKNOWN` on every citation and say the date is missing: that is the finding, and it is
  resolved once by writing the date, not re-litigated on every run.
- `[attest]` Entity names appear in full in assertive prose, never shortened or bare. Quoted
  source text, trade names, document titles and filenames are exempt and must not be rewritten
  to satisfy this. This was tried as a mechanical check and withdrawn: on a real corpus every
  hit was a legitimate exemption, because a pattern match cannot tell a party reference from a
  brand, a caption, or the other side's own words.
- `[blocked]` Pages actually read equals the document's page count. A partial read cannot
  support a negative finding. **Not currently runnable and excluded from the mechanical
  subset:** "pages read" is a property of the reader, not of the document, and no manifest in
  use records per-document read coverage — only page count. A check that returns `UNKNOWN` on
  every document cannot pass and cannot fail, so leaving it in the runnable set is noise in a
  slot. It becomes `[mechanical]` the day a manifest records coverage.
- `[attest]` Before reporting that something is absent, the whole document was read to the end,
  and it was the right document. Report the negative as a negative — "no X was located in Y" —
  rather than converting it into an affirmative claim about the world.
- `[attest]` AI work product — summaries, trackers, prior memos — is a navigation aid and never
  a fact source. Any citation resting on one is flagged, not promoted.
- `[attest]` Analysis is kept distinguishable from documentary fact. "The instrument conveys
  title" is analysis; "the instrument recites a conveyance dated <date>" is a documentary fact.

## Recorded instrument — deed, quitclaim, mortgage, release

- `[mechanical]` Filename or document text contains `DRAFT`, `UNSIGNED`, `UNEXECUTED`, or
  `never recorded` → the instrument's status is **draft**. This half is a fact about the
  document: the marker is present or it is not, and a script decides it.
- `[attest]` A draft instrument is not relied on as evidence of a conveyance. Proximity is not
  the test — a draft marker sitting beside conveyance language is *correct* usage when the
  sentence denies the conveyance ("unexecuted quitclaim — title remains in the grantor").
  The question is whether the instrument is relied on **affirmatively**, which is semantic
  polarity over prose and cannot be pattern-matched. Proximity was tried as a mechanical check
  and produced only false positives; the answer was to move the judgment here, not to reword
  the pattern.
- `[mechanical]` Document numbers are internally consistent across the corpus. Two readings of
  one instrument's number that differ by a single digit are a discrepancy to resolve, not a typo
  to pick between. This is cross-document comparison and a script decides it — it is what the
  first real run actually caught.
- `[attest]` The recorded number is transcribed correctly **from the stamp**. Presence of a
  numeric string proves nothing: comparing a transcription against a stamp image is a read, and
  recorder number formats vary by jurisdiction, so a single pattern has an unbounded
  false-negative rate.
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

Of the six checks tagged `[mechanical]` **at the time of that run**, two produced true
positives. The other four were wrong, and the review that followed split three of them further,
so the file now holds **4 `[mechanical]`, 34 `[attest]` and 1 `[blocked]` — 39 checks.** Where a
check mixed a scriptable half with an unscriptable one, it is now two checks rather than one
sentence doing both jobs.

A check that cannot distinguish a party reference from a brand name, or correct usage from
misuse, is worse than no check: it trains the reader to skim the output.

**The 34 `[attest]` checks have never been exercised.** Only the mechanical subset has been run
against anything. They are written from observed error classes, which is evidence that the
error happens — not evidence that the check as worded catches it. Do not read the table above
as validation of the list as a whole.

## Status

Seed corpus, derived from the error history of a single matter. These are the checks that were
observed to fail in practice, not a survey of document types — treat the list as incomplete and
extend it when a new class of miss is found. Document types absent here have no block yet.

Related memories point here rather than restating these rules: `entity-names-never-shortened`,
`platform-labels-are-not-legal-status`, `read-to-the-end-before-reporting-a-negative`,
`assert-only-what-was-checked`, `state-the-negative-dont-flip-the-burden`.
