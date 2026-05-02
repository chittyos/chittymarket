![ChittyOS](https://img.shields.io/badge/ChittyOS-service-6366F1?style=flat-square)
![Tier](https://img.shields.io/badge/tier-3%20operational-3730A3?style=flat-square)

# ChittyMarket

The ChittyOS ecosystem marketplace for Claude Code — skills, agents, hooks, and MCP servers.

## Quick Start

```bash
# Clone and bootstrap (new machine)
gh repo clone CHITTYOS/chittymarket
cd chittymarket
./scripts/bootstrap.sh

# Or with a specific profile
./scripts/bootstrap.sh --profile=devops

# Or install as a Claude Code plugin
/plugin add CHITTYOS/chittymarket
```

The `chittymarket-manager` plugin is the entry point — install it first, then use `/market` to manage everything else. This is the self-bootstrapping pattern: the marketplace installs itself, then installs the rest.

## What's Included

| Plugin | Contents |
|--------|----------|
| **chittyos-core** | Session persistence (ChittyXL), context checkpoints, cleanup, ecosystem agents (schema, register, connect, auth, claude, canon) |
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

## Profiles

Preset plugin configurations for different work contexts:

| Profile | Plugins | Use Case |
|---------|---------|----------|
| `minimal` | core | Bare essentials — session and context only |
| `coding` | core, devops | Pure development work |
| `devops` | core, devops, governance + MCP | Infrastructure and deployment |
| `legal` | core, legal, governance + MCP | Legal case management |
| `integrations` | core, proxy-agents + MCP | External service work |
| `full` | everything | All plugins enabled |

```bash
./scripts/bootstrap.sh --profile=legal
# or
/market profile legal
```

## Dependencies

Plugins declare dependencies via `requires` in their `plugin.json`:

```
chittyos-core (no deps)
├── chittyos-devops
├── chittyos-legal
├── chittyos-governance
└── chittyos-proxy-agents
```

Enabling a plugin auto-checks that its dependencies are available.

## Per-Project Overrides

Place `.claude/marketplace.project.json` in any project root:

```json
{
  "profile": "devops",
  "plugins": {
    "enable": ["chittyos-proxy-agents"],
    "disable": ["chittyos-legal"]
  }
}
```

See [docs/per-project-overrides.md](docs/per-project-overrides.md) for full schema.

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
/market info <id>    # Show artifact details
/market profile <p>  # Switch to a profile
/market sync         # Reconcile manifest with filesystem
/market lint         # Check for conflicts
```

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/bootstrap.sh` | One-command setup (symlinks, profiles) |
| `scripts/generate-marketplace.sh` | Regenerate native manifest from plugins/ |
| `scripts/lint-plugins.sh` | Detect conflicts across plugins |
| `scripts/test-plugins.sh` | Validate plugin structure and files |
| `scripts/record-telemetry.sh` | Record and view plugin usage stats |

## Self-Bootstrapping

The marketplace is itself a marketplace item. The installation flow:

1. Clone `CHITTYOS/chittymarket`
2. Run `bootstrap.sh` — installs `chittymarket-manager` plugin (the `/market` skill)
3. `/market list` shows all available artifacts
4. `/market profile full` enables everything
5. The marketplace manages itself from then on

This means a fresh machine goes from zero to fully operational with one clone + one script.
