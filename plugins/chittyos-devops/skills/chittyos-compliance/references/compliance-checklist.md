# ChittyOS Compliance Checklist

Detailed pass/fail criteria for each compliance check.

## File Checks

### CHARTER.md
- [ ] File exists at repo root
- [ ] Has canonical YAML frontmatter with all required fields:
  - `uri` — format: `chittycanon://docs/ops/policy/{service}-charter`
  - `namespace` — `chittycanon://docs/ops`
  - `type` — `policy`
  - `version` — valid semver
  - `status` — one of: DRAFT, PENDING, CERTIFIED, CANONICAL, DEPRECATED, ARCHIVED
  - `registered_with` — `chittycanon://core/services/canon`
  - `title` — non-empty string
  - `certifier` — `chittycanon://core/services/chittycertify` (if CERTIFIED+)
  - `visibility` — one of: PUBLIC, INTERNAL, CONFIDENTIAL, RESTRICTED
- [ ] Contains Classification section with canonical URI, tier, domain
- [ ] Contains Mission section
- [ ] Contains Scope section (IS / IS NOT responsible for)
- [ ] Contains Dependencies table
- [ ] Contains API Contract table
- [ ] Contains Ownership table
- [ ] Contains Compliance checklist

### CHITTY.md
- [ ] File exists at repo root
- [ ] Has canonical YAML frontmatter (type: architecture, includes certifier field)
- [ ] First line after frontmatter: `# {ServiceName}`
- [ ] Has blockquote with: canonical URI | Tier N (Layer Name) | domain
- [ ] Tier matches CHARTER.md
- [ ] Domain matches CHARTER.md
- [ ] Has Architecture section (stack, key components)
- [ ] Has ChittyOS Ecosystem section (certification badge, ChittyDNA, dependencies, endpoints)

### CLAUDE.md
- [ ] File exists at repo root
- [ ] Contains project overview
- [ ] Contains common commands
- [ ] Contains architecture section
- [ ] References correct tech stack (not stale/legacy)

## Identity Checks

### Canonical URI
- [ ] Format: `chittycanon://core/services/{service-name}`
- [ ] Service name is kebab-case
- [ ] Consistent across CHARTER.md, CHITTY.md, and any code references

### Tier Classification
- [ ] Tier is a number 0-5
- [ ] CHARTER.md and CHITTY.md agree on tier
- [ ] Tier matches the service's role in the ecosystem

### Domain
- [ ] Format: `{name}.chitty.cc`
- [ ] Consistent across CHARTER.md and CHITTY.md
- [ ] Matches wrangler config routes (if present)

### Package Name
- [ ] `package.json` name matches service name
- [ ] Not a legacy name (e.g., `rest-express`, `my-app`)

## Endpoint Checks

### /health
- [ ] Route exists in source code
- [ ] Returns JSON: `{"status":"ok","service":"{service-name}"}`
- [ ] Returns HTTP 200
- [ ] No authentication required
- [ ] (Live) Responds within 5 seconds

### /api/v1/status
- [ ] Route exists in source code
- [ ] Returns service metadata (name, version, mode, etc.)
- [ ] Returns HTTP 200
- [ ] No authentication required (or minimal auth)

## Ontology Checks

### Entity Type Compliance
- [ ] Any code referencing entity types includes all 5: P, L, T, E, A
- [ ] Authority (A) is never omitted from type lists/enums/maps
- [ ] No code classifies Claude/AI contexts as Thing (T) — must be Person (P)
- [ ] "Entity type" used as field name, not "entity" as a value
- [ ] Code that defines entity types cites: `// @canon: chittycanon://gov/governance#core-types`

### Domain Types vs. Ontology
- [ ] Domain-specific types (e.g., tenant types: holding, series, property) are NOT confused with canonical entity types (P/L/T/E/A)
- [ ] No code conflates LLC organizational taxonomy with ontological types

## Security Checks

### Auth Pattern
- [ ] Service token env var: `CHITTY_AUTH_SERVICE_TOKEN` (not variants)
- [ ] No references to `CHITTYCONNECT_API_TOKEN` or `CHITTY_CONNECT_SERVICE_TOKEN`
- [ ] JWT library: `jose` for edge/Workers (not `jsonwebtoken`)
- [ ] Bearer token auth on protected routes
- [ ] Public routes (health, webhooks) skip auth

### Type Safety (Hono apps)
- [ ] No `(c as any).storage` or similar unsafe patterns
- [ ] Variables interface properly typed in env.ts
- [ ] Using `c.get()` / `c.set()` for typed context
- [ ] No `process.env` references in Workers code (use `c.env`)

### Credential Safety
- [ ] No hardcoded secrets in code or config
- [ ] Secrets flow through 1Password / wrangler secrets
- [ ] No `DATABASE_URL` or API keys in wrangler `[vars]`

## Infrastructure Checks

### Wrangler Config
- [ ] Worker name follows `chitty*` convention
- [ ] `compatibility_date` is within 6 months of today
- [ ] `[[tail_consumers]]` includes `service = "chittytrack"`
- [ ] Entry point file (`main`) exists
- [ ] No hardcoded secrets in `[vars]`
- [ ] KV/R2/D1 bindings use real IDs (not placeholders)
- [ ] Production environment configured

### Database (Neon PostgreSQL)
- [ ] Uses `@neondatabase/serverless` for Workers (not `pg` Pool)
- [ ] Drizzle ORM with `drizzle-orm/neon-http` adapter
- [ ] Single consolidated DB connection (not multiple conflicting files)
- [ ] All queries tenant-scoped (multi-tenant services)

## Registration Checks

- [ ] Service name is valid for URI (kebab-case, unique)
- [ ] Registration JSON has all required fields: name, description, version, endpoints, schema, security
- [ ] Schema entities list matches actual database tables
- [ ] Endpoints list matches actual implemented routes

## Audit Report Format

Generate this format after completing an audit:

```
CHITTYOS COMPLIANCE REPORT
===========================
Service: {name}
URI: chittycanon://core/services/{name}
Domain: {name}.chitty.cc
Tier: {N}
Date: {YYYY-MM-DD}

REQUIRED FILES
  CHARTER.md .... [PASS/FAIL] {details}
  CHITTY.md ..... [PASS/FAIL] {details}
  CLAUDE.md ..... [PASS/FAIL] {details}

FRONTMATTER
  CHARTER.md .... [PASS/FAIL] {missing fields}
  CHITTY.md ..... [PASS/FAIL] {missing fields}

IDENTITY
  Canonical URI .. [PASS/FAIL]
  Tier consistency [PASS/FAIL] {CHARTER says X, CHITTY says Y}
  Domain match ... [PASS/FAIL]
  Package name ... [PASS/FAIL]

ENDPOINTS
  /health ........ [PASS/FAIL]
  /api/v1/status . [PASS/FAIL]

ONTOLOGY
  Entity types ... [PASS/FAIL] {violations found}

SECURITY
  Auth pattern ... [PASS/FAIL] {env var name issues}
  Token safety ... [PASS/FAIL]

INFRASTRUCTURE
  Wrangler config  [PASS/FAIL] {issues}
  Compat date .... [PASS/FAIL] {age}
  Tail consumer .. [PASS/FAIL]

REGISTRATION
  Status ......... [REGISTERED/PENDING/NOT REGISTERED]

OVERALL: [COMPLIANT / NEEDS REMEDIATION / NON-COMPLIANT]
  Critical: {N}  Major: {N}  Minor: {N}  Advisory: {N}
```
