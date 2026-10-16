---
name: counsel-style-adapter
canon_uri: chittycanon://core/services/chittymarket#skills/counsel-style-adapter
description: >-
  Adapt attorney-facing legal work product to a specifically identified counsel's demonstrated working style without changing governed facts, evidence status, legal authority, or matter boundaries. Use when asked to learn a lawyer's style from pleadings, engagement terms, emails, redlines, comments, or other counsel-authored artifacts; maintain an evolving counsel profile; recut an attorney roadmap, issue brief, filing draft, exhibit packet, chronology, or decision memo for that counsel; or compare a draft against counsel's observed preferences. Requires an explicit matter and counsel identity/profile. Style observations must remain source-linked and matter-scoped.
kind: skill
plugin: chittyos-legal
runtimes:
  - claude-code
  - codex
  - universal
classification:
  - legal
  - counsel
  - drafting
  - strategy
canonical_capability_ref: "chittycanon://capability/legal/counsel-style-adapter"
overlay:
  title: "Counsel Style Adapter"
  capability_group: "legal"
  group_assignment_source: "override"
  execution_class: "@chitty/reasoning"
  canonical_version: "0.1.0"
  projection_version_policy: "inherit-canonical"
  ontology:
    primary: ["P", "A"]
    secondary: ["E", "T"]
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
    context_cost: "medium"
    mutation_risk: "medium"
  discovery:
    indexable: true
    session_index: "hidden"
    ambient_by_intent: false
    verbs: ["adapt", "tailor", "counsel", "style", "redline", "brief"]
    fallback_search: true
  phase0_audit:
    job_to_be_done: "generate"
    environmental_footprint: "forensic-legal-grade"
    evidentiary_risk: "legal-grade"
    advisory_disposition: "legal-only"
  visibility: "recommended"
  access: "readwrite"
  compatible_channels:
    - claude_code
    - claude_ai
    - claude_desktop
    - chatgpt
    - codex
    - openclaw
  source_links:
    - local://canonical/skills/counsel-style-adapter.md
---

# Counsel Style Adapter

Shape legal work product for a specific attorney using source-linked observations of that attorney's demonstrated working style.

## Core boundary

This capability adapts **presentation and workflow**, never truth.

- Do not change governed facts, source status, citations, legal authority, deadlines, or evidentiary posture to match a lawyer's preferences.
- Do not infer case facts from style-source documents.
- Treat a retainer, email, pleading, redline, or oral note as evidence of counsel behavior only to the extent the artifact supports that observation.
- Keep attorney-specific observations matter-scoped unless an explicit cross-matter profile is authorized.
- Never store confidential matter facts in the canonical skill or marketplace metadata.
- Never impersonate counsel or claim a draft was authored, approved, or reviewed by counsel unless that occurred.

## Upstream and downstream composition

Load `legal-operating-defaults`.

Use:
- `review-legal-record` / `fact-governance` for facts and record integrity.
- `evidence-to-filing` for filing materialization.
- this skill only for counsel-specific selection, sequencing, framing, density, tone, and workflow.

Preferred chain:

`governed record -> counsel profile -> counsel-style-adapter -> evidence-to-filing / attorney packet`

## Required inputs

Require:
- explicit matter/case identifier;
- identified counsel or `counsel_profile_id`;
- at least one style source or an existing profile;
- requested output type.

Do not default to the last lawyer discussed.

## Style-source hierarchy

Weight observations roughly in this order:

1. counsel-authored filed briefs/motions/responses;
2. counsel redlines or revisions to drafts;
3. substantive counsel emails/memos;
4. engagement/retainer language showing scope, risk, communication, or control posture;
5. hearing notes or client recollection of oral comments.

Lower tiers may inform hypotheses but should not override repeated direct drafting evidence.

## Observation model

For every profile observation retain:

`ObservationID | Dimension | Observation | Status | Confidence | SourceArtifactID | SourceDate | ExactExcerpt | Location | MatterID | FirstSeen | LastConfirmed | ContraryObservationIDs | Notes`

Statuses:

`OBSERVED | INFERRED | HYPOTHESIS | SUPERSEDED | CONTRADICTED`

Confidence:

`HIGH | MEDIUM | LOW`

Never convert an inference into OBSERVED without a source.

## Default dimensions

Track at minimum:

- issue framing
- procedural sequencing
- argument structure
- treatment of adverse facts
- evidentiary density
- citation/authority style
- contradiction/arithmetic usage
- tone and rhetorical temperature
- preservation/waiver language
- primary vs fallback relief
- client-control expectations
- scope/engagement boundaries
- document length/density
- preferred attorney decision points
- tolerance for unresolved facts
- use of exhibits and record pinpoints
- use of AI / delegation / internal systems when expressly documented

## Evolution rules

- Repeated direct observations raise confidence.
- A later counsel-authored revision may supersede an earlier preference.
- One artifact never establishes a universal rule unless the preference is explicit.
- Preserve contrary observations instead of averaging them away.
- Separate stable style from matter-specific tactics.
- Version the profile; never silently rewrite history.
- Every generated profile must state its evidence base and last-updated date.

## Anchor brief

Maintain a concise `COUNSEL_STYLE_BRIEF` as the first retrieval/input artifact for downstream systems.

It should contain:

1. counsel identity + matter scope;
2. stable high-confidence style rules;
3. medium-confidence tendencies;
4. explicit avoidances;
5. drafting consequences;
6. unresolved style questions;
7. source inventory;
8. profile version/date.

The brief is a **style control document**, not a case-fact source.

## Dynamic memory / retrieval architecture

When a persistent runtime is available, prefer:

- a scoped memory profile keyed by `matter_id + counsel_profile_id` for compact evolving observations;
- persistent agent state for version, open hypotheses, contrary observations, and update checkpoints;
- semantic retrieval over source artifacts for source excerpts and examples;
- metadata filters that enforce matter and counsel isolation before retrieval.

Do not use generated-code sandboxes as the memory store. Sandboxes may transform or compare text, but durable profile state stays in the scoped memory/state layer.

## Progressive references

- When persisting or exchanging a counsel profile, read `references/profile-schema.md`.
- When the user requests a persistent/dynamic Cloudflare implementation, Agent Memory, AI Search, Durable Objects, Agents SDK, or Code Mode, read `references/cloudflare-runtime.md` before designing or provisioning anything.

## Adaptation workflow

1. Load the current `COUNSEL_STYLE_BRIEF`.
2. Retrieve only relevant source examples for the requested artifact.
3. Load governed facts/evidence separately.
4. Draft the legal artifact using the governed record.
5. Apply counsel adaptation only to:
   - selection;
   - ordering;
   - headings;
   - level of detail;
   - treatment of adverse facts;
   - citation density;
   - fallback relief;
   - decision flags;
   - tone.
6. Run a style-conformance pass.
7. Run an evidence-integrity pass after style adaptation.
8. Label the result `COUNSEL-ADAPTED DRAFT`; never `COUNSEL APPROVED` absent actual review.

## Output contract

For profile-building requests, return:

- `COUNSEL_STYLE_BRIEF`
- `STYLE_OBSERVATION_LEDGER`
- `OPEN_STYLE_QUESTIONS`
- `PROFILE_CHANGELOG`

For adaptation requests, return:

- adapted artifact;
- short `STYLE_APPLICATION_NOTE` listing material style choices;
- any conflict where style preference was rejected because evidence/legal requirements controlled.

## Stop conditions

Stop and name the blocker when:
- matter or counsel identity is ambiguous;
- no style source/profile exists;
- a requested style change would distort evidence or legal authority;
- source material is privileged outside the authorized matter;
- the user asks to present AI-generated work as counsel-authored or counsel-approved.

Evidence controls style. Style never controls evidence.
