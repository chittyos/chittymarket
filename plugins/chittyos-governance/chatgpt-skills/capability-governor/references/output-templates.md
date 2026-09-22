# Output Templates

## Capability taxonomy entry

```json
{
  "canonical_id": "capability.slug",
  "display_name": "Human Name",
  "job_to_be_done": "verify | collect | route | generate | govern | operate | resolve | remember",
  "entity_anchors": ["person", "location", "thing", "event", "action", "record"],
  "source_of_truth": "repo/file/manifest/url",
  "allowed_projections": ["skill", "gateway", "local-cli", "legal-space"],
  "restricted_projections": [],
  "owner": "unknown",
  "status": "draft | active | deprecated | retired | hold"
}
```

## Decision log

```json
{
  "decision_id": "dec_yyyymmdd_slug",
  "date": "YYYY-MM-DD",
  "capability_name": "",
  "canonical_id": "",
  "source_links": [],
  "current_state": "",
  "decision": "keep | promote | project | merge | gateway | skill | local-only | legal-only | retire | hold",
  "job_to_be_done": "",
  "environmental_footprint": "",
  "evidentiary_risk": "",
  "rationale": "",
  "duplicates_found": [],
  "migration_required": false,
  "migration_owner": "",
  "next_action": "",
  "review_date": "YYYY-MM-DD"
}
```

## Migration queue item

```json
{
  "migration_item": "mig_yyyymmdd_slug",
  "from_artifact": "",
  "to_canonical_capability": "",
  "action": "merge | rename | reroute | retire | document | restrict",
  "blocking_dependencies": [],
  "risk_level": "low | medium | high | legal-grade",
  "owner": "",
  "status": "backlog | active | blocked | done",
  "completion_evidence": []
}
```

## Retirement record

```json
{
  "retired_artifact": "",
  "replacement_capability": "",
  "reason": "duplicate | obsolete | unsafe | ownerless | superseded",
  "source_links": [],
  "effective_date": "YYYY-MM-DD",
  "rollback_path": ""
}
```
