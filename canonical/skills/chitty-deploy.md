---
name: chitty-deploy
canon_uri: chittycanon://core/services/chittymarket#skills/chitty-deploy
description: Deploy a ChittyOS service to Cloudflare Workers via SSH-bridged wrangler. Handles compatibility flags, secrets provisioning, and post-deploy health verification.
kind: skill
plugin: chittyos-devops
runtimes:
  - claude-code
  - codex
classification:
  - operations
  - deployment
---

# ChittyOS Deploy Skill

## Overview
Deploy ChittyOS services to Cloudflare Workers with proper environment handling.

## Usage
```
/deploy [service-name] [environment]
```

## Parameters
| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| service-name | Yes | - | Service to deploy (e.g., chittyid, chittyauth) |
| environment | No | production | Target environment (production, staging, preview) |

## Workflow

### 1. Locate Service
Find service in repository structure:
- `/home/ubuntu/projects/github.com/CHITTYFOUNDATION/{service}/`
- `/home/ubuntu/projects/github.com/CHITTYOS/{service}/`
- `/home/ubuntu/projects/github.com/CHITTYAPPS/{service}/`
- `/home/ubuntu/projects/github.com/CHITTYCORP/{service}/`

### 2. Pre-Deploy Checks
```bash
# Verify wrangler.toml exists
ls -la wrangler.toml

# Check for uncommitted changes
git status

# Run build if package.json has build script
npm run build 2>/dev/null || pnpm build 2>/dev/null
```

### 3. Deploy
```bash
# Production deploy
npx wrangler deploy --env production

# Or using npm script
npm run deploy:production
```

### 4. Post-Deploy Verification
```bash
# Check service health
curl -s https://{service}.chitty.cc/health | jq .
```

## Environment Variables
Secrets are managed by **ChittySecrets** (`secrets.chitty.cc`, Layer 0) fronting the Cloudflare
Secrets Store. Runtime values arrive through the worker's `secrets_store_secrets` binding declared
in `wrangler.toml` — there is no wrapper command that injects them at deploy time.

Classify before placing: service URLs and Notion DB IDs go in `vars`; tokens, third-party
credentials, and signing keys go in the Secrets Store. Never `[vars]` for a secret, never KV as
authority.

Do NOT wrap wrangler in `op run --env-file=...`: the `op` lane is non-functional on this host
(`op account list` is empty; env-files containing `op://` references fail
`403 Forbidden (Service Account Deleted)`), so the wrapper exits 1 and wrangler never runs.

Route credential materialization through ChittyConnect (`/chico`), and fail closed and loud
if the broker is unreachable:
```bash
# Preflight: broker must be reachable before a deploy that needs secret bindings.
curl -fsS https://connect.chitty.cc/health >/dev/null || {
  echo "POLICY_BLOCKED_CHITTYCONNECT_UNAVAILABLE: connect.chitty.cc unreachable — not deploying" >&2
  exit 78
}

# Secrets bound via ChittyConnect/Secrets Store are delivered at runtime; deploy plainly.
npx wrangler deploy --env production
```
If a binding is missing or needs rotation, hand off to the ChittyConnect concierge (`/chico`).
Never render a local env file and never paste a secret value into the shell or chat.

## Common Services

| Service | Domain | Repo Location |
|---------|--------|---------------|
| chittyid | id.chitty.cc | CHITTYFOUNDATION/chittyid |
| chittyauth | auth.chitty.cc | CHITTYFOUNDATION/chittyauth |
| chittyconnect | connect.chitty.cc | CHITTYOS/chittyconnect |
| chittyapi | api.chitty.cc | CHITTYOS/chittyapi |
| chittymcp | mcp.chitty.cc | CHITTYOS/chittymcp |

## Error Handling
- Build failures: Check TypeScript errors, missing dependencies
- Auth failures: Run `npx wrangler whoami`. If a secret binding is missing, confirm the worker
  declares the `secrets_store_secrets` binding and that the named secret exists (`secrets_list`
  via ChittySecrets — names only, never values), then route provisioning through `/chico`
  (ChittyConnect). Do NOT try `op` — that lane is dead on this host and will fail with
  `403 Service Account Deleted` or a missing env-file error.
- DNS issues: Verify custom domain in Cloudflare dashboard
