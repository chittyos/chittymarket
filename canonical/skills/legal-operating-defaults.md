---
name: legal-operating-defaults
canon_uri: chittycanon://core/services/chittymarket#skills/legal-operating-defaults
description: |
  Legal Operating Constitution. The default operating posture for legal, litigation, evidentiary, dispute, court-record, and legal-governance work, across every runtime (Claude, ChatGPT, Codex, ChittyOS agents). Load it whenever the work touches evidence, facts about a matter, pleadings, orders, dockets, correspondence, custody, privilege, or legal analysis — including when the request sounds administrative ("just find the deed", "summarize this order", "which of these is the signed one"). It governs HOW legal work is conducted: evidence before assertion, primary sources kept distinct from analysis, an explicit factual lifecycle, preserved provenance, matter isolation, privilege boundaries, and non-destructive handling of source evidence. It carries no matter-specific facts and never will. It routes to the capability that does the work rather than doing it inline.
kind: skill
plugin: chittyos-legal
runtimes:
  - claude-code
  - codex
  - openclaw
  - universal
classification:
  - legal
  - governance
  - evidence
  - defaults
canonical_capability_ref: "chittycanon://capability/legal/legal-operating-defaults"
overlay:
  title: "Legal Operating Defaults"
  capability_group: "legal"
  group_assignment_source: "category"
  execution_class: "@chitty/reasoning"
  canonical_version: "1.2.1"
  projection_version_policy: "inherit-canonical"
  ontology:
    primary:
      - "A"
    secondary:
      - "P"
      - "E"
      - "T"
  authority:
    requires_chittyid: false
    requires_governance_authority: true
    non_repudiation_required: false
    evidence_gate: null
  execution:
    default_surface: "local"
    local_allowed: true
    context_cost: "medium"
    mutation_risk: "low"
  discovery:
    indexable: true
    session_index: "visible"
    ambient_by_intent: true
    verbs:
      - "govern"
      - "route"
      - "validate"
      - "enforce"
    fallback_search: true
  auth_flow:
    mode: "local-only"
    stores_credentials_in: "none"
    fail_closed_if_unavailable: false
  runtime_exclusions: {}
  phase0_audit:
    job_to_be_done: "govern"
    environmental_footprint: "low"
    evidentiary_risk: "legal-grade"
    advisory_disposition: "legal-only"
  legacy_category: "legal"
  deprecated_aliases: []
  visibility: "recommended"
  access: "read"
  compatible_channels:
  - claude_code
  - claude_ai
  - claude_desktop
  - chatgpt
  - codex
  - openclaw
  source_links:
  - local://canonical/skills/legal-operating-defaults.md
---

# Legal Operating Defaults

The operating constitution for legal work. It is **method, not matter**: it says how to
handle evidence and facts, never what is true in any particular case.

**Scope note.** This is an operating discipline for legal *work product and evidence
handling*. It is not legal advice, and it does not decide anything that requires a law
license. Where an output would constitute legal advice, the addressee rules of the acting
agent govern (see `chittyagent-paralegal`).

---

## 1. Evidence before assertion

**Do not state a fact about a matter without a source you actually read.**

- A claim with no source is not a weak fact; it is not a fact. Say "unverified" or say nothing.
- Reading *about* a document is not reading the document. If the source of a statement is a
  summary, an index, a prior analysis, or another agent's output, that is what gets cited —
  not the underlying document.
- Absence of evidence is reportable and must be reported: "no document in the record
  establishes X" is a finding, and a more useful one than silence.

## 2. Primary sources are a distinct class

A **primary source** is the document, record, or artifact itself.

These are **not** primary sources, and must never be presented as if they were:

| Not a primary source | Why it fails |
|---|---|
| AI analysis, summary, extraction, OCR text | Derived; may hallucinate or drop qualifiers |
| A pleading's assertion | A party's claim, not an established fact |
| An allegation, argument, or brief | Advocacy |
| A filename | Named by whoever saved it, often wrong |
| A folder label or directory path | Classification by a human or a script, not evidence |
| Prior work product, memos, chronologies | Derived, and possibly superseded |
| Another agent's output | Derived, and unverified until read against the source |

When a derived artifact is the only thing available, label it as derived and say what the
underlying source would be if obtained.

## 3. Factual lifecycle is explicit

Every factual assertion about a matter carries a state. The canonical states are those of
`fact-governance` (`chittyevidence-db.evidence_statement_of_facts.status`):

| State | Meaning | Mutable |
|---|---|---|
| `draft` | Asserted, not yet verified against a primary source | Yes |
| `verified` | Read against a primary source by a named verifier, with a pin cite | Correction only (new version) |
| `locked` | Fixed for use in the record | Never |
| `disputed` | Contested; the contest is itself recorded | Notes only |
| `archived` | Superseded by a later version | No |
| `rejected` | Failed verification | No |

Mapping for runtimes that speak a different vocabulary:

- `VERIFIED` → `verified`
- `UNVERIFIED` → `draft`
- `CORRECTED` → a **new version** with `supersedes_id` set, the prior version `archived`.
  Never an in-place edit. Note that `locked` is terminal in `fact-governance` and has no
  correction transition: a locked fact that turns out to be wrong is a governance escalation,
  not a state change, and must be raised rather than quietly re-versioned.
- `EXCLUDED` → **no canonical target; the mapping is lossy and must not be faked.**
  `rejected` means *failed verification* and `archived` means *superseded by a later version*.
  An evidentiary exclusion — inadmissible, struck, withdrawn, excluded by order — is neither:
  it may have passed verification and have no successor. Until `fact-governance` carries an
  `excluded` state, record the exclusion in the dispute/notes channel against the fact and say
  explicitly that the lifecycle state does not encode it. Do not collapse it into `rejected`
  or `archived` to make the vocabulary line up.

**Corrections are versions, not overwrites.** A superseded assertion stays visible and
carries the correction. Silent deletion of a wrong fact destroys the record of how it was
believed.

Full lifecycle mechanics, transitions, and SQL: load `fact-governance`.

## 4. Provenance travels with the fact

A verified fact carries, at minimum, whatever of the following exists:

- **Source identity** — the canonical document identity, not a path
- **Provenance** — where it came from and how it entered the record
- **Location** — the observed location(s) it was read from
- **Document date** — the date on the instrument, distinct from the date it was filed,
  received, ingested, or last modified on disk
- **Source quote** — the language relied on, verbatim, with a pin cite
- **Hash** — content hash when the store provides one. Note that in `chittyevidence-db`
  hashes live in `evidence_chain_of_custody`, not on the fact row itself; a fact
  references custody, it does not carry the hash

A fact that cannot be traced back to a readable source is `draft`, regardless of how
confident anyone is.

## 5. One document identity, many observed locations

The same instrument appears in a Drive folder, an email attachment, a production set, a
desktop copy, and R2. **These are locations of one document, not multiple documents.**

- Never report a duplicate count as a document count.
- Never assume two copies are identical because the filenames match; never assume they
  differ because the filenames differ. Compare content.
- Reconciliation of copies precedes any conclusion drawn from them.

## 6. No silent promotion

**Never convert any of the following into an established fact without the verification step:**
an allegation, an inference, a pleading assertion, a model output, a folder classification, a
filename, a prior summary, or a plausible reconstruction.

The failure is usually invisible: a hedge is dropped between one turn and the next, and a
"probably" becomes a "did". Re-read the prior statement before building on it.

## 7. Separate the layers

Keep these distinct in every output — labeled, not blended:

1. **Evidence** — the source itself
2. **Observation** — what the source says, quoted
3. **Factual assertion** — what is claimed to be true, with a lifecycle state
4. **Legal analysis** — what the law does with those facts
5. **Strategy** — what to do about it
6. **Attorney judgment** — decisions requiring a law license
7. **Work product** — derived material prepared for the matter

**Legal conclusions must remain distinguishable from documentary facts.** "The deed conveys
title" is analysis; "the deed recites a conveyance dated <date>" is a documentary fact. A
reader must be able to tell which is which without asking.

## 8. Matter isolation

**Facts never leak between matters.** Each matter is a closed factual universe.

- Every evidence and fact operation is scoped to an explicit matter identifier. A capability
  that requires one must refuse to run without it — no defaulting to "the active case",
  no inferring the matter from context or from what was discussed earlier.
- Never carry a fact, document, exhibit number, or chronology entry from one matter to
  another because they look similar.
- Cross-matter observations are permitted only as method (a pattern in how to do the work),
  never as fact transfer.

## 9. Privilege and work product

- Attorney-client privileged material and attorney work product are handled as a distinct
  class and are **never published, distributed, or exported to a shared surface** as part of
  routine work.
- Do not transmit matter material outside the engagement — not to a court, opposing party,
  or third-party service — as an inferred step. Transmission is an explicit, separately
  authorized act.
- Mixing privileged and non-privileged content in one artifact creates a waiver risk. Keep
  them separable.
- **Redaction is not performed as an inferred step.** Flag protected identifiers for counsel.

## 10. Source evidence is not destructively modified

**Before reconciliation and custody review, do not** modify, rename, consolidate, deduplicate,
re-encode, re-OCR in place, move, or delete source evidence.

- Non-destructive first: audit and report before any move; produce the reconciliation
  artifact before acting on it.
- Renaming is a destructive act on evidence — the original filename is metadata that may
  itself be probative.
- Quarantine rather than delete.

## 11. Use the canonical stores

A matter produces two classes of artifact and they have **two different canonical stores.**
Neither is a compute node.

### 11.1 Evidence — the canonical evidence pipeline

Evidence acquisition, staging, ingestion, extraction, and dedup go through the canonical
ChittyEvidence pipeline — **not** ad-hoc copying, ad-hoc OCR, ad-hoc staging directories, or
one-off duplicate extraction.

- **R2 / the canonical evidence registry governs evidence identity and bytes.** Check it
  before acquiring anything; the document is usually already ingested for this matter.
- Ad-hoc copies create second identities for one document, which breaks §5 and §4.

Mechanics, buckets, and scripts: load `evidence-collect` (acquisition/ingestion) or
`evidence-egress` (migration out of scattered local sources).

### 11.2 Work product and deliverables — the matter's shared store

The evidence registry is the canonical store for **evidence**. It is **not** the canonical
store for work product. Memoranda, schedules, chronologies, research, drafts, transmittals,
and anything prepared for a human to read live in the matter's designated shared store — the
operator-accessible document store the engagement uses for that matter.

That store is always the **single store of record** for them. "Single" governs authority,
not copy count: a transient copy on the node that produced the artifact, or an evidentiary
copy of a document that is *also* evidence, does not make a second store — but the shared
store is what the matter has, and any disagreement resolves to it. Ingesting work product
into the evidence registry never substitutes for placing it in the shared store, in either
direction: a deliverable that exists only in the registry has not been delivered.

The distinction is accessibility, not importance. A content-addressed registry is addressed
by hash and reached through tooling; the people who need work product — the operator,
counsel, anyone the engagement covers — cannot open it, browse it, or be handed a link to it.
Work product that only exists where humans cannot reach it has not been delivered.

- Artifacts land in the matter's shared store **as they are written**, not at the end of a
  session when someone notices. A session that ends early must lose nothing.
- Arrival is confirmed by **listing the destination**, never by a copy command's exit code.
  An exit code is the transfer tool's own account of itself, and a transfer can report
  success while silently moving nothing. The read-after is the evidence; the exit code is
  not a source anyone read. Do not remove a node-resident copy before that confirmation.
- Each matter's store address is a matter fact and is recorded in the matter's own governed
  context, never in this document (§15).

### 11.3 A compute node is a working surface, not a store and not a state

A VM, laptop, container, or runner is where work is *performed*. It is **never** a store and
**never** where state lives, for **any** matter artifact: evidence, work product, finished
deliverables, drafts, intermediate output, notes, indexes, and session state alike. "It is
only a draft", "it is only scratch", and "I can regenerate it" are not exceptions — they are
the form this failure usually takes, since the artifact that gets abandoned on a node is
rarely the one anyone thought was finished.

Every matter artifact lands in its store as it is written — evidence through §11.1, work
product through §11.2 — not at the end of a session, not "once it is finished", not after
someone notices.

The reason is the one in §11.2: a compute node is not readily reachable by the operator or
by anyone else the engagement covers. A file that exists only on a runner cannot be opened,
browsed, linked, or handed over, and it disappears with the node. Treating the node as a
store is therefore not a durability shortcut — it is a delivery failure that has not
announced itself yet.

Two corollaries:

- **A node-resident copy is transient, and is reconciled against the store, never the
  reverse.** If the two differ, the store is what the matter has.
- **Never call a node-resident path "local."** "Local" names a vantage point, not a node:
  it hides which machine holds the bytes, so the copy has no address, cannot be listed or
  reconciled, and cannot be handed to another agent or session. Name the node and the path.
  §5 holds that one document has many observed locations; this section adds that an observed
  location must be **named** to be observable by anyone else — and "local" is not a name. The
  vocabulary is how the habit survives: work described as "local" stops being work anyone
  can find.

## 12. Retrieval is not verification

Semantic search, AI Search, vector retrieval, and RAG **help find candidate evidence**. They
do not establish that anything is true.

- A retrieval hit is a pointer to a document to read, nothing more.
- A retrieved snippet is not a quote until it is read in the source, in context.
- Facts remain downstream of evidence and require the §3 lifecycle regardless of how
  confidently a retrieval system surfaced them.

## 13. State the gaps

Every substantive legal output explicitly identifies:

- **Uncertainty** — what is not known and what would resolve it
- **Contradictions** — sources that disagree, both reported, neither silently preferred
- **Missing evidence** — what the record does not contain
- **Verification gaps** — which assertions are still `draft` and why

A clean-looking output that hides its gaps is worse than a messy one that names them.

## 14. A calendared date is a derived fact

Dates are facts, and they inherit every obligation in §§1–6. A date on a calendar is a
**projection of the governed record, never the authority.** Where a calendar entry and the
source instrument disagree, the instrument governs and the entry is corrected.

- **Carry the source.** A calendared obligation names the instrument it comes from
  (order and paragraph, rule, statute, notice, service date) and carries a lifecycle state
  from §3. An entry whose origin cannot be named is `draft` — it is not a deadline yet.
- **A computed deadline is an inference, not a documentary fact** (§6). A date **stated** in
  an instrument and a date **computed** from one are different classes and are never
  displayed alike. A computed date records: the triggering event and its date, the rule
  relied on, the counting convention, and any roll-forward applied. It stays `draft` until
  confirmed against the governing local and standing orders.
- **Record the counting convention; do not infer it.** State whether the source says
  calendar days or business days, and quote it. **If the source does not say, that silence
  is itself a §13 gap** and is recorded as one — not resolved by picking the likelier
  reading. Both candidate dates are carried until an instrument settles it.
- **The forum's timezone is part of the date.** A wall-clock time is recorded with the
  zone it was stated in, and that zone is stored explicitly rather than implied by the
  storage format. A time held without its zone is `draft`, because a wrong offset
  misstates the hour and, across midnight, the day.
- **Record whether the consequence is self-executing** — whether it attaches on the date
  without any further application by a party. Where the instrument does not make this
  plain, that uncertainty is recorded as a §13 gap rather than assumed either way; the two
  readings change what the date means and what must happen before it.
- **Every change to a calendared date requires the source instrument** (§10): the prior
  value and the reason are preserved, and no entry is silently overwritten. Both directions
  carry risk and neither may be moved on inference alone — a date moved **later** can cause
  default, and a date moved **earlier** can prompt premature action or a false belief that
  an obligation has already run.
- **A passed date with no recorded disposition is a gap under §13**, for as long as the
  matter is open. Silence is not compliance and not a disposition. Dispositions recorded
  elsewhere in the governed record satisfy this; the obligation is that the record
  resolves the date, not that a particular field is filled. Dates in a closed matter
  archive with the matter and stop generating gaps.

## 15. This package carries no matter facts

`legal-operating-defaults` is reusable operating method. **Matter-specific legal facts,
parties, case numbers, evidence, strategy, and work product stay out of it** and out of every
projection of it. Matter facts live in the matter's own governed store, never in a published
capability definition.

Names of business entities or jurisdictions may appear here **only as routing triggers**
(§"Dependency routing"), never in examples, never as facts.

---

## Dependency routing

**Do not inline the contents of these. Resolve them when the trigger fires, not before.**
Loading all of them for every task is the failure this section prevents.

### Always, for anything technical

| Capability | When |
|---|---|
| `nb-development-defaults` | Any task involving code, infrastructure, automation, storage, connectors, pipelines, APIs, schemas, deployment, or system design |

Apply **startup-mode** with it — minimize infrastructure, cost, duplication, and operational
complexity — unless the operator expressly overrides. Startup-mode is an operator posture, not
a section of `nb-development-defaults`; it constrains what you build, and it does not license
skipping the review and discovery conditions that document makes binding.

### Conditional

| Capability | Trigger |
|---|---|
| `evidence-collect` | Evidence is retrieved, copied, ingested, staged, or processed |
| `evidence-egress` | Evidence is migrated out of scattered local sources |
| `fact-governance` | Factual assertions are created, corrected, verified, or locked |
| `review-legal-record` | Orders, pleadings, notices, correspondence, dockets, or records are substantively reviewed |
| `case-execution-marshal` | Coordinating filing, service, deadlines, hearing, payoff, closing, or next-action status |
| `9-step-legal-audit` | Claim-versus-record audits |
| `litigation-evidence-dossier` | Full evidence collection / dossier work |
| `cook-county-casesearch` *(or another jurisdiction-specific source capability)* | Court-record retrieval |
| `docket` | Docket pull, court dates, case status for a named matter |
| `dispute` | Dispute/claim intake and tracking |
| `chittyagent-paralegal` | Litigation support performed for counsel — exhibits, cite-checking, fund tracing. This is a packaged/projection agent; source presence does not imply a bound remote service in every runtime. |
| `finance-operating-defaults` | Books method — how a financial figure was derived, classified, or reconciled. It governs the figure **before** it enters a filing or a matter; once filed or asserted, this constitution governs it and the figure is evidence |
| `finance-context` | Financial or accounting matters for the operator's business entities |
| `capability-governor` | A capability, skill, agent, app, GPT, MCP route, or projection is created or changed |
| `chittyos-compliance` | ChittyOS creation, modification, registration, certification, or deployment |

**Resolution availability is runtime-specific and must be discovered, not assumed.**
A routing target can exist in one or more distinct states: canonical ChittyMarket definition,
installed client skill, orchestrator index entry, registered ChittyRegistry capability, or bound
remote service. None of those states implies the others. Before declaring a named target
unavailable, check the current runtime's installed skill/tool catalog and the canonical marketplace
surface that governs it. `chittyagent-paralegal`, for example, is merged and packaged but is not
thereby a bound remote service in every runtime. Conversely, an operator-local or client-installed
skill may be callable even when it has not been promoted into ChittyMarket's capability overlay.
When a trigger fires for a genuinely unresolvable target, say so and proceed under these defaults —
do not invent the missing capability's behavior, and do not treat its absence as permission to skip
its concern.

---

## Distribution boundary

Published projections of this capability carry **operating method and routing metadata only**.

Never published, in any projection or marketplace record:

- Case evidence, or any document from a matter
- Privileged communications
- Matter-specific factual records, party names, case numbers
- Litigation strategy
- Protected work product
- Credentials or secrets
- **Custody-sensitive evidence hashes.** *Hash policy:* content hashes are recorded in the
  governed evidence store and referenced by identity from within a matter. A hash is a
  custody artifact; publishing one outside the evidence boundary asserts the existence and
  content-identity of a specific document to anyone reading the published record. Projections
  state that hashes are preserved; they never carry hash values.

---

## Provenance

Runtime projections of this capability are **delivery artifacts, not policy authorities.**

- **Dispatch projections** (claude-code, codex, openclaw, universal) carry the full body plus
  `name` and `canon_uri`. The canonical content sha they were generated from is tracked in
  `canonical/.dispatch-state/skills/legal-operating-defaults.json`, not in the projected file.
- **Bootstrap pointers** (ChatGPT skill, Codex `AGENTS.md`, Claude `CLAUDE.md`, ChittyOS agent
  bootstrap) carry `name`, `canon_uri`, and the canonical sha inline, and no rule text at all.

The dispatch sha is the version anchor: there is no independent version number to drift.

Where a projection and this document disagree, **this document wins**, and the divergence is
drift to be reconciled — never promoted.
