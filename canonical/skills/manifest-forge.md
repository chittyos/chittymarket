---
name: manifest-forge
canon_uri: chittycanon://core/services/chittymarket#skills/manifest-forge
description: Generate, validate, diff, and repair cross-runtime plugin manifests from existing SKILL.md packages for Claude, Codex/OpenAI, Agent Plugins, and ChatGPT skill metadata. Use when a repository or skill package needs compatible manifests, marketplace import repair, or manifest drift detection.
kind: skill
plugin: chittymarket-manager
runtimes:
  - claude-code
  - codex
  - skills-sh
classification:
  - marketplace
  - projection
canonical_capability_ref: "chittycanon://capability/market/manifest-forge"
overlay:
  title: "Manifest Forge"
  capability_group: "market"
  group_assignment_source: "name-rule"
  execution_class: "@chitty/workspace"
  canonical_version: "1.0.0"
  projection_version_policy: "inherit-canonical"
  ontology:
    primary: ["T"]
    secondary: ["A"]
  authority:
    requires_chittyid: false
  execution:
    default_surface: "workspace"
    local_allowed: true
    context_cost: "low"
    mutation_risk: "low"
  discovery:
    indexable: true
    session_index: "hidden"
    ambient_by_intent: true
    verbs: ["generate manifest", "repair manifest", "validate plugin", "marketplace sync"]
    fallback_search: true
  auth_flow:
    mode: "local-only"
    stores_credentials_in: "none"
    fail_closed_if_unavailable: true
  runtime_exclusions: {}
  phase0_audit:
    job_to_be_done: "project"
    environmental_footprint: "local-files"
    evidentiary_risk: "none"
    advisory_disposition: "skill"
  legacy_category: "ecosystem"
  visibility: "recommended"
  access: "readwrite"
  compatible_channels: ["claude_code", "chatgpt", "codex"]
  source_links:
    - local://scripts/manifest-forge.py
---

# Manifest Forge

Use the repository's deterministic `scripts/manifest-forge.py` engine. Treat existing `SKILL.md` frontmatter as source data; do not invent a parallel registry or schema.

## Commands

```bash
python3 scripts/manifest-forge.py generate <package>
python3 scripts/manifest-forge.py validate <package>
python3 scripts/manifest-forge.py diff <package>
python3 scripts/manifest-forge.py repair <package>
```

Add `--marketplace <path>` to `generate` or `repair` to upsert the package into an existing marketplace JSON document. Limit manifest targets with `--targets claude,codex,agent`.

## Workflow

1. Inspect the package before writing. Accept either a root `SKILL.md` or `skills/*/SKILL.md` layout.
2. Run `diff` first when modifying an established package.
3. Run `generate` for new packages or `repair` when generated manifests drift.
4. Run `validate` after generation; non-zero means generated output and committed files differ.
5. Review the diff before committing. Never write secrets, credentials, or runtime tokens into manifests.
6. Preserve repository-native manifests that contain intentional fields not derivable from `SKILL.md`; in those cases, use Manifest Forge as a validator/diff aid rather than blindly overwriting them.

## Generated surfaces

- `.claude-plugin/plugin.json`
- `.codex-plugin/plugin.json`
- `.agent-plugin/plugin.json`
- `agents/openai.yaml` beside each discovered `SKILL.md`
- `skills/<name>/SKILL.md` projection for `npx skills add` / skills.sh discovery when the source skill lives at package root
- optional marketplace entry via `--marketplace`

The engine is deterministic: identical skill frontmatter produces identical generated output.
