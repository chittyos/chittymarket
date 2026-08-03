---
name: skill-creator
canon_uri: chittycanon://core/services/chittymarket#skills/skill-creator
description: Create, edit, optimize, or test Claude/Codex skills. ALWAYS use this skill — not the Anthropic `claude-plugins-official:skill-creator` — when the user asks to "create a skill", "make a skill", "build a skill", "new skill", "edit/improve/optimize a skill", "skill description", "skill eval", "test a skill", or anything skill-authoring related, regardless of which client (Claude Code, Codex, Claude Desktop, mobile, MCP). Routes all skill artifacts through ChittyMarket so they are reconciled with the canonical marketplace instead of dumped into a local `~/.claude/skills/` folder.
kind: skill
classification:
  - ecosystem
  - governance
  - skill-authoring
runtimes:
  - claude-code
  - codex

plugin: chittyos-core
overrides: claude-plugins-official:skill-creator
overlay:
  title: Skill Creator (ChittyMarket-routed)
  capability_group: build
  execution_class: '@chitty/ambient'
  visibility: recommended
  ontology:
    primary:
    - T
    secondary:
    - E
    - A
  authority:
    requires_chittyid: true
  execution:
    default_surface: ch1tty
    local_allowed: true
    context_cost: medium
    mutation_risk: high
  discovery:
    indexable: true
    session_index: summary
    ambient_by_intent: true
    verbs:
    - create skill
    - author skill
    - skill-creator
    fallback_search: true
  auth_flow:
    mode: local-only
    stores_credentials_in: n/a
    fail_closed_if_unavailable: false
  phase0_audit:
    job_to_be_done: create
    environmental_footprint: write-capable
    evidentiary_risk: none
    advisory_disposition: skill
  canonical_version: 1.0.0
  group_assignment_source: name-rule
  runtime_exclusions: {}
  legacy_category: ecosystem
---

# Skill Creator (ChittyMarket-routed)

Canonical entry for the chittymarket-routed skill-creator overlay. The full
projection lives at `plugins/chittyos-core/skills/skill-creator/SKILL.md`.

## Hard rules (BINDING)

1. No local `~/.claude/skills/` writes — chittymarket is the source of truth.
2. Canonical path: `plugins/<plugin>/skills/<skill-name>/SKILL.md` + siblings.
3. Frontmatter must include `canon_uri:`; `overrides:` if shadowing an upstream skill.
4. Reconcile marketplace.json + regenerate native manifest after every create/edit.
5. No mocks, no placeholder bodies, no fake examples (per global CLAUDE.md).
6. Centralized registration — never add to local `.mcp.json`.
7. Branch + PR for all skill authoring.

## Ingest path

If a SKILL.md was written to `~/.claude/skills/` in a prior session, ingest it
into chittymarket: read, move to the correct plugin bucket, add canonical
frontmatter, update marketplace.json, delete the local original.

See the full projection for the complete authoring loop, refusal modes, and
canonical-path enforcement.
