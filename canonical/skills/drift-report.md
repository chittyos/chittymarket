---
name: drift-report
canon_uri: chittycanon://core/services/chittymarket#skills/drift-report
description: Report on version drift
kind: skill
classification:
  - report
runtimes: []
plugin: chittyos-core
---

# Version Drift Report

Based on the capability inventory, here are the top 5 cases of version drift across runtimes:

| Skill Name | Canonical Lines | Wildest Version Lines | Location of Wildest | Recommended Action |
| --- | --- | --- | --- | --- |
| `neon-postgres` | 0 (not in canonical yet) | 376 | `~/.agents/skills/neon-postgres/SKILL.md` | Promote to canonical, run dispatch hook to sync to 376 lines across runtimes (Codex currently has 186). |
| `claimable-postgres` | 0 (not in canonical yet) | 249 | `~/.gemini/config/skills/claimable-postgres/SKILL.md` | Promote to canonical, run dispatch hook to sync across runtimes (Codex has 224). |
| `skill-creator` | 41 (stub) | 480 | `~/.gemini/skills/skill-creator/SKILL.md` | Update canonical to the full projection (completed in this PR), which overrides the 30-line stubs. |
| `chitty-registry` | 132 | 132 | `~/.gemini/config/skills/chitty-registry/SKILL.md` | The `chittyos-devops` plugin version only has 94 lines. Reconcile latest 132-line version to canonical and dispatch. |
| `chitty-deploy` | 0 (Wait, is it in canonical?) | 81 | `~/.gemini/config/plugins/chittyos-devops/skills/chitty-deploy/SKILL.md` | Promote 81-line version to canonical, run dispatch to overwrite the 77-line versions. |
