---
name: gws-modelarmor
canon_uri: chittycanon://core/services/chittyagent-google#skills/gws-modelarmor
description: |
  Google Model Armor: Filter user-generated content for safety.
kind: skill
classification:
  - integrations
  - google-workspace
runtimes:
  - claude-code
  - codex
plugin: chittyos-gws
canonical_capability_ref: "chittycanon://capability/connect/gws-modelarmor"
overlay:
  title: "GWS Modelarmor"
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
    mutation_risk: "low"
  discovery:
    indexable: true
    session_index: "hidden"
    ambient_by_intent: false
    verbs:
      - "sanitize"
      - "filter"
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

# modelarmor (v1)

> **PREREQUISITE:** Read `../gws-shared/SKILL.md` for auth, global flags, and security rules. If missing, run `gws generate-skills` to create it.

```bash
gws modelarmor <resource> <method> [flags]
```

## Helper Commands

| Command | Description |
|---------|-------------|
| [`+sanitize-prompt`](../gws-modelarmor-sanitize-prompt/SKILL.md) | Sanitize a user prompt through a Model Armor template |
| [`+sanitize-response`](../gws-modelarmor-sanitize-response/SKILL.md) | Sanitize a model response through a Model Armor template |
| [`+create-template`](../gws-modelarmor-create-template/SKILL.md) | Create a new Model Armor template |

## Discovering Commands

Before calling any API method, inspect it:

```bash
# Browse resources and methods
gws modelarmor --help

# Inspect a method's required params, types, and defaults
gws schema modelarmor.<resource>.<method>
```

Use `gws schema` output to build your `--params` and `--json` flags.

