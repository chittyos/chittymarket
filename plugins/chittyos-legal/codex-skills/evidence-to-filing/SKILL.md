---
name: evidence-to-filing
description: Convert an explicitly identified legal matter's already-governed evidence and verified facts into an attorney-reviewable filing package. Use when asked to turn a contradiction matrix, verified chronology, citation map, exhibit set, or evidence audit into litigation work product; build exhibit/Bates architecture; prepare a statement of facts, memorandum, motion shell, proposed order, service shell, or e-filing checklist; or make an evidence package filing-ready. Requires a named matter and preserves source-to-fact-to-exhibit traceability. It does not collect evidence, verify new facts, choose disputed legal relief, or silently label a package court-ready.
canon_uri: chittycanon://core/services/chittymarket#skills/evidence-to-filing
---

# Evidence to Filing

Materialize an evidence-governed legal record into a filing package without weakening provenance. This capability is downstream of evidence collection, document intake, fact governance, record review, and legal audit.

## Upstream controls

Load `legal-operating-defaults`. Reuse, rather than duplicate:

- `evidence-collect` for acquisition/ingestion.
- `doctype-checks` for source-document intake checks.
- `fact-governance` for factual lifecycle/corrections.
- `review-legal-record` for record comparison and contradiction identification.
- `9-step-legal-audit` for structured evidence/citation audit.

If a requested filing package depends on a missing upstream step, route there first.

## Matter lock

Require an explicit `matter_id`, `case_id`, or unambiguous registered matter reference. Never default to the most recently discussed matter or infer a matter from file contents.

## Core boundary

This skill **materializes**; it does not establish truth.

- Consume primary-source records and facts already carrying lifecycle status.
- Never promote `draft`, unsupported, inferred, or AI-derived assertions to established facts.
- A pleading allegation proves that the allegation was made, not that its contents are true.
- Keep evidence, observation, factual assertion, legal analysis, strategy, and attorney judgment distinct.
- Never modify canonical source evidence. Bates-stamp and annotate litigation copies only.
- Never transmit or file anything without explicit authorization.

## Workflow

### 1. Lock scope and procedural target

Record:

- matter identifier
- court / jurisdiction
- filing purpose or procedural vehicle, if selected
- source-backed filing deadline/hearing date, if any
- attorney/reviewer, if known
- requested outputs

If relief or procedural vehicle is unresolved, do not silently choose it. Produce an attorney decision memo and neutral shells where useful.

### 2. Build the internal control layer

Normalize a **Master Contradiction Matrix**. Keep it attorney/work-product unless counsel deliberately uses a portion as a demonstrative.

For each material assertion record:

- `ContradictionID`
- source statement / pleading paragraph
- exact quote and pin cite
- atomic proposition
- contrary or qualifying source(s)
- exact quote(s) and pin cite(s)
- fact lifecycle state
- assessment
- evidentiary gap
- proposed litigation use
- candidate exhibits

Allowed assessments:

`SUPPORTED | PARTIALLY_SUPPORTED | CONTRADICTED | MISCHARACTERIZED_OVERBROAD | LEGAL_CONCLUSION | UNRESOLVED_MISSING_SOURCE`

Normalize date, amount, entity, period, and obligation before calling two records contradictory.

### 3. Build the Verified Fact & Citation Ledger

For each proposition eligible for court-facing use retain:

- `FactID`
- neutral statement
- lifecycle status
- canonical `SourceID`
- exact source name
- document date
- exact supporting quote
- pin cite/page/paragraph/timestamp
- provenance location
- authentication route
- `ExhibitID`
- Bates range
- privilege/work-product flag

Only `verified` or `locked` facts may be stated as established facts in the court-facing factual section. A `disputed` fact may be presented only as disputed, preserving both sourced positions.

### 4. Keep source and exhibit identity separate

Use immutable source IDs independently of litigation exhibit numbers.

Example:

`SRC-EMAIL-0042` -> canonical source identity
`Respondent Exhibit 7` -> litigation presentation identity
`R000143-R000149` -> Bates range on the litigation copy

Court-facing citations use exhibit + Bates. The internal ledger preserves the route to the canonical source. A hyperlink is never the only evidentiary reference.

### 5. Curate, do not dump

Select the smallest set of propositions and exhibits necessary for the procedural purpose.

Default **attorney-only** package:

1. attorney roadmap
2. master contradiction matrix
3. verified fact & citation ledger
4. verified chronology
5. source/foundation gaps
6. privilege/work-product segregation notes

Default **court-facing** package, when appropriate:

1. motion/petition/response shell for the selected vehicle
2. memorandum or verified statement if procedurally appropriate
3. concise statement of material facts or chronology
4. exhibit index
5. exhibit cover sheets + litigation copies
6. proposed order
7. proof/certificate of service shell when applicable
8. jurisdiction-specific e-filing checklist

Do not file internal control artifacts merely because they exist.

### 6. Build conventional citations

Every material factual sentence in a court-facing draft must resolve to an exhibit/pin cite, e.g. `Resp. Ex. 3 at R0047-R0048.`

Run both directions:

- every material proposition has a citation or is labeled allegation/argument;
- every cited exhibit actually supports the proposition for which it is cited.

### 7. Build exhibits non-destructively

For each selected exhibit:

- identify the canonical source
- create/use a litigation copy
- preserve original filename/source metadata internally
- add cover sheet only to the litigation copy
- apply sequential Bates numbering only to the litigation copy
- OCR litigation copies when necessary without overwriting the source
- record page count/Bates range
- record authentication route and foundation issue

Do not reorder source pages unless a derivative compilation is required and clearly labeled.

### 8. Verify current filing rules

Before any `FILING_READY_CANDIDATE` status, verify current rules from authoritative court sources. Check at minimum:

- accepted PDF/document format
- page size/margins/font/legibility
- file and envelope size limits
- exhibit handling
- confidentiality/redaction
- signatures
- service
- proposed-order procedure
- e-filing naming/document codes

Record rule source and verification date. If current rules cannot be verified, status cannot exceed `ATTORNEY_REVIEW`.

### 9. Run packet QA

At minimum verify:

- no dangling FactIDs, SourceIDs, ExhibitIDs, or Bates cites
- every Bates pinpoint lies inside the cited exhibit range
- no unresolved source gap is disguised as a fact
- no legal conclusion is presented as documentary fact
- no privileged/work-product source is court-facing without an explicit attorney decision
- all court-facing copies derive from known canonical sources
- every required filing component is present or marked not applicable

### 10. Assign readiness honestly

Use only:

- `DRAFT` — structural/source/procedural gaps remain.
- `ATTORNEY_REVIEW` — source mapping supports counsel review; legal/procedural decisions remain.
- `FILING_READY_CANDIDATE` — current filing rules verified, court-facing facts governed, required artifacts present, and attorney review recorded. This is not a guarantee of clerk/judicial acceptance.
- `FILED` — only after a filing receipt/transaction record exists.

Never state “accepted by the court” without an acceptance receipt.

## Output contract

At minimum produce:

- `00_ATTORNEY_ROADMAP`
- `01_MASTER_CONTRADICTION_MATRIX`
- `02_VERIFIED_FACT_CITATION_LEDGER`
- `03_VERIFIED_CHRONOLOGY`
- `04_EXHIBIT_INDEX`
- court-facing draft components appropriate to the selected vehicle
- `PACKET_MANIFEST`
- `QA_REPORT`

### Contradiction matrix columns

`ContradictionID | Topic | SourceStatementID | SourceStatementLocation | StatementA | QuoteA | SourceAID | SourceADate | StatementB | QuoteB | SourceBID | SourceBDate | AtomicConflict | Assessment | FactStatusA | FactStatusB | EvidentiaryGap | ProposedUse | CandidateExhibits | AttorneyReview`

### Fact/citation ledger columns

`FactID | Statement | LifecycleStatus | SourceID | SourceDocument | DocumentDate | ExactQuote | PinCite | ObservedLocation | AuthenticationRoute | ExhibitID | BatesRange | PrivilegeFlag | CourtFacingEligible | Notes`

### Exhibit index columns

`ExhibitID | SourceID | ExactDocumentName | DocumentDate | BatesRange | PropositionsProved | AuthenticationRoute | FoundationIssue | CourtFacing`

### Packet manifest minimum fields

`matter_id | court | jurisdiction | procedural_vehicle | packet_status | local_rules_verified | local_rules_verified_at | local_rule_sources | attorney_reviewed | attorney_reviewer | artifacts | exhibits | citations | blockers`

For each exhibit record at minimum:

`exhibit_id | source_id | source_name | source_status | bates_start | bates_end | authentication_route | court_facing | privileged_or_work_product`

For each citation record at minimum:

`citation_id | fact_id | exhibit_id | bates_start | bates_end | pinpoint`

`FILING_READY_CANDIDATE` is prohibited unless local rules are verified, attorney review is recorded, there are no blocking items, all court-facing source propositions are governed, every citation resolves, and every Bates pinpoint falls within its exhibit range.

## Stop conditions

Stop at `DRAFT` or `ATTORNEY_REVIEW` and name the blocker when:

- the matter is not explicit
- a material proposition lacks primary source/pin cite
- the governing fact is only `draft`
- source identity is ambiguous
- privilege/work-product status is unresolved
- exhibit authentication/foundation is materially uncertain
- requested relief requires attorney selection
- current filing rules cannot be verified
- the packet would require modifying source evidence

Do not solve a source defect by stronger prose.