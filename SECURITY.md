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

## Security Model

ChittyMarket is a private repository/build/release control plane. It does not currently expose a standalone HTTP service and should not be given one merely to satisfy legacy architecture text.

That does **not** mean it has no attack surface. Its primary attack surface is the capability supply chain:

- source definitions determine what gets packaged;
- generated skills/agents/hooks/MCP/App manifests can execute with significant operator authority;
- external package references can change what is installed;
- publication mistakes can expose private operator, infrastructure, or legal information;
- identity or authority drift can turn a benign projection into a confused-deputy path.

A merge or release from this repository can therefore be materially equivalent to a deployment.

## Trust Boundaries

| Boundary | Risk | Required control |
|---|---|---|
| Canon/Register/Registry -> Market | false or unresolved identity | resolve upstream identity; fail closed |
| Market canonical -> generated projection | drift / transformation error | deterministic adapters + idempotency audit |
| Projection -> target runtime | schema/runtime incompatibility | native validation + actual runtime verification |
| Market -> Ch1tty/MCP/App execution | privilege blending | downstream auth/approval enforcement |
| Private source -> public package | data leakage | explicit allowlist + generated sanitized projection |
| External source -> package install | upstream compromise / unreviewed change | pin/attest where possible; admission review |
| PR -> main/release | malicious or accidental change | code review + required CI + release evidence |
| Legal/evidence source -> generic Market artifact | matter leakage / custody contamination | legal-only boundary; no matter-specific publication |

## Canonical Identity Boundary

ChittyMarket does not mint canonical capability identity.

A Market projection may be emitted only when it can preserve or resolve the existing upstream capability reference. A display name, package name, group, slug, filename, runtime path, or local manifest ID is not evidence of canonical identity.

`scripts/market-reconcile.py` enforces the migration rule:

- already-published bindings may be preserved while they are backfilled;
- a new/unpublished projection without explicit `chittycanon://capability/...` identity remains HOLD;
- explicit identity conflict is an error;
- new projections also require explicit governance metadata;
- new compiled marketplace entries default disabled.

Generated manifests remain outputs, not identity authorities.

## Dispatch and Verification Truth

Projection success and verification success are separate security facts.

New dispatch-state records distinguish:

- `dispatch.status: projected` — an adapter rendered/wrote the projection;
- `verification.projection.status: pending|passed|failed` — repository projection audit result;
- `verification.runtime.status: not_run|passed|failed` — native runtime/client result.

`dispatch.sh verify` can update only projection verification. It must not claim runtime verification.

This prevents the failure mode where a successful write leaves the only durable state saying “success” even though a later audit failed.

## Publication Boundary

The working repository is private. Historical public exposure must be assumed.

Future public distribution uses:

```text
private authoring
  -> explicit publication policy / allowlist
  -> generated sanitized artifact
  -> provenance/signature
  -> public distribution
```

Do not republish the private repository after repeated regex scrubbing. Publication is a generated projection problem.

Public artifacts must exclude, at minimum:

- operator-private identity/contact/account details not intended for publication;
- property/residence/network/camera topology;
- credentials, secret-binding values, tokens, or recovery material;
- private banking/payment identifiers;
- local filesystem paths that disclose operator environment;
- matter-specific legal facts, parties, case data, evidence, custody data, or privileged communication;
- internal deployment/admin details not required by the public package.

## Legal / Evidence Boundary

Generic Market artifacts may describe reusable legal/evidence **methods**, but matter-specific facts and evidence remain in Legal/evidence systems.

Any capability involving filings, disputes, evidence custody, ownership, valuation, sworn facts, or non-repudiable legal records must route through the approved legal/evidence boundary. Market publication must never become an alternate evidence store.

## Auth and Credentials

ChittyMarket should not contain long-lived secrets.

Installed capabilities that need credentials must use the existing delegated auth/credential infrastructure. ChittyMarket may declare auth requirements, but enforcement belongs at ChittyConnect/ChittyAuth, the App/MCP server, gateway middleware, or the target platform.

A manifest field, skill instruction, prompt, or tool annotation is not an authorization boundary.

Do not:

- hardcode secrets in Market files;
- create a parallel Market credential store;
- treat a broad service token as a substitute for workload/user delegation;
- let Ch1tty generic execution bypass the downstream capability's authority/approval requirements.

## Ch1tty / Gateway Risk

Ch1tty's intentionally small search/execute surface is useful only if execution preserves downstream identity and authority.

Every routed execution should retain or resolve:

- canonical capability identity;
- origin/runtime target;
- user/workload identity;
- requested permission scope;
- read/write/destructive semantics;
- data/evidence classification;
- approval requirement;
- runtime/provenance receipt where policy requires it.

A generic execute tool that collapses those controls becomes a confused-deputy privilege blender.

## Hooks and Policy-in-Prose

Hooks, skills, manifests, and agent prompts can communicate policy, but they are not sufficient enforcement for high-risk actions.

Required controls belong in:

- authorization services;
- gateway/server middleware;
- CI/release gates;
- legal/evidence systems;
- runtime approval mechanisms;
- durable audit/provenance systems.

If a local hook is part of defense in depth, verify that it is installed and current before relying on it.

## External Dependencies

External package sources are outside the review boundary of this repository unless their exact content is pinned or attested.

Prefer:

- immutable refs or release versions where supported;
- dependency/BOM visibility;
- provenance attestations;
- verified publishers;
- least-privilege installation scopes.

Org ownership alone is not equivalent to content verification.

## Supply-Chain Provenance

Current content hashes are a substrate, not a complete trust chain.

Target release evidence:

```text
content hash
  -> deterministic build
  -> build/source provenance
  -> approved signature/attestation
  -> release bundle
  -> optional internal audit anchor
```

Do not treat an internal ledger anchor as a substitute for software supply-chain provenance, and do not publish private operator identities into public transparency systems without an explicit privacy decision.

## CI as a Security Control

The validation workflow should gate:

- plugin/package lint;
- legal/matter leakage checks;
- inventory/overlay coverage;
- overlay schema and hash provenance;
- identity-first Market reconciliation;
- Market reconciliation regression tests;
- dispatch-state separation regression tests;
- dispatch idempotency and drift audit;
- native manifest idempotency;
- runtime smoke tests.

A schema-mimic smoke test is weaker than native runtime evidence. Record the mode that actually ran.

A CI workflow only enforces policy when the protected branch/release path actually requires it.

## Default Enablement

Compilation or discovery must not imply activation.

For new projections the safe default is disabled. Over time, broad legacy `enabled:true` state should be migrated toward explicit availability/recommendation/installation/connection/elevation semantics rather than a single ambiguous boolean.

## Startup-Mode Security

Security controls should not require wasteful always-on infrastructure when deterministic/event-driven controls suffice.

Prefer:

- CI/release-time checks;
- event-driven validation;
- serverless auth/gateway enforcement;
- queues/sinks for deferred write processing where needed;
- existing registries and stores.

Do not weaken identity, legal/evidence, credential, or destructive-action controls in the name of cost reduction.

## Reporting

Security issues include:

- malicious or compromised capability packages;
- unexpected projection drift;
- identity or authority mismatches;
- publication leaks;
- unreviewed external dependencies;
- incorrect runtime-verification claims;
- bypass of legal/evidence boundaries.

Record the issue privately in the canonical work chain before enabling or publishing the affected artifact.

---
*Policy Version: 1.1.0 | Updated: 2026-09-22*
