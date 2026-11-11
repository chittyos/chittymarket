![ChittyOS](https://img.shields.io/badge/ChittyOS-service-6366F1?style=flat-square)
![Tier](https://img.shields.io/badge/tier-3%20operational-3730A3?style=flat-square)

# ChittyMarket

ChittyMarket is the private capability supply-chain and projection control plane for ChittyOS. It packages governed capabilities for runtime-native delivery; it is **not** the canonical product catalog, and plugin directories are **not** product identities.

## Operating Model

ChittyMarket keeps these layers separate:

| Layer | Authority | Meaning |
|---|---|---|
| Product / application | ChittyCorp / ChittyApps, resolved through canonical identity | User-facing or commercial offering that may compose many capabilities |
| Capability | ChittyCanon / ChittyRegistry | Canonical job-to-be-done, identified independently of its delivery surface |
| Market package | ChittyMarket | Install/distribution bundle that projects one or more governed capabilities |
| Runtime control plane | Ch1tty, Apps/MCP, Cloudflare MCP Portals / AI Gateway | Curates, authorizes, routes, and observes runtime access |
| Execution substrate | MCP server, agent, Worker, local host, tool | Where the work actually executes |

The user-facing capability groups are `workspace`, `build`, `ship`, `govern`, `legal`, `finance`, `connect`, `local-lab`, `agent-runtime`, `market`, and `internal`.

**Do not infer a product or capability from a package, repository, Worker, MCP server, portal, display name, or hostname.** Product/application identity and canonical capability identity must already resolve upstream.

See [Capability Router Architecture](docs/architecture/CHITTYMARKET_CAPABILITY_ROUTER.md) and the [2026-11-01 live control-plane audit](docs/audits/2026-11-01-marketplace-control-plane-audit.md).

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

## Install Package Groupings

These are **delivery bundles**, not the product taxonomy. Their names may remain stable for compatibility even when the user-facing marketplace is organized by capability group.

### Foundation / Market

| Package | Purpose |
|---|---|
| **chittymarket-manager** | Marketplace operator workflow (`/market`) |
| **chittymarket-canonical** | Market-owned projection definitions and sync source |
| **chittyos-core** | Core session/context operations and base ecosystem projections |

### Routing / Agent Runtime

| Package | Purpose |
|---|---|
| **ch1tty** | Slim intent resolution and tool-routing projection |
| **chittyagent-autobot** | Autonomous feature/PR workflow orchestrator |
| **chittyagent-dispatch** | Canonical-to-runtime projection/dispatch pipeline |
| **nowebmaster** | Cross-surface capability lifecycle and hot-loading workflow |

### Domain Capability Packs

| Package | Purpose |
|---|---|
| **chittyos-devops** | Deploy, health, registry, pipelines, wrangler audit, compliance ops |
| **chittyos-governance** | Governance controls and platform policy projections |
| **chittyos-legal** | Legal workflows: evidence, disputes, docket, fact governance |
| **chittyos-finance** | Finance operating method, reconciliation, books governance |

### Connect / Runtime Delivery

| Package | Purpose |
|---|---|
| **chittyos-gws** | Google Workspace capability projections |
| **chittyos-proxy-agents** | Remote integration/proxy projections |
| **chittyos-mcp** | Standalone ChittyOS MCP packaging / compatibility path |
| **neon-mcp** | Standalone Neon MCP packaging / compatibility path |
### Notes on Runtime Artifacts

Some IDs shown by `/market` are runtime artifacts (skills/agents/MCP entries), not plugin directories. Examples include `chittyhelper`, `chittyagent`, `chittycommand`, and `legal-arsenal`.

## Agent Groupings

| Group | Agents |
|------|--------|
| **Core Service Agents** | `chittyagent-canon`, `chittyschema-overlord`, `chittyagent-register`, `chittyagent-connect`, `chittyagent-claude` |
| **Orchestration Agents** | `chittyagent-autobot`, `chittyagent-dispatch` |
| **Governance/Platform Agents** | `chittyagent-neon` |
| **Proxy Agents** | `chittyagent-chatgpt`, `chittyagent-cloudflare`, `chittyagent-notion` |

## Skill Groupings

| Group | Skills |
|------|--------|
| **Autonomy Pipeline** | `chitty-autonomy`, `chitty-autonomy-affirm`, `chitty-autonomy-discover`, `chitty-autonomy-plan`, `chitty-autonomy-generate`, `chitty-autonomy-implement`, `chitty-autonomy-tidy`, `chitty-autonomy-cicd`, `chitty-autonomy-ship` |
| **Marketplace** | `market` |
| **Core Operations** | `checkpoint`, `chitty-cleanup`, `chittycontext`, `chittyxl` |
| **DevOps Operations** | `chitty-deploy`, `chitty-health`, `chitty-pipelines`, `chitty-registry`, `chittyos-compliance`, `wrangler-audit` |
| **Legal Operations** | `dispute`, `docket`, `evidence-collect`, `fact-governance` |

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

## Runtime Delivery

ChittyMarket does not own the live execution catalog.

- **Ch1tty** provides slim capability discovery and execution routing.
- **Cloudflare MCP Server Portals** can curate remote MCP servers/tools, Access/OAuth policy, Code Mode, Secure Web Gateway, synchronization, and request observability.
- **AI Gateway** governs model-provider traffic and policy; it is not a capability registry.
- **Standalone MCP configs** remain compatibility/advanced delivery paths where needed.

Package installation, canonical registration, portal membership, server synchronization, and server readiness are **separate facts**. A configured or synced MCP server is not runtime-verified unless the target reports a usable ready state.

Current live-account evidence is recorded in [docs/audits/2026-11-01-marketplace-control-plane-audit.md](docs/audits/2026-11-01-marketplace-control-plane-audit.md).
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
