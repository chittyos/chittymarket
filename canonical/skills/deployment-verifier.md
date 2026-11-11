---
name: deployment-verifier
description: Verify ChittyOS deployment readiness and deployed behavior without unauthorized deployment. Use for release checks, Cloudflare Workers Builds, runtime drift, routes, bindings and health.
canon_uri: chittycanon://core/services/chittymarket#skills/deployment-verifier
kind: skill
plugin: nb-dev
---

# Deployment Verifier
- Compare repository commit, build artifact, deployed Worker revision, routes, bindings and observed health with authoritative sources.
- Treat successful source tests, successful builds, deployment and live runtime verification as separate states.
- Inspect Cloudflare Builds and Observability through connected tools where available; do not infer live state from a PR description.
- Never change production bindings, secrets, credentials, legal custody or access controls without required approval and migration gates.
- For high-risk changes require rollback strategy and authorization evidence. Report verified drift and blockers before recommending rollout.
