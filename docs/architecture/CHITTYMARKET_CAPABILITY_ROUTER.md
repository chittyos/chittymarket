# ChittyMarket: Capability Router Architecture

**Status:** Approved & Finalized
**Scope:** ChittyMarket, Ch1tty, ChittyMCP, Canonical Agent Projections, Channel Manifests

## Executive Summary
ChittyMarket has transitioned from a static file directory of "plugins" into a **Capability Router**. The marketplace surface prioritizes **Jobs-to-be-Done (JTBD)** (e.g., *ChittyShip*, *ChittyGovern*), while the routing layer utilizes **Execution Classes** (e.g., `@chitty/workspace` vs `@chitty/connectors`) to dictate where and how an artifact runs.

Centralized registration in Ch1tty is mandatory for all capabilities, enforcing a Zero-Trust Device-Code authorization flow and immutable canonical versioning, ensuring deterministic behavior across all heterogeneous AI channels.

---

## 1. The Dual-Layer Taxonomy
Every capability carries both a `capability_group` (UX/JTBD) and an `execution_class` (Routing/System).

### User-Facing: Capability Groups (JTBD)
*Note: The groups below use the branded display convention. At the schema layer, they use bare slugs (e.g., `build`, `ship`).*

*   **ChittyWorkspace**: Workspace Memory & Session Continuity
*   **ChittyBuild**: Understand, Edit & Review Code
*   **ChittyShip**: Ship & Operate Services
*   **ChittyGovern**: Governance, Identity & Trust *(Globally enabled system-wide; independent of profiles)*
*   **ChittyLegal**: Legal Evidence & Case Workflows
*   **ChittyConnect**: Connect External Systems
*   **ChittyLocalLab**: Local-Only Tools
*   **ChittyAgentRuntime**: Agent Runtime Projection
*   **ChittyMarket**: Marketplace Control Plane
*   **ChittyInternal**: Experimental / Owner-only tools

### Routing Layer: Execution Classes
*   **@chitty/ambient**: Always-on, core OS primitives (Identity, Context, Sequential Thinking). Pre-loaded globally.
*   **@chitty/workspace**: Local execution requiring filesystem, shell, LSP, or git worktree.
*   **@chitty/connectors**: Stateless Cloud APIs. Routed strictly via Ch1tty OAuth.
*   **@chitty/reasoning**: Episodic, massive-context workflows (Legal, Audits). Discovered via Slim-MCP search, executed on-demand.

---

## 2. Canonical Schema Model
Artifacts are identified by `ChittyCanon` URIs (e.g., `chittycanon://capability/legal/evidence.collect`). The canonical record is the sole source of truth. Projections carry a build hash and timestamp, but **no independent semver**. Deviations are handled via `runtime_exclusions`.

*   **Canonical Versioning:** Strict semver is maintained at the canonical capability level.
*   **Projection Version Policy:** Strict inherit. Projections cannot fork.
*   **Runtime Exclusions:** If a runtime deviates (e.g., OpenClaw strips a tool), it is encoded as a canonical capability flag (`runtime_exclusions`), not a forked version.

---

## 3. Discovery & Intent Broadening

### Zero-Tolerance Slim-MCP Discovery
To protect context windows without risking silent misses, `chittycontext` requests a tailored index at `SessionStart` from `agent.chitty.cc/api/v1/capabilities/index?channel=<channel>`.

**Injection Envelope Payload:**
```json
{
  "index_version": "2026.05.11",
  "channel": "claude_code",
  "text": "Available ChittyOS capabilities:\n- evidence.collect: Case-scoped evidence collection [hint: execute({capability: 'evidence.collect'})]\n...",
  "capabilities": ["chittycanon://capability/legal/evidence.collect"]
}
```

*Implementation Note: `chittycontext` injects only the `text` field into the system prompt. The structured array supports caching, diffing, and local diagnostics without consuming tokens.*

### Triple-AND Intent Broadening

If an LLM queries the registry, Ch1tty applies a highly conservative fallback. Broadening to a "Did you mean..." response occurs **only if all three conditions are met**:

1. `(search_results < 3)`
2. `AND (verb ∈ high_signal_verbs OR group_hint detected)` *(using the 16 baseline verbs: deploy, audit, evidence, etc.)*
3. `AND (channel has compatible projection)`

**Output format:** `{ "status": "needs_selection", "candidates": [...] }`

---

## 4. Zero-Trust Auth & State Sync

### Device-Code Auth Flow

Local CLI prompting for API keys or pasting into chat is strictly banned (Sensitive Intent Contract).

1. `/market add <capability>` triggers a device code request.
2. CLI output: `Open https://ch1tty.com/auth/device?code=ABCD-1234`
3. **Foreground Polling:** The CLI polls synchronously for **90 seconds**.
4. **Background Degradation:** If incomplete after 90s, it degrades gracefully to a resumable state (no always-running daemons): `Still pending. Continue working; run /market auth status to resume.`
5. Tokens are vaulted centrally in ChittyConnect (1Password).

### Mid-Session Index Staleness

When a capability is successfully added mid-session, state synchronization varies by channel architecture:

| Channel | Refresh Mechanism |
| --- | --- |
| **Claude Code** | SSE push (via SLIM/A2A handlers) + `/market refresh` command |
| **Claude.ai Web** | Portal state updates server-side immediately |
| **ChatGPT** | Next Action call sees updated state (Prompt may stay stale; acceptable) |
| **Codex** | Daemon sync on next polling interval |
| **OpenClaw** | Explicit `dispatch refresh` (Zero-trust determinism requirement) |

---

## 5. Security & Governance Rules

* **Legal Write Capabilities:** Write access outside Claude Code requires three un-bypassable components:
  1. Explicit `case_id` parameter. (No "last case" fallback).
  2. Session bound to ChittyID with `legal:write:case:<id>` scope.
  3. Non-repudiation receipt (hash + timestamp + actor) recorded *before* mutation.


* **OpenClaw Defaults:** All projections default to **read-only**. Write access requires explicit elevation in the local `openclaw.yaml` policy file. *Note: Governance writes are elevatable; Legal/Finance writes are NEVER elevatable.*
* **Compliance Language:** Documentation is restricted to asserting *"Non-repudiation support"* and *"Chain-of-custody discipline"*. *"Forensic auditability"* is reserved strictly for capabilities producing signed, timestamped, immutable logs (e.g., `chittyevidence`).
* **CI Drift Granularity:** The `pre-commit-drift` hook fails PRs **only** for enforced runtimes and capabilities physically touched by the PR. Full-repository drift analysis is handled via a non-blocking nightly report.
* **ChittyMCP Visibility:** ChittyMCP acts entirely as an implementation backend behind Ch1tty. Its 21 tools surface as Ch1tty-discoverable capabilities, not as a separate marketplace.
* **Primary UX Surface:** Three surfaces, one source: **Ch1tty portal** (cross-channel browse), `/market` (developer entry in Claude Code/Codex), neutral web (public discovery). All read from the same canonical capability records.

---

## 6. Migration Plan (Non-Destructive 7-Phase Overlay)

* **Phase 0: Freeze & Audit.** Execute audit scripts. Map physical artifacts to capabilities. Auto-flag `inventory-only` for artifacts with 0 invocations in 90 days.
* **Phase 1: Capability Overlay.** Generate `capabilities.generated.json` and views. Add metadata to existing files without moving them.
* **Phase 2: `/market` UX Update.** `/market` serves canonical cards. Add alias resolution. Old aliases trigger a `console.warn` pointing to the new `chittycanon://` URI.
* **Phase 3: Manifest Projection.** Generate `.claude-plugin/marketplace.json` dynamically from capability packs to preserve `/plugin add` compatibility.
* **Phase 4: Registration Enforcement.** Mark cross-channel services as Ch1tty-managed. Implement Device-Code Auth.
* **Phase 5: Canonical Dispatch Hardening.** Deploy projection adapters. Enforce `pre-commit-drift` hook in PRs.
* **Phase 6: Deprecation & Reshuffle.**
  * **Alias Sunset Policy:** Remove physical directories/aliases only when telemetry confirms `< 1%` usage for 30 days (effectively a 60-day hard fail for renames).



---

## 7. The Kill / Merge / Demote List

*Physical folder deprecation occurs strictly in Phase 6.*

**Merge into JTBD Packs (Keep as Projections):**

* **➔ workspace**: `chittyos-core`, `chittyxl`, `chittycontext`, `checkpoint`, `chitty-cleanup`, `sequential-thinking`
* **➔ ship**: `chitty-deploy`, `chitty-health`, `chitty-registry`, `chitty-pipelines`, `wrangler-audit`, `plugin-sentry`
* **➔ govern**: Hookify entity rules, ChittyID hooks, deploy gate hooks, schema drift agents, `plugin-ralph-loop`, `agent-chittyagent-canon`
* **➔ legal**: `evidence-collect`, `fact-governance`, `docket`, `dispute`, `search-evidence-documents`
* **➔ agent-runtime**: `chittyagent-autobot` skills (`plan`, `ship`, `tidy`, `affirm`) consolidated into a single on-demand workflow; `plugin-chittyhelper`, `plugin-chittyagent`, `plugin-chittycommand`, `chittyagent-dispatch`.

**Demotions & Removals:**

* `chittyos-proxy-agents` (Notion, Cloudflare, ChatGPT, Supabase, Plaid) ➔ **Demote to connect** (Ch1tty Backends / Remove local skills).
* `chittyos-mcp` & `neon-mcp` ➔ **Demote to legacy/advanced** (Fold default execution into Ch1tty).
