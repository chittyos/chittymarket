---
name: stripe
canon_uri: chittycanon://core/services/chittymarket#mcp/stripe
description: Stripe Billing — charges, customers, invoices, subscriptions via the ch1tty-managed Stripe MCP server
kind: mcp-server
plugin: chittyos-mcp
runtimes: []
classification:
- billing
- payments
- finance
canonical_capability_ref: chittycanon://capability/connect/stripe
overlay:
  title: Stripe Billing
  capability_group: connect
  group_assignment_source: override
  execution_class: "@chitty/connectors"
  canonical_version: 1.0.0
  ontology:
    primary:
    - E
    - T
    secondary:
    - P
    - A
  authority:
    requires_chittyid: true
  execution:
    default_surface: ch1tty
    local_allowed: false
    context_cost: medium
    mutation_risk: high
  discovery:
    indexable: false
    session_index: hidden
    ambient_by_intent: false
    verbs:
    - query
    - search
    - operate
    fallback_search: true
  auth_flow:
    mode: service-token
    stores_credentials_in: ChittyConnect
    fail_closed_if_unavailable: true
  phase0_audit:
    job_to_be_done: operate
    environmental_footprint: write-capable
    evidentiary_risk: medium
    advisory_disposition: gateway
  visibility: advanced
  legacy_category: ecosystem
  access: readwrite
  compatible_channels:
  - claude_code
  runtime_exclusions:
    claude_ai:
    - write_requires_policy_elevation
    chatgpt:
    - write_requires_policy_elevation
    claude_desktop:
    - write_requires_policy_elevation
    codex:
    - write_requires_policy_elevation
    openclaw:
    - write_requires_policy_elevation
  source_links:
  - local://canonical/mcp/stripe.md
  - ch1tty://servers.json#stripe
---

# Stripe Billing

Canonical record for the ch1tty-managed Stripe MCP server (`servers.json` id `stripe`).
It exists so the live, readwrite, enabled server has a governance record. Before this
entry it had none.

- **Source of truth for the server definition:** ch1tty `servers.json`. This record
  carries no `mcp:` block and `runtimes: []`, so dispatch projects nothing. The `plugin:`
  field is a dispatch requirement only; the server is not packaged in that plugin.
- **Writes are operator-gated.** `mutation_risk: high`. Production financial writes
  follow `finance-operating-defaults`. A Stripe record filed in a matter hands off to
  `legal-operating-defaults`.
- **Credentials** route through ChittyConnect. Fails closed with
  `POLICY_BLOCKED_CHITTYCONNECT_UNAVAILABLE`.
- **Channels:** `claude_code` only until the write tools are assessed.

## Not registered here

- `stripe@claude-plugins-official` (hosted `https://mcp.stripe.com`, browser OAuth, no
  ChittyConnect credential path). Not projected. See
  `docs/decisions/capability-audit-log.md`.
- The claude.ai Stripe connector (`mcp__claude_ai_Stripe__*`). Same reason.
