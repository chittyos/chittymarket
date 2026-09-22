---
uri: chittycanon://docs/ops/architecture/chittymarket
namespace: chittycanon://docs/ops
type: architecture
version: 1.1.0
status: DRAFT
registered_with: chittycanon://core/services/canon
title: "ChittyMarket"
certifier: chittycanon://core/services/chittycertify
visibility: INTERNAL
---

# ChittyMarket

> `chittycanon://core/services/chittymarket` | Tier 3 (Operational / control plane)

## Product

ChittyMarket is the private capability supply chain and projection control plane for ChittyOS.

Its job is to take an already-governed capability identity and produce controlled packages and runtime projections without creating parallel identity, auth, data, or evidence systems.

```text
Canon / Register / Registry
  -> Market projection definition
  -> deterministic package/projection
  -> validation
  -> runtime verification
  -> provenance/signing
  -> publish
  -> index
```

The product is the repository/build/release control plane. There is no standalone ChittyMarket HTTP runtime today, and no current requirement to deploy `market.agent.chitty.cc`.

## Authority Model

| Concern | Authority |
|---|---|
| Canonical capability identity / ontology | ChittyCanon |
| Registration / admission | ChittyRegister |
| Discoverable ecosystem catalog | ChittyRegistry |
| Projection/package/release policy | ChittyMarket |
| Credentials / delegated auth | ChittyConnect / ChittyAuth |
| Slim execution routing | Ch1tty |
| Domain execution | Apps, MCP servers, agents, local runtimes |
| Legal/evidence truth | Legal / evidence systems |

ChittyMarket may carry resolvable references to these systems; it does not replace them.

## Source Hierarchy

### Authoritative

- `canonical/` — Market-owned projection definitions.
- ChittyCanon / ChittyRegister / ChittyRegistry — upstream identity and ownership.
- GitHub history / PRs / CI — implementation and release evidence.

### Materialized / generated

- `marketplace.json` — distribution inventory and operator state; not canonical identity.
- `capabilities.generated.json` — materialized capability overlay; not canonical identity.
- `.claude-plugin/marketplace.json` and other native manifests — generated delivery surfaces.
- Runtime-specific skills/agents/tool manifests under `plugins/` — generated projections.

During migration, existing overlay records may temporarily preserve established identity/governance data for already-published artifacts. New artifacts must not use the generated overlay as an authority.

## Core Components

| Component | Role |
|---|---|
| `scripts/market-reconcile.py` | Identity-first reconciliation/compiler; refuses invented identity |
| `chittyagent-dispatch` | Deterministic runtime projection and drift reconciliation |
| `scripts/lib/state.py` under dispatch | Durable separation of dispatch, projection verification, runtime verification |
| `scripts/overlay-provenance.py` | Content-hash provenance substrate |
| `scripts/validate-overlay-schema.py` | Overlay structural validation |
| `scripts/check-overlay-coverage.sh` | Inventory/overlay coverage |
| GitHub CI | Admission and regression controls |
| `/market` skill | Operator-facing management/discovery workflow |

## Truth States

ChittyMarket does not use a single boolean such as `synced` or `enabled` as release truth.

| State | Meaning |
|---|---|
| `AUTHORED` | Projection definition/source exists |
| `IDENTITY_RESOLVED` | Upstream canonical capability identity is known |
| `PROJECTED` | Target package/artifact was rendered |
| `VALIDATED` | Static/schema/policy checks passed |
| `RUNTIME_VERIFIED` | Target runtime/client actually loaded or executed it |
| `SIGNED` | Approved provenance/signature exists |
| `PUBLISHED` | Artifact is available on intended distribution surface |
| `INDEXED` | Discovery surface resolves to the intended published/runtime artifact |

No state implies the next one.

## Dispatch State

Per-projection dispatch state lives under `canonical/.dispatch-state/<kind>/<name>.json`.

New state records distinguish:

```json
{
  "dispatch": {
    "status": "projected"
  },
  "verification": {
    "projection": {
      "status": "pending"
    },
    "runtime": {
      "status": "not_run"
    }
  }
}
```

`dispatch.sh verify` may mark the repository projection audit passed/failed. It must not set runtime verification. Native runtime proof is a separate release stage.

## Capability Placement

Use the lowest-power safe projection:

| Surface | Use when |
|---|---|
| Skill | Repeatable method, SOP, convention, procedure, domain operating logic |
| App / connector | External service, API, data integration, or user-authorized action |
| MCP server | Controlled integration/execution boundary exposing tools |
| Tool | Small operation beneath an App/MCP boundary |
| Agent | Delegated actor that materially needs planning/tool use/autonomous multi-step execution |
| Local-only | Filesystem/browser/device/machine-privileged work |
| Legal-only | Evidence, filings, disputes, custody, ownership, valuation, non-repudiable records |

Do not create an MCP server merely because a skill exists. Do not create an agent merely because a workflow has multiple steps.

## Publication Model

The repository is private. Any public marketplace/package is a generated projection, not a visibility change on this repository.

```text
private source
  -> explicit publication allowlist/policy
  -> sanitized generated package
  -> provenance/signature
  -> public distribution
```

Historical public exposure is treated as a security fact and is not evidence that current files are publication-safe.

## Startup-Mode Architecture

ChittyMarket is intentionally repository/build-centric:

- no new database for marketplace metadata;
- no always-on Market worker;
- no polling loop merely to keep indexes synchronized;
- prefer CI/event-driven reconciliation and existing registries/gateways;
- queues/sinks may be used for deferred work when a write pipeline needs buffering;
- any future paid or always-on runtime requires measured need and a separate product decision.

## Native Projection Strategy

Prefer native standards at the boundary and Chitty-specific governance inside:

- portable Agent Skills for reusable method;
- native plugin/package manifests for installable capability packs;
- Apps/MCP for service integration;
- A2A Agent Cards only for true delegated actors;
- Ch1tty remains intentionally slim for search/execute routing.

Do not fork an upstream package schema when an additive Chitty extension or separate governance reference is sufficient.

## Security Posture

Primary risk is supply-chain and authority confusion:

- identity must resolve upstream before projection;
- new projections compile disabled by default;
- generated artifacts are never authority;
- plugin/skill prose is not a security boundary;
- write/admin/deploy/legal capabilities require real enforcement at auth/gateway/runtime boundaries;
- matter-specific legal data stays out of generic/public Market artifacts;
- private-to-public release is allowlisted and generated.

See `SECURITY.md`.

## Ecosystem Dependencies

| Service / Surface | Purpose |
|---|---|
| ChittyCanon | Canonical namespace and ontology |
| ChittyRegister | Registration authority |
| ChittyRegistry | Discoverable capability/service catalog |
| ChittyConnect / ChittyAuth | Delegated auth and credential broker |
| Ch1tty | Slim capability discovery/execution gateway |
| GitHub | Source control, PR review, CI, release receipts |
| Native runtime/plugin/app ecosystems | Delivery and execution surfaces |
| Legal / evidence systems | Restricted evidence-grade truth |

## Certification

- **Document status**: DRAFT
- **Certification status**: pending re-certification after the 2026 architecture migration
- **Certifier**: `chittycanon://core/services/chittycertify`

Do not infer a current certification badge from older documents or generated manifests.

## ChittyDNA

- **Canonical service URI**: `chittycanon://core/services/chittymarket`
- **Lineage**: ChittyOS capability governance / distribution control plane
- **DNA hash**: pending governed provenance process

---
*Architecture Version: 1.1.0 | Updated: 2026-09-22*
