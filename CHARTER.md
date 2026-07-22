---
uri: chittycanon://docs/ops/policy/chittymarket-charter
namespace: chittycanon://docs/ops
type: policy
version: 1.0.0
status: DRAFT
registered_with: chittycanon://core/services/canon
title: "ChittyMarket Charter"
certifier: chittycanon://core/foundation/mychitty-vault
visibility: PUBLIC
---

# ChittyMarket Charter

## Classification
- **Canonical URI**: `chittycanon://core/services/chittymarket`
- **Tier**: 3 (Operational)
- **Organization**: CHITTYOS
- **Domain**: Local-only (no HTTP deployment)
- **ChittyID**: `03-1-USA-5222-T-2603-1-36`

## Mission

Provide a unified marketplace manifest and management interface for all Claude Code artifacts (MCP servers, skills, plugins, agents, hooks) in the ChittyOS ecosystem, enabling enable/disable toggling and install mode switching through a single `/market` skill.

## Scope

### IS Responsible For
- Maintaining the central artifact manifest (`marketplace.json`)
- Toggling artifacts enabled/disabled via type-specific actuators
- Switching artifact install mode between Ch1tty (orchestrated) and standalone
- Reconciling manifest state with filesystem state via `/market sync`
- Providing CLI-style management through the `/market` skill

### IS NOT Responsible For
- Installing new artifacts or downloading packages
- Modifying artifact source code or configuration beyond toggle state
- Exposing a network API or HTTP endpoints
- Identity generation (ChittyID)
- Token provisioning (ChittyAuth)
- Service registration (ChittyRegister)

## Dependencies

| Type | Service | Purpose |
|------|---------|---------|
| Upstream | Ch1tty | MCP server management — `enabled` field in servers.json |
| Upstream | Claude Code | Plugin toggles via settings.json `enabledPlugins` |
| Upstream | Hookify | Hook rule frontmatter for enable/disable |
| Storage | Local filesystem | marketplace.json, skill dirs, agent .md files |

## API Contract

**Interface**: Local `/market` skill (no HTTP endpoints)

### Commands
| Command | Purpose |
|---------|---------|
| `/market list` | List all artifacts grouped by type |
| `/market list --type=X` | Filter by artifact type |
| `/market list --category=X` | Filter by category |
| `/market enable <id>` | Enable an artifact |
| `/market disable <id>` | Disable an artifact |
| `/market info <id>` | Show artifact details |
| `/market mode <id> ch1tty\|standalone` | Switch install mode |
| `/market sync` | Reconcile manifest with filesystem |

### Manifest Schema
| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique identifier |
| `name` | string | Display name |
| `description` | string | One-liner |
| `type` | enum | mcp-server, skill, plugin, agent, hook |
| `category` | enum | ecosystem, code, search, reasoning, desktop, documents, communication, legal, automation |
| `access` | enum | read, write, readwrite |
| `enabled` | boolean | Current state |
| `installMode` | enum | ch1tty, standalone, both |
| `standalone` | object | Standalone install metadata |
| `ch1tty` | object | Ch1tty-managed install metadata |
| `tags` | string[] | Searchable tags |

## Ownership

| Role | Owner |
|------|-------|
| Service Owner | ChittyOS |
| Technical Lead | @chittyos-infrastructure |
| Contact | chittymarket@chitty.cc |

## Consumers

- Human operator via `/market` skill
- Future: ChittyConnect for remote artifact management
- Future: ChittyDashboard for visual marketplace UI

## Compliance

- [x] Service registered in ChittyRegister
- [x] CLAUDE.md development guide present
- [x] CHARTER.md present
- [x] CHITTY.md present
- [x] marketplace.json manifest validated (106 artifacts)

---
*Charter Version: 1.0.0 | Last Updated: 2026-07-22*
