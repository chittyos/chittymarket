---
name: chitty-autonomy-ship
description: Phase 9 — Ship. Pushes branch, opens PR, blocks ship until Pentad complete for new services. Updates ChittyRegistry. Syncs canonical Notion entry. Lands the PR through the gated orchestrator skill autoassist:pr_land_v1 (pinned to the reviewed head, reviewer attestations attached); falls back to a gated local merge only when that skill is unavailable. Never blind-merges. Finalizes ChittyChronicle.
canonical_uri: chittycanon://skills/chitty-autonomy-ship
status: DRAFT
---

# Phase 9: Ship

## Pre-ship gates (HARD)

- Cert valid.
- All commits made; working tree clean.
- New service? Pentad complete (CHARTER + CHITTY + CLAUDE + SECURITY + AGENTS — schema-validated).
- Phase 6 review findings resolved or explicitly waived in cert metadata.
- Tests passing on current commit (re-run; do not trust earlier state).
- Reviewed head recorded: the 40-hex SHA the separated reviewers (Phase 6) signed off on.
- Reviewer attestations present: one JSON file per separated reviewer, each at a path matching `^\.gate/reviews/[a-z0-9-]+\.json$`. Missing or misnamed → stop; do not ship.

If any gate fails, return to the prior phase.

## Process

1. `git push -u origin <branch>`
2. Build PR body referencing cert_id, chronicle entries, canonical pipelines used, Pentad status.
3. `gh pr create` with conventional title.
4. Registration for new services: `POST register.chitty.cc/api/v1/register` with CHARTER URI + tier + domain.
   **CORRECTED 2026-07-30** — this said `POST registry.chitty.cc/api/services`.
   ChittyRegistry is a read-only **directory, not a gatekeeper**; ChittyRegister
   (`register.chitty.cc`, "Compliance Gateway & Onboarding") owns registration.
   Verified live: `register.chitty.cc/api/v1/register` returns 400 on an empty
   body (endpoint exists, validating), while `registry.chitty.cc/api/services`
   404s on GET. Read the ChittyRegister payload contract before shipping —
   do not guess the schema from the field list above.
5. Notion sync: Projects DB entry created/updated with PR URL, status, cert ID. Actions DB entry for follow-ups.
6. Land the PR — see **Landing** below. Cert must still be valid at this step.
7. Emit final ChittyChronicle entry (include `land_path`, `instance_id` or merge SHA, and any `error_code`).

## Landing

Why: Ship used to run `gh pr merge` with GitHub auto-merge enabled. That merged whatever head the PR
had when checks went green — not necessarily the head the reviewers saw — and it ignored the
review gates. Landing is now pinned to the reviewed head and gated on attestations and CI.

**Never enable GitHub auto-merge** (no `gh pr merge` auto flag, no repo-side auto-merge toggle) on either path.

### Primary path — `autoassist:pr_land_v1` via the orchestrator

Invoke through `ch1tty/cast` or the orchestrator's `skill_execute`. Autobot never holds
`AUTOASSIST_ADMIN_TOKEN`; the orchestrator authenticates to autoassist with its own token.

1. Submit:
   ```json
   skill_execute({
     "skill_id": "autoassist:pr_land_v1",
     "args": {
       "repo": "<owner>/<repo>",
       "pr_number": <n>,
       "expected_head": "<40-hex reviewed head SHA>",
       "attestations": [
         {"path": ".gate/reviews/<reviewer>.json", "content": "<base64 of the file bytes>"}
       ]
     }
   })
   ```
   One `attestations` entry per separated-reviewer file. Base64-encode the exact file bytes.
2. Interpret the submit response:
   - **202 with `instance_id`** → pr-land has started. Write `instance_id` into
     `chittycontext/structured-autonomy/<feature>/state.json` immediately, so a resumed run polls
     instead of re-submitting. Go to step 3.
   - **409 with `status`** → pr-land is already running or ran for this repo + PR + head. Do not
     re-submit and do not fall back. Report the returned `status` (and `instance_id` if present, which
     you then poll) and stop.
   - **Skill unavailable** — not registered with the orchestrator, or the binding is missing
     (`POLICY_BLOCKED_AUTOASSIST_*` returned by the submit call itself, with no `instance_id`) → use the
     **Fallback** path.
   - **Anything else** (transport error, timeout, 5xx, unparseable body) → stop and report. The
     submit may have started an instance; do not fall back.
3. Poll with `skill_execute({"skill_id": "autoassist:pr_land_v1", "args": {"instance_id": "<id>"}})`.
   The response is a Cloudflare Workflow instance status.
   - `queued`, `running`, `waiting` → non-terminal; poll again after a delay. Use a bounded loop.
   - `complete` → report the merge commit from `output`. Done.
   - `errored` → report the error code from `error` (for example `HEAD_MOVED`, `CHECKS_TIMEOUT`,
     `POLICY_BLOCKED_*`) and stop.
   - Any other value (`terminated`, `paused`, unknown) → treat as failure; report and stop.
   - Bound exhausted → report `instance_id` and the last status, and stop.

**Fallback rule:** the deciding question is "did any submit return an `instance_id`?" Once one has,
the Fallback path is forbidden — whatever the outcome, including a `POLICY_BLOCKED_*` terminal error.
Report and stop.

### Fallback path — gated local merge

Use only when the submit call showed the skill unavailable (above). Every step is a gate; any
failure stops Ship and is reported — never merge "anyway".

1. **PR is OPEN at the reviewed head.** Both must hold:
   - `gh pr view <n> --json state,headRefOid` → `state == "OPEN"` and `headRefOid == <reviewed head>`.
   - `git ls-remote origin refs/pull/<n>/head` → SHA equals `<reviewed head>` (works for fork PRs too).
2. **Commit and push the attestations.** Add the `.gate/reviews/*.json` files on the PR branch, commit,
   push. Record the new head `<new_sha>`. Verify `<new_sha>`'s parent is `<reviewed head>` and the
   commit touches only `.gate/reviews/` paths; otherwise stop.
3. **Wait for CI on `<new_sha>`.** Query `gh run list --commit <new_sha> --json status,conclusion,name,databaseId`
   in a bounded loop until at least one run exists and every run has `status == "completed"`. Do not use
   a bare `gh pr checks` — right after a push it returns the previous head's results. No runs within the
   bound → stop, do not merge.
4. **Merge only if every check passed.** Every run's `conclusion` must be `success`, except checks named
   in the operator-supplied allow-list (an explicit input to the run; empty by default — Autobot never
   invents entries). Then:
   `gh pr merge <n> --squash --match-head-commit <new_sha>`
   The head pin makes GitHub refuse the merge if anything was pushed after CI. Any other conclusion
   → stop and report the failing checks.

## PR body template

```markdown
## Summary
<bullets>

## Sovereignty Affirmation
- Cert: <cert_id> (issued <iso>, expires <iso>)
- Synthetic entity: <chitty_id>
- Scope: feat=<feature>, branch=<branch>
- Sovereignty: type=<earned|declared> level=<operational|partial|provisional|process_governed|full>

## Canonical alignment
- Entity types touched (P/L/T/E/A): <list> (cited via `// @canon:` in code)
- Canonical pipelines used: <list>
- Pentad status (if new service): CHARTER ✓ CHITTY ✓ CLAUDE ✓ SECURITY ✓ AGENTS ✓

## Test plan
- [ ] <observable verification>

## ChittyChronicle entries
- chittycanon://docs/audit/<feature>/affirm
- chittycanon://docs/audit/<feature>/commit-1
- ...

🤖 Generated by chittyagent-autobot
```

## Output Contract

```json
{
  "phase": "ship",
  "status": "shipped|merged|land_failed",
  "pr_url": "<url>",
  "reviewed_head": "<40-hex>",
  "land_path": "pr_land|fallback|none",
  "pr_land_instance_id": "<id|null>",
  "merge_commit": "<sha|null>",
  "error_code": "<HEAD_MOVED|CHECKS_TIMEOUT|POLICY_BLOCKED_*|...|null>",
  "registry_updated": false,
  "notion_entry": "<page-id>",
  "chronicle_final_entry": "<id>"
}
```
