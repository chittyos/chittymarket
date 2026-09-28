---
name: market
description: ChittyMarket capability office for end-to-end inventory, canonical resolution, composition, configuration, validation, publication, synchronization, drift detection, and retirement across configurations, skills, plugins, apps, agents, MCP routes, connectors/connections, hooks, and runtime projections. Use for /market operations and capability lifecycle management.
---

# ChittyMarket Capability Office

Manage the capability estate, not just marketplace toggles.

## Authority

- ChittyRegistry: canonical identity and ownership.
- ChittyMarket: distribution and lifecycle policy.
- Ch1tty/ChittyMCP: governed integration routing.
- ChittyConnect/ChittyAuth: connections, auth, and credential custody.
- Skills: method. Apps/connectors: integration. Agents: delegated execution. Projects/workspaces: context.

Never create a parallel registry, auth flow, MCP gateway, schema, database, or unmanaged clone.

## Workflow

For create/update/install/publish/migrate/retire:

1. Inventory existing canonical and live projected state.
2. Resolve the canonical capability before creating anything.
3. Compose required skills, apps, MCP routes, connectors and connections; bundle only owned implementation.
4. Resolve auth, permissions, runtimes, mutation risk and install policy.
5. Read the repository's current generators and validators to derive the acceptance contract.
6. Compile generated manifests, provenance and projections from canonical source.
7. Run the same validation gates as CI, including source freshness, provenance, reconciliation and idempotency.
8. Publish through the canonical PR/merge/register/index path.
9. Verify installed/indexed/connected state with receipts.
10. Audit drift and retire superseded projections dependency-first.

## Commands

Keep existing `list`, `info`, `enable`, `disable`, `verify`, `mode`, and `sync`.

Add lifecycle intents:
- `inventory` — canonical/projection/dependency/connection inventory.
- `resolve` — identify canonical owner and disposition.
- `deps` — dependency and connection resolution.
- `preflight` — derive and execute current publication gates.
- `publish` — preflight -> compile -> validate -> PR -> gate -> publish/register -> verify.
- `audit` — duplicates, stale projections, broken connections/dependencies, provenance drift.
- `retire` — dependency-aware deprecation/removal.

Use `~/.claude/skills/market/market.sh` only for commands it actually implements. For lifecycle commands, use canonical repository tooling and connected ChittyRegistry/Ch1tty/ChittyMCP/platform surfaces. Never fabricate actuator support.

## Publication safeguards

- Existing capability search is mandatory.
- Generated artifacts are not hand-authored when a generator exists.
- Dependency identity and provenance/source location are separate concepts.
- Accepted source-link schemes come from current validators, not memory.
- Bundled implementation must not accidentally become an independent standalone artifact.
- Generation must be idempotent.
- CI confirms local/preflight validation rather than discovering basic contract violations.
- Unresolved identity, authority, connection, auth, or validation state => HOLD.

## Result

Report canonical capability, projections, dependencies/connections, validation state, writes/receipts, drift/duplicates, holds, and next action. Never claim completion without evidence.
