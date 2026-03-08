# ChittyMarket

The ChittyOS ecosystem marketplace for Claude Code — skills, agents, hooks, and MCP servers.

## Install

```bash
# Via Claude Code /plugin command
/plugin add /path/to/chittymarket

# Or from GitHub
/plugin add CHITTYOS/chittymarket
```

## What's Included

| Plugin | Contents |
|--------|----------|
| **chittyos-core** | Session persistence (ChittyXL), context checkpoints, cleanup, ecosystem agents (schema, register, connect, claude, canon) |
| **chittyos-devops** | Deploy, health checks, registry, pipelines, wrangler audit, compliance |
| **chittyos-legal** | Evidence governance, disputes, court docket, evidence collection |
| **chittyos-governance** | Entity type validation hooks, ChittyID accountability, deploy gates |
| **chittyos-proxy-agents** | Notion, ChatGPT, Cloudflare proxy agents via agent.chitty.cc |
| **chittymarket-manager** | The `/market` skill for managing all artifacts |
| **chittyhelper** | Architectural navigation ("which service handles X?") |
| **chittyagent** | Session lifecycle, ecosystem routing, Mercury finance |
| **chittycommand** | Life management dashboard |
| **legal-arsenal** | Legal case management with ChittyStorage |
| **chittyos-mcp** | Standalone ChittyOS MCP gateway |
| **neon-mcp** | Standalone Neon PostgreSQL MCP server |

## Ch1tty (Optional)

Ch1tty is an MCP server orchestrator that aggregates 14 MCP servers through a single stdio connection with lazy loading. If you use Ch1tty, MCP servers are managed through its `servers.json` instead of standalone `.mcp.json` configs.

- **Without Ch1tty**: Marketplace plugins provide everything including standalone MCP configs
- **With Ch1tty**: Ch1tty manages MCP servers, marketplace provides skills, agents, and hooks
- **Switch modes**: `/market mode <id> ch1tty|standalone`

## Management

```bash
/market              # List all artifacts
/market enable <id>  # Enable an artifact
/market disable <id> # Disable an artifact
/market sync         # Reconcile manifest with filesystem
```
