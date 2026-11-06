---
name: chittyos-mcp-routing
description: Route ChittyOS development work to existing ChittyDev, Ch1tty gateway, ChittyAgent Orchestrator, ChittyGAM, Cloudflare MCP and GitHub connectors. Use when asked to use Chitty MCPs, ChittyDev, agent execution, gateway tools, registry or capability discovery.
---

# ChittyOS MCP and ChittyDev Routing

## Discovery first
- Discover live connected tools and their schemas; tool availability is per-chat, not guaranteed by this plugin. Never invent tool identifiers or assume a named service is connected.
- Prefer `ChittyDev.portal_list_servers` and `portal_codemode_search` to discover upstream MCP servers and methods, and `portal_codemode_execute` only after inspecting the selected method schema.
- Prefer `Ch1tty.chitty.search` then `Ch1tty.chitty.execute` for slim-gateway capabilities. Check `Ch1tty.gateway_status` when routing fails.
- Prefer `ChittyAgent_Orchestrator.skill_search` / `agent_search` before `skill_execute` / `agent_execute`; consult `ChittyGAM.list_capabilities` for existing capabilities.
- Use GitHub for canonical repository state, PRs, review and issue evidence; Cloudflare MCP and CF_Builds/CF_Observability for builds, logs and runtime evidence.
- Use ChittyAgent Canon for canonical identity and schema validation; ChittyAgent Auth for auth-provider diagnostics. Never expose resolved credentials.

## Tool discipline
- Inspect exact tool descriptions and required arguments before invocation; linked ChittyDev accounts may differ. Never arbitrarily select an account when ambiguous.
- Use read-only discovery first. Treat MCP execute tools as potentially write-capable; classify side effects and approval gates before calling.
- Distinguish connected MCP availability from plugin packaging: instructions do not themselves install, connect or grant permissions to MCP servers.
- If one gateway fails, attempt an existing authorized alternative once, record the error, then continue safe independent work.
- Do not create parallel services, gateways, credentials or agent registrations where canonical capabilities exist.

## ChittyOS development precedence
1. Repo CHARTER/CHITTY/AGENTS and ChittyRegistry.
2. Canonical auth/identity/secrets and evidence boundaries.
3. Existing ChittyDev, Ch1tty, ChittyAgent, Cloudflare and GitHub execution paths.
4. Only propose a new capability after existing-first reconciliation and explicit need.
