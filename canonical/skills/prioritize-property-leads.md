---
name: prioritize-property-leads
canon_uri: chittycanon://core/services/chittymarket#skills/prioritize-property-leads
description: |
  Rank furnished, mid-term, and conventional rental leads using evidence-controlled status reconciliation, overlapping-date analysis, conversion likelihood, lease economics, turnover constraints, and seasonal vacancy exposure. Use when comparing applicants or inquiries, reconciling lead messages, or deciding which candidate should receive the next reversible action. Keep conversion priority separate from economic/operational priority and never use protected characteristics.
kind: skill
plugin: furnished-housing-operator
runtimes:
  - claude-code
  - codex
classification:
  - operations
  - property
  - leasing
canonical_capability_ref: "chittycanon://capability/connect/prioritize-property-leads"
overlay:
  title: "Prioritize Property Leads"
  capability_group: "connect"
  group_assignment_source: "override"
  execution_class: "@chitty/reasoning"
  canonical_version: "1.0.0"
  projection_version_policy: "inherit-canonical"
  ontology:
    primary:
      - "P"
      - "E"
    secondary:
      - "L"
      - "T"
      - "A"
  authority:
    requires_chittyid: true
  execution:
    default_surface: "ch1tty"
    local_allowed: false
    context_cost: "high"
    mutation_risk: "low"
  discovery:
    indexable: true
    session_index: "hidden"
    ambient_by_intent: false
    verbs:
      - "compare"
      - "rank"
      - "lead"
      - "lease"
      - "availability"
    fallback_search: true
  auth_flow:
    mode: "existing-session"
    stores_credentials_in: "ChittyConnect"
    fail_closed_if_unavailable: true
  runtime_exclusions: {}
  phase0_audit:
    job_to_be_done: "decide"
    environmental_footprint: "read-only"
    evidentiary_risk: "business-record"
    advisory_disposition: "skill"
  legacy_category: "operations"
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
    - "local://plugins/furnished-housing-operator/skills/prioritize-property-leads/SKILL.md"
---

# Prioritize Property Leads

Produce a defensible lead order without confusing engagement with economics or stale inquiries with active candidates.

## Workflow

1. Identify the exact property and controlling availability evidence.
2. Consolidate notifications by person and platform channel.
3. Read the latest substantive message for every candidate.
4. Treat withdrawals, declines, signed agreements, and superseding communications as controlling.
5. Normalize each active lead: source, dates, term, budget/rate, occupants, pets, parking/access, payment source, screening/application/lease state, latest message, vacancy exposure, turnover dependencies, and source IDs.
6. Classify status: `area-match`, `direct-inquiry`, `active-negotiation`, `qualified`, `contracted`, `closed`, or `stale`.
7. Evaluate conversion priority separately from economic/operational priority.
8. Apply vacancy/seasonality only after exact dates are established.
9. State the ordering basis, conditions, conflicts, and next reversible action.

## Two axes

**Conversion:** direct engagement, recency, responsiveness, material-term alignment, screening/payment/lease readiness, and remaining uncertainty.

**Economic/operational:** probability-weighted revenue, term, vacancy before/after, re-leasing seasonality, turnover burden, temporary accommodation, pets, parking, access, cleaning, and building constraints.

Never call a lead simply “preferred” without naming the axis. Do not use protected characteristics or proxies.

## Evidence rules

- Do not rank from an initial inquiry without checking later messages.
- A platform match is not a direct inquiry, application, reservation, or property selection.
- A displayed monthly rate is not a complete offer.
- Acceptance-like wording is not a booking unless the accepted terms are recoverable.
- Executed leases, signed terminations, possession dates, and turnover constraints control over listing calendars.
- Keep verified facts, market heuristics, and inference visibly separate.

Read `references/decision-rules.md` when seasonality, temporary accommodation, or overlapping dates materially affect the decision.

## Output

Return active leads, closed/stale leads when material, conversion order, economic/operational order, calendar conflicts/vacancy windows, conditions that could change the order, and exact source identifiers when available. Do not send outreach or change external records without explicit approval.
