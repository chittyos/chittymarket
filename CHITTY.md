---
uri: chittycanon://docs/ops/architecture/chittymarket
namespace: chittycanon://docs/ops
type: architecture
version: 1.0.0
status: DRAFT
registered_with: chittycanon://core/services/canon
title: "ChittyMarket"
certifier: chittycanon://core/foundation/mychitty-vault
visibility: PUBLIC
---

# ChittyMarket

> `chittycanon://core/services/chittymarket` | Tier 3 (Operational) | Local-only

## What It Does

Local artifact marketplace and manager for the ChittyOS Claude Code environment. Catalogs **104 capabilities** (MCP servers, skills, plugins, agents, hooks) with enable/disable toggle support and install mode switching (Ch1tty vs standalone). Phase 1 capability overlay generated 2026-05-11 — see `capabilities.generated.json` and `docs/architecture/CHITTYMARKET_CAPABILITY_ROUTER.md`.

## Architecture

Claude Code skill + JSON manifest — no standalone process or HTTP deployment.

### Stack
- **Runtime**: Claude Code session
- **Storage**: JSON file on local filesystem (`marketplace.json`)
- **Interface**: `/market` slash command skill
- **Actuator**: `market.sh` shell script for instant toggles

### Key Components
- `marketplace.json` — Central manifest (single source of truth)
- `~/.claude/skills/market/SKILL.md` — Skill definition
- `~/.claude/skills/market/market.sh` — Shell actuator for toggles

### Toggle Flow
```
/market list                          <-- Skill interface
    |
    v
marketplace.json                      <-- Single source of truth
    |
    +-> Ch1tty servers.json           <-- MCP servers (enabled/disabled)
    +-> ~/.claude/settings.json       <-- Official plugins (enabledPlugins)
    +-> ~/.claude/plugins/blocklist   <-- Local plugins
    +-> ~/.claude/skills/*/SKILL.md   <-- Skills (rename to .disabled)
    +-> ~/.claude/agents/*.md         <-- Agents (rename to .disabled)
    +-> ~/.claude/hooks/*.md          <-- Hookify rules (YAML enabled field)
```

## ChittyOS Ecosystem

### Certification
- **Badge**: ChittyOS Compatible
- **Certifier**: ChittyFoundation (`chittycanon://core/foundation/mychitty-vault`)
- **Last Certified**: Pending

### ChittyDNA
- **ChittyID**: `03-1-USA-5222-T-2603-1-36`
- **DNA Hash**: Pending
- **Lineage**: root (new service)

### Dependencies
| Service | Purpose |
|---------|---------|
| Ch1tty | MCP server enabled/disabled field |
| Claude Code | Plugin toggles (settings.json) |
| Hookify | Hook rule frontmatter toggles |

### Artifact Counts (2026-05-11, post Phase 1 overlay)
| Type | Count |
|------|-------|
| MCP servers | 28 |
| Plugins | 40 |
| Skills | 15 |
| Hooks | 10 |
| Agents | 9 |
| **Total** | **104** capabilities |

### Capability Distribution (JTBD groups, Phase 1)
| Group | Count |
|-------|-------|
| build | 29 |
| connect | 22 |
| govern | 15 |
| ship | 12 |
| workspace | 6 |
| legal | 5 |
| local-lab | 5 |
| agent-runtime | 4 |
| internal | 3 |
| market | 1 |

### Install Modes
| Mode | Description |
|------|-------------|
| `ch1tty` | Managed by Ch1tty MCP gateway |
| `standalone` | Direct Claude Code (skill/plugin/agent) |
| `both` | Available in either mode |
