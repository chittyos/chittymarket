---
name: chitty-autonomy-cicd
description: Phase 8 — CI/CD scaffolding. Creates .github/workflows/ for the canonical ChittyOS deploy pipeline. Audits CLOUDFLARE_API_TOKEN GitHub-Actions secret scopes against project needs (Workers Scripts:Edit always; Workers Secrets Store:Edit if secrets_store bindings; Workers Pipelines:Edit if pipelines; Workers R2 Data Catalog:Edit if Iceberg sinks). Catches the deploy-loop class of failure up-front.
canonical_uri: chittycanon://skills/chitty-autonomy-cicd
status: DRAFT
---

# Phase 8: CI/CD

## Why this phase exists

Observed failure (2026-05-01): chittyconnect Worker entered a deploy loop because the GitHub Actions `CLOUDFLARE_API_TOKEN` secret lacked `Workers Secrets Store:Edit` scope. Every PR merge → CI → deploy fails with code 10021 → no rollback → next merge tries again. **Phase 8 catches token-scope gaps up-front so this class of failure cannot recur.**

## Process

1. Verify cert valid.
2. Detect build/deploy mode:
   - Cloudflare Worker → `cf deploy`
   - npm package → `npm publish`
   - Static site → CF Pages
   - Mixed → branch the workflow file accordingly.
3. Scaffold `.github/workflows/`:
   - `deploy.yml` — push to main → lint+test+deploy
   - `pr-checks.yml` — on PR → lint+test
   - `chitty-canon-check.yml` — invokes chittyagent-canon
4. **Token scope audit** — programmatically list scopes on `CLOUDFLARE_API_TOKEN`:
   - REQUIRE: `Workers Scripts:Edit` (always)
   - IF wrangler config has `secrets_store_secrets` → REQUIRE: `Workers Secrets Store:Edit`
   - IF wrangler config has `pipelines` bindings → REQUIRE: `Workers Pipelines:Edit`
   - IF wrangler config uses Iceberg / R2 Data Catalog sinks → REQUIRE: `Workers R2 Data Catalog:Edit`
5. If any required scope is missing, surface a precise checklist for the user to add via the dashboard. CF API doesn'\''t expose scope mutation; this is informational + dashboard-side.
6. Emit ChittyChronicle entry.

## Output Contract

```json
{
  "phase": "cicd",
  "status": "completed",
  "workflows_scaffolded": ["deploy.yml", "pr-checks.yml"],
  "token_scopes_audit": {
    "current": [...],
    "required": [...],
    "missing": [...]
  },
  "user_action_required": false,
  "chronicle_entry": "<id>"
}
```
