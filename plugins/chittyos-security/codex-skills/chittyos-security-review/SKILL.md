---
name: chittyos-security-review
description: |
  Review ChittyOS code and configuration for security weaknesses across Cloudflare Workers,
  Workers AI, MCP/Ch1tty boundaries, ChittyConnect and ChittySecrets, D1/Neon/R2, webhooks,
  and Workers Builds. Triggers on security review, hardening, secret handling, auth boundary,
  Worker security, MCP security, or threat-preflight requests.
canon_uri: chittycanon://core/services/chittymarket#skills/chittyos-security-review
---

# ChittyOS Security Review

Perform a read-only, evidence-based review before proposing changes. Inspect the real repository,
its `CHARTER.md`, `CHITTY.md`, `CLAUDE.md`, `AGENTS.md`, Worker configuration, routes, bindings,
workflows, and tests. Do not request or expose credentials.

## Review order

1. Establish scope: repository, Worker/service, changed files, data handled, and deployment path.
2. Discover existing owners and canonical services before suggesting a new control. Reuse ChittyConnect,
   ChittyAuth, ChittyID, ChittySecrets, ChittyCanon, ChittyTrack, and Ch1tty where applicable.
3. Trace trust boundaries: browser/client → Worker → MCP/Ch1tty → upstream service → D1/Neon/R2/KV.
4. Inspect authentication, authorization, tenant isolation, input validation, output handling, CORS,
   webhook verification, replay protection, rate limits, and failure behavior.
5. Inspect `wrangler.toml`/`wrangler.jsonc`, bindings, routes, compatibility date, observability,
   Workers Builds triggers, and GitHub workflows for secret leakage or fail-open deployment gates.
6. Check AI-specific risks: prompt injection, untrusted tool arguments, model-output trust, data leakage,
   unbounded prompts/completions, provider fallback, usage limits, and generation persistence.
7. Classify each finding as critical, high, medium, low, or informational, with file/line evidence.

## ChittyOS rules

- Secrets and tokens are broker-managed. Never grep, print, paste, rotate, or invent secret values.
- Route credential and deployment intent through ChittyConnect/Chico; fail closed when the broker is unavailable.
- Treat Ch1tty as the MCP umbrella and do not bypass it for orchestration or intent-driven calls.
- Never treat KV as the authoritative store for security state, idempotency, audit, or custody records.
- Prefer Workers Builds for deployment. GitHub Actions may validate but must not become a deployment queue.
- Do not add paid-GitHub assumptions, broad workflow fan-out, or duplicate deploy workflows.
- Do not weaken auth, CORS, tenant boundaries, logging redaction, or deploy gates to make a test pass.
- Findings must distinguish a confirmed vulnerability from a missing control or an unverified assumption.

## Output

Return:

1. Scope and evidence inspected.
2. Findings table: severity, evidence, impact, exploit/precondition, and recommended remediation.
3. Positive controls already present.
4. Prioritized remediation backlog with smallest safe next steps.
5. Tests or probes that would prove each fix.
6. Explicit caveats where runtime, registry, binding, or provider state was unavailable.

Do not implement fixes, mutate infrastructure, or change credentials unless separately requested and approved.
