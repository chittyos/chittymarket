# Counsel Profile Schema

Use this reference when persisting or exchanging counsel-style state.

## Profile key

`matter_id + counsel_profile_id`

Do not use counsel name alone as the key.

## Counsel profile

```yaml
profile_version: 0.1.0
matter_id:
counsel_profile_id:
counsel_name:
scope: matter-only
last_updated:
anchor_brief_source:
source_artifact_ids: []
stable_rules: []
tendencies: []
avoidances: []
open_questions: []
```

## Observation

```yaml
observation_id:
dimension:
observation:
status: OBSERVED|INFERRED|HYPOTHESIS|SUPERSEDED|CONTRADICTED
confidence: HIGH|MEDIUM|LOW
source_artifact_id:
source_date:
exact_excerpt:
location:
matter_id:
first_seen:
last_confirmed:
contrary_observation_ids: []
notes:
```

## Retrieval metadata

Use metadata that permits pre-retrieval isolation:

```yaml
matter_id:
counsel_profile_id:
artifact_type: pleading|redline|email|retainer|memo|hearing-note|other
authorship: counsel-authored|counsel-edited|third-party|client-note
style_eligible: true|false
source_date:
```

Never index an artifact into a counsel-style corpus merely because counsel received it.
