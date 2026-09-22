---
uri: chittycanon://docs/ops/policy/chittymarket-security
namespace: chittycanon://docs/ops
type: policy
version: 1.1.0
status: DRAFT
registered_with: chittycanon://core/services/canon
title: "ChittyMarket Security Policy"
certifier: chittycanon://core/services/chittycertify
visibility: INTERNAL
---

# ChittyMarket Security Policy

> `chittycanon://core/services/chittymarket` | Tier 3 (Operational / control plane)

## Threat Model

ChittyMarket is primarily the security boundary for the private **capability supply chain and projection control plane**.

It does not currently require a standalone HTTP runtime. Its attack surface is the path by which capability definitions become installable or executable packages:

```text
canonical identity
  -> Market projection definition
  -> generated package/projection
  -> validation
  -> runtime verification
  -> provenance/signing
  -> publish/index
  -> operator/runtime execution
```

A compromise anywhere in this path can change what an operator or agent is allowed to discover, install, or execute.

The principal risks are:

- canonical identity confusion or capability spoofing;
- publication of private/operator/legal material;
- privilege escalation through overly broad package/tool/agent projections;
- projection drift or hand-edited generated files;
- stale or unverified runtime claims;
- unpinned or compromised external dependencies;
- prompt/tool poisoning carried through capability metadata;
- credentials leaking into manifests, logs, or package payloads;
- false provenance or release-state claims.

## Security Invariants

1. **Identity is upstream.** Market must not derive a canonical capability ID from a title, slug, group, package name, or file path.
2. **Generated artifacts are not authority.** A manifest or projection may carry references but cannot establish identity or ownership.
3. **Projection is not verification.** A rendered artifact may still fail static validation, projection audit, or native runtime verification.
4. **Fail closed.** Unresolved identity, conflicting ownership, missing governance metadata, or failed verification blocks promotion.
5. **Least privilege by surface.** Use the lowest-power projection that satisfies the job.
6. **Private by default.** The working repository remains private.
7. **Public release is generated.** Publication uses an explicit allowlist/policy and sanitized output, not repository-wide scrubbing.
8. **Legal/evidence boundary is hard.** Matter-specific evidence, filings, custody records, ownership facts, and non-repudiable legal data remain in restricted legal/evidence systems.
9. **Prompts are not controls.** Skill prose, agent prompts, manifest flags, and tool annotations do not substitute for server-side authorization.
10. **No secret custody in Market.** ChittyMarket package metadata must never become a credential store.

## Authority Boundaries

| Boundary | Security responsibility |
|---|---|
| ChittyCanon | Canonical namespace and ontology |
| ChittyRegister | Registration/admission gate |
| ChittyRegistry | Discoverable registered identity |
| ChittyMarket | Projection/package/release policy |
| ChittyConnect / ChittyAuth | Delegated auth and credential brokering |
| Ch1tty / MCP / Apps | Controlled execution routing and tool boundary |
| Domain agents | Delegated execution state |
| Legal/evidence systems | Restricted evidentiary truth and custody |

A Market projection must preserve these boundaries rather than collapsing them into a single "marketplace service."

## Repository Trust Boundaries

| Boundary | What crosses it | Required control |
|---|---|---|
| PR -> `main` | Source definitions, generators, package metadata | Review + CI + identity/provenance gates |
| `canonical/` -> runtime projections | Agent/skill/tool behavior | Deterministic dispatch + drift audit |
| Market inventories -> native packages | Capability references and distribution metadata | Identity-first reconcile + schema validation |
| Private source -> public package | Potentially sensitive source/material | Explicit allowlist + generated sanitized projection |
| Package -> runtime | Executable instructions/tools/config | Native runtime validation where supported |
| Registry/gateway -> execution | Discoverable capability to executable action | AuthZ, scope, approval, runtime verification |
| External dependency -> package | Third-party/org code | Pinning/provenance/dependency review |

## Identity and Projection Controls

`scripts/market-reconcile.py` enforces migration-safe identity rules:

- already-published artifacts may retain their established capability binding while migration is in progress;
- a new/unpublished definition must provide an explicit `chittycanon://capability/...` identity before it can be emitted;
- a conflicting explicit identity is an error;
- unresolved unpublished definitions remain HOLD;
- new projections compile disabled by default;
- governance metadata is not inferred from a name/title/category.

The compiler must not silently invent or repair an identity.

## Dispatch and Verification Controls

`chittyagent-dispatch` records three different security facts:

```text
dispatch.status
verification.projection.status
verification.runtime.status
```

A successful adapter render records only dispatch success. Projection verification is recorded separately by audit. Native runtime verification remains `not_run` until a real target client/runtime check is executed.

This distinction prevents the most dangerous false-success state: a system that says "synced" after writing a file even though the projected artifact drifted or never loaded in the target runtime.

Schema-mimic tests are useful but are not equivalent to native runtime proof.

## Publication Boundary

The current repository is private. Prior public exposure must be assumed for incident/risk purposes.

Approved public release model:

```text
PRIVATE AUTHORING
  -> publication allowlist/policy
  -> generated sanitized package
  -> privacy/leak gate
  -> provenance/signature
  -> public distribution
```

Prohibited model:

```text
private repo
  -> regex scrub
  -> publish the same repository
```

Sensitive categories that must not cross the publication boundary include:

- matter-specific legal/evidence content;
- private email addresses or account identifiers;
- property, claim, insurance, banking, or payment details;
- internal network topology, IPs, device/camera inventory;
- secret-binding details that materially expose production security posture;
- local filesystem paths tied to operator-private environments;
- non-public service/account/database identifiers when they are not required by the package contract.

## Legal / Evidence Boundary

Generic capability definitions may describe reusable legal/evidence methods, but must not embed matter-specific facts.

Legal-grade capabilities require:

- explicit restricted placement;
- authoritative source/evidence references;
- custody/timestamp/hash policy where applicable;
- real enforcement at the legal/evidence boundary;
- no public projection unless a separate sanitized, non-matter-specific package is explicitly approved.

## Authorization

ChittyMarket does not replace authorization infrastructure.

For projected capabilities:

- interactive user access should use supported platform/OAuth authorization;
- managed organization access should use organization-managed authorization where available;
- agent/workload access should use short-lived delegated/workload identity mechanisms where supported;
- legacy service-token usage should be treated as migration debt, not the target state;
- credentials should be brokered through ChittyConnect/ChittyAuth-compatible flows;
- hardcoded credentials or manifest-embedded secrets are prohibited.

Write/admin/deploy/legal capabilities require explicit authority and should never be ambient solely because a plugin is installed.

## Secrets

No secret value belongs in this repository.

A capability may declare that it requires auth or a broker, but the package must not contain the credential itself. Secrets must remain in the approved credential infrastructure and be resolved at execution time.

Do not ask an operator to paste production credentials into a skill, manifest, issue, or generated package.

## External Dependencies

External plugin/package sources are a trust boundary.

Requirements:

- pin or otherwise establish reproducible provenance where the upstream format permits;
- record unresolved unpinned dependencies as risk, not as implicitly trusted;
- prefer native platform/app integrations over cloning APIs into Market packages;
- verify that package ownership and source match the canonical capability identity;
- include dependency/BOM provenance in the release pipeline as that layer is implemented.

Organization ownership alone is not sufficient proof of immutable contents.

## Hooks and Local Controls

Operator-local hooks may add useful defense in depth, but Market must not claim they are active unless verified on the target environment.

A rule referenced in package metadata but implemented only in local configuration is not a repository-enforced control.

Mandatory controls belong in CI, auth services, execution gateways, server-side middleware, registry/admission policy, or restricted Legal/evidence systems.

## Provenance

Current content hashes are a substrate, not a complete supply-chain attestation.

Target release evidence should bind:

```text
source/content hash
  -> CI build provenance
  -> dependency/BOM evidence
  -> approved signing identity
  -> release bundle
  -> optional internal ChittyLedger audit anchor
```

Do not treat an internal ledger anchor as a substitute for software supply-chain provenance.

Do not publish private/operator identities into public transparency systems without a deliberate privacy review.

## CI Controls

The validation workflow should gate at least:

- plugin/package lint;
- matter/private-data leak checks;
- inventory/overlay coverage;
- overlay schema;
- source-link freshness;
- content-hash verification;
- identity-first Market reconciliation;
- Market reconciliation regression tests;
- dispatch-state regression tests;
- dispatch projection idempotency;
- dispatch drift/orphan audit;
- native manifest idempotency;
- runtime smoke checks, with explicit reporting when a schema-mimic fallback was used.

A workflow file is not itself enforcement. Required branch checks and merge policy must be verified separately.

## Startup-Mode Security

Security controls must not create an always-on paid backend merely for convenience.

Prefer:

- deterministic CI/event-driven checks;
- existing ChittyRegistry/Ch1tty/Auth infrastructure;
- queues or deferred event processing where needed;
- local/build-time verification when it is authoritative.

Do not trade away identity, custody, auth, or publication controls for cost savings.

## Incident Handling

Treat these as security incidents or release blockers:

- unexpected capability identity change;
- generated/public package containing private or legal matter data;
- projection/runtime mismatch after release;
- compromised or unexpectedly changed external dependency;
- secret committed to Market or generated output;
- bypass of publication allowlist or auth scope;
- false runtime-verification or provenance claim.

Contain by disabling/de-indexing the affected projection where possible, preserve evidence, identify the authoritative source, and remediate through the existing work chain.

---
*Policy Version: 1.1.0 | Updated: 2026-09-22*
