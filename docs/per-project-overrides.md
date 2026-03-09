# Per-Project Plugin Overrides

Place a `.claude/marketplace.project.json` file in any project root to control which ChittyMarket plugins are active for that project.

## Schema

```json
{
  "profile": "devops",
  "plugins": {
    "enable": ["chittyos-devops"],
    "disable": ["chittyos-legal"]
  },
  "mcp": {
    "enable": ["neon-mcp"],
    "disable": []
  }
}
```

## Fields

| Field | Type | Description |
|-------|------|-------------|
| `profile` | string | Optional. Base profile from `profiles.json` to start from. |
| `plugins.enable` | string[] | Plugins to force-enable for this project (additive to profile). |
| `plugins.disable` | string[] | Plugins to force-disable for this project (overrides profile). |
| `mcp.enable` | string[] | MCP wrappers to enable. |
| `mcp.disable` | string[] | MCP wrappers to disable. |

## Resolution Order

1. Start with global `marketplace.json` state (all currently enabled artifacts)
2. If `profile` is set, apply that profile's plugin set
3. Apply `plugins.enable` additions
4. Apply `plugins.disable` removals (highest priority)
5. Same for `mcp`

## Examples

### Legal project
```json
{
  "profile": "legal",
  "plugins": {
    "enable": [],
    "disable": ["chittyos-devops"]
  }
}
```

### Pure infrastructure
```json
{
  "profile": "devops",
  "plugins": {
    "enable": ["chittyos-proxy-agents"],
    "disable": ["chittyos-legal"]
  },
  "mcp": {
    "enable": ["chittyos-mcp", "neon-mcp"],
    "disable": []
  }
}
```

### Minimal coding session
```json
{
  "profile": "minimal"
}
```
