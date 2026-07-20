---
uri: chittycanon://docs/ops/remediation/projection-merge-onset-thornton
namespace: chittycanon://docs/ops
type: remediation
status: PROPOSED
visibility: PUBLIC
owner: chittyos/chittymarket
created: 2026-07-20
---

# Projection Merge: Onset / Thornton

## Decision

Set the onset runtime projection alias for merge into the thornton ChittyMarket projection lane.

This is a canonical projection merge. It is not a direct production registration write and it is not a blind copy of runtime files.

## Merge Rule

ChittyMarket remains the source of truth for marketplace-shipped capabilities:

- skills
- agents
- commands
- hooks
- MCP/tool definitions
- plugin metadata

Runtime folders and portable sync folders are projections. They may be reconciled into ChittyMarket only after classification and evidence-backed promotion.

## Merge Queue

| ID | Status | Action | Target | Completion Evidence |
|---|---|---|---|---|
| OTM-01 | READY | Inventory runtime-projected capabilities under the onset alias | merge worksheet | inventory hash or source manifest |
| OTM-02 | READY | Classify each item as keep, project, merge, local-only, retire, or hold | ChittyMarket capability map | disposition table |
| OTM-03 | READY | Promote mergeable capabilities into canonical ChittyMarket lanes | canonical/ or plugins/ | PR diff and validation results |
| OTM-04 | BLOCKED | Sync promoted capabilities through live ChittyMarket registration routes | ChittyMarket API | issue #70 resolved or equivalent auth/proxy proof |
| OTM-05 | READY_AFTER_OTM-03 | Reduce non-canonical runtime projections to rendered output only | runtime projection layer | post-merge drift report |

## Proof Gates

Do not mark this merge complete until:

1. Every in-scope item has a disposition.
2. All promoted artifacts exist in ChittyMarket canonical/plugin lanes.
3. Validation passes for marketplace manifests and plugin tests.
4. Live registration/sync either succeeds, or the accepted PR explicitly records that repository projection is the current canonical state while the live API remains blocked.

## Current Blocker

Live registration remains blocked by ChittyMarket issue #70. Until that is resolved, repository-backed projection is the available merge path and live API sync remains blocked.
