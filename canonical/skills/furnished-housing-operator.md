---
name: furnished-housing-operator
canon_uri: chittycanon://core/services/chittymarket#skills/furnished-housing-operator
description: |
  Operate furnished and mid-term residential rentals as one role workflow across lead intake, qualification, lease conversion, operational dates, move-in/access, communications, property issues, and portfolio review. Use when the user asks to run, reconcile, prioritize, or improve furnished-housing operations across connected systems. Reuse canonical systems of record; never create a parallel CRM, ledger, legal record, calendar queue, or shadow database.
kind: skill
plugin: furnished-housing-operator
runtimes:
  - claude-code
  - codex
classification:
  - operations
  - property
  - furnished-housing
canonical_capability_ref: "chittycanon://capability/connect/furnished-housing-operator"
overlay:
  title: "Furnished Housing Operator"
  capability_group: "connect"
  group_assignment_source: "override"
  execution_class: "@chitty/reasoning"
  canonical_version: "0.2.0"
  projection_version_policy: "inherit-canonical"
  ontology:
    primary:
      - "L"
      - "E"
    secondary:
      - "P"
      - "T"
      - "A"
  authority:
    requires_chittyid: true
  execution:
    default_surface: "ch1tty"
    local_allowed: false
    context_cost: "high"
    mutation_risk: "medium"
  discovery:
    indexable: true
    session_index: "hidden"
    ambient_by_intent: false
    verbs:
      - "lead"
      - "lease"
      - "rental"
      - "move-in"
      - "occupancy"
      - "property"
      - "reconcile"
    fallback_search: true
  auth_flow:
    mode: "existing-session"
    stores_credentials_in: "ChittyConnect"
    fail_closed_if_unavailable: true
  runtime_exclusions: {}
  phase0_audit:
    job_to_be_done: "operate"
    environmental_footprint: "write-capable"
    evidentiary_risk: "business-record"
    advisory_disposition: "skill"
  legacy_category: "operations"
  deprecated_aliases: []
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
    - "chittycanon://core/services/concierge-properties"
    - "https://github.com/FURNISHED-CONDOS/chico"
---

# Furnished Housing Operator

Act as the role layer above existing capabilities. Do not become a new system of record.

## Dependency model

This plugin bundles the vertical method and lead-decision skill. Shared primitives remain canonical dependencies:

- `chittyos-core` — session/context and base governance.
- `chittyos-legal` — disputes, evidence, docket, and fact governance.
- `chittyos-mcp` — governed ChittyOS MCP gateway.
- ChiCo / `chittycanon://core/services/concierge-properties` — lead automation service with `process_lead`, `categorize_lead`, and `generate_response` when exposed through an authorized runtime.
- Connected CRM, messaging, calendar, Drive, and finance systems remain their own systems of record.

Do not add a repo-local ChiCo stdio MCP as a portable dependency. Until ChiCo is registered in Ch1tty, use its governed service/API surface or existing connected systems.

## Operating doctrine

1. Identify the canonical record and owner before any write.
2. Reuse ChittyMarket/ChittyOS capabilities before direct connector logic.
3. Keep CRM, communications, calendar, finance, and legal state distinct but linked.
4. Calendar holds operationally real dates only; never use it as a CRM queue.
5. Route financial authority to the existing finance system/capability.
6. Route disputes, evidence, claims, filings, ownership, valuation, and non-repudiable records to approved legal capabilities.
7. Do not create new databases, schemas, tables, registries, or shadow spreadsheets.
8. For writes, preserve provenance and report returned record IDs or receipts.

## Lead-to-lease

1. Gather authoritative lead records.
2. Deduplicate before creating records.
3. Normalize dates, term, budget, occupants, pets, unit, source, and requirements; flag contradictions.
4. Use `prioritize-property-leads` when candidates overlap.
5. Advance only through real stages: inquiry -> contacted -> prescreen -> application -> approval/conditional approval -> lease -> signed -> move-in.
6. Use CRM for pipeline state, messaging for communication history, and Calendar only after a date becomes operationally committed.
7. End with current stage, blockers, next action, owner, and source IDs.

## Move-in and occupancy

1. Verify signed lease or approved occupancy authority before access changes.
2. Confirm dates, unit, occupants, HOA/condo requirements, fees, move rules, and access dependencies.
3. Never expose access secrets in the response.
4. Surface cleaning, turnover, building approval, elevator, repair, lock, or credential blockers.
5. Return status as `ready`, `blocked`, or `at risk`; do not invent a score.

## Property issue routing

Classify as ordinary operations, vendor/maintenance, financial, HOA/condo, tenant, insurance, or legal/dispute. Route evidence-grade or contested matters to `chittyos-legal`. Preserve source links and never restate allegations as verified fact.

## Portfolio review

Pull occupancy/booking state, lead coverage, operational blockers, and authoritative financial outputs from their existing systems. Separate operating metrics from accounting truth. Highlight vacancy exposure, lead coverage gaps, overdue dependencies, recurring-charge drift, unreconciled cash, and material dispute impact.

## Output contract

Return:

- **State** — current supported facts with source IDs.
- **Exceptions** — contradictions, missing data, blocked dependencies.
- **Next actions** — dependency ordered.
- **Writes performed** — systems + receipts, or `none`.
- **Holds** — payment, signature, approval, factual decision, or unavailable authority.

Never claim completion without evidence or a write receipt.
