---
uri: chittycanon://docs/ops/audit/chittymarket-control-plane-2026-11-01
namespace: chittycanon://docs/ops
type: summary
version: 1.0.0
status: DRAFT
registered_with: chittycanon://core/services/canon
title: "ChittyMarket Live Control-Plane Audit — 2026-11-01"
certifier: chittycanon://core/services/chittycertify
visibility: INTERNAL
---

# ChittyMarket Live Control-Plane Audit — 2026-11-01

## Scope

Read-only reconciliation of:

1. ChittyCanon ecosystem/product boundaries;
2. ChittyMarket capability ontology and package inventory;
3. active ChittyApps repositories as product/application observations;
4. live Cloudflare accounts, Workers, MCP Portals, MCP Servers, and AI Gateways.

This audit does **not** create product identities, canonical capability identities, portals, servers, schemas, databases, or registry records.

## Authority Findings

### Canonical ontology

ChittyCanon remains the authority for the P/L/T/E/A entity ontology and the `chittycanon://` namespace.

Sources:
- `chittyfoundation/chittycanon/CHARTER.md`
- `chittyfoundation/chittycanon/specs/ONTOLOGY_LIFECYCLE.md`

### Ecosystem/product boundary

The current ChittyCanon ecosystem reference separates:

- **CHITTYFOUNDATION** — protocols, specs, governance;
- **CHITTYOS** — platform APIs, SDKs, infrastructure and developer tools;
- **CHITTYCORP** — commercial products and services;
- **CHITTYAPPS** — user-facing applications.

Source: `chittyfoundation/chittycanon/reference/ECOSYSTEM.md`.

The reference names ChittyFinance and ChittyChat as application examples. It is informational, not a canonical current-product catalog.

### Capability ontology

ChittyMarket's governed JTBD groups are:

`workspace`, `build`, `ship`, `govern`, `legal`, `finance`, `connect`, `local-lab`, `agent-runtime`, `market`, `internal`.

Source: `docs/architecture/CHITTYMARKET_CAPABILITY_ROUTER.md`.

These groups are marketplace navigation/routing ontology. They are **not** the commercial product family.

### Product-set evidence status

Active ChittyApps repositories include application/product candidates such as ChittyFinance, ChittyChat, ChittyPortal, ChittyDashboard, ChittyCharge, ChittyReception, ChittyConcierge, ChittyProof, ChittyXL, ChittyTrace, ChittyFlow, ChittyFormFill, ChittyForge, ChittyEvidence, and ChittyPro ecosystem components.

Source: live GitHub organization inventory for `chittyapps`, checked 2026-11-01.

**Finding:** repository presence is observed implementation evidence only. No single canonical, exhaustive current-product catalog was found in the checked ChittyCanon/ChittyApps sources. ChittyMarket therefore MUST NOT synthesize product identity from repository or plugin names. Product mapping remains `HOLD` unless canonical identity/ownership resolves upstream.

## ChittyMarket Package Inventory

The Agent Plugin marketplace manifest currently contains 15 local install packages:

- `ch1tty`
- `chittyagent-autobot`
- `chittyagent-dispatch`
- `chittymarket-canonical`
- `chittymarket-manager`
- `chittyos-core`
- `chittyos-devops`
- `chittyos-finance`
- `chittyos-governance`
- `chittyos-gws`
- `chittyos-legal`
- `chittyos-mcp`
- `chittyos-proxy-agents`
- `neon-mcp`
- `nowebmaster`

Source: `.agents/plugins/marketplace.json`.

**Disposition:** keep these as package identities for compatibility until capability ownership, dependency edges, runtime usage, and retirement evidence justify a merge. Do not present them as fifteen products.

## Live Cloudflare Control Plane

Read-only Cloudflare API snapshot taken 2026-11-01.

| Account | Workers | MCP Portals | MCP Servers | AI Gateways |
|---|---:|---:|---:|---:|
| ChittyCorp LLC | 117 | 8 | 65 | 4 |
| Digital Dossier | 100 | 0 | 0 | 1 |
| Furnished-Condos | 14 | 0 | 1 | 2 |

Account boundaries are preserved. Counts are not additive product counts.

### ChittyCorp MCP Portals

| Portal | Hostname | Code Mode | SWG | Server memberships |
|---|---|---|---|---:|
| `gws-portal` | `portal.gws.chitty.cc` | default_on | yes | 37 |
| `dev-portal` | `dev.chitty.cc` | default_on | yes | 35 |
| `chode` | `chode.chitty.cc` | default_on | yes | 56 |
| `chittymcp-vm` | `vm.ch1tty.com` | opt_in | no | 1 |
| `chittycomms` | `msg.chitty.cc` | opt_in | yes | 14 |
| `chitty-mcp` | `mcp.chitty.cc` | opt_in | yes | 64 |
| `cf` | `cf.chitty.cc` | default_on | yes | 16 |
| `apf-portal` | `portal.actors.chitty.cc` | default_on | yes | 21 |

Membership counts overlap because the same upstream server can be exposed through multiple portals.

### ChittyCorp MCP readiness

Of 65 configured MCP servers:

- **27 ready**
- **34 error**
- **2 waiting**
- **2 stale**

Examples of material drift observed in the live control plane:

- `schema`: newly configured; version-negotiation/connectivity failure; no successful sync.
- `secrets`: waiting; authentication required; no successful sync.
- `google`: waiting for authentication.
- `finance`: authorization failure against required service token.
- `gws`: invalid/missing token at sync.
- `ext-apify` and `cf-bindings`: stale / needs reauthorization.
- multiple agent-backed MCP servers currently time out during Cloudflare synchronization.

This means **58% of configured ChittyCorp MCP servers are not currently ready** (38 of 65).

### Furnished-Condos

The only configured MCP server, `harvest`, is stale and has never completed a successful sync in the current portal record because OAuth credentials require repair.

### AI Gateway

Observed gateways:

- ChittyCorp: `default`, `central`, `finance`, `chittycounsel`
- Digital Dossier: `chitty`
- Furnished-Condos: `default`, `furnished-condos`

AI Gateway is model-routing/policy infrastructure, not product or capability identity.

## Cloudflare Management Fit

Cloudflare MCP Server Portals already provide runtime functions ChittyMarket should consume rather than duplicate:

- grouping remote MCP servers behind portal endpoints;
- per-portal server/tool curation;
- Access/OAuth state;
- Code Mode policy;
- Secure Web Gateway controls;
- server synchronization state;
- tool-call analytics / request observability.

Official references:
- https://developers.cloudflare.com/cloudflare-one/access-controls/ai-controls/mcp-portals/
- https://developers.cloudflare.com/agents/model-context-protocol/protocol/governance/

## Synthesis Decision

Use this ownership chain:

```text
canonical product/application identity (when applicable)
        ↕ many-to-many
canonical capability identity / JTBD
        ↓
ChittyMarket projection + install package
        ↓
Ch1tty / App / Cloudflare MCP Portal runtime exposure
        ↓
MCP server / agent / Worker / local execution substrate
```

### Keep

- the 11 JTBD capability groups as the user-facing marketplace ontology;
- the current 15 plugin package names as compatibility/distribution units;
- ChittyCanon/Registry as identity authority;
- ChittyMarket as projection/package/release authority;
- Cloudflare MCP Portals as a live remote-MCP policy/distribution surface.

### Demote from product semantics

- plugin/package names;
- Worker names;
- MCP server IDs;
- portal IDs;
- AI Gateway IDs;
- repository names.

### Hold

- any package-to-product-family merge until a canonical current-product catalog/identity is resolved;
- any package retirement until dependency and telemetry evidence supports it;
- any production Cloudflare mutation from this audit.

## Required Follow-up

1. Reconcile the 38 non-ready ChittyCorp MCP server records before using portal membership as runtime-verification evidence.
2. Resolve a canonical current-product catalog/identity source for ChittyCorp/ChittyApps if product-family navigation is required in Market.
3. Map capabilities to products only by canonical reference; preserve many-to-many relationships.
4. Keep account scope in all live-runtime projections.
