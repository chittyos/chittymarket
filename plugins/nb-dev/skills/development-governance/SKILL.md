---
name: development-governance
description: Route ChittyOS architecture, canonical identity, capability inventory, certification, ontology, and MCP gateway decisions to the authoritative governance skills and services. Use for governance reviews, architecture changes, duplicate capability decisions, compliance, registration, or creating new ChittyOS services.
---

# Governance and Authority Routing

1. Identify the actual job-to-be-done, service owner, risk and existing ChittyRegistry identity. Separate canonical capability from its ChatGPT skill, plugin, agent or MCP projection.
2. For capability taxonomy, duplicates, promotion, retirement or plugin/skill placement, **invoke existing `capability-governor`**. Do not create a second capability registry or schema.
3. For service compliance, CHARTER/CHITTY/AGENTS triad, registration readiness and certification, **invoke `chittyos-compliance`**; distinguish ChittyGov (policy), ChittyCanon (ontology), ChittyRegister (registration), ChittyRegistry (discovery), ChittyCertify (certification), and ChittyCert (PKI).
4. For MCP portal/gateway reconciliation, **invoke `mcp-gateway-reconciler`**. For legal records/custody use matter-isolated evidence skills; do not move legal evidence into a generic development workflow.
5. Inspect live connected tools through `chittyos-mcp-routing`; do not assume MCP availability or fabricate approvals.
6. Return canonical owner, evidence, requested change class, approval gate, and recommended existing-first implementation. Record decision in the canonical work item.
