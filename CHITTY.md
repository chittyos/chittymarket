# CHITTY.md — ChittyMarket

## Architecture

ChittyMarket is a local artifact marketplace for the ChittyOS Claude Code environment. It consists of:

1. **marketplace.json** — Central manifest listing all 86+ artifacts with metadata and state
2. **/market skill** — Claude Code skill providing CLI-style management commands
3. **Toggle actuators** — Type-specific mechanisms for enabling/disabling artifacts

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

## Stack

- **Runtime**: Claude Code session (no standalone process)
- **Storage**: JSON file on local filesystem
- **Interface**: `/market` slash command skill

## Ecosystem Position

ChittyMarket sits at Tier 3 (Operational), providing management capabilities over:

- **Tier 0-2 services** accessed via MCP servers through Ch1tty
- **Skills** that provide slash commands and auto-active behaviors
- **Plugins** (official + local) that extend Claude Code capabilities
- **Agents** that provide specialized subagent workflows
- **Hooks** that enforce behavioral rules

## Install Modes

Each artifact supports one or more install modes:

- **ch1tty**: Managed by Ch1tty MCP gateway — tools namespaced as `serverId/toolName`
- **standalone**: Installed directly in Claude Code (skill dir, plugin, agent .md)
- **both**: Available in either mode, user chooses via `/market mode`

## Artifact Counts (as of 2026-03-08)

| Type | Count |
|------|-------|
| MCP Servers | 14 |
| Skills | 14 |
| Official Plugins | 30 |
| Local Plugins | 5 |
| Agents | 9 |
| Hooks | 10 |
| **Total** | **86** (with 4 disabled) |

## Certification

- **Level**: Bronze (local tooling, no network exposure)
- **Compliance**: CHARTER.md + CHITTY.md + CLAUDE.md present
