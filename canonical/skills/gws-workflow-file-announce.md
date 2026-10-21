---
name: gws-workflow-file-announce
canon_uri: chittycanon://core/services/chittyagent-google#skills/gws-workflow-file-announce
description: |
  Google Workflow: Announce a Drive file in a Chat space.
kind: skill
classification:
  - integrations
  - google-workspace
runtimes:
  - claude-code
  - codex
plugin: chittyos-gws
canonical_capability_ref: "chittycanon://capability/connect/gws-workflow-file-announce"
overlay:
  title: "GWS Workflow File Announce"
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
      - "announce"
      - "share"
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

# workflow +file-announce

> **PREREQUISITE:** Read `../gws-shared/SKILL.md` for auth, global flags, and security rules. If missing, run `gws generate-skills` to create it.

Announce a Drive file in a Chat space

## Usage

```bash
gws workflow +file-announce --file-id <ID> --space <SPACE>
```

## Flags

| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--file-id` | ✓ | — | Drive file ID to announce |
| `--space` | ✓ | — | Chat space name (e.g. spaces/SPACE_ID) |
| `--message` | — | — | Custom announcement message |
| `--format` | — | — | Output format: json (default), table, yaml, csv |

## Examples

```bash
gws workflow +file-announce --file-id FILE_ID --space spaces/ABC123
gws workflow +file-announce --file-id FILE_ID --space spaces/ABC123 --message 'Check this out!'
```

## Tips

- This is a write command — sends a Chat message.
- Use `gws drive +upload` first to upload the file, then announce it here.
- Fetches the file name from Drive to build the announcement.

## See Also

- [gws-shared](../gws-shared/SKILL.md) — Global flags and auth
- [gws-workflow](../gws-workflow/SKILL.md) — All cross-service productivity workflows commands
