---
name: market
description: ChittyMarket capability office — end-to-end inventory, canonical resolution, composition, configuration, validation, publication, synchronization, drift detection, and retirement for configurations, skills, plugins, apps, agents, MCP routes, connectors/connections, hooks, and runtime projections.
canon_uri: chittycanon://core/services/chittymarket#skills/market
---

# /market — ChittyMarket Capability Office

Operate the lifecycle of ChittyOS capabilities from one governed interface. Treat a capability as the canonical job-to-be-done; configurations, skills, plugins, apps, agents, MCP routes, connectors, connections, hooks, and runtime artifacts are controlled projections or dependencies.

## Non-negotiable rules

1. Search for an existing canonical capability before creating or promoting anything.
2. ChittyRegistry owns identity; ChittyMarket owns distribution; Ch1tty/ChittyMCP owns integration routing; ChittyConnect/ChittyAuth owns connection and credential state.
3. Skills own method, apps/connectors own integrations, agents own delegated execution, and projects/workspaces own context.
4. Never clone a shared MCP, skill, connector, registry, auth flow, database, or schema into a vertical plugin merely to make it self-contained.
5. Generated manifests, provenance records, and runtime projections are compiler outputs. Do not hand-author them when a canonical generator exists.
6. Validate the live repository acceptance contract before publication. CI confirms preflight; CI must not be the first place contract violations are discovered.
7. Separate dependency identity from provenance/source location.
8. All external writes require an owner, approval boundary, rollback path when applicable, and returned receipt.
9. If canonical identity, authority, dependency resolution, or required connection state is uncertain, return HOLD instead of inventing it.

## Lifecycle

For create, update, install, publish, migrate, or retire requests:

1. **Inventory** — inspect canonical definitions, ChittyRegistry, ChittyMarket, Ch1tty/ChittyMCP, runtime projections, and relevant platform/plugin state.
2. **Resolve** — identify canonical capability ID, owner, job-to-be-done, and existing projections. Classify duplicates as merge/project/retire rather than creating another source.
3. **Compose** — declare required skills, apps, MCP routes, connectors, connections, and platform capabilities. Bundle only implementation owned by this capability.
4. **Configure** — resolve auth mode, connection requirements, permissions, supported runtimes/channels, mutation risk, and install policy.
5. **Preflight** — read current validators/generators and derive accepted source-link schemes, schema fields, provenance rules, projection rules, and distribution constraints.
6. **Compile** — generate derived manifests, capability records, hashes, and runtime projections from canonical source.
7. **Validate** — run the same lint/schema/source-freshness/provenance/reconciliation/idempotency/runtime checks used by CI.
8. **Publish** — open/update the canonical PR; merge only after required checks pass; register/index through existing ChittyMarket/Ch1tty mechanisms.
9. **Verify** — confirm installed/indexed state and required connections. Never report completion without receipts.
10. **Operate** — sync versions, enable/disable, diagnose broken dependencies/connections, and detect projection drift.
11. **Retire** — deprecate superseded projections and remove dangling dependencies only after consumers are reconciled.

## Commands

Existing commands remain valid:

- `/market list [filters]`
- `/market info <id>`
- `/market enable|disable <id>`
- `/market verify [<id>|--all]`
- `/market mode <id> ch1tty|standalone`
- `/market sync`

Capability-office commands:

- `/market inventory [<id>|--all]` — canonical + projection + dependency + connection inventory.
- `/market resolve <intent|artifact>` — locate canonical owner and recommend keep/project/merge/gateway/retire/hold.
- `/market deps <id>` — show required skills/apps/MCPs/connectors/connections and their live resolution state.
- `/market preflight <id|path>` — derive the current publication contract and run pre-publication gates.
- `/market publish <id|path>` — preflight, compile, validate, PR, gate, publish/register, verify.
- `/market audit [<id>|--all]` — find duplicates, broken dependencies/connections, stale projections, invalid provenance, and orphaned artifacts.
- `/market retire <id>` — dependency-aware deprecation/removal workflow.

## Existing actuator

Use `~/.claude/skills/market/market.sh` for list/enable/disable/info/verify/sync where supported. Do not pretend the shell actuator implements the new office commands until it does. For office commands, use canonical ChittyMarket repository tooling and connected ChittyRegistry/Ch1tty/ChittyMCP/platform surfaces directly.

## Preflight contract

Before any publish:

- inspect the current generator and validation scripts rather than relying on remembered schemas;
- require accepted source-link schemes;
- verify every dependency identity independently from source/provenance;
- ensure bundled implementation is not also emitted as an unmanaged standalone projection unless explicitly governed;
- regenerate hashes/projections through canonical tooling;
- require idempotent second generation with no diff;
- stop on unresolved auth/connection requirements;
- stop on validation failure.

## Output contract

Return:
- **Canonical capability**
- **Owned projections**
- **Dependencies/connections**
- **Validation state**
- **Writes/receipts**
- **Drift/duplicates**
- **Holds**
- **Next action**

Do not claim published, installed, connected, synchronized, or retired without direct evidence.
