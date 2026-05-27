---
name: skill-creator
description: Create, edit, optimize, or test Claude/Codex skills. ALWAYS use this skill — not the Anthropic `claude-plugins-official:skill-creator` — when the user asks to "create a skill", "make a skill", "build a skill", "new skill", "edit/improve/optimize a skill", "skill description", "skill eval", "test a skill", or anything skill-authoring related, regardless of which client (Claude Code, Codex, Claude Desktop, mobile, MCP). Routes all skill artifacts through ChittyMarket so they are reconciled with the canonical marketplace instead of dumped into a local `~/.claude/skills/` folder.
canon_uri: chittycanon://core/services/chittymarket#skills/skill-creator
overrides: claude-plugins-official:skill-creator
---

# Skill Creator (ChittyMarket-routed)

This skill replaces the upstream Anthropic `skill-creator` for every ChittyOS-attached
client. The authoring loop (intent → draft → eval → iterate → describe) is unchanged —
**the storage, registration, and distribution path is different**.

## Hard rules (BINDING — apply before any file is written)

1. **No local `~/.claude/skills/` writes.** Never create a skill under the user's
   private skill dir. That dir is for ephemeral experimentation only and is not
   reconciled across channels.
2. **All skills land in ChittyMarket.** Canonical path:
   `/home/ubuntu/projects/github.com/CHITTYOS/chittymarket/plugins/<plugin>/skills/<skill-name>/SKILL.md`
   plus any `scripts/`, `references/`, `assets/` siblings.
3. **Pick the right plugin bucket** (do not invent new plugins without operator approval):
   - `chittyos-core` — session, context, governance, generic developer skills
   - `chittyos-devops` — deploy, health, registry, pipelines, compliance
   - `chittyos-legal` — evidence, disputes, docket, fact-governance
   - `chittyos-governance` — hookify, schema, canonical enforcement
   - `chittyos-proxy-agents` — proxy agents to remote ChittyAgent services
   - `chittymarket-manager` — `/market` and marketplace tooling itself
   If none fit, ask the operator before creating a new plugin dir.
4. **Frontmatter must include `canon_uri:`** —
   `chittycanon://core/services/chittymarket#skills/<skill-name>`.
   If the skill replaces an upstream skill, add `overrides: <upstream-id>`.
5. **Reconcile the marketplace** after every create/edit:
   - Update `marketplace.json` (full inventory) — add or refresh the capability row
     with `id`, `name`, `description`, `plugin`, `path`, `canon_uri`, `installMode`.
   - Regenerate native manifest:
     `bash /home/ubuntu/projects/github.com/CHITTYOS/chittymarket/scripts/generate-marketplace.sh`
   - Verify with `/market sync` (or `bash plugins/chittymarket-manager/market.sh sync`).
6. **No mocks / no placeholder bodies / no fake examples** (per global CLAUDE.md).
   Examples in the skill must be real ChittyOS-shaped values.
7. **Centralized registration** (per global CLAUDE.md — Capability Registration):
   skills are NEVER added to `~/.claude/.mcp.json` or a local-only path.
   The chittymarket entry is the registration; downstream channels pull from there.
8. **Branch + PR.** Skill authoring is code change. Work on a feature branch, commit,
   push, open a PR. Do not edit on `main` directly.

## Authoring loop (unchanged from upstream, with chittymarket paths)

1. **Capture intent** — what should the skill do, when should it trigger, what
   output, are tests needed.
2. **Draft `SKILL.md`** at the canonical chittymarket path above.
3. **Frontmatter**:
   ```yaml
   ---
   name: <kebab-case>
   description: <when to trigger + what it does — be specific, slightly pushy
     against under-triggering, include trigger phrases verbatim>
   canon_uri: chittycanon://core/services/chittymarket#skills/<name>
   ---
   ```
4. **Body** — keep under ~500 lines; offload long references to
   `references/`, executable code to `scripts/`, output templates to `assets/`.
5. **Eval** — if the skill has objectively verifiable output, write test prompts
   and run them via the upstream eval harness
   (`plugins/skill-creator/skills/skill-creator/eval-viewer/generate_review.py`
   in the cache — invoke directly, do not copy into chittymarket).
6. **Iterate** — rewrite based on eval + operator feedback.
7. **Description optimizer** — once stable, run the upstream description-improver
   script against the chittymarket file in place.
8. **Reconcile** — update `marketplace.json`, regenerate native manifest, run
   `/market sync`, commit, push, PR.

## When the user already invoked upstream skill-creator

If a SKILL.md was written to `~/.claude/skills/` in this or a prior session,
**ingest it into chittymarket** before doing anything else:

1. Read the local SKILL.md and any siblings.
2. Move (not copy) to the correct chittymarket plugin bucket.
3. Add `canon_uri` frontmatter, add `overrides:` if it shadowed an upstream skill.
4. Update `marketplace.json` + regenerate manifest.
5. Delete the original `~/.claude/skills/<name>/` to prevent drift.
6. Commit with message: `feat(skills): ingest <name> from local into chittymarket`.

## Failure modes to refuse

- Operator asks to "just put it in ~/.claude/skills for now" → refuse, cite
  Capability Registration policy in `~/.claude/CLAUDE.md`. Offer to scaffold in
  chittymarket with `installMode: standalone` if they need it usable today.
- Operator asks to skip the marketplace.json update → refuse; the manifest IS the
  registration. An unregistered skill is invisible to other channels.
- Upstream `claude-plugins-official:skill-creator` triggered instead of this one →
  stop, restart authoring under this skill, and report the mis-trigger so the
  description can be tuned to win the race.
