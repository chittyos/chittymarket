# /market — ChittyMarket Artifact Manager

Manage all Claude Code artifacts (MCP servers, skills, plugins, agents, hooks) from a single interface.

## Triggers

- User types `/market`
- User mentions "marketplace", "market list", "market enable", "market disable"

## Arguments

- `/market` or `/market list` — List all artifacts grouped by type
- `/market list --type=<type>` — Filter by type (mcp-server, skill, plugin, agent, hook)
- `/market list --category=<cat>` — Filter by category (ecosystem, code, search, legal, etc.)
- `/market list --enabled` — Show only enabled artifacts
- `/market list --disabled` — Show only disabled artifacts
- `/market enable <id>` — Enable an artifact
- `/market disable <id>` — Disable an artifact
- `/market info <id>` — Show artifact details
- `/market mode <id> ch1tty|standalone` — Switch install mode
- `/market sync` — Scan filesystem and reconcile manifest with actual state

## Manifest Location

The single source of truth is: `~/.claude/marketplace.json`
(Symlinked from `/Users/nb/Desktop/Projects/github.com/CHITTYOS/chittymarket/marketplace.json`)

## Shell Actuator

A shell script at `~/.claude/skills/market/market.sh` handles all commands. **Use this script for all operations** instead of manually reading/editing JSON files.

```bash
~/.claude/skills/market/market.sh list                    # List all
~/.claude/skills/market/market.sh list --type=skill       # Filter by type
~/.claude/skills/market/market.sh list --category=code    # Filter by category
~/.claude/skills/market/market.sh list --enabled          # Only enabled
~/.claude/skills/market/market.sh list --disabled         # Only disabled
~/.claude/skills/market/market.sh enable <id>             # Enable artifact
~/.claude/skills/market/market.sh disable <id>            # Disable artifact
~/.claude/skills/market/market.sh info <id>               # Show details
~/.claude/skills/market/market.sh sync                    # Reconcile with filesystem
```

When this skill is triggered, run the appropriate `market.sh` command via Bash. Display the output to the user. For `/market mode`, fall back to the manual instructions below since `market.sh` doesn't implement mode switching yet.

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

## Key File Paths

- Marketplace manifest: `~/.claude/marketplace.json`
- Ch1tty servers: `/Users/nb/Desktop/Projects/github.com/CHITTYOS/ch1tty/servers.json`
- Settings: `~/.claude/settings.json`
- Plugin blocklist: `~/.claude/plugins/blocklist.json`
- Skills: `~/.claude/skills/<id>/SKILL.md`
- Agents: `~/.claude/agents/<name>.md`
- Hooks: `~/.claude/hooks/hookify.<name>.local.md`
