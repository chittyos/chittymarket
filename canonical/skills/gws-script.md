---
name: gws-script
canon_uri: chittycanon://core/services/chittyagent-google#skills/gws-script
description: |
  Manage Google Apps Script projects.
kind: skill
classification:
  - integrations
  - google-workspace
runtimes:
  - claude-code
  - codex
plugin: chittyos-gws
canonical_capability_ref: "chittycanon://capability/connect/gws-script"
overlay:
  title: "GWS Script"
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
      - "manage"
      - "run"
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

# script (v1)

> **PREREQUISITE:** Read `../gws-shared/SKILL.md` for auth, global flags, and security rules. It ships in the `chittyos-gws` plugin alongside this skill.

```bash
gws script <resource> <method> [flags]
```

## Helper Commands

| Command | Description |
|---------|-------------|
| [`+push`](../gws-script-push/SKILL.md) | Upload local files to an Apps Script project |

## API Resources

### processes

  - `list` — List information about processes made by or on behalf of a user, such as process type and current status.
  - `listScriptProcesses` — List information about a script's executed processes, such as process type and current status.

### projects

  - `create` — Creates a new, empty script project with no script files and a base manifest file.
  - `get` — Gets a script project's metadata.
  - `getContent` — Gets the content of the script project, including the code source and metadata for each script file.
  - `getMetrics` — Get metrics data for scripts, such as number of executions and active users.
  - `updateContent` — Updates the content of the specified script project. This content is stored as the HEAD version, and is used when the script is executed as a trigger, in the script editor, in add-on preview mode, or as a web app or Apps Script API in development mode. This clears all the existing files in the project.
  - `deployments` — Operations on the 'deployments' resource
  - `versions` — Operations on the 'versions' resource

### scripts

  - `run` — 

## Discovering Commands

Before calling any API method, inspect it:

```bash
# Browse resources and methods
gws script --help

# Inspect a method's required params, types, and defaults
gws schema script.<resource>.<method>
```

Use `gws schema` output to build your `--params` and `--json` flags.

