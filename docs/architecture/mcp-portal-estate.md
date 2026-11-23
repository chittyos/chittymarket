# MCP portal estate (design v0.1 + implementation pointer)

Implementation in this repo (nothing is applied to Cloudflare):

- `scripts/gen-portal-definitions.mjs` + `scripts/portal-classification.json` generate `canonical/mcp-portal/{server,portal}-<id>.md` from `inventory/portals-2026-11-23.json`.
- `plugins/chittyagent-dispatch/scripts/adapters/cf-portal.sh` projects them to `plugins/chittyos-mcp/cf-portal/{servers,portals}/`; `scripts/cf-portal-manifest.mjs` aggregates `manifest.json`.
- `scripts/cf-portal-plan.mjs` emits the dry-run plan `inventory/portal-plan-2026-11-23.{md,json}`.
- Deviations from the design text below: layout is flat with `server-<id>`/`portal-<id>` file names (dispatch resolves canonicals by bare name; neon, dispute, market, ship collide with existing canonicals); frontmatter carries `server_id`/`portal_id`, `auth.target`/`auth.current`/`access_apps` (a list), `classification`, `current_portals`.

---

---
---
title: MCP Portal Estate — ChittyMarket as source of truth
version: 0.1.0
status: draft (definitions not yet approved by operator)
date: 2026-11-23
supersedes_in_part: proposals/GATEWAY_BINDING_CONTRACT.md v0.2 (server auth model, §"servers are unauthenticated")
baseline: chittyos/chittymarket#261 (inventory/portals-2026-11-23.json)
---

# MCP Portal Estate v0.1

## 1. Problem (measured, PR #261 baseline)

- 8 Cloudflare MCP portals, 65 servers, 112 Access apps.
- 46/65 servers `error`; 45 of them are 401 because the operator's "ChittyAgents" Access app
  (2026-11-22 23:45Z) now gates all of `agent.chitty.cc` while those servers are `auth_type: unauthenticated`.
- 63/65 servers sit in more than one portal; portals are not groupings.
- 194 tools carry a doubled prefix (`viewport_viewport_hydrate`), 205 are deprecated aliases, 47 names collide.
- Desired membership today comes from the ChittyRegistry triage doc
  (`chittyagents/mcp-builder/src/lib/portal-reconcile.ts:25-41`), not from ChittyMarket.
  The reconciler is additive only and never removes or recreates a server.
- No ChittyMarket kind exists for a portal server or a portal (`lib/resolve_output.py:_MAP`).

## 2. Locked decisions

| # | Decision | Source |
|---|---|---|
| D1 | **Proposed:** the portal estate is coordinated through ChittyMarket. Composition with the registry: ChittyRegistry stays authoritative for *which services exist and are live* (mcp-builder's triage gate); ChittyMarket `canonical/` defines *how each is exposed* — auth, portal placement, Access binding, tags, tool-name policy, prompt curation. A server is projected only if the registry lists it live. | operator: "coordinate with / through chittymarket" |
| D2 | Keep the "ChittyAgents" Access app on `agent.chitty.cc`. | operator 2026-11-23 |
| D3 | **Pending probe.** Target: every `agent.chitty.cc/<x>/mcp` server is `auth_type: oauth`. CF `PUT /mcp/servers/{id}` ignores `auth_type`, so the change is delete + POST. Not yet proven that an oauth server passes "ChittyAgents" (`tasks` passes through its own two Access apps). Probe run 2026-11-23 22:2xZ: created `viewport-oauth-probe` (no portal, oauth, shared callback) → `status: waiting`, `authentication_status: required`, `registered_at: null`; sync refused. **Finding: every oauth server needs one admin OAuth authorization in the dashboard before it syncs** — 45 recreated servers = 45 authorizations. Alternative recorded as D3-alt: `auth_type: bearer` with `auth_credentials = {"headers":{"cf-access-client-id","cf-access-client-secret"}}` (an Access service token brokered via ChittySecrets/`/chico`) plus a Service Auth policy on "ChittyAgents" — no per-server clicks, fully projectable, but the upstream sees the service identity, not the user (`on_behalf` semantics change). Blocks the apply plan, not the definitions PR. | operator; API probe 2026-11-23 |
| D4 | Tool naming: an upstream tool name never starts with its own server id; the portal's `<server_id>_<tool>` is the only prefix. Matches MCP-SOP v1 §3 (`mcp-builder/src/lib/naming.ts:4-13`). | operator 2026-11-23 |
| D5 | Breaking change, no further deprecation window: aliases are deleted in chittyentity PR `feat/mcp-tool-names-no-self-prefix`. | operator 2026-11-23 |
| D6 | Portal membership is by audience, not "everything everywhere". A server may be in more than one portal only with a stated reason in its definition. | this doc |

## 3. Canonical kinds (new)

### `kind: mcp-portal-server` — `canonical/mcp-portal/servers/<server_id>.md`

```yaml
name: <server_id>                 # == CF server id; the portal tool prefix
canon_uri: chittycanon://core/services/chittymarket#mcp-portal/servers/<server_id>
kind: mcp-portal-server
plugin: chittyos-mcp
runtimes: [cf-portal]
description: |-
  <one line>
upstream:
  url: https://agent.chitty.cc/<route>/mcp
  worker: chittyagent-<x>          # null for third-party upstreams
  repo: chittyos/chittyentity      # null for third-party
auth:
  type: oauth | bearer | unauthenticated
  access_app: <Access app name>    # the app whose destination covers upstream.url, or null
  on_behalf: true|false
portals:                          # target membership; each entry needs a reason when len > 1
  - id: <portal_id>
    reason: <why this audience needs it>
tools:
  naming: no-self-prefix          # D4; the check rejects violators
  expected: [<bare names>]        # from the post-D5 upstream; drift = audit finding
prompts:
  expose: [<names>] | none        # default none for third-party pass-through prompts
resources: unavailable            # the CF servers API returns no resources field (PR #261)
tags:                             # applied only where CF Resource Tagging supports the resource type
  chitty.repo: <owner/repo>
  chitty.path: <build root>
  chitty.env: production
  chitty.portal: <primary portal id>
status: active | retire           # retire = remove from every portal, then delete the server
```

### `kind: mcp-portal` — `canonical/mcp-portal/portals/<portal_id>.md`

```yaml
name: <portal_id>
kind: mcp-portal
plugin: chittyos-mcp
runtimes: [cf-portal]
hostname: <portal hostname>
audience: <who connects through it>
access_app: <the mcp_portal Access app>
status: active | merge-into:<portal_id> | retire
```

Membership is declared on the server, never on the portal, so one file owns each fact.

## 4. Projection

- New `_MAP` rows: `("cf-portal","mcp-portal-server")` → `plugins/chittyos-mcp/cf-portal/servers/{name}.json`,
  `("cf-portal","mcp-portal")` → `plugins/chittyos-mcp/cf-portal/portals/{name}.json`; adapter `scripts/adapters/cf-portal.sh`.
- An aggregate `plugins/chittyos-mcp/cf-portal/manifest.json` (all servers + portals), the artifact mcp-builder will read.
- `scripts/cf-portal-plan.mjs --manifest <manifest> --snapshot inventory/portals-<date>.json` emits the dry-run plan:
  `create`, `recreate(auth_type)`, `delete(retire)`, `membership add/remove`, `tag set`, `no-op`, plus `blocked` rows
  (e.g. an upstream URL with no covering Access app). Deterministic, no network.
- Apply is out of this goal: mcp-builder gains a manifest-driven, non-additive mode in a later chittyentity PR, gated
  on the operator approving the plan and on mcp-builder's CF token gaining "MCP Portals Write" (via `/chico`).

## 5. Portal audiences (classification rules for the builder)

| Portal | Hostname | Audience | Gets |
|---|---|---|---|
| `chitty-mcp` | mcp.chitty.cc | operator core | ChittyOS control-plane agents: tasks, context, viewport, orchestrator, builder, helper, canon, market, monitor, comptroller, ship, git, sync, dispatch, resolve, auth, alchemist, autoassist, command, ai, sandbox, bindings, heartbeat, human-escalator, cleaner, storage, schema, neon, notion, cloudflare |
| `chittycomms` | msg.chitty.cc | messaging | quo, twilio, imessage, bluebubbles, notes, chatgpt |
| `gws-portal` | workspace.chitty.cc | Google Workspace | gws/google only |
| `dev-portal` | dev.chitty.cc | developer docs & tooling | cf-* docs/builds/observability, npm, gh, openai-docs, context7-like third-party |
| `cf` | cf.chitty.cc | Cloudflare platform | cf-* third-party servers, cloudflare agent |
| `apf-portal` | portal.actors.chitty.cc | scraping | apify, ext-apify, chitty-scrape, scrape |
| `chode`, `chittymcp-vm` | chode.chitty.cc, vm.ch1tty.com | near-mirrors of chitty-mcp (59/58 servers); likely the code-mode connectors | builder reads each portal's `code_mode` + description and maps the claude.ai connectors (ChittyMCP, ChittyDev, Chitty Code-Mode, Chitty Msg) to portals. A code-mode portal may legitimately carry every server (D6 exception, reason recorded); otherwise `status` is an operator question |

Live consumers: the claude.ai connectors above call these portals today, so every membership removal is listed
in the plan as a client-visible break.

Definitions are **generated**, not hand-written: `scripts/gen-portal-definitions.mjs` reads the PR #261 snapshot and
a classification table (this section), and hard-asserts definition ids == the 65 snapshot ids, with every server
either placed or explicitly `unclassified`.

Legal/finance agents (evidence, dispute, contextual, finance) stay in `chitty-mcp` only, with matter isolation
enforced by the agents, not by portal placement. Anything a rule does not cover is listed as `unclassified` in the
plan rather than placed.

## 6. Risks

- Recreating a server drops its per-user OAuth connections and its portal membership; the plan must recreate and
  re-add in one step per server, and the operator re-authorizes once per portal afterwards.
- Removing a server from a portal breaks any client that called it there; the plan lists removals separately.
- `chode` / `chittymcp-vm` purpose is unknown; retiring them is an operator decision, not a default.
- CF Resource Tagging may not support Access apps or MCP servers; tags are declared but only applied where the
  API accepts the resource type (the plan marks the rest `unsupported`).
