---
name: chittyos-threat-model
description: |
  Build a practical threat model for ChittyOS services and workflows, including Cloudflare Workers,
  AI inference, MCP tools, webhooks, D1/Neon/R2 data flows, service ownership, and Workers Builds.
  Triggers on threat model, abuse cases, attack surface, security architecture, or ownership map requests.
canon_uri: chittycanon://core/services/chittymarket#skills/chittyos-threat-model
---

# ChittyOS Threat Model

Create a bounded threat model from repository evidence. This is a design and review artifact, not an
authorization to deploy, change permissions, or modify production data.

## Method

1. Define the system, intended users, protected assets, security objectives, and explicit out-of-scope areas.
2. Map components and trust boundaries using actual routes, bindings, MCP tools, queues, databases, buckets,
   AI providers, and build/deploy triggers.
3. Build an ownership map: service/repository, canonical owner, data owner, deploy authority, secret broker,
   downstream consumers, and evidence source. Mark unknown ownership as a finding.
4. Enumerate abuse cases for spoofing, tampering, repudiation, information disclosure, denial of service,
   and privilege escalation. Include AI prompt/tool abuse and webhook replay where relevant.
5. Rank risks by likelihood, impact, exploitability, and blast radius. Separate design risk from confirmed exposure.
6. Identify preventive, detective, and recovery controls. Prefer existing ChittyOS primitives over new infrastructure.
7. Produce a minimal remediation sequence and verification plan.

## Required checks

- Authn and authz are enforced at every externally reachable route and tool boundary.
- Tenant/user scope is carried through reads, writes, background jobs, and result retrieval.
- Webhooks authenticate payloads, reject stale/replayed events, and handle duplicate delivery safely.
- AI tools constrain arguments, validate model output before side effects, and cap input/output/resource usage.
- Prompts, outputs, tokens, headers, and secret material are not written to logs or public storage.
- D1/Neon/R2 permissions follow least privilege and large/sensitive objects have retention controls.
- Worker restarts, client disconnects, retries, and provider failures do not create fail-open state.
- Workers Builds and GitHub checks cannot silently bypass required validation or deploy authorization.
- Ownership, escalation path, and evidence links are recorded for every high-risk asset.

## Output

Return:

- system and trust-boundary summary;
- asset/owner/data-flow table;
- prioritized STRIDE-style abuse-case table;
- existing controls and control gaps;
- remediation backlog with owner, dependency, and verification test;
- residual risk and assumptions;
- explicit human-review items for deploy, credential custody, destructive actions, or external communication.

Never claim a service is secure merely because tests pass. A threat model is complete only when unknown
boundaries and ownership are called out, not silently assumed away.
