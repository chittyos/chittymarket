# ChittyMarket Refactor — Gemini Strategy Prompt

Use this prompt to drive a from-first-principles refactor of ChittyMarket,
grounded in evolved user experience across heterogeneous AI channels.

---

You are a product/platform architect. Help me refactor ChittyMarket — the artifact
marketplace for the ChittyOS ecosystem — from first principles, driven by evolved
user experience across heterogeneous AI channels.

## Current state

ChittyMarket today is a dual-manifest repo:
- `.claude-plugin/marketplace.json` — 12 plugins for native Claude Code `/plugin add`
- `marketplace.json` — 108-artifact inventory consumed by a `/market` skill

Current plugin groupings (org-chart-style, not UX-driven):
- chittyos-core (session/context + ecosystem agents)
- chittyos-devops (deploy/health/registry/pipelines/compliance)
- chittyos-legal (evidence/disputes/docket)
- chittyos-governance (hookify rules + neon-schema agent)
- chittyos-proxy-agents (Notion/ChatGPT/Cloudflare proxies)
- chittymarket-manager (/market skill)
- chittyos-mcp + neon-mcp (standalone MCP wrappers)

Artifact types in the inventory: plugins, skills, agents, MCP servers, hooks,
slash commands, and remote ChittyAgent services.

## The channels that consume these artifacts

Each channel ingests/uses artifacts differently — and that difference now matters
more than the org-chart groupings:

| Channel        | How artifacts arrive                          | Constraints                                  |
|----------------|-----------------------------------------------|----------------------------------------------|
| Claude Code    | `/plugin add`, local skills, `.mcp.json`      | Full filesystem, rich tools, large context   |
| Claude.ai web  | Portal MCP connectors                         | Server-side only, no filesystem              |
| Claude Desktop | MCP connectors + extensions                   | Mixed — some local, some gateway             |
| ChatGPT        | Custom GPTs, MCP (limited), Actions           | Different tool semantics, smaller context    |
| Codex / Codex App | Skills via daemon sync                     | Local-ish, different runtime                 |
| OpenClaw       | Skills via dispatch projection                | Self-hosted, security-first defaults         |

We also project a single canonical agent definition into per-runtime adapters
via `chittyagent-dispatch` (canonical → claude-code / codex-skill / openclaw-agent).

## The two MCP gateways that change everything

1. **Ch1tty** (`ch1tty.com/mcp`) — single OAuth-protected MCP aggregator. Adds
   new backends to `servers.json` once; all channels (Claude, ChatGPT, mobile,
   API) get them. Pairs with `chittyagent-orchestrator/slim-mcp` which exposes
   only 2 tools (`search` + `execute`) to keep context lean — capabilities load
   on-demand.
2. **ChittyMCP** (`mcp.chitty.cc/mcp`) — HTTP gateway, 21 tools, MemoryCloude
   persistence, credential retrieval, Notion/Neon queries, ecosystem awareness.

Centralized registration is policy: NEVER recommend adding tools to local
`.mcp.json` — register backends to Ch1tty so all channels inherit them.

## What to produce

Give me a refactor strategy for ChittyMarket that answers:

1. **What groupings should replace the current org-chart-style plugins?**
   Drive groupings from how a user/model actually reaches for the artifact —
   by *job-to-be-done*, by *channel-affinity*, by *context-cost*, or some other
   axis you propose. Justify the axis.

2. **What is the right artifact taxonomy across channels?**
   How should we model the fact that the same canonical agent fans out to
   Claude Code skill / Codex skill / OpenClaw agent / Ch1tty-registered tool?
   Should the marketplace surface canonical sources, channel-specific projections,
   or both? How do we avoid the user seeing 5 entries for "the same thing"?

3. **Per-channel UX matrix.** For each channel above, what should the install
   experience look like? Where does the marketplace live in that channel's
   surface area? (Slash command? Web portal? Server-side capability index?)
   Which artifacts should *not* appear in which channels?

4. **Gateway-first vs. local-first.** The Ch1tty slim-MCP pattern means
   capabilities can load on-demand without bloating context. ChittyMCP has 21
   pre-loaded tools. When should a new capability be a Ch1tty backend vs. a
   slim-MCP-discoverable skill vs. a ChittyMCP tool vs. a local plugin?
   Propose a decision tree.

5. **Migration plan.** Given the existing 12 plugins / 108 artifacts and the
   dual manifest, what is a low-risk path from today's groupings to the new
   strategy? Which moves are pure renames, which are content reshuffles, which
   require deprecation cycles?

6. **What we should kill.** Be opinionated. Which current plugins, skills, or
   agents should be merged, demoted to "internal," or removed entirely because
   the channel evolution has made them obsolete?

7. **Risks and tradeoffs.** Where does this strategy weaken the experience?
   What gets harder? Which channels lose capabilities under the new design?

Constraints:
- Centralized registration is non-negotiable (Ch1tty owns the registry).
- Canonical-first authoring is non-negotiable (one source, many runtime
  projections via chittyagent-dispatch).
- The native `.claude-plugin/marketplace.json` must stay functional for
  `/plugin add` users — it can shrink/restructure but can't disappear.
- Don't propose breaking ChittyID, Trust, or the P/L/T/E/A entity ontology.

Output format:
- Executive summary (5 bullets max)
- Proposed taxonomy with concrete plugin/group names
- Per-channel UX matrix (table)
- Decision tree for "where should a new capability live?"
- Migration phases with rough effort estimate
- Kill list
- Open questions for me to answer before you finalize
