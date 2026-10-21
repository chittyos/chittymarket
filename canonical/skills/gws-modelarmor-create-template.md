---
name: gws-modelarmor-create-template
canon_uri: chittycanon://core/services/chittyagent-google#skills/gws-modelarmor-create-template
description: |
  Google Model Armor: Create a new Model Armor template.
kind: skill
classification:
  - integrations
  - google-workspace
runtimes:
  - claude-code
  - codex
plugin: chittyos-gws
canonical_capability_ref: "chittycanon://capability/connect/gws-modelarmor-create-template"
overlay:
  title: "GWS Modelarmor Create Template"
  capability_group: "connect"
  group_assignment_source: "override"
  execution_class: "@chitty/connectors"
  canonical_version: "1.0.0"
  projection_version_policy: "inherit-canonical"
  ontology:
    primary:
      - "P"
    secondary:
      - "E"
      - "T"
  authority:
    requires_chittyid: true
  execution:
    default_surface: "local"
    local_allowed: true
    context_cost: "low"
    mutation_risk: "medium"
  discovery:
    indexable: true
    session_index: "hidden"
    ambient_by_intent: false
    verbs:
      - "create"
      - "template"
    fallback_search: true
  auth_flow:
    mode: "local-only"
    stores_credentials_in: "local gws CLI OAuth token store"
    fail_closed_if_unavailable: false
  runtime_exclusions: {}
  phase0_audit:
    job_to_be_done: "generate"
    environmental_footprint: "write-capable"
    evidentiary_risk: "none"
    advisory_disposition: "skill"
  legacy_category: "ecosystem"
  deprecated_aliases: []
  visibility: "recommended"
  access: "readwrite"
  compatible_channels:
  - claude_code
  - codex
---

# modelarmor +create-template

> **PREREQUISITE:** Read `../gws-shared/SKILL.md` for auth, global flags, and security rules. It ships in the `chittyos-gws` plugin alongside this skill.

Create a new Model Armor template

## Usage

```bash
gws modelarmor +create-template --project <PROJECT> --location <LOCATION> --template-id <ID>
```

## Flags

| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--project` | ✓ | — | GCP project ID |
| `--location` | ✓ | — | GCP location (e.g. us-central1) |
| `--template-id` | ✓ | — | Template ID to create |
| `--preset` | — | — | Use a preset template: jailbreak |
| `--json` | — | — | JSON body for the template configuration (overrides --preset) |

## Examples

```bash
gws modelarmor +create-template --project P --location us-central1 --template-id my-tmpl --preset jailbreak
gws modelarmor +create-template --project P --location us-central1 --template-id my-tmpl --json '{...}'
```

## Tips

- Defaults to the jailbreak preset if neither --preset nor --json is given.
- Use the resulting template name with +sanitize-prompt and +sanitize-response.

> [!CAUTION]
> This is a **write** command — confirm with the user before executing.

## See Also

- [gws-shared](../gws-shared/SKILL.md) — Global flags and auth
- [gws-modelarmor](../gws-modelarmor/SKILL.md) — All filter user-generated content for safety commands
