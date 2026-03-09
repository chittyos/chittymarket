# Plugin Usage Telemetry

ChittyMarket tracks plugin usage locally to answer "which plugins are worth keeping?"

## Storage

`~/.claude/chittymarket-telemetry.json` — local-only, never sent externally.

## Schema

```json
{
  "version": "1.0.0",
  "firstRecorded": "2026-03-08T00:00:00Z",
  "lastUpdated": "2026-03-08T23:00:00Z",
  "plugins": {
    "chittyos-core": {
      "installed": "2026-03-08",
      "skills": {
        "chittyxl": { "invocations": 42, "lastUsed": "2026-03-08T22:00:00Z" },
        "chittycontext": { "invocations": 15, "lastUsed": "2026-03-08T21:30:00Z" },
        "checkpoint": { "invocations": 8, "lastUsed": "2026-03-07T18:00:00Z" }
      },
      "agents": {
        "chittyagent-schema": { "invocations": 5, "lastUsed": "2026-03-06T14:00:00Z" }
      },
      "hooks": {}
    }
  },
  "sessions": {
    "total": 85,
    "withPluginActivity": 72
  }
}
```

## Collection Points

| Event | Source | What's Recorded |
|-------|--------|----------------|
| Skill invocation | `/market` skill or hook-log-tool.sh | Plugin name, skill name, timestamp |
| Agent spawn | Task tool usage logged by hooks | Plugin name, agent name, timestamp |
| Hook fire | PostToolUse/PreToolUse hooks | Plugin name, hook event, timestamp |
| Session start | SessionStart hook | Session count increment |

## Integration with Existing Hooks

The `hook-log-tool.sh` PostToolUse hook already logs every tool call to Neon DB. Telemetry can be derived by:

1. Querying tool usage logs for skill/agent invocations
2. Mapping tool names back to plugin owners via marketplace.json
3. Aggregating counts into the local telemetry file

## Commands

```bash
# Record a skill invocation (called by hooks)
scripts/record-telemetry.sh skill chittyos-core chittyxl

# Record an agent spawn
scripts/record-telemetry.sh agent chittyos-core chittyagent-schema

# Show usage summary
scripts/record-telemetry.sh summary
```

## Privacy

- All data stays local in `~/.claude/chittymarket-telemetry.json`
- No external reporting unless explicitly synced via ChittyConnect
- User can delete the file at any time to reset
