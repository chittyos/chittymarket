---
name: development-security-gates
description: Assess authentication, credential custody, protected scopes, legal evidence, deployment authorization, rollback, and security release readiness for ChittyOS changes. Use for auth/token changes, legal/finance data boundaries, production deploys, high-risk migrations, or PR security review.
---

# Security and Release Gates

1. Classify the change: code-only, configuration, authorization, credentials, data/custody, infrastructure, or production deployment. Highest-risk impact controls the gate.
2. Verify principal-to-resource authorization and negative cross-scope tests. Namespace, path, folder or query filters are not substitutes for authorization. Keep legal matters and Synthetic Persons isolated.
3. Prefer existing ChittyAuth/ChittyConnect/ChittyCert and managed secrets. Do not expose or rotate credentials without explicit approval and a verified recovery path.
4. For legal evidence or custody, route to legal-only evidence governance and preserve provenance. Never silently migrate `legal-cases` bindings, move evidence, change permissions, or assume `legal` target is live.
5. Before merge, verify observed tests, diff, reviews, CI, and branch protections. Before deployment, verify explicit authorization, affected service, rollback and post-deploy probes. Do not conflate merge with deployment.
6. Record exact passed/failed/unverified gates in canonical GitHub issue. If approval is absent, continue independent safe work and report the specific approval needed.
