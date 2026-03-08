# CHARTER.md — ChittyMarket

## Service Identity

- **Name**: ChittyMarket
- **ID**: chittymarket
- **Tier**: 3 (Operational)
- **Domain**: Artifact management, marketplace
- **Status**: Active

## Scope

ChittyMarket manages the lifecycle of all Claude Code artifacts in the ChittyOS ecosystem. It provides:

1. A central manifest (`marketplace.json`) cataloging all artifacts
2. A `/market` skill for listing, enabling, disabling, and switching modes
3. Toggle actuators for each artifact type (MCP servers, skills, plugins, agents, hooks)
4. Filesystem reconciliation via `/market sync`

## API Contract

ChittyMarket is a local-only service — no HTTP endpoints. It operates through:

- **Manifest**: `marketplace.json` — JSON file read/written by the `/market` skill
- **Skill**: `/market` — Claude Code skill for artifact management

### Manifest Schema

Each artifact entry:
```
id: string           — unique identifier
name: string         — display name
description: string  — one-liner
type: enum           — mcp-server | skill | plugin | agent | hook
category: enum       — ecosystem | code | search | reasoning | desktop | documents | communication | legal | automation
access: enum         — read | write | readwrite
enabled: boolean     — current state
installMode: enum    — ch1tty | standalone | both
standalone: object   — { available, type, ref|path }
ch1tty: object       — { available, serverId? }
tags: string[]       — searchable tags
```

## Dependencies

- **Ch1tty** (upstream) — MCP server management, `enabled` field in servers.json
- **Claude Code settings.json** — Official plugin toggles
- **Hookify** — Hook rule frontmatter for enable/disable

## Consumers

- Human operator via `/market` skill
- Future: ChittyConnect for remote artifact management
- Future: ChittyDashboard for visual marketplace UI

## Boundaries

- ChittyMarket does NOT install new artifacts — it manages existing ones
- ChittyMarket does NOT modify artifact code — it only toggles enabled state
- ChittyMarket does NOT expose a network API — it is local-only
