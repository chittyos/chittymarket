# ChittyOS Compliance Templates

Templates for scaffolding new ChittyOS-compliant services.

## CHARTER.md Template

```markdown
---
uri: chittycanon://docs/ops/policy/{SERVICE_NAME}-charter
namespace: chittycanon://docs/ops
type: policy
version: 1.0.0
status: DRAFT
registered_with: chittycanon://core/services/canon
title: "{SERVICE_DISPLAY_NAME} Charter"
certifier: chittycanon://core/services/chittycertify
visibility: PUBLIC
---

# {SERVICE_DISPLAY_NAME} Charter

## Classification
- **Canonical URI**: `chittycanon://core/services/{SERVICE_NAME}`
- **Tier**: {TIER} ({TIER_LABEL})
- **Organization**: CHITTYOS
- **Domain**: {DOMAIN}.chitty.cc

## Mission

{DESCRIPTION}

## Scope

### IS Responsible For
- {responsibility_1}
- {responsibility_2}

### IS NOT Responsible For
- Identity generation (ChittyID)
- Token provisioning (ChittyAuth)
- Service registration (ChittyRegister)

## Dependencies

| Type | Service | Purpose |
|------|---------|---------|
| Upstream | ChittyAuth | Token validation |
| Storage | Neon PostgreSQL | Database |

## API Contract

**Base URL**: https://{DOMAIN}.chitty.cc

### Core Endpoints
| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/health` | GET | Health check |
| `/api/v1/status` | GET | Service status |

## Ownership

| Role | Owner |
|------|-------|
| Service Owner | ChittyOS |
| Technical Lead | @chittyos-infrastructure |
| Contact | {SERVICE_NAME}@chitty.cc |

## Compliance

- [ ] Service registered in ChittyRegistry
- [ ] Health endpoint operational at /health
- [ ] CLAUDE.md development guide present
- [ ] CHARTER.md present
- [ ] CHITTY.md present

---
*Charter Version: 1.0.0 | Last Updated: {DATE}*
```

## CHITTY.md Template

```markdown
---
uri: chittycanon://docs/ops/architecture/{SERVICE_NAME}
namespace: chittycanon://docs/ops
type: architecture
version: 1.0.0
status: DRAFT
registered_with: chittycanon://core/services/canon
title: "{SERVICE_DISPLAY_NAME}"
certifier: chittycanon://core/services/chittycertify
visibility: PUBLIC
---

# {SERVICE_DISPLAY_NAME}

> `chittycanon://core/services/{SERVICE_NAME}` | Tier {TIER} ({TIER_LABEL}) | {DOMAIN}.chitty.cc

## What It Does

{DESCRIPTION}

## Architecture

Cloudflare Worker (Hono) deployed at {DOMAIN}.chitty.cc.

### Stack
- **Runtime**: Cloudflare Workers
- **Framework**: Hono
- **Database**: Neon PostgreSQL (Drizzle ORM)
- **Storage**: KV / R2

### Key Components
- `server/worker.ts` — Entry point
- `server/routes/` — API route modules
- `server/db/` — Database schema and queries

## ChittyOS Ecosystem

### Certification
- **Badge**: {BADGE_LEVEL} (ChittyOS Compatible | Chitty Compliant | ChittyCertified | ChittyCanonical)
- **Certifier**: ChittyCertify (`chittycanon://core/services/chittycertify`)
- **Last Certified**: {DATE}

### ChittyDNA
- **ChittyID**: {CHITTY_ID}
- **DNA Hash**: {DNA_HASH}
- **Lineage**: {PARENT_SERVICE or "root"}

### Dependencies
| Service | Purpose |
|---------|---------|
| ChittyAuth | Token validation |
| ChittyConnect | Ecosystem integration |

### Endpoints
| Path | Method | Auth | Purpose |
|------|--------|------|---------|
| `/health` | GET | No | Health check |
| `/api/v1/status` | GET | No | Service metadata |
```

## Health Endpoint Template (Hono)

```typescript
import { Hono } from 'hono';
import type { HonoEnv } from '../env';

export const healthRoutes = new Hono<HonoEnv>();

// GET /health — ChittyOS standard health check
healthRoutes.get('/health', (c) => {
  return c.json({ status: 'ok', service: '{SERVICE_NAME}' });
});

// GET /api/v1/status — Service metadata
healthRoutes.get('/api/v1/status', (c) => {
  return c.json({
    name: '{SERVICE_DISPLAY_NAME}',
    version: c.env.APP_VERSION || '1.0.0',
    mode: c.env.MODE || 'system',
    environment: c.env.NODE_ENV || 'production',
  });
});

// GET /api/v1/metrics — Basic metrics
healthRoutes.get('/api/v1/metrics', (c) => {
  return c.json({
    uptime: 'worker',
    timestamp: new Date().toISOString(),
  });
});
```

## Wrangler Config Template

```toml
name = "{SERVICE_NAME}"
main = "server/worker.ts"
compatibility_date = "{DATE}"
compatibility_flags = ["nodejs_compat"]

[observability]
enabled = true

[[tail_consumers]]
service = "chittytrack"

[vars]
MODE = "system"
APP_VERSION = "1.0.0"

[[kv_namespaces]]
binding = "{SERVICE_UPPER}_KV"
id = "{KV_NAMESPACE_ID}"

[[r2_buckets]]
binding = "{SERVICE_UPPER}_R2"
bucket_name = "{SERVICE_NAME}-storage"

[env.production]
routes = [
  { pattern = "{DOMAIN}.chitty.cc", custom_domain = true }
]

[env.staging]
routes = [
  { pattern = "{DOMAIN}-staging.chitty.cc", custom_domain = true }
]
```

## Registration JSON Template

```json
{
  "name": "{SERVICE_NAME}",
  "description": "{DESCRIPTION}",
  "version": "1.0.0",
  "endpoints": [
    { "path": "/health", "method": "GET", "auth": false },
    { "path": "/api/v1/status", "method": "GET", "auth": false }
  ],
  "schema": {
    "version": "1.0.0",
    "entities": []
  },
  "security": {
    "authentication": "jwt",
    "encryption": "tls"
  }
}
```

## Env Type Template (Hono)

```typescript
export interface Env {
  DATABASE_URL: string;
  CHITTY_AUTH_SERVICE_TOKEN: string;
  MODE?: string;
  NODE_ENV?: string;
  APP_VERSION?: string;
  {SERVICE_UPPER}_KV: KVNamespace;
  {SERVICE_UPPER}_R2: R2Bucket;
  ASSETS: Fetcher;
}

export interface Variables {
  tenantId: string;
  userId: string;
}

export type HonoEnv = {
  Bindings: Env;
  Variables: Variables;
};
```

## Tier Labels Reference

| Tier | Label |
|------|-------|
| 0 | Trust Anchors |
| 1 | Core Identity |
| 2 | Platform |
| 3 | Service Layer |
| 4 | Domain |
| 5 | Application |
