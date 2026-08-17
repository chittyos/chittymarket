---
name: chitty-autonomy-tidy
description: Phase 7 — Auto-tidy. Runs format/lint sweep, branch cleanup (gone-tracking branches removed), invokes chitty-cleanup for local machine, runs wrangler-audit if Workers were touched, removes dead code per silent-failure-hunter findings.
canonical_uri: chittycanon://skills/chitty-autonomy-tidy
status: DRAFT
---

# Phase 7: Tidy

## Process

1. Verify cert valid.
2. **Format/lint sweep** — repo-wide:
   - `npm run format` / `prettier --write .` (JS/TS)
   - `npm run lint -- --fix` / `eslint --fix .`
   - language-appropriate equivalents (`go fmt ./...`, `cargo fmt`, `ruff check --fix`, etc.)
3. **Branch cleanup** — invoke `commit-commands:clean_gone` skill (removes branches marked `[gone]` after upstream deletion).
4. **Local machine cleanup** — invoke `chitty-cleanup` skill (clears regenerable caches; respects user'\''s prior preferences).
5. **Wrangler audit** — if `wrangler.toml` / `wrangler.jsonc` files were touched, invoke `wrangler-audit` skill (consistency, stale compatibility dates, missing tail consumers, binding gaps).
6. **Dead-code sweep** — re-run `feature-dev:code-reviewer` confidence-filtered to `silent-failure-hunter` patterns; surface findings.
7. **Memory hygiene** — drop session-temporary memories; verify project memories are still relevant.
8. Emit ChittyChronicle entry.

## Constraints

- Format/lint changes that aren'\''t auto-applicable should be surfaced as review issues, not blanket-disabled.
- DO NOT auto-delete files outside the project repo (other than caches managed by chitty-cleanup).
- DO NOT rewrite git history (no rebase, no force-push).

## Output Contract

```json
{
  "phase": "tidy",
  "status": "completed",
  "format_changes": <int>,
  "branches_pruned": <int>,
  "wrangler_audit": {"passed": <bool>, "findings": [...]},
  "dead_code_findings": [...],
  "chronicle_entry": "<id>"
}
```
