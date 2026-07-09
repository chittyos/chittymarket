---
name: chitty-autonomy-generate
description: Phase 4 — Implementation Doc Generator. Replaces structured-autonomy-generate. Reads plan.md, produces implementation.md with copy-paste TDD-aware code. NO placeholders. NO Cursor-syntax. Generated code carries canon citations and product-level enforcement annotations.
canonical_uri: chittycanon://skills/chitty-autonomy-generate
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

# Phase 4: Generate Implementation Doc

## Inputs
- `plan.md` (validated; zero NEEDS_CLARIFICATION)
- `discovery.md` (canonical patterns, pipelines, schemas)
- `--tdd` flag (optional)

## Process

1. Verify plan and cert valid.
2. Pull current canonical patterns from each cited Charter URI (live, not training).
3. For each commit in plan.md, generate:
   - File path(s) per project conventions (read project's CLAUDE.md).
   - **TDD path** (if `--tdd`): test file first (runnable, fails meaningfully), then implementation.
   - **Non-TDD path**: implementation + verification commands.
   - Required `// @canon: chittycanon://...` citations.
   - Auth boilerplate per project's SECURITY.md.
4. Write `implementation.md` with markdown checkboxes per item.
5. Each commit ends with `STOP & COMMIT` (parent drives the pause).
6. Emit ChittyChronicle entry.

## implementation.md template

```markdown
# <Feature> — Implementation

**Cert:** <cert_id>
**Plan:** [plan.md](./plan.md)

## Commit 1: <name>

### Test (TDD only)
- [ ] Create `<test-file>`:
\`\`\`<lang>
<runnable test that fails meaningfully now>
\`\`\`
- [ ] Run `<test cmd>` — confirm FAIL for expected reason.

### Implementation
- [ ] Edit `<file>`:
\`\`\`<lang>
// @canon: chittycanon://gov/governance#core-types  (if entity types touched)
<COMPLETE code, no TODO, no placeholders>
\`\`\`
- [ ] Run `<test cmd>` — confirm PASS.
- [ ] Run `<lint cmd>`, `<format cmd>` — clean.
- [ ] Commit: `<feat|fix|chore>: <message>`

### Verification
- [ ] `<observable check>`

### STOP & COMMIT
```

## Constraints on generated code

- NO `rclone copy` to evidence buckets — use canonical pipeline endpoint.
- NO direct `env.DOCUMENTS.put` outside `gatekeeper.ts` / `intake-worker.ts`.
- NO `cf deploy` raw — use CI workflow.
- NO `#tool:` / `#context7` Cursor syntax.
- Every entity-type validation MUST list all five (P/L/T/E/A).

## Output Contract

```json
{
  "phase": "generate",
  "status": "completed",
  "implementation_doc": "chittycontext/structured-autonomy/<feature>/implementation.md",
  "commits": [{"n": 1, "files": [...], "tdd": false}],
  "canon_citations_required": [...],
  "chronicle_entry": "<id>"
}
```
