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
overlay:
  title: Deploy to Cloudflare Workers
  capability_group: ship
  execution_class: '@chitty/workspace'
  visibility: recommended
  ontology:
    primary:
    - L
    - E
    secondary:
    - A
    - T
  authority:
    requires_chittyid: true
    requires_deploy_authority: true
  execution:
    default_surface: local
    local_allowed: true
    context_cost: medium
    mutation_risk: low
  discovery:
    indexable: true
    session_index: hidden
    ambient_by_intent: false
    verbs:
    - deploy
    - ship
    - release
    - wrangler
    fallback_search: true
  auth_flow:
    mode: service-token
    stores_credentials_in: ChittyConnect
    fail_closed_if_unavailable: true
  phase0_audit:
    job_to_be_done: operate
    environmental_footprint: admin-system
    evidentiary_risk: none
    advisory_disposition: local-only
  canonical_version: 1.0.0
  group_assignment_source: name-rule
  runtime_exclusions:
    claude_ai:
    - requires_local_filesystem
    chatgpt:
    - requires_local_filesystem
  legacy_category: ecosystem
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
Secrets are managed via 1Password integration:
```bash
op run --env-file=/Volumes/chitty/config/cloudflare-chittycorp.env -- npx wrangler deploy
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
