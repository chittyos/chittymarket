---
name: chico
description: 'Shortcut to dispatch the ChittyConnect concierge (chittyos-core/chittyconnect-concierge) — the canonical owner of credentials, connections, secret rotation, KV/D1 bindings, and ChittyConnect-side wiring. Triggers on "/chico", "/chico-keys", or when the user wants to invoke the concierge by its nickname. The concierge handles ChittySecrets resolution, wrangler secret put, CF API token rotation, binding restore, deploy-time binding audits, and anything in the credential lane. The operator (user) is OPERATOR ONLY — never asked to paste a secret; route through chico-keys.'
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

The user invoked `/chico` to dispatch the **chittyagent-connect** agent (nickname: "chico-keys"). Treat the rest of the user's message as the task brief for the concierge.

## What to do

1. Read the user's arguments / message body — that's the brief.
2. Dispatch the concierge via the Task tool with:
   - `subagent_type: "chittyagent-connect"` — verified 2026-09-18: this is the `name:` in
     `plugins/chittyos-core/agents/chittyagent-connect.md`, and **no agent anywhere declares
     `name: chittyconnect-concierge`**. Naming the concierge alias as a `subagent_type` makes the
     dispatch fail. `chittyos-core:chittyagent-connect` also resolves.
   - `description`: a 3-5 word summary of the task
   - `prompt`: the user's brief, expanded with the standing constraints below if needed
   - `run_in_background: true` for longer credential/deploy work; foreground for quick lookups
3. When the concierge returns, summarize its report to the user.

## Standing constraints to apply to any concierge dispatch

These are binding for every chico-keys invocation:

- **The operator is OPERATOR ONLY** — never asked to paste/provide/rotate any credential value.
- **ChittySecrets (`secrets.chitty.cc`) is the cold source of truth.** 1Password is RETIRED as both lane and authority (ratified 2026-08-21, `~/.ops/operator-manifest.json`). `op` v2.30.0 is installed but `op account list` is EMPTY, so every `op read` / `op run` on this host fails. Do not attempt it; do not restore it.
- **Store credentials where the operator can see them.** Coordination that ends in "over to you to provision" is not done — the value belongs in ChittySecrets as cold source, with Cloudflare Secrets Store for runtime delivery.
- **Real validation only** — no mocks, no placeholder values, no "would-be" config. Concrete evidence (curl output, deploy version id, audit script result).
- **Safe deploy only** — bare `wrangler deploy` is the documented anti-pattern (see chittyconnect#217/#221, chittyentity#324/#315). Always `--env production` (or staging), routed through `safe-deploy.sh` if the worker has one.
- **Operator approval required** for: production deploys of new (not yet shipped) code, secret rotations affecting org-wide auth, anything irreversible without rollback. Surface for go/no-go; do not auto-execute.
- **If genuinely blocked** (secret absent from ChittySecrets, CF Access denied, cross-cutting policy) → STOP and file a follow-up issue on the right repo (chittyconnect, chittyentity, etc.). Do NOT route the blocker back to the operator as a credential ask.

## When NOT to use /chico

- Pure code work that doesn't touch credentials, secrets, bindings, or deploy → use a general-purpose agent.
- Verifying running services / probing endpoints → can be done directly (read-only) or with a general agent.
- Architecture decisions / refactors → concierge focuses on the credential + connection lane; pure design belongs elsewhere.

## Examples

- `/chico restore chittyconnect bindings` → dispatch concierge to inspect deployed bindings, restore any missing via safe-deploy, audit post-deploy.
- `/chico rotate CF token #215` → dispatch concierge to handle CF API token rotation (chittyconnect#215), through ChittySecrets + gh secret set, no operator credential asking.
- `/chico claim Action 1b 2aacb316` → dispatch concierge to claim the chittyagent-tasks task `2aacb316` (ChittyConnect neon_auth readiness PR) via `tasks_claim`, execute, then `tasks_complete`.
- `/chico audit deployed bindings` → dispatch concierge for a one-shot drift audit across the chittyconnect / chittyagent-viewport / chittyagent-* workers using their safe-deploy scripts.

## Where the concierge lives

- Agent type: `chittyagent-connect` — defined at `plugins/chittyos-core/agents/chittyagent-connect.md` (plugin id `chittyos-core:chittyagent-connect`).
- Lane: credentials, connections, secrets, ChittySecrets, wrangler secrets, CF tokens, KV/D1 bindings, deploy hygiene.
- Memory alias: "chico-keys" (saved in [[orchestrate-via-systems]]).
