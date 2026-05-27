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
