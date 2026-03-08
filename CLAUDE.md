# CLAUDE.md — ChittyMarket

## What This Is

ChittyMarket is the artifact marketplace and manager for the ChittyOS Claude Code environment. It provides a single manifest (`marketplace.json`) that catalogs all installed artifacts (MCP servers, skills, plugins, agents, hooks) and a `/market` skill to manage them.

## Commands

```bash
/market              # List all artifacts
/market list         # Same as above
/market enable <id>  # Enable an artifact
/market disable <id> # Disable an artifact
/market info <id>    # Show artifact details
/market mode <id> ch1tty|standalone  # Switch install mode
/market sync         # Reconcile manifest with filesystem
```

## Architecture

- **marketplace.json** — Single source of truth for all artifact metadata and state
- **~/.claude/marketplace.json** — Symlink to the repo's marketplace.json
- **/market skill** — Claude Code skill at `~/.claude/skills/market/SKILL.md`

### Toggle Actuators

Each artifact type has a specific mechanism for enabling/disabling:

| Type | Enable | Disable |
|------|--------|---------|
| mcp-server | `"enabled": true` in Ch1tty servers.json | `"enabled": false` |
| skill | Rename `.disabled` → `SKILL.md` | Rename `SKILL.md` → `.disabled` |
| plugin (official) | `true` in settings.json `enabledPlugins` | `false` |
| plugin (local) | Remove from blocklist.json | Add to blocklist.json |
| agent | Rename `.disabled` → `.md` | Rename `.md` → `.disabled` |
| hook | `enabled: true` in YAML frontmatter | `enabled: false` |

## Key Paths

- Manifest: `/Users/nb/Desktop/Projects/github.com/CHITTYOS/chittymarket/marketplace.json`
- Ch1tty servers: `/Users/nb/Desktop/Projects/github.com/CHITTYOS/ch1tty/servers.json`
- Settings: `~/.claude/settings.json`
- Skill: `~/.claude/skills/market/SKILL.md`

## Key Patterns

- The `installMode` field tracks whether an artifact runs via Ch1tty (orchestrated) or standalone (direct Claude Code)
- Artifacts with `installMode: "both"` are available in either mode
- The `/market sync` command is the reconciliation tool — run it to align manifest with reality
- Never edit marketplace.json by hand during normal operations — use `/market` commands
