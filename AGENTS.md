# AGENTS.md — ChittyMarket

ChittyMarket is the private capability supply-chain and projection control plane for ChittyOS.

## Service identity

- **Canonical service URI:** `chittycanon://core/services/chittymarket`
- **Tier:** 3 (Operational / control plane)\n- **Architecture tier:** Tier 3
- **Deployment form:** private repository + deterministic build/release workflows
- **Standalone HTTP domain:** none
- **Network projections:** ChittyRegistry, Ch1tty/MCP, Apps/connectors, and runtime-native package surfaces
- **Certification:** pending re-certification after the 2026 architecture migration

Do not provision a `market.agent.chitty.cc` worker merely because legacy documents referenced one.

## Authority boundaries

- **ChittyCanon / ChittyRegister / ChittyRegistry** own canonical identity, registration, and discoverability.
- **ChittyMarket** owns package/projection policy, deterministic generation, validation, release promotion, and platform-specific delivery artifacts.
- **ChittyConnect** owns delegated credential brokering and auth integration.
- **Ch1tty / MCP / Apps / agents** execute capabilities; they do not define canonical identity.
- **Legal space** owns evidence-grade legal truth. Matter-specific legal data must not be published through Market artifacts.

Do not create a new database, schema, registry, or parallel capability identity model unless existing structures are proven insufficient and the change is explicitly approved.

## Product invariant

Every release path must preserve this ordering:

```text
canonical identity
  -> Market projection definition
  -> deterministic projection/package
  -> static validation
  -> runtime verification
  -> provenance/signing
  -> publish
  -> index/discovery
```

A generated projection is never a source of canonical identity. A successful dispatch is not proof that runtime verification passed.

## Development loop

For each bounded iteration:

1. Inspect current main, open issues/PRs, registry/runtime state, and recent standards changes.
2. Select the highest-leverage unresolved defect or drift.
3. Reuse an existing canonical capability, issue, branch, service, and data store where possible.
4. Implement the smallest coherent change.
5. Validate generated artifacts and source/projection idempotency.
6. Verify the runtime path when the change affects execution or discovery.
7. Run an adversarial review for privilege, privacy, identity, provenance, and publication failures.
8. Record receipts in the relevant issue/PR.
9. Promote only when the evidence distinguishes authored, projected, validated, runtime-verified, signed, published, and indexed states.

## Required checks

Run the repository validation workflow and, where applicable:

```bash
bash scripts/lint-plugins.sh
bash scripts/test-plugins.sh
bash scripts/check-overlay-coverage.sh
python3 scripts/validate-overlay-schema.py
bash scripts/check-source-freshness.sh
python3 scripts/overlay-provenance.py verify
bash plugins/chittyagent-dispatch/scripts/dispatch.sh audit
```

When a deterministic Market inventory compiler is present, its read-only audit must be part of CI and generation must be idempotent.

Schema-mimic tests are not runtime proof. Record when a native runtime or MCP Inspector/real client was unavailable.

## Identity rules

- Never derive a canonical capability identifier from display title, package name, group, slug, or runtime artifact path.
- Resolve canonical capability identity from the authoritative existing source first.
- If identity cannot be resolved, **hold/refuse projection** and report the missing reference.
- Platform projections may carry aliases and projection IDs, but those identifiers must resolve back to the canonical capability.
- Persist verification outcome separately from dispatch/projection outcome.

## Artifact placement

Use the lowest-power safe projection:

- **Skill**: method, SOP, domain workflow, convention, or reusable procedure.
- **App/connector**: external service, API, data integration, or user-authorized action.
- **MCP server**: controlled integration/execution boundary exposing tools.
- **Tool**: small operation beneath an App/MCP boundary.
- **Agent**: delegated actor that materially needs planning, tool use, or autonomous multi-step execution.
- **Local-only**: filesystem, browser, device, or machine-privileged work.
- **Legal-only**: evidence, filings, disputes, ownership, valuation, custody, or non-repudiable legal records.

Do not create an MCP server merely because a skill exists. Do not create an agent merely because a tool has multiple steps.

## Security and publication

The working repository is private. Treat historical public exposure as a security fact, not as evidence that files are publication-safe.

Future public distribution must use:

```text
private authoring -> explicit allowlist/publication policy -> generated sanitized package
```

Do not publish by repeatedly scrubbing the private repository.

Manifest policy, skill prose, tool annotations, and agent prompts are not enforcement boundaries. Enforcement belongs in auth services, execution gateways, server-side middleware, CI, and Legal/evidence controls.

## Startup-mode constraints

Prefer included/serverless/event-driven infrastructure. Do not introduce always-on compute, polling that prevents scale-to-zero, or a new paid dependency without measurement and justification. Use queues/sinks for deferred work where appropriate.

## Branch and review discipline

- GitHub is source of truth for code.
- Prefer an existing work item/branch over creating a competing implementation.
- Keep changes bounded and reversible.
- Never merge a stale implementation merely because it already exists; reconcile its design against current main and current standards first.
- For sensitive mutation, auth, deployment, billing, registry writes, or publication changes, preserve an explicit approval/audit boundary.
