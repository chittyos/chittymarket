---
name: market
description: ChittyMarket capability office — end-to-end inventory, canonical resolution, composition, configuration, validation, publication, synchronization, drift detection, and retirement for configurations, skills, plugins, apps, agents, MCP routes, connectors/connections, hooks, and runtime projections.
canon_uri: chittycanon://core/services/chittymarket#skills/market
---

# /market — ChittyMarket Capability Office

Operate the lifecycle of ChittyOS capabilities from one governed interface. Treat a capability as the canonical job-to-be-done; configurations, skills, plugins, apps, agents, MCP routes, connectors, connections, hooks, and runtime artifacts are controlled projections or dependencies.

## Non-negotiable rules

1. Search for an existing canonical capability before creating or promoting anything.
2. ChittyRegistry (read-only directory) holds identity records and ChittyRegister is the only registration write path; ChittyMarket owns distribution; Ch1tty/ChittyMCP owns integration routing; ChittyConnect/ChittyAuth owns connection and credential state.
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
8. **Publish** — open/update the canonical PR; merge only after required checks pass; register through ChittyRegister (register.chitty.cc) and index through existing ChittyMarket/Ch1tty mechanisms.
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

`~/.claude/skills/market/market.sh` implements list/enable/disable/info/verify/sync and the office commands inventory/deps/preflight/audit/publish/retire. `publish` and `retire` only report HOLD (exit 2) and never mutate. `mode` and `resolve` are not implemented in the shell: perform `/market mode` from the Manual Instructions below, and perform `resolve` as an agent step against the canonical overlay. If `market.sh` is unavailable, use the Manual Instructions.

Authority split: ChittyRegistry (`registry.chitty.cc`) is read-only discovery; registration and other registry mutations go only through ChittyRegister (`register.chitty.cc`); credentials, deploys and infrastructure changes go through the ChittyConnect broker and are never handled here. Fail closed if the broker is unavailable.

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

## Manual Instructions (fallback)

If `market.sh` is unavailable, read `~/.claude/marketplace.json` and execute the requested command manually.

### `/market list`

1. Read `~/.claude/marketplace.json`
2. Filter out `_comment` entries
3. Group artifacts by `type`
4. For each artifact, display:
   ```
   [ON]  serena          Read and Write Source Code       mcp-server  code      ch1tty+standalone
   [OFF] plugin-github   GitHub                           plugin      code      standalone
   ```
5. If `--type=X` is provided, only show that type
6. If `--category=X` is provided, only show that category
7. Show summary counts at the bottom

### `/market enable <id>`

1. Read marketplace.json, find artifact by `id`
2. If already enabled, inform user
3. Apply the toggle based on artifact type:

| Type | How to Enable |
|------|--------------|
| `mcp-server` | Read Ch1tty's `servers.json` at `/Users/nb/Desktop/Projects/github.com/CHITTYOS/ch1tty/servers.json`. Find the server entry matching the artifact's `ch1tty.serverId`. Set `"enabled": true`. |
| `skill` | Check if `SKILL.md.disabled` exists at the skill path. If so, rename it to `SKILL.md` using: `mv <path>/SKILL.md.disabled <path>/SKILL.md` |
| `plugin` (official) | Read `~/.claude/settings.json`. In the `enabledPlugins` map, set the plugin ref to `true`. |
| `plugin` (local) | Read `~/.claude/plugins/blocklist.json`. Remove the entry matching this plugin from the `plugins` array. |
| `agent` | Check if `<name>.md.disabled` exists. If so, rename to `<name>.md` |
| `hook` (hookify) | Read the hookify rule `.md` file. In the YAML frontmatter, set `enabled: true` |

4. Update `"enabled": true` in marketplace.json
5. Confirm to user

### `/market disable <id>`

1. Read marketplace.json, find artifact by `id`
2. If already disabled, inform user
3. Apply the toggle based on artifact type:

| Type | How to Disable |
|------|---------------|
| `mcp-server` | In Ch1tty's `servers.json`, set `"enabled": false` for the matching server entry |
| `skill` | Rename `SKILL.md` to `SKILL.md.disabled` at the skill path |
| `plugin` (official) | In `~/.claude/settings.json` `enabledPlugins`, set the ref to `false` |
| `plugin` (local) | Add entry to `~/.claude/plugins/blocklist.json` with reason "disabled-via-market" |
| `agent` | Rename `<name>.md` to `<name>.md.disabled` |
| `hook` (hookify) | In the hookify rule, set `enabled: false` in YAML frontmatter |

4. Update `"enabled": false` in marketplace.json
5. Confirm to user

### `/market info <id>`

1. Find the artifact in marketplace.json
2. Display all fields in a readable format:
   - Name, description, type, category, access
   - Enabled status
   - Install mode (ch1tty / standalone / both)
   - Tags
   - Standalone details (ref or path)
   - Ch1tty details (serverId if applicable)

### `/market mode <id> ch1tty|standalone`

1. Find the artifact in marketplace.json
2. Verify the requested mode is available (check `standalone.available` or `ch1tty.available`)
3. If switching to ch1tty: disable standalone install, enable in Ch1tty servers.json
4. If switching to standalone: disable in Ch1tty servers.json, enable standalone install
5. Update `installMode` in marketplace.json
6. Confirm to user

### `/market sync`

Reconcile marketplace.json with actual filesystem state:

1. **MCP Servers**: Read Ch1tty servers.json, compare `enabled` field
2. **Skills**: Check each skill path — if `SKILL.md` exists it's enabled, if `SKILL.md.disabled` exists it's disabled
3. **Official Plugins**: Read `~/.claude/settings.json` `enabledPlugins` map
4. **Local Plugins**: Check `~/.claude/plugins/blocklist.json`
5. **Agents**: Check if `.md` or `.md.disabled` exists
6. **Hooks**: Check hookify rule frontmatter for `enabled` field

For any discrepancies, update marketplace.json to match actual state. Report what changed.
