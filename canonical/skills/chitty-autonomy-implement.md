---
name: chitty-autonomy-implement
description: Phase 5 — Implementation Executor. Replaces structured-autonomy-implement. Walks implementation.md commit-by-commit, runs tests, formats/lints inline, commits each step. Invokes superpowers:test-driven-development if --tdd was set; superpowers:systematic-debugging on test failure. Re-verifies sovereignty cert before destructive ops.
canonical_uri: chittycanon://skills/chitty-autonomy-implement
status: DRAFT
kind: skill
plugin: chittyagent-autobot
runtimes:
  - claude-code
  - codex
classification:
  - governance
  - autonomy
---

# Phase 5: Implement

## Inputs
- `implementation.md`
- Sovereignty cert (re-verified at phase entry)

## Process per commit

1. Pre-commit cert check — `POST cert.chitty.cc/api/v1/verify`. If invalid, abort.
2. Apply all unchecked items in current commit. Use `Edit` tool with bytes-exact matches; refuse fuzzy edits.
3. Run verification commands. On failure:
   - Invoke `superpowers:systematic-debugging`.
   - Fix in-place; do NOT silently work around.
   - On unfixable failure, return to Phase 4 with the symptom.
4. Run formatters/linters (prettier, eslint, language-appropriate). If still dirty after auto-fix, surface as review issue but commit.
5. Stage exactly the files listed in the plan; refuse `git add -A`.
6. Commit message: `<type>(<scope>): <summary> [cert: <cert_short>]`.
7. Mark all items checked in implementation.md.
8. Emit ChittyChronicle entry `chittycanon://docs/audit/<feature>/commit-<n>`.
9. Pause for parent orchestrator.

## Constraints

- No code outside what plan specifies.
- No `--no-verify` on git commit (skips hooks).
- No `git add -A`.
- If a product-level hook blocks the commit, surface the block as Phase 5 failure; loop back to Phase 4.

## Output Contract per commit

```json
{
  "phase": "implement",
  "commit_n": 1,
  "status": "committed",
  "sha": "<short>",
  "files_changed": [...],
  "tests_passed": true,
  "lint_clean": true,
  "chronicle_entry": "<id>"
}
```

## Failure recovery

| Symptom | Action |
|---|---|
| Test fails after fix attempts | `superpowers:systematic-debugging`; if still red, back to Phase 4 |
| Hook blocks commit | Read output; if canonical-pipeline-bypass, back to Phase 4 with corrective instruction |
| Cert expired mid-phase | Pause; request renewal via Phase 0; resume |
| Edit tool fails (old_string not unique) | Surface conflict; do not blind-edit |
