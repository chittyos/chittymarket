# Environment & Operational Canon

Durable facts about this operator's environment. Load when orienting in a new session, resolving paths, or acting on governance/authority.

## Host duality (the #1 gotcha)

`~/.claude/CLAUDE.md` references `~/.ops/` and `~/projects/...` — those are **VM paths** on `chittyserv-vm` (Oracle Cloud), **not present on the local Mac**.

- **Local Mac (`chittymini-00`):** operator baselines live at `/Volumes/chitty/Workspace/openclaw/ops/`. Edit-and-SSH box only.
- **ChittyOS service/repo code is VM-only:** `ssh chittyserv-vm` → `~/projects/github.com/...`. `chittyserv-vm` is canonical; `chittyserv-dev` is a legacy alias for the same host. Public-IP fallback: `ssh chittyserv-public`.
- **Run repo commands on the VM, not locally.** "We're not working on this machine anymore."
- Always resolve paths against the actual host before acting.

## Node roles

- **`chittymini-00` = the operator (treat it as "me").** It is the operator's personal **orchestration seat** — the device Nick works *from*. It **pivots**: sometimes attached to the cluster, sometimes traveling solo; it will take temporary, travel-scoped cluster-adjacent roles (e.g. the iPhone-tether internet-sharing gateway) *because that's where the operator physically is*. But it is **primarily a personal device, not cluster infrastructure** — do not pin **persistent, always-on** infra roles (permanent subnet router, exit node, standing gateway, iMessage host) to it as if it were a stable cluster node. Persistent infra belongs on `chittyserv-vm` or `chittymini-02..06`; -00 does the *transient* version of those because it is the operator's hands. When -00 takes such a role, scope it as travel/opt-out (idempotent, easy to detach), not permanent pinning.
- **All permanent code, storage, and processes live on the cluster — never on -00.** -00 is ephemeral: an orchestration/edit-and-dispatch seat. Anything durable (services, data, standing daemons, state) belongs on `chittyserv-vm` or a `chittymini-0N` cluster node. If you're about to persist something on -00, that's a smell — place it on the cluster and orchestrate it from -00.

## The chittyserv cluster

`chittyserv` = the compute fabric: **`chittyserv-vm` (cloud) + the `chittymini-00..06` nodes.** The `chittymini` nodes ARE the cluster.

**Model: fungible capacity + logical roles + dynamic mapping (do NOT hard-pin roles to boxes).**
- **Physical nodes are fungible capacity.** Each advertises what it has (cpu/mem/node/uptime/health) to a central registry. A node is a slot, not an identity.
- **Roles are logical orchestration identities** — e.g. "Finance Orchestrator Director" — addressable by a stable name (`ssh finance-orchestrator`) that resolves to whatever node currently backs the role. Roles move; addressing doesn't change.
- **Work lives in a system that maps it to available capacity** (a scheduler/placement layer on `chittyserv-vm`), not in per-node hardcoded jobs. Nodes pull assigned roles/tasks; the mapper reassigns on failure or load.
- So: **don't say "chittymini-04 is the vector store."** Say "the vector-store role currently runs on whatever node the mapper placed it on," reachable by its logical alias.

**Fixed anchors (not fungible):**
| Element | Where | Nature |
|---|---|---|
| `chittyserv-vm` (`100.86.86.0`) | cloud | Durable-work home + the **placement/orchestration brain** + gateway + split-DNS. |
| `chittymini-00` (`100.69.69.0`) | operator | **Operator seat (ephemeral).** Orchestrates the fleet; hosts nothing permanent; pivots in/out. |
| `chittymini-01..06` (`100.69.69.1..6`) | homelab | **Fungible worker capacity** (2012 Catalina). `-01` currently backs the iMessage-bridge role. |
| `chittyclaw` (`100.69.69.7`) | — | OpenClaw node (tagged). |

- Canonical topology decisions: `/Volumes/chitty/Workspace/openclaw/ops/decisions/` (ADR 0001 = openclaw per-node split; the fungible-capacity model supersedes its static per-node role framing — ratify in a successor ADR).

**Two planes (how work runs):**
- **Control plane — deterministic, no LLM in the hot path.** Capacity registry + placement/scheduler + heartbeat + failover (brain on `chittyserv-vm`). Reliability-critical; keep it dumb. Placement may be LLM-*advised* but the loop stays deterministic.
- **Execution plane — LLM/agentic.** Logical roles ARE LLM agents (OpenClaw/ChittyAgent instances with persona + context). They drain work for their role and execute by reasoning + MCP tool-use, routing inference through **chittyclaw → CF AI Gateway (`three-wise-men` dynamic route)** for cloud models, or **local `ollama` on-node** for the cheap/offline lane. Don't hardcode the model — the dynamic route decides. Tools via MCP (Ch1tty `:9099`, cowork `:8850`); the gateway token comes via the broker, never on the node in plaintext. See `llm-routing.md`.
- **`ollama` on the minis = the on-node execution lane for these agents** (not a competing "inference fleet" idea) — light/cheap/offline reasoning local, heavy reasoning to CF cloud models via the gateway. Bounded by 2012 Catalina hardware → small local models only.

## Conflict precedence (who wins)

`~/.ch1tty/canon` (write-origin / authoring root) → `~/.ops` shared baselines → `~/.claude/CLAUDE.md` (interprets, never redefines). Neon / Cloudflare / GitHub are **execution replicas**; origin↔replica drift is a policy incident, not a merge. (`~/.ch1tty/canon/fractalled-authority-direction-v1.md`)

## Operating posture — Consciousness Coordinates {TY, VY, RY, tau}

Dynamic operating state, distinct from static ChittyID (`openclaw/ops/consciousness-coordinates.md`, active baseline):
- **TY** = ontological identity/role/lane (inferred from artifacts, not self-claimed)
- **VY** = behavioral trust (earned through good loops; decays on drift)
- **RY** = earned/delegated authority (high TY ≠ high RY)
- **tau** = temporal/causal position in workflow
- Default synthetic posture: **high-TY, medium-VY, low-RY.** Secrets / deploy / governance / destructive actions require explicit **high RY**.

## Lane model (default authority)

Default lane = `implementation`. (`operator-manifest.json` `policy.lanes`)
- `strategy` — low authority, read-only discovery/design
- `implementation` — medium, code-write-with-verification
- `review` — low, findings-first, no edit by default
- `operations` — high-gated, deploy/secrets under policy

## Canonical governance — P/L/T/E/A

Five entity types (`chittycanon://gov/governance#core-types`): **P**erson / **L**ocation / **T**hing / **E**vent / **A**uthority. All five mandatory in any validation; **Authority (A) never omitted**; **Claude/agents are Person (P), never Thing**; "Entity" is not a valid type value. ChittyID format `VV-G-LLL-SSSS-T-YM-C-X`.
- API boundary: `mint.chitty.cc` wants full-word camelCase `entityType` (`person`/`place`/`thing`/`event`/`authority`), NOT the P/L/T/E/A codes — map at the boundary. Python `urllib` gets 403 (UA filtered); use `curl`.

## Capability centralization (binding)

Never add MCP servers / tools / skills to local `.mcp.json` or `~/.claude/skills/` for capabilities that should be centralized. Register through Ch1tty's backend (`servers.json`, orchestrator KV `skill:index`/`agent:index`); use the slim-MCP `search`+`execute` pattern. Session state → `chittyagent-tasks`; persistent memory → ContextConsciousness — not local JSON.

## Operator events

Emit via `openclaw/ops/write-operator-event.sh` (VM canonical `~/.ops/write-operator-event.sh`) with lane + T/V/R/tau. Types: `tool_event`, `session_start`, `session_end`, `context_commit`, `checkpoint_save`, `escalation`, `deploy_action`. Tool events also flow to Neon via `can chitty log-tool`.

## Workspace map (`/Volumes/chitty/Workspace/`)

| Dir | What it is |
|---|---|
| `process-ops/` | Ecosystem-ops bridge (SSH-Makefile to VM); health/registry/inventory, secret-migration runbooks |
| `dev-ops/` | Dev/infra ops — homelab networking, camera monitors, MCP scaffold, email routing |
| `storage-ops/` | R2 / Google Drive sync / ChittyStorage / evidence ingestion |
| `openclaw/` | `chittycorp/ops` IaC — operator baselines (`ops/`), per-host configs, standards |
| `ai-parity/` | Portable AI-tooling parity across Codex/Claude/OpenClaw (config distribution) |
| `memory/` | Daily continuity notes `memory/YYYY-MM-DD.md` |

## Service topology & validation

Services are tiered 0–5 at `*.chitty.cc`. Treat the `process-ops/CLAUDE.md` inventory as local audited truth and **always re-verify live health** rather than trusting docs (several services are 522/aspirational; ChittyLedger largely aspirational; registry coverage partial). Health = `curl -s https://{svc}.chitty.cc/health | jq .`; catalog = `curl -s https://registry.chitty.cc/api/services | jq .`. Caveats: `trust.chitty.cc` (not `chittytrust.`), `dispute.chitty.cc` singular.

## Never blind-purge `~/.claude/` artifacts

todos / debug / security_warnings / session_logs each have a ChittyOS ingestion destination (chittyagent-tasks, ChittyLedger) — ingest before cleanup.
