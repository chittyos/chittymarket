---
name: chittyos-compliance
description: "This skill should be used when building, auditing, deploying, or certifying any ChittyOS service or artifact. It covers compliance auditing ('check compliance', 'audit this service', 'is this compliant?'), scaffolding new services ('scaffold new service', 'generate CHARTER.md/CHITTY.md/CLAUDE.md'), monitoring deployed health endpoints ('check health', 'monitor services', 'service status'), and certification ('certify', 'ChittyCertify', 'what badge level?'). Also trigger proactively when creating new ChittyOS services, modifying wrangler configs, writing CHARTER/CHITTY/CLAUDE docs, checking canonical compliance, registration readiness, or preparing for deployment."
---

# ChittyOS Compatibility & Compliance

Full lifecycle compliance management for the ChittyOS ecosystem: audit existing services, scaffold new ones, monitor deployed services, and certify artifacts.

## Modes

| Mode | Trigger | Purpose |
|------|---------|---------|
| **Audit** | "audit", "check compliance", "is this compliant?" | Full compliance check against ChittyOS standards |
| **Scaffold** | "scaffold", "new service", "generate templates" | Generate compliant CHARTER.md, CHITTY.md, health endpoint, wrangler config |
| **Monitor** | "monitor", "check health", "service status" | Hit deployed `*.chitty.cc/health` endpoints, verify live compliance |
| **Certify** | "certify", "certification", "ChittyCertify" | Evaluate artifacts against certification criteria, assign badge level |

## Core Standards

Every ChittyOS service MUST satisfy these requirements.

### Required Files

| File | Purpose | Frontmatter Required |
|------|---------|---------------------|
| `CHARTER.md` | Service charter — mission, scope, dependencies, API contract, ownership | Yes (type: policy) |
| `CHITTY.md` | Service badge & one-pager — identity, architecture, certification badges, ChittyDNA, ecosystem position. The service's "work badge" at a glance. | Yes (type: architecture) |
| `CLAUDE.md` | Developer guide — commands, dev workflow, patterns, gotchas | No |

### Document Triad Coordination

CHARTER.md, CHITTY.md, and CLAUDE.md form a coordinated triad — the charter (policy), the badge (identity), and the guide (developer docs). When auditing or creating these files, verify cross-document consistency:

- **Tier** must match across CHARTER.md and CHITTY.md
- **Canonical URI** must be identical in both chartered docs
- **Domain** (`{name}.chitty.cc`) must be consistent across all three
- **Service name** in CLAUDE.md must match CHARTER.md classification
- **Dependencies** in CHARTER.md should appear in both CHITTY.md ecosystem section and CLAUDE.md architecture
- **API endpoints** in CHARTER.md contract must match CHITTY.md endpoints table and CLAUDE.md docs
- **Certification badge** in CHITTY.md must match `status` field in frontmatter
- **ChittyDNA** in CHITTY.md must reflect actual service lineage and identity
- **Tech stack** in CLAUDE.md must reflect actual implementation (not legacy references)

When updating any one document, check the other two for consistency. When scaffolding, generate all three together to ensure alignment from the start.

### Canonical YAML Frontmatter

All chartered documents (CHARTER.md, CHITTY.md) require this metadata envelope. CHARTER.md uses `type: policy`, CHITTY.md uses `type: architecture`:

```yaml
---
uri: chittycanon://docs/{domain}/{type}/{identifier}
namespace: chittycanon://docs/{domain}
type: policy|spec|procedure|registry|architecture|catalog|summary
version: semver
status: DRAFT|PENDING|CERTIFIED|CANONICAL|DEPRECATED|ARCHIVED
registered_with: chittycanon://core/services/canon
title: string
certifier: chittycanon://core/services/chittycertify
visibility: PUBLIC|INTERNAL|CONFIDENTIAL|RESTRICTED
---
```

Domains: `tech`, `legal`, `ops`, `exec`, `gov`

### Service Identity

- **Canonical URI**: `chittycanon://core/services/{service-name}` (kebab-case)
- **Domain**: `{service-name}.chitty.cc` or `{short-name}.chitty.cc`
- **Tier**: Must be consistent across CHARTER.md and CHITTY.md

| Tier | Layer | Examples |
|------|-------|---------|
| 0 | Trust Anchors | ChittyID, ChittyTrust, ChittySchema |
| 1 | Core Identity | ChittyAuth, ChittyCert, ChittyRegister |
| 2 | Platform | ChittyConnect, ChittyRouter, ChittyAPI |
| 3 | Operational/Service | ChittyMonitor, ChittyFinance, ChittyLedger |
| 4 | Domain | ChittyEvidence, ChittyIntel, ChittyScore |
| 5 | Application | ChittyCases, ChittyPortal, ChittyDashboard |

### Required Endpoints

Every service MUST implement:
- `GET /health` returning `{"status":"ok","service":"<name>"}`
- `GET /api/v1/status` returning service metadata

### Entity Type Ontology (P/L/T/E/A)

All 5 types MUST be included in any entity type validation. Claude contexts are Person (P, Synthetic) — NEVER Thing (T). "Entity type" is the field name; "Entity" is NOT a valid type value.

### Auth & Security

- Standardize on `CHITTY_AUTH_SERVICE_TOKEN` (not `CHITTYCONNECT_API_TOKEN` or variants)
- Use `jose` library for JWT/JWKS on edge (not `jsonwebtoken`)
- CORS restricted to `*.chitty.cc` + localhost
- No hardcoded secrets in `[vars]`

### Infrastructure

- Worker name: `chitty*` convention
- `compatibility_date`: within 6 months of today
- `[[tail_consumers]]` with `service = "chittytrack"` for observability
- `package.json` name must match the service name

---

## Ecosystem Discovery (Step 0 — ALL Modes)

Before auditing, scaffolding, monitoring, or certifying ANY service, first discover its ecosystem context. Do NOT build or evaluate in a vacuum.

### Discovery Steps

1. **Query ChittyRegistry**: `curl -s https://registry.chitty.cc/api/services | jq .` — get the full service catalog
2. **Identify upstream/downstream services** — who does this service depend on? Who consumes it?
3. **Read the Compliance Triad** of related services — for each upstream and downstream dependency, read their `CHARTER.md` (API contract, endpoints), `CHITTY.md` (architecture, ecosystem position), and `CLAUDE.md` (dev patterns, integration examples)
4. **Check service repos** at: `/Volumes/chitty/github.com/CHITTYFOUNDATION/`, `/Volumes/chitty/github.com/CHITTYOS/`, `/Users/nb/desktop/projects/github.com/chittyapps`
5. **Local fallback**: `/Volumes/chitty/temp/systems-registry-import-v3.csv`

### Why This Matters

- Auditing requires knowing what correct integration looks like — read the dependency CHARTER.md contracts
- Scaffolding requires knowing what services to wire into — read peer CHITTY.md ecosystem sections
- Certifying requires knowing if dependencies are properly declared — cross-reference the registry
- Do NOT ask the user to list services — discover them yourself using these resources

---

## Audit Mode

Perform a comprehensive compliance check.

### Audit Steps

Run through the checklist directly:

0. **Ecosystem Discovery** — Run Step 0 above to understand the service's place in the ecosystem
1. Check for required files (CHARTER.md, CHITTY.md, CLAUDE.md)
2. Validate frontmatter on chartered docs
3. Verify cross-document consistency (tier, URI, domain, endpoints)
4. Check canonical URI format
5. Verify health endpoint implementation
6. Scan for entity type violations
7. Check auth patterns and env var naming
8. Audit wrangler config
9. Verify package.json name
10. Check for `(c as any)` or other type-safety violations

For detailed pass/fail criteria, consult **`references/compliance-checklist.md`**.

### Deep Audit

Dispatch specialized agents in parallel using `Task` with `run_in_background: true`:

| Agent | Checks |
|-------|--------|
| `chittyagent-canon` | URI scheme, frontmatter, naming, ontology |
| `chittyagent-neon-schema` | Schema drift, cross-service compatibility |
| `chittyagent-register` | Registration readiness, payload validation |
| `chittyagent-connect` | Credentials, auth patterns, integrations |

Perform the quick audit inline while agents run. Aggregate all findings into a unified report using the format in **`references/compliance-checklist.md`** (Audit Report Format section).

---

## Scaffold Mode

Generate compliant files for a new ChittyOS service.

### Pre-Scaffold: Ecosystem Discovery

Before scaffolding, run **Step 0 (Ecosystem Discovery)** to:
- Understand what tier this service belongs to and who its neighbors are
- Identify upstream dependencies by reading their CHARTER.md API contracts
- Identify downstream consumers by searching for services that reference this one
- Pre-populate the CHARTER.md dependencies section and CHITTY.md ecosystem section with real, verified integration points — not stubs

### Scaffold Inputs

Ask the user for:

1. **Service name** (kebab-case)
2. **Tier** (0-5)
3. **Short description** (one sentence)
4. **Domain** (defaults to `{name}.chitty.cc`)
5. **Stack** (Hono + Workers is default)

Generate files using templates from **`references/templates.md`**: CHARTER.md, CHITTY.md, health endpoint, wrangler config, and registration JSON. Populate dependency and integration sections from ecosystem discovery, not from guesswork. After scaffolding, run an audit to verify compliance.

---

## Monitor Mode

Check live deployed services.

### Single Service
```bash
curl -s https://{service}.chitty.cc/health --max-time 5 | jq .
```

### Ecosystem Sweep
```bash
for svc in id auth connect api registry schema mcp finance command; do
  echo -n "$svc: "
  curl -s "https://$svc.chitty.cc/health" --max-time 5 | jq -r '.status // "DOWN"'
done
```

Compare deployed state against source: verify `/health` response format, check CHARTER.md tier consistency, verify wrangler compatibility date freshness.

---

## Certify Mode (ChittyCertify)

Evaluate any artifact against ChittyOS certification criteria and award badges.

ChittyCertify operates like SOX/SOC II compliance auditing — it awards progressive **certifications** (NOT certificates; certificates are ChittyCert's domain).

### Badge Progression

```
[No Badge] → ChittyOS Compatible → Chitty Compliant → ChittyCertified → ChittyCanonical
```

Each level is cumulative. For full badge criteria, certification process, and report format, consult **`references/certification-criteria.md`**.

---

## Authority Model

| Service | Role | What It Owns |
|---------|------|-------------|
| **ChittyGov** | Business governance & compliance | Required reports, state filings, regulatory compliance, business guidelines, legal requirements. Defines what "compliant" means. Approves Canonical status. |
| **ChittyCertify** | Compliance certification (like SOX/SOC II) | Audits services against compliance standards, awards certification badges (Compatible/Compliant/Certified/Canonical), issues compliance **certifications** + JWT attestation tokens. Certifications, NOT certificates. |
| **ChittyCert** | Certificate Authority (CA) | PKI infrastructure, X.509 **certificates**, OCSP revocation, JWKS key registry, evidence authentication. Certificates, NOT certifications. |
| **ChittyRegister** | Registration authority | Service onboarding, compliance gatekeeper, validates before ecosystem entry. Register, NOT registry. |
| **ChittyRegistry** | Discoverable service registry | Searchable catalog of all registered services, tools, scripts, agents, and artifacts. Services are discovered here. Registry, NOT register. |
| **ChittyCanon** | Canonical authority | Entity type ontology (P/L/T/E/A), URI namespace, code pattern governance |

---

## Reference Files

Consult these for detailed information:

- **`references/compliance-checklist.md`** — Detailed pass/fail criteria for every compliance check, plus audit report format
- **`references/certification-criteria.md`** — Full badge award criteria, certification process, artifact types, and certification report format
- **`references/templates.md`** — Complete templates for scaffold mode (CHARTER.md, CHITTY.md, health endpoint, wrangler config, registration JSON, env types)

## Integration with Other Skills

| Skill | When to Chain |
|-------|--------------|
| `wrangler-audit` | After audit finds wrangler issues |
| `chitty-health` | During monitor mode for live checks |
| `chitty-deploy` | After scaffold + audit confirms compliance |
| `chitty-registry` | After certification to register the service |
