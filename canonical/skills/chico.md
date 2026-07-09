---
name: chico
description: 'Shortcut to dispatch the ChittyConnect concierge (chittyos-core/chittyconnect-concierge) — the canonical owner of credentials, connections, secret rotation, KV/D1 bindings, and ChittyConnect-side wiring. Triggers on "/chico", "/chico-keys", or when the user wants to invoke the concierge by its nickname. The concierge handles op/chittysecrets reads, wrangler secret put, CF API token rotation, binding restore, deploy-time binding audits, and anything in the credential lane. The operator (user) is OPERATOR ONLY — never asked to paste a secret; route through chico-keys.'
canon_uri: chittycanon://core/services/chittymarket#skills/chico
kind: skill
classification:
  - credentials
  - operations
runtimes:
  - claude-code
  - codex
plugin: chittyos-core
---

# /chico — ChittyConnect Concierge Alias

The user invoked `/chico` to dispatch the **chittyos-core:chittyconnect-concierge** agent (nickname: "chico-keys"). Treat the rest of the user's message as the task brief for the concierge.

## What to do

1. Read the user's arguments / message body — that's the brief.
2. Dispatch the concierge via the Task tool with:
   - `subagent_type: "chittyos-core:chittyconnect-concierge"`
   - `description`: a 3-5 word summary of the task
   - `prompt`: the user's brief, expanded with the standing constraints below if needed
   - `run_in_background: true` for longer credential/deploy work; foreground for quick lookups
3. When the concierge returns, summarize its report to the user.

## Standing constraints to apply to any concierge dispatch

These are binding for every chico-keys invocation:

- **The operator is OPERATOR ONLY** — never asked to paste/provide/rotate any credential value. If a value is needed, source from chittysecrets via `op` (concierge's job).
- **Real validation only** — no mocks, no placeholder values, no "would-be" config. Concrete evidence (curl output, deploy version id, audit script result).
- **Safe deploy only** — bare `cf deploy` is the documented anti-pattern (see chittyconnect#217/#221, chittyentity#324/#315). Always `--env production` (or staging), routed through `safe-deploy.sh` if the worker has one.
- **Operator approval required** for: production deploys of new (not yet shipped) code, secret rotations affecting org-wide auth, anything irreversible without rollback. Surface for go/no-go; do not auto-execute.
- **If genuinely blocked** (missing op item, vault access, cross-cutting policy) → STOP and file a follow-up issue on the right repo (chittyconnect, chittyentity, etc.). Do NOT route the blocker back to the operator as a credential ask.

## When NOT to use /chico

- Pure code work that doesn't touch credentials, secrets, bindings, or deploy → use a general-purpose agent.
- Verifying running services / probing endpoints → can be done directly (read-only) or with a general agent.
- Architecture decisions / refactors → concierge focuses on the credential + connection lane; pure design belongs elsewhere.

## Examples

- `/chico restore chittyconnect bindings` → dispatch concierge to inspect deployed bindings, restore any missing via safe-deploy, audit post-deploy.
- `/chico rotate CF token #215` → dispatch concierge to handle CF API token rotation (chittyconnect#215), through op + gh secret set, no operator credential asking.
- `/chico claim Action 1b 2aacb316` → dispatch concierge to claim the chittyagent-tasks task `2aacb316` (ChittyConnect neon_auth readiness PR) via `tasks_claim`, execute, then `tasks_complete`.
- `/chico audit deployed bindings` → dispatch concierge for a one-shot drift audit across the chittyconnect / chittyagent-viewport / chittyagent-* workers using their safe-deploy scripts.

## Where the concierge lives

- Plugin id: `chittyos-core:chittyconnect-concierge`
- Lane: credentials, connections, secrets, op/chittysecrets, wrangler secrets, CF tokens, KV/D1 bindings, deploy hygiene.
- Memory alias: "chico-keys" (saved in [[orchestrate-via-systems]]).
