# ChittyCertify Certification Criteria

Detailed badge requirements, certification process, and report formats for ChittyCertify compliance certification.

## Certification Badges

ChittyCertify awards progressive certification badges. Each badge has specific requirements that must ALL pass. Badge progression is cumulative — each level includes all requirements of the previous level.

| Badge | Meaning | Requirements Summary |
|-------|---------|---------------------|
| **ChittyOS Compatible** | Can interoperate with the ecosystem | Health endpoint, canonical URI, CHITTY.md present, correct tier |
| **Chitty Compliant** | Meets all mandatory standards | Compatible + CHARTER.md with frontmatter, auth patterns, type safety, ontology |
| **ChittyCertified** | Fully certified by ChittyCertify | Compliant + registered, live health check, consumer contract tests |
| **ChittyCanonical** | Source of truth designation | Certified + ChittyGov approval, all docs CANONICAL, zero advisory issues |

## Badge Award Criteria

### ChittyOS Compatible (entry level)

- [ ] CHITTY.md exists with canonical URI and tier
- [ ] `/health` endpoint returns `{"status":"ok","service":"<name>"}`
- [ ] Canonical URI format: `chittycanon://core/services/{name}`
- [ ] Package name matches service name
- [ ] Hono/Workers stack or equivalent edge runtime

### Chitty Compliant (standard)

- [ ] All "Compatible" checks pass
- [ ] CHARTER.md with full YAML frontmatter
- [ ] CHITTY.md with full YAML frontmatter
- [ ] CLAUDE.md present and accurate
- [ ] Tier consistency across all docs
- [ ] Auth uses `CHITTY_AUTH_SERVICE_TOKEN` pattern
- [ ] No `(c as any)` type-safety violations
- [ ] Entity type ontology compliance (P/L/T/E/A)
- [ ] Wrangler config compliant (naming, compat date, tail consumer)
- [ ] No hardcoded secrets

### ChittyCertified (production-ready)

- [ ] All "Compliant" checks pass
- [ ] Service registered in ChittyRegistry
- [ ] Live health endpoint responds at `{name}.chitty.cc/health`
- [ ] `/api/v1/status` endpoint operational
- [ ] Consumer contract tests exist and pass
- [ ] Database queries are tenant-scoped (multi-tenant services)
- [ ] All document statuses at CERTIFIED or higher

### ChittyCanonical (source of truth)

- [ ] All "Certified" checks pass
- [ ] ChittyGov compliance approval on record (required reports, registrations, regulatory adherence verified)
- [ ] All document frontmatter status = CANONICAL
- [ ] Zero advisory-level issues
- [ ] Full agent audit (Canon Cardinal + Schema Overlord + Compliance Sergeant + Connect Concierge) passes clean

## Certification Lifecycle

```
[No Badge] --> ChittyOS Compatible --> Chitty Compliant --> ChittyCertified --> ChittyCanonical
                                                                |
                                                                v
                                                           DEPRECATED
```

## What Can Be Certified

| Artifact Type | Applicable Badges |
|---------------|------------------|
| **Service** | All 4 badges (full progression) |
| **Document** | Compliant, Certified, Canonical (no health endpoint needed) |
| **Schema** | Compatible, Compliant (cross-service compatibility) |
| **API Contract** | Compatible, Compliant, Certified (consumer tests) |
| **Wrangler Config** | Compatible, Compliant |
| **Code Module** | Compatible, Compliant (type safety, patterns) |

## Certification Process

1. **Identify artifact** type and current badge level
2. **Determine target badge** (next level up, or specific level requested)
3. **Run badge-specific checks** against criteria above
4. **For ChittyCertified+**, dispatch background agents for deep analysis
5. **Award badge** if all criteria pass, or report gaps
6. **Update frontmatter** status field to match badge level:
   - Compatible = DRAFT
   - Compliant = PENDING
   - Certified = CERTIFIED
   - Canonical = CANONICAL
7. **Generate certification report**

## Certification Report Format

```
CHITTYCERTIFY CERTIFICATION REPORT
====================================
Artifact: {name}
Type: {service|document|schema|api-contract|wrangler-config|code-module}
URI: {chittycanon://...}
Current Badge: {None|Compatible|Compliant|Certified|Canonical}

TARGET: {badge name}

BADGE CRITERIA
  {check 1} .............. [PASS/FAIL]
  {check 2} .............. [PASS/FAIL]
  ...

RESULT: {AWARDED / NOT AWARDED}
  Badge: {badge name or "none - {N} checks failed"}

HIGHEST BADGE EARNED: {badge name}
  Certifier: chittycanon://core/services/chittycertify
  Date: {YYYY-MM-DD}

NEXT LEVEL: {badge name}
  Gaps: {list of failing checks to address}
```
