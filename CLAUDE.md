# CLAUDE.md — ChittyMarket

## What This Is

ChittyMarket is the Claude Code marketplace for the ChittyOS ecosystem. It serves three purposes:

1. **Native Claude Code Marketplace** — `.claude-plugin/marketplace.json` lists 12 plugins installable via `/plugin add`
2. **Artifact Inventory** — `marketplace.json` catalogs all 102 capabilities with rich metadata for the `/market` skill
3. **Capability Overlay (Phase 1, 2026-05-11)** — `capabilities.generated.json` projects every artifact into a Canonical Capability Record with ChittyCanon URI, JTBD group, execution_class, and full §16 metadata schema. See `docs/architecture/CHITTYMARKET_CAPABILITY_ROUTER.md`.

## Structure

```
chittymarket/
  .claude-plugin/marketplace.json   # Native Claude Code marketplace (12 plugins)
  marketplace.json                  # Full artifact inventory (102 capabilities, for /market skill)
  plugins/
    chittyos-core/                  # Session, context, cleanup + 5 ecosystem agents
    chittyos-devops/                # Deploy, health, registry, pipelines, compliance
    chittyos-legal/                 # Evidence, disputes, docket, evidence-collect
    chittyos-governance/            # Hookify rules + neon-schema agent
    chittyos-proxy-agents/          # Notion, ChatGPT, Cloudflare proxy agents
    chittymarket-manager/           # /market skill + market.sh
    chittyos-mcp/                   # Standalone ChittyOS MCP gateway
    neon-mcp/                       # Standalone Neon PostgreSQL MCP
    chittyagent-autobot/            # Autonomous PR-driver agent (advanced/on-demand)
    chittyagent-dispatch/           # Canonical → runtime projection adapters
  scripts/
    generate-marketplace.sh         # Regenerate native manifest from plugins/
```

## Dual Manifest

- **`.claude-plugin/marketplace.json`** — What Claude Code sees via `/plugin add`. Lists 12 plugins (6 inline, 4 GitHub repos, 2 standalone MCP wrappers).
- **`marketplace.json`** — Authoritative inventory read by `/market` skill and `market.sh`. 102 capabilities including official Anthropic plugins, Claude.ai MCP servers, and Ch1tty-managed servers.
- **`~/.claude/marketplace.json`** — Symlink to `marketplace.json`

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

## Ch1tty Integration

Ch1tty is the optional MCP orchestrator. When present, it manages MCP servers via `servers.json`. Without it, standalone `.mcp.json` configs in `plugins/chittyos-mcp/` and `plugins/neon-mcp/` provide direct MCP access.

The `installMode` field in `marketplace.json` tracks which mode each MCP server uses:
- `ch1tty` — Managed by Ch1tty's aggregator
- `standalone` — Direct Claude Code MCP config
- `both` — Available in either mode

## Key Paths

- Native marketplace: `.claude-plugin/marketplace.json`
- Full inventory: `marketplace.json` (symlinked to `~/.claude/marketplace.json`)
- Ch1tty servers: `/Users/nb/Desktop/Projects/github.com/CHITTYOS/ch1tty/servers.json`
- Settings: `~/.claude/settings.json`

## Key Patterns

- Each inline plugin has `.claude-plugin/plugin.json` + `skills/`, `agents/`, `hooks/` directories
- Skills use `SKILL.md` convention, agents use `<name>.md`
- The `scripts/generate-marketplace.sh` can regenerate the native manifest from plugins/
- Never edit `.claude-plugin/marketplace.json` by hand — edit plugin.json files and regenerate
- The full `marketplace.json` inventory is managed via `/market` commands
