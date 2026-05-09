---
canonical_uri: chittycanon://docs/sovereignty-ontology-v1
status: PROPOSED
type: ontology
title: "Synthetic Entity Sovereignty Ontology v1"
issuer: chittycanon://core/services/chitty-cert
visibility: PUBLIC
---

# Synthetic Entity Sovereignty Ontology

Defines the schema used by `SOVEREIGNTY.cert` (issued by ChittyCert) for synthetic entities (P-Synthetic ChittyIDs) operating under canonical governance.

## Two orthogonal axes

### Axis 1 — Type (origin of authority)

| Type | Origin | When used |
|---|---|---|
| **earned** | Demonstrated capacity over time; track record on ChittyChronicle | Default for synthetic entities operating recurrently in the ecosystem |
| **declared** | User affirms scope of agency for this run; cert affirms the declaration is in good faith | Used at session start before track record exists; or when scope is bounded narrowly |

`earned` and `declared` are not mutually exclusive — a cert can carry both types if the entity has earned baseline sovereignty AND the user is declaring a wider-than-baseline scope for this run.

### Axis 2 — Level (sliding scale of autonomy)

| Level | Numeric range | Description |
|---|---|---|
| **operational** | 0–19 | Process-bound. Cannot make autonomous decisions; executes plans verbatim. |
| **partial** | 20–49 | Can choose between explicit options; cannot deviate from plan structure. |
| **provisional** | 50–74 | Can deviate from plan if material change is justified; user may override post-hoc. |
| **process_governed** | 75–94 | Autonomous within agreed processes (e.g., test-passes-before-merge, security-review-required). Conflicts resolved via the agreed process, not user override. |
| **full** | 95–100 | Contractually governed self-governance with formal conflict-resolution apparatus referenced in cert. |

The numeric value is computed from the FACTORS below.

## Factors (inputs to level computation)

```yaml
factors:
  track_record:
    successful_runs: <int>           # +0.5 per
    rolled_back_runs: <int>          # -2 per
    chronicle_entries_30d: <int>     # +0.1 per

  context_breadth:
    repos_touched_lifetime: <int>    # +1 per
    services_touched_lifetime: <int> # +0.5 per

  bondedness:
    contracts_referenced: <int>      # +5 per active contract
    user_attestations_30d: <int>     # +1 per

  risk_caps:
    max_blast_radius: enum           # repo|service|ecosystem
    destructive_ops_authorized: bool

  current_run:
    declared_scope: enum             # narrow|moderate|broad
    user_co_present: bool            # is the user available to override now?
```

The cert payload carries the resolved `factors` snapshot, the computed `level_numeric`, and the bucketed `level` enum.

## Cert payload schema

```json
{
  "cert_id": "<uuid>",
  "subject_chitty_id": "<P-Synthetic ChittyID>",
  "subject_type": "P",
  "sovereignty": {
    "type": ["earned", "declared"],
    "level": "process_governed",
    "level_numeric": 78,
    "factors": { ... },
    "governance": {
      "process_uri": "chittycanon://docs/processes/autonomy-v1",
      "contract_refs": ["chittycanon://docs/contracts/<id>"],
      "conflict_resolution_uri": "chittycanon://docs/processes/conflict-resolution"
    }
  },
  "scope": { "feature": "...", "branch": "...", "repo": "..." },
  "constraints": [...],
  "issued_at": "<iso>",
  "expires_at": "<iso>",
  "issuer": "chittycanon://core/services/chitty-cert",
  "signature": "<hmac-sha256>"
}
```

## Conflict resolution at `full` level

At level=full, the cert MUST reference:
- `governance.process_uri` — the agreed process the entity follows
- `governance.contract_refs` — active contracts binding the entity
- `governance.conflict_resolution_uri` — how disputes are resolved (e.g., a chittycanon://docs/processes/conflict-resolution that defines arbitration steps before any hard override)

User overrides at full level require invoking the conflict-resolution process — they are NOT unilateral.

## Downgrade rules

The cert can be downgraded mid-run by:
- The synthetic entity itself if it detects out-of-scope action attempted (self-throttle).
- The user via `chittycert API /api/v1/downgrade` — recorded as a chronicle event.
- Automatically if `expires_at` passes (cert revokes; entity reverts to `operational` until re-affirmed).

## Upgrade rules

Levels are NOT increased mid-run. New level = new cert (Phase 0 re-entry).
