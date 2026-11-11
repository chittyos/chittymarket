---
uri: chittycanon://docs/ops/policy/chittymarket-charter
namespace: chittycanon://docs/ops
type: policy
version: 1.1.1
status: DRAFT
registered_with: chittycanon://core/services/canon
title: "ChittyMarket Charter"
certifier: chittycanon://core/services/chittycertify
visibility: INTERNAL
---

# ChittyMarket Charter

## Classification

- **Canonical service URI**: `chittycanon://core/services/chittymarket`
- **Tier**: 3 (Operational / control plane)\n- **Architecture tier:** Tier 3
- **Organization**: CHITTYOS
- **Deployment form**: private repository + deterministic build/release workflows
- **Standalone HTTP domain**: none
- **Network projections**: existing ChittyRegistry, Ch1tty/MCP, Apps/connectors, and runtime-specific package surfaces as appropriate

ChittyMarket is not an application-data service and is not a second canonical registry. A standalone `market.agent.chitty.cc` service is not part of the current architecture and must not be provisioned merely to satisfy an old document.

## Mission

Operate the private capability supply chain and projection control plane for ChittyOS.

ChittyMarket takes an already-governed capability identity and produces trusted, policy-constrained runtime packages and discovery projections for supported platforms. It manages how a capability is packaged, validated, released, deprecated, and projected. It does not own canonical identity, credentials, application data, execution state, or evidence truth.

## Authority Boundary

```text
ChittyCanon / ChittyRegister / ChittyRegistry
  identity + registration + discoverability
        |
        v
ChittyMarket
  projection definition + package policy + validation + release
        |
        v
Skills / Plugins / Apps / MCP / Agent Cards / local projections
        |
        v
Ch1tty / domain Apps / MCP servers / agents / local runtimes
```

Supporting boundaries:

- **ChittyConnect / ChittyAuth** — delegated authentication and credential brokering.
- **Ch1tty / MCP / Apps / agents** — execution surfaces; they do not define canonical capability identity.
- **Legal / evidence systems** — evidence-grade truth, custody, filings, disputes, ownership, and matter-specific records.

## Scope

### Responsible For

- Market-owned projection definitions under `canonical/`.
- Deterministic generation or reconciliation of runtime/distribution artifacts.
- Native package projections for supported platforms.
- Capability placement policy: skill vs app/connector vs MCP vs tool vs agent vs local-only vs legal-only.
- Admission controls for identity, authority, risk, publication, and provenance.
- Drift detection between projection definitions, generated artifacts, and runtime/discovery surfaces.
- Release-state truth: authored, identity-resolved, projected, validated, runtime-verified, signed, published, indexed.
- Private-to-public publication gating when a deliberately public package is approved.
- Deprecation, migration, alias, and compatibility policy for Market projections.
- CI execution-substrate projection policy, including the governed runner selector used by repository workflows.

### Not Responsible For

- Minting ChittyID or canonical capability identity.
- Replacing ChittyRegister or ChittyRegistry.
- Storing application business data.
- Holding long-lived credentials or secrets.
- Acting as the legal/evidence source of truth.
- Owning runtime execution state for domain agents.
- Creating a new database, schema, registry, or always-on service merely for marketplace metadata.
- Treating a successful file projection as proof that a target runtime loaded or executed it.

## Product Invariants

1. **One canonical capability, many controlled projections.**
2. **Identity first.** Never derive a canonical capability ID from display title, group, slug, package name, file path, or runtime artifact.
3. **Generated artifacts are outputs.** `marketplace.json`, `capabilities.generated.json`, native plugin manifests, skills, and agent cards are not canonical identity authorities.
4. **Projection is not verification.** Dispatch, static validation, projection audit, native runtime verification, publication, and indexing are separate facts.
5. **Fail closed on unresolved identity or authority.** An authored definition may remain HOLD; it may not be silently published.
6. **Private authoring, explicit publication.** Public distribution must be generated through an allowlisted publication policy; the private repository is never made public by scrub-and-hope.
7. **Lowest-power safe projection.** Do not create an MCP server because a skill exists, or an agent because a workflow has multiple steps.
8. **Startup mode applies.** Prefer included/serverless/event-driven infrastructure and avoid new always-on compute or stores without measured need.

## Authoritative Sources

For any capability decision, use the highest available source:

1. ChittyCanon / ChittyRegister / ChittyRegistry for identity and ownership.
2. Live platform/runtime surfaces for deployed state.
3. ChittyMarket `canonical/` for Market-owned projection definitions.
4. Generated Market manifests for delivery state only.
5. Git history, issues, and audit artifacts for provenance and migration evidence.

During the current migration, an already-published overlay binding may preserve an established capability reference until that reference is backfilled into the Market-owned projection definition. New projections must carry explicit upstream identity.

## Release Lifecycle

```text
AUTHORED
  -> IDENTITY_RESOLVED
  -> PROJECTED
  -> VALIDATED
  -> RUNTIME_VERIFIED
  -> SIGNED
  -> PUBLISHED
  -> INDEXED
```

No earlier state implies a later state.

## Interfaces

ChittyMarket currently exposes repository/build interfaces rather than a standalone HTTP API:

| Interface | Purpose |
|---|---|
| `canonical/` | Market-owned projection definitions |
| `scripts/market-reconcile.py` | Identity-first inventory reconciliation/compiler |
| `chittyagent-dispatch` | Runtime projection + projection drift/verification state |
| `/market` skill | Operator-facing discovery/management workflow |
| GitHub PR + CI | Admission, validation, review, and release evidence |
| ChittyRegistry / Ch1tty / platform directories | Downstream discovery/execution projections |

Any future network API is a separate product/deployment decision and must reuse existing identity/auth/runtime infrastructure rather than create a parallel Market backend by default.

## CI Execution Substrate Policy

Runner selection is a **Market-owned runtime projection**, not a new capability, identity class, or agent.

```text
repository / governed owner
  -> workload class + risk boundary
  -> ChittyMarket execution-substrate policy
  -> GitHub CI_RUNNER projection
  -> permitted GitHub runner group / labels
```

Rules:

- ChittyCanon / ChittyRegister / ChittyRegistry remain authoritative for canonical identity and ownership inputs.
- ChittyEntity implementations may expose governed entity/ownership context, but ChittyEntity does not become the CI scheduler or runner authority.
- Ordinary GitHub Actions jobs are not ChittyAgents. ChittyAgent is used only when delegated execution materially requires planning, tool use, or autonomous multi-step behavior.
- ChittyMarket workflows must resolve `runs-on` through `${{ vars.CI_RUNNER || 'ubuntu-latest' }}` unless a reviewed exception is documented in the same change.
- Repository/org variable `CI_RUNNER` is the configuration projection point. GitHub runner-group membership and repository access remain GitHub enforcement boundaries and must not be inferred from Market metadata.
- A self-hosted runner is an execution substrate, never an evidence or application-data store.
- No new database, registry, schema, or always-on service is introduced for runner routing.

## Dependencies

| Type | Service / Surface | Purpose |
|---|---|---|
| Identity | ChittyCanon | Canonical URI/ontology authority |
| Registration | ChittyRegister | Registration authority / admission boundary |
| Discovery | ChittyRegistry | Discoverable ecosystem catalog |
| Auth | ChittyConnect / ChittyAuth | Delegated credentials and auth integration |
| Gateway | Ch1tty | Slim search/execute routing and controlled MCP access |
| Source control | GitHub | Code source of truth, PRs, CI, release receipts |
| Runtime | Native platform/plugin/app formats | Delivery surfaces generated from Market definitions |
| Legal | Legal/evidence systems | Matter-specific truth and non-repudiable records |

## Security / Publication Boundary

The working repository is private. Historical public exposure must be treated as a security fact.

Approved publication shape:

```text
PRIVATE AUTHORING
  -> publication policy / allowlist
  -> generated sanitized package
  -> public distribution
```

Matter-specific legal content, private operator configuration, internal network details, secrets, and account identifiers must never cross that boundary.

## Ownership

| Role | Owner |
|---|---|
| Product / service owner | ChittyOS |
| Canonical identity authority | ChittyCanon / ChittyRegister / ChittyRegistry |
| Projection/release authority | ChittyMarket |
| Credential authority | ChittyConnect / ChittyAuth |
| Legal/evidence authority | Legal space / evidence systems |

## Compliance Status

- [x] CHARTER.md present
- [x] CHITTY.md present
- [x] AGENTS.md present
- [x] SECURITY.md present
- [x] Identity-first reconciliation path exists
- [x] Dispatch and verification state are modeled separately
- [ ] Governance metadata fully backfilled from legacy generated overlay
- [ ] Native runtime verification receipts implemented for every supported target
- [ ] Supply-chain signing/provenance release gate implemented
- [ ] Re-certification after migration completion

---
*Charter Version: 1.1.1 | Updated: 2026-10-05*
