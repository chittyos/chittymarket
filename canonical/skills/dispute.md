---
name: dispute
canon_uri: chittycanon://core/services/chittymarket#skills/dispute
description: >-
  Issue and dispute management for property, insurance, legal, and financial matters.
  Triggers on: "dispute", "issue", "claim", "damage", "leak", "create dispute",
  "list disputes", "dispute status", "water damage", "insurance claim",
  "property issue", "vendor dispute", "tenant complaint".
  Creates, tracks, and resolves multi-domain disputes via the ChittyDisputes API.
kind: skill
plugin: chittyos-legal
runtimes:
  - claude-code
  - codex
classification:
  - legal
  - evidence
overlay:
  title: Dispute Manager
  capability_group: legal
  execution_class: '@chitty/connectors'
  visibility: recommended
  ontology:
    primary:
    - E
    - T
    secondary:
    - P
    - L
    - A
  authority:
    requires_chittyid: true
    requires_case: true
    write_scope: case-scoped
    no_last_case_fallback: true
    non_repudiation_required: true
    evidence_gate: projection-internal
  execution:
    default_surface: ch1tty
    local_allowed: false
    context_cost: high
    mutation_risk: high
  discovery:
    indexable: true
    session_index: hidden
    ambient_by_intent: false
    verbs:
    - evidence
    - collect
    - docket
    - dispute
    fallback_search: true
  auth_flow:
    mode: existing-session
    stores_credentials_in: ChittyConnect
    fail_closed_if_unavailable: true
    requires_case_id: true
    no_fallback_last_case: true
  phase0_audit:
    job_to_be_done: resolve
    environmental_footprint: write-capable
    evidentiary_risk: legal-grade
    advisory_disposition: legal-only
  canonical_version: 1.0.0
  group_assignment_source: name-rule
  runtime_exclusions:
    openclaw:
    - write_requires_policy_elevation
  legacy_category: legal
---

# Dispute — Issue/Dispute Management

## Overview

Manages multi-domain disputes that can span property management, insurance, legal, financial, and vendor domains simultaneously. A single issue (e.g., water leak at Addison) can touch property damage, insurance claims, vendor remediation, tenant communication, and legal liability all at once.

## API Configuration

| Field | Value |
|-------|-------|
| **Service** | ChittyDisputes |
| **Base URL** | `https://disputes.chitty.cc` |
| **Health** | `GET /health` |
| **Database** | Neon PostgreSQL (ChittyLedger), schema: public |

## Dispute Types

| Type | When to Use |
|------|-------------|
| `PROPERTY` | Physical property damage, maintenance, repairs |
| `INSURANCE` | Insurance claims, coverage disputes, adjuster interactions |
| `LEGAL` | Liability, breach of contract, negligence claims |
| `FINANCIAL` | Billing disputes, payment issues, cost overruns |
| `TENANT` | Tenant complaints, lease violations, move-out disputes |
| `VENDOR` | Contractor/vendor quality, timeline, payment disputes |
| `HOA` | HOA violations, special assessments, board disputes |
| `REGULATORY` | Code violations, permit issues, compliance failures |

## Severity Levels

| Level | Criteria |
|-------|----------|
| `CRITICAL` | Active damage, safety hazard, imminent deadline |
| `HIGH` | Approaching deadline, significant financial exposure |
| `MEDIUM` | Standard priority, no immediate deadline pressure |
| `LOW` | Informational, monitoring only |

## Status Lifecycle

```
INTAKE → OPEN → INVESTIGATING → PENDING → ESCALATED → RESOLVED
                                   ↓                      ↓
                                 CLOSED                  CLOSED
```

## API Endpoints

### Create Dispute
```bash
curl -X POST https://disputes.chitty.cc/api/disputes \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Water leak at 541 W Addison #3S",
    "description": "Upstairs unit water damage to kitchen ceiling...",
    "dispute_type": "PROPERTY",
    "severity": "HIGH",
    "domains": ["PROPERTY", "INSURANCE", "VENDOR"],
    "property_address": "541 W Addison St",
    "property_unit": "3S",
    "reported_by": "nick@aribia.cc",
    "estimated_cost": 5000,
    "next_action_date": "2026-02-25T00:00:00Z",
    "next_action_description": "Get remediation estimate from ServiceMaster",
    "tags": ["water-damage", "addison"]
  }'
```

### List Disputes
```bash
# All open disputes
curl "https://disputes.chitty.cc/api/disputes?status=OPEN"

# Property disputes
curl "https://disputes.chitty.cc/api/disputes?type=PROPERTY"

# By severity
curl "https://disputes.chitty.cc/api/disputes?severity=HIGH"

# By property
curl "https://disputes.chitty.cc/api/disputes?property=Addison"
```

### Get Dispute with Timeline
```bash
curl "https://disputes.chitty.cc/api/disputes/{id}"
```

### Update Dispute
```bash
curl -X PATCH "https://disputes.chitty.cc/api/disputes/{id}" \
  -H "Content-Type: application/json" \
  -d '{
    "status": "INVESTIGATING",
    "assigned_to": "nick@aribia.cc",
    "next_action_date": "2026-02-28T00:00:00Z",
    "next_action_description": "Follow up with State Farm adjuster",
    "updated_by": "claude-session"
  }'
```

### Add Timeline Event
```bash
curl -X POST "https://disputes.chitty.cc/api/disputes/{id}/events" \
  -H "Content-Type: application/json" \
  -d '{
    "event_type": "phone_call",
    "summary": "Called State Farm, claim #SF-2026-12345 opened",
    "details": {"claim_number": "SF-2026-12345", "adjuster": "Jane Smith"},
    "actor": "nick"
  }'
```

### Dashboard Summary
```bash
curl "https://disputes.chitty.cc/api/disputes/summary"
```

## Workflows

### Creating a New Dispute

When the user reports an issue:

1. **Identify the dispute type and domains** — A water leak is `PROPERTY` type but domains might include `['PROPERTY', 'INSURANCE', 'VENDOR']`
2. **Set severity** based on urgency — active damage = `CRITICAL`, deadline approaching = `HIGH`
3. **Create the dispute** via API with all known details
4. **Set next action** — what needs to happen next and by when
5. **Report back** the dispute ID and summary

### Updating an Existing Dispute

1. **List or search** for the dispute
2. **Add timeline events** for any actions taken (calls, emails, documents received)
3. **Update status** as the dispute progresses through the lifecycle
4. **Link documents** by adding to `document_refs` array
5. **Track costs** — update `estimated_cost` and `actual_cost` as quotes come in

### Resolving a Dispute

1. **Set resolution_type** — what resolved it (e.g., "repaired", "settled", "insured")
2. **Add resolution_notes** — summary of resolution
3. **Set status to RESOLVED**
4. **Log final costs** in `actual_cost`

## Domains Array

A dispute's `domains` array tracks which areas it touches. This is key for the Addison water leak example:

```json
{
  "domains": ["PROPERTY", "INSURANCE", "VENDOR"],
  "explanation": "Property damage needs repair (PROPERTY), insurance claim filed (INSURANCE), remediation vendor hired (VENDOR)"
}
```

As the dispute evolves, domains can be added:
- Tenant complains → add `TENANT`
- Liability question arises → add `LEGAL`
- HOA gets involved → add `HOA`

## Event Types

| Type | When |
|------|------|
| `created` | Dispute first created (auto) |
| `status_change` | Status transitions (auto-logged by trigger) |
| `note` | General notes, observations |
| `document_added` | Document attached or referenced |
| `email_received` | Relevant email received |
| `email_sent` | Email sent regarding dispute |
| `phone_call` | Phone call made/received |
| `assignment` | Dispute assigned to someone |
| `escalation` | Escalated to attorney or higher |
| `deadline_set` | New deadline established |
| `cost_update` | Cost estimate or actual cost changed |
| `resolution` | Resolution details recorded |

## Notion Sync

Disputes can be synced to Notion for human visibility. Use the Notion MCP tools to:

1. Create a row in the disputes database with key fields
2. Update the row when status changes
3. Add timeline events as comments or sub-pages

## Important Rules

- **Always set `next_action_date` and `next_action_description`** — disputes without next actions go stale
- **Log every interaction as a timeline event** — phone calls, emails, document receipts
- **Use domains array** to track which areas a dispute touches — this is how we route and prioritize
- **Set deadlines** — response_deadline for when we must respond, resolution_deadline for target resolution
- **Track costs** — estimated_cost when first assessed, actual_cost when invoices arrive
