---
name: chitty-deploy
description: Deploy a ChittyOS service to Cloudflare Workers via SSH-bridged wrangler. Handles compatibility flags, secrets provisioning, and post-deploy health verification.
canon_uri: chittycanon://core/services/chittymarket#skills/chitty-deploy
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
- `/Volumes/chitty/github.com/CHITTYFOUNDATION/{service}/`
- `/Volumes/chitty/github.com/CHITTYOS/{service}/`
- `/Volumes/chitty/workspace/{service}/`

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
npx cf deploy --env production

# Or using npm script
npm run deploy:production
```

### 4. Post-Deploy Verification
```bash
# Check service health
curl -s https://{service}.chitty.cc/health | jq .
```

## Environment Variables
Secrets are managed via chittysecrets integration:
```bash
chittysecrets run --env-file=/Volumes/chitty/config/cloudflare-chittycorp.env -- npx cf deploy
```

## Common Services

| Service | Domain | Repo Location |
|---------|--------|---------------|
| chittyid | id.chitty.cc | CHITTYFOUNDATION/chittyid |
| chittyauth | auth.chitty.cc | CHITTYFOUNDATION/chittyauth |
| chittyconnect | connect.chitty.cc | CHITTYFOUNDATION/chittyconnect |
| chittyapi | api.chitty.cc | workspace/chittyapi |
| chittymcp | mcp.chitty.cc | workspace/chittymcp |

## Error Handling
- Build failures: Check TypeScript errors, missing dependencies
- Auth failures: Verify `op` is authenticated, check env file paths
- DNS issues: Verify custom domain in Cloudflare dashboard
