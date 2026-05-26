---
name: chitty-autonomy-plan
description: Phase 3 — Plan Generation. Replaces structured-autonomy-plan with ChittyOS-canonical version. Reads discovery.md, breaks the feature into commits, generates a plan.md with [NEEDS_CLARIFICATION] markers that BLOCK the next phase until resolved. Cites canonical URIs for entity-type touches. No code, no Cursor-syntax, no Windows-API debt.
canonical_uri: chittycanon://skills/chitty-autonomy-plan
status: DRAFT
kind: skill
plugin: chittyagent-autobot
runtimes:
  - claude-code
classification:
  - governance
  - autonomy
---

# Phase 3: Plan

## Inputs
- `chittycontext/structured-autonomy/<feature>/discovery.md` (mandatory)
- `chittycontext/structured-autonomy/<feature>/SOVEREIGNTY.cert` (verified valid)
- Conversation context from Phase 2 (brainstorming output, if any)

## Process

1. Verify cert + discovery are present. If either missing, return to prior phase.
2. Determine commit count: SIMPLE features = 1 commit; COMPLEX = N (each independently testable).
3. Generate `plan.md` to `chittycontext/structured-autonomy/<feature>/plan.md`.
4. Validate `[NEEDS_CLARIFICATION]` count.
5. If count > 0: PAUSE for user input. Re-enter Phase 3 after answers.
6. Emit ChittyChronicle entry `chittycanon://docs/audit/<feature>/plan`.

## plan.md template

```markdown
# <Feature Name>

**Branch:** `feat/<kebab>`
**Sovereignty cert:** <cert_id> (expires <iso>)
**Discovery doc:** [discovery.md](./discovery.md)

## Goal
<1-2 sentences>

## Canonical alignment
- Touches entity types: <P/L/T/E/A or none>  *(if any, code MUST cite `// @canon: chittycanon://gov/governance#core-types`)*
- Calls canonical pipelines: <list>
- New service? <yes/no>  *(if yes: Pentad scaffolding required at Phase 5)*

## Commits

### Commit 1: <name>
**Files:** <list>
**What:** <description>
**Tests:** <verification — must be observable, not "looks right">
**Canon citations needed:** <list of chittycanon:// URIs>

### Commit 2: <name>
…
```

## Validation gates (PRODUCT-level, not local hooks)

Before declaring this phase complete, the plan MUST:

- [ ] Have ZERO `[NEEDS_CLARIFICATION]` markers.
- [ ] If touching entity types, list ALL FIVE in any validation regex/map (P/L/T/E/A — never omit Authority).
- [ ] If creating a new service, declare full Pentad in commit list.
- [ ] If calling external services, cite their Charter URI.
- [ ] If the work writes to R2, declare which canonical pipeline (NOT `rclone copy`, NOT `wrangler r2 object put` — these would fail the canonical-pipeline check).

## Output Contract

```json
{
  "phase": "plan",
  "status": "completed",
  "plan_doc": "chittycontext/structured-autonomy/<feature>/plan.md",
  "commits": <int>,
  "new_service": <bool>,
  "entity_types_touched": ["P", ...],
  "canonical_pipelines_used": ["/documents", ...],
  "chronicle_entry": "<id>"
}
```
