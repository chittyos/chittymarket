# ChittyMarket: Capability Router Architecture

**Status:** Approved & Finalized  
**Target path:** `docs/architecture/CHITTYMARKET_CAPABILITY_ROUTER.md`  
**Scope:** ChittyMarket, Ch1tty, ChittyMCP, Canonical Agent Projections, Channel Manifests

---

## Executive Summary

ChittyMarket has transitioned from a static file directory of “plugins” into a **Capability Router**.

The marketplace surface prioritizes **Jobs-to-be-Done (JTBD)** groups such as `ship`, `govern`, and `legal`, while the routing layer uses **Execution Classes** such as `@chitty/workspace` and `@chitty/connectors` to decide where and how a capability runs.

Centralized registration in Ch1tty is mandatory for all capabilities. Execution remains local only when the job physically requires local filesystem, shell, LSP, git worktree, hooks, desktop, or browser context.

This architecture enforces:

- gateway-first registration
- zero-trust device-code authorization
- immutable canonical versioning
- projection inheritance
- non-destructive migration
- alias-based compatibility
- channel-aware capability routing

---

# 1. Dual-Layer Taxonomy

Every capability carries both:

1. `capability_group` — the user-facing Jobs-to-be-Done group.
2. `execution_class` — the system-facing runtime/routing class.

Ontology metadata, authority scopes, and context cost are enforcement layers. They are not the primary marketplace navigation model.

Slug convention:

- Generated artifact slugs use **bare names**: `workspace`, `build`, `ship`, `govern`, `legal`, `connect`, `local-lab`, `agent-runtime`, `market`, `internal`.
- Documentation and UI may use Chitty-branded display labels such as `ChittyBuild`, `ChittyShip`, and `ChittyGovern`.
- Branded labels are presentation-layer only. They are not canonical group slugs.

---

## 1.1 User-Facing Capability Groups

The groups below use bare schema slugs. Human-facing UI may render branded display labels such as `ChittyWorkspace`, `ChittyBuild`, and `ChittyGovern`.

### `workspace`

**Label:** Workspace Memory & Session Continuity  
**Job:** Preserve and restore operational continuity.  
**Examples:** checkpoints, session restore, state summaries, edge cache, context persistence, sequential thinking.  
**Ontology:** `P` Synthetic Person, `E` session events.

---

### `build`

**Label:** Understand, Edit & Review Code  
**Job:** Support code search, repo navigation, LSP integrations, PR review, semantic analysis, and code improvement.  
**Ontology:** `T` digital code artifacts, `E` commits/reviews.

---

### `ship`

**Label:** Ship & Operate Services  
**Job:** Deploy, monitor, and operate services.  
**Examples:** Cloudflare Worker deployment, service registry queries, health checks, pipelines, wrangler audit.  
**Ontology:** `L` deployment location, `A` deploy authority, `E` deployment event.

---

### `govern`

**Label:** Governance, Identity & Trust  
**Job:** Enforce identity, canonical rules, trust, policy, and schema discipline.  
**Examples:** ChittyID enforcement, Hookify rules, canonical pattern auditors, schema drift checks.  
**Ontology:** `A` authority, `P` actor identity.  
**Rule:** Globally enabled system-wide; independent of profiles.

---

### `legal`

**Label:** Legal Evidence & Case Workflows  
**Job:** Manage case-scoped legal evidence, facts, disputes, dockets, and chain-of-custody workflows.  
**Examples:** evidence collection, dispute management, fact governance, docket monitoring.  
**Ontology:** `E` evidence/fact events, `T` documents, `L` jurisdiction.  
**Rule:** Requires explicit case scope. No “last active case” fallback.

Approved language:

- “chain-of-custody discipline”
- “non-repudiation support”
- “forensic auditability” only for signed immutable-log capabilities

Banned language until formal audit:

- “E-SIGN compliant”
- “court-admissible”
- “legally binding”

---

### `connect`

**Label:** Connect External Systems  
**Job:** Connect ChittyOS to third-party systems and external namespaces.  
**Examples:** Notion, Cloudflare, ChatGPT, Neon, Supabase, Plaid, Gmail, Calendar, Figma, Mercury.  
**Ontology:** `L` external namespace, `A` delegated OAuth.

---

### `local-lab`

**Label:** Local-Only Tools  
**Job:** Run tools that physically require a local host.  
**Examples:** browser automation, desktop control, shell-dependent scripts, local filesystem, LSPs.

---

### `agent-runtime`

**Label:** Agent Runtime Projection  
**Job:** Manage canonical agent definitions and runtime projection adapters.  
**Examples:** Claude Code agents, Codex skills, OpenClaw agents, orchestrator KV entries.  
**Mode:** Advanced / developer mode.

---

### `market`

**Label:** Marketplace Control Plane  
**Job:** Discover, enable, disable, sync, profile, lint, and diagnose capabilities.  
**Examples:** `/market`, profiles, alias resolution, projection diagnostics.

---

### `internal`

**Label:** Experimental / Owner-only Tools  
**Job:** Hold unsafe, experimental, deprecated, or owner-only artifacts.  
**Rule:** Hidden from normal marketplace UX.

---

## 1.2 Routing Execution Classes

### `@chitty/ambient`

Always-on, low-context, high-frequency primitives.

Examples:

- Sequential Thinking
- ChittyXL Session Manager
- ChittyContext Checkpoints
- Checkpoint Manager
- identity posture
- trust posture
- compact capability index

Rule:

- Ambient is a discovery/context posture, not necessarily a physical execution location.
- Ambient-by-intent can override a physically local workspace primitive into the static prompt index without changing where the tool executes.

---

### `@chitty/workspace`

Local execution requiring one or more of:

- filesystem access
- shell access
- local binaries
- git worktree
- LSP
- hooks
- desktop/browser control

Cannot run in Claude.ai Web or ChatGPT as a true local operation.

---

### `@chitty/connectors`

Cloud APIs and external SaaS/database integrations.

Rules:

- routed through Ch1tty OAuth
- no local API key collection
- no paste-token flows
- credentials terminate in ChittyConnect / approved vault
- fails closed if vault unavailable

---

### `@chitty/reasoning`

Episodic, high-context workflows discovered through Slim-MCP and executed on demand.

Examples:

- legal evidence analysis
- audits
- autonomy workflows
- multi-step investigation
- complex orchestration

---

# 2. Canonical Schema Model

Artifacts are identified by ChittyCanon URIs.

Example:

```text
chittycanon://capability/legal/evidence.collect
```

The canonical record is the sole source of truth. Runtime projections inherit canonical versioning. Projections may carry build hashes and timestamps, but they do not receive independent semantic versions.

## 2.1 Canonical Capability Record

```json
{
  "capability_id": "chittycanon://capability/legal/evidence.collect",
  "legacy_id": "evidence-collect",
  "name": "Collect Evidence",
  "capability_group": "legal",
  "execution_class": "@chitty/reasoning",
  "canonical_version": "1.0.0",
  "projection_version_policy": "inherit-canonical",
  "ontology": {
    "primary": ["E", "T"],
    "secondary": ["P", "L", "A"]
  },
  "discovery": {
    "slim_mcp_hints": ["evidence", "ingest", "chain-of-custody"],
    "high_signal_verbs": ["evidence", "collect", "preserve"]
  },
  "auth_flow": {
    "mode": "existing-session",
    "stores_credentials_in": "ChittyConnect",
    "fail_closed_if_unavailable": true,
    "requires_case_id": true,
    "no_fallback_last_case": true
  },
  "authority": {
    "requires_chittyid": true,
    "requires_case": true,
    "write_scope": "case-scoped",
    "non_repudiation_required": true
  },
  "runtime_exclusions": {
    "openclaw": ["write"]
  }
}
```

## 2.2 Versioning Rules

- Canonical semver controls behavior.
- Projection versions strictly inherit from canonical.
- Runtime differences are expressed with `runtime_exclusions`.
- Projection artifacts may include build hash, generated timestamp, and projection adapter version.
- Drift is not silently accepted.
- Direct edits to generated projections trigger reconciliation.

---

# 3. Discovery and Intent Broadening

## 3.1 Zero-Tolerance Slim-MCP Discovery

To protect context windows without creating silent misses, `chittycontext` requests a tailored capability index at `SessionStart`:

```text
agent.chitty.cc/api/v1/capabilities/index?channel=<channel>
```

## 3.2 Injection Envelope Payload

```json
{
  "index_version": "2026.05.11",
  "channel": "claude_code",
  "text": "Available ChittyOS capabilities:\n- evidence.collect: Case-scoped evidence collection [hint: execute({capability: 'evidence.collect'})]\n...",
  "capabilities": [
    "chittycanon://capability/legal/evidence.collect"
  ]
}
```

Implementation rule:

- `chittycontext` injects only `text` into the system prompt.
- `capabilities[]` supports caching, diffing, diagnostics, and `/market refresh`.

## 3.3 Triple-AND Intent Broadening

Ch1tty returns a “Did you mean...” response only if all three conditions are true:

```text
(search_results < 3)
AND
(verb in high_signal_verbs OR group_hint detected)
AND
(channel_has_compatible_projection == true)
```

Output format:

```json
{
  "status": "needs_selection",
  "reason": "multiple_capabilities_match_intent",
  "candidates": [
    {
      "id": "chitty.legal.evidence.collect",
      "why": "matches evidence + collect"
    }
  ]
}
```

Suggested baseline high-signal verbs:

```json
[
  "audit",
  "deploy",
  "ship",
  "evidence",
  "collect",
  "docket",
  "dispute",
  "checkpoint",
  "restore",
  "sync",
  "register",
  "connect",
  "review",
  "refactor",
  "query",
  "govern"
]
```

---

# 4. Zero-Trust Auth and State Sync

## 4.1 Device-Code Auth Flow

Local CLI prompting for API keys or pasting keys into chat is banned.

Flow:

1. User runs `/market add <capability>`.
2. CLI requests a device code from Ch1tty.
3. CLI prints:

```text
Open https://ch1tty.com/auth/device?code=ABCD-1234
```

4. CLI polls synchronously for 90 seconds.
5. If auth is still pending, it degrades gracefully:

```text
Waiting for auth... 90s. Still pending. Continue working; run /market auth status to resume.
```

6. Tokens are vaulted centrally in ChittyConnect / approved credential vault.
7. If ChittyConnect is unavailable, connector enablement fails closed.

## 4.2 No Always-Running Polling Daemon

Do not spawn long-lived local auth polling daemons.

Allowed:

- foreground polling for 90 seconds
- resumable `/market auth status`
- server-side portal state
- short-lived process invocation

---

## 4.3 Mid-Session Index Staleness

When a capability is added mid-session, refresh behavior depends on the channel.

| Channel | Refresh Mechanism |
|---|---|
| Claude Code | SSE push if available + `/market refresh` command |
| Claude.ai Web | Portal state updates server-side immediately |
| ChatGPT | Next Action call sees updated Ch1tty state; prompt may stay stale |
| Codex | Daemon sync on next polling interval |
| OpenClaw | Explicit `dispatch refresh` for zero-trust determinism |

Rule:

- Do not require `/checkpoint` to refresh capability discovery.
- `/checkpoint` may persist state, but capability index refresh is a marketplace concern.

---

# 5. Security and Governance Rules

## 5.1 Legal Write Capabilities

Write access outside Claude Code requires all of the following:

1. Explicit `case_id` parameter.
2. Session bound to ChittyID with `legal:write:case:<id>` scope.
3. Non-repudiation receipt recorded before mutation:
   - hash
   - timestamp
   - actor
   - capability ID
   - case ID
   - request digest

Hard prohibitions:

- no “last case” fallback
- no cross-case file movement without explicit confirmation
- no direct local mutation of canonical legal state
- no undocumented evidence copy paths

---

## 5.2 OpenClaw Defaults

OpenClaw projections default to read-only.

Write access requires explicit elevation in local signed policy.

Rules:

- Governance writes may be elevatable.
- Legal writes are not elevatable by default.
- Finance writes are not elevatable by default.
- Sensitive write paths require gateway mediation.

---

## 5.3 Compliance Language

Allowed:

- “non-repudiation support”
- “chain-of-custody discipline”
- “forensic auditability” only for signed immutable-log capabilities

Banned pending formal external audit:

- “E-SIGN compliant”
- “court-admissible”
- “legally binding”

---

## 5.4 CI Drift Granularity

`pre-commit-drift` fails PRs only for:

- enforced runtimes
- capabilities touched by the PR
- projections whose canonical source changed

Full-repository drift analysis runs as a non-blocking nightly report.

---

## 5.5 ChittyMCP Visibility

ChittyMCP is an implementation backend behind Ch1tty.

Users should not shop for “ChittyMCP.” They should enable JTBD capabilities. Ch1tty decides whether ChittyMCP tools are required behind the scenes.

---

# 6. Per-Channel UX Matrix

| Channel | Discovery & Install UX | Execution Surface | Excluded Artifacts |
|---|---|---|---|
| Claude Code | `/market`, `/plugin add`; installs local projections and profiles | Local skills, hooks, agents + Ch1tty connectors | Claude.ai-only connectors, remote-only shadows |
| Claude.ai Web | Toggle through Ch1tty Web Portal | Gateway-safe capabilities and remote connectors | `local-lab`, filesystem, shell, LSP |
| Claude Desktop | Portal deep link + Chitty extension | Hybrid: gateway + local tools | background OS daemons, Codex-only projections |
| ChatGPT | Custom GPT / Actions backed by Ch1tty | gateway-safe search/execute and remote services | local filesystem, shell tools, heavy tool bundles |
| Codex / App | daemon-synced skill catalog | OS daemon UI / Codex skill projections | Claude.ai portal connectors, desktop/browser UI control |
| OpenClaw | `dispatch add <cap>` with signed projection | policy-first CLI/orchestrator, read-only default | OAuth cloud connectors unless explicitly authorized |

---

# 7. Phase 0/1 Current Distribution

Phase 1 unified pass produced full coverage across 102 capabilities.

## 7.1 By Job

| Group | Count | Percent |
|---|---:|---:|
| build | 29 | 28% |
| connect | 22 | 22% |
| govern | 15 | 15% |
| ship | 12 | 12% |
| workspace | 6 | 6% |
| legal | 5 | 5% |
| local-lab | 5 | 5% |
| agent-runtime | 4 | 4% |
| internal | 3 | 3% |
| market | 1 | 1% |
| Total | 102 | |

## 7.2 By Execution Class

| Execution Class | Count |
|---|---:|
| `@chitty/connectors` | 77 |
| `@chitty/workspace` | 16 |
| `@chitty/reasoning` | 5 |
| `@chitty/ambient` | 4 |

## 7.3 By Channel Compatibility

| Channel | Compatible | Excluded Reason |
|---|---:|---|
| `claude_code` / `claude_desktop` / `codex` | 102 | none |
| `openclaw` | 97 | 5 legal-write require policy elevation |
| `chatgpt` / `claude_ai` | 78 | 24 workspace + local-lab + agent-runtime need local host |

## 7.4 By Context Cost

| Cost | Count |
|---|---:|
| medium | 89 |
| high | 9 |
| low | 4 |

## 7.5 By Authority

| Flag | Count |
|---|---:|
| requires_chittyid_only | 70 |
| requires_governance_authority | 15 |
| requires_deploy_authority | 12 |
| non_repudiation_required | 8 |
| requires_case | 5 |

## 7.6 Assignment Attribution

| Source | Count |
|---|---:|
| name-rule | 45 |
| category | 34 |
| override | 23 |
| fallback | 0 |

---

# 8. Migration Plan: Non-Destructive Overlay

Physical folder deprecation occurs only after the overlay proves stable.

---

## Phase 0: Freeze and Audit

**Goal:** Map physical artifacts to canonical capabilities without changing behavior.

Actions:

- freeze taxonomy changes
- export current manifest snapshots
- scan `plugins/`
- detect `plugin.json`, `.mcp.json`, `agents/`, `skills/`, hooks
- emit JSON and Markdown audit reports
- flag `inventory-only` artifacts
- identify manual-review candidates

Outputs:

```text
docs/audits/chittymarket-artifact-audit.json
docs/audits/chittymarket-artifact-audit.md
docs/audits/chittymarket-plugin-package-audit.json
```

Telemetry rule:

- artifacts with no detected implementation and zero invocations in 90 days are `inventory-only`
- inventory-only artifacts remain visible only with `/market list --include-inventory`

---

## Phase 1: Capability Overlay

**Goal:** Generate logical capability views without moving files.

Outputs:

```text
capabilities.generated.json
views/by-job.json
views/by-channel.json
views/by-authority.json
views/by-context-cost.json
docs/overrides/capability-group-overrides.json
```

Actions:

- add capability metadata
- add ChittyCanon URIs
- add execution classes
- add ontology metadata
- add authority metadata
- keep old IDs
- use bare JTBD group slugs

---

## Phase 2: `/market` UX Update

**Goal:** Make `/market` serve canonical cards.

Actions:

- default `/market` view shows capability cards
- add alias resolution
- add `/market legacy <old_id>`
- add `/market refresh`
- add `/market doctor`
- old aliases emit warnings pointing to `chittycanon://` URI

---

## Phase 3: Manifest Projection

**Goal:** Preserve `/plugin add` compatibility while shifting to capability packs.

Actions:

- update generation script to read capability packs
- generate `.claude-plugin/marketplace.json` from canonical overlay
- retain old names during alias window
- preserve local plugin paths
- avoid physical moves

---

## Phase 4: Registration Enforcement

**Goal:** Make Ch1tty registration mandatory for cross-channel services.

Actions:

- mark cross-channel services as Ch1tty-managed
- stop recommending local `.mcp.json` for new backends
- implement device-code auth for `connect`
- probe `ch1tty.com/api/v1/backends` to align current connectors
- add linter for missing registration metadata

---

## Phase 5: Canonical Dispatch Hardening

**Goal:** Make generated projections reliable.

Actions:

- complete `chittyagent-dispatch` adapters
- support Claude Code agent projection
- support Claude Code skill projection
- support Codex skill projection
- support OpenClaw agent projection
- support Ch1tty/orchestrator KV projection
- enforce `pre-commit-drift` on touched enforced runtimes

---

## Phase 6: Deprecation and Reshuffle

**Goal:** Remove legacy surface only after proof.

Actions:

- demote old org-chart names
- move duplicate wrappers to `legacy/`
- remove default visibility from deprecated entries
- preserve aliases until sunset
- delete physical directories only when telemetry shows below-threshold use

Alias sunset policy:

- 60-day hard fail target
- 1–2 release cycles for renames
- 2–3 release cycles for splits
- hard deletion only after telemetry shows `< 1%` usage for 30 days

---

# 9. Kill / Merge / Demote List

Physical folder deprecation occurs strictly in Phase 6.

---

## 9.1 Merge into JTBD Packs

### `workspace`

Keep as projections:

- `chittyos-core`
- `chittyxl`
- `chittycontext`
- `checkpoint`
- `chitty-cleanup`
- `sequential-thinking`

---

### `ship`

Keep as projections:

- `chitty-deploy`
- `chitty-health`
- `chitty-registry`
- `chitty-pipelines`
- `wrangler-audit`
- `plugin-sentry`

---

### `govern`

Keep as projections:

- Hookify entity rules
- ChittyID hooks
- deploy gate hooks
- schema drift agents
- `plugin-ralph-loop`
- `agent-chittyagent-canon`

---

### `legal`

Keep as projections:

- `evidence-collect`
- `fact-governance`
- `docket`
- `dispute`
- `search-evidence-documents`

---

### `agent-runtime`

Consolidate into advanced/on-demand runtime capability:

- `chittyagent-autobot` skills
- `plan`
- `ship`
- `tidy`
- `affirm`
- `plugin-chittyhelper`
- `plugin-chittyagent`
- `plugin-chittycommand`
- `chittyagent-dispatch`

---

## 9.2 Demotions and Removals

### `chittyos-proxy-agents`

Demote to `connect`.

Examples:

- Notion
- Cloudflare
- ChatGPT
- Supabase
- Plaid

Action:

- remove as standalone local skills
- preserve as Ch1tty backends / connector projections

---

### `chittyos-mcp` and `neon-mcp`

Demote to legacy/advanced.

Action:

- fold default execution into Ch1tty
- keep fallback only for advanced/local escape hatches
- stop surfacing as normal user marketplace entries

---

# 10. Phase 1 View Generator

Save to:

```text
/tmp/run_phase1_views.py
```

```python
#!/usr/bin/env python3
"""Phase 1: Generate remaining views (by-channel, by-context-cost, by-authority)
from the capabilities.generated.json overlay.
"""
import json
from pathlib import Path
from collections import defaultdict

REPO = Path.home() / ".claude/plugins/marketplaces/chittymarket"
CAP_FILE = REPO / "capabilities.generated.json"
VIEWS_DIR = REPO / "views"


def main():
    if not CAP_FILE.exists():
        print(f"Error: Could not find {CAP_FILE}")
        return

    with open(CAP_FILE) as f:
        data = json.load(f)

    caps = data.get("capabilities", [])

    by_channel = defaultdict(list)
    by_cost = defaultdict(list)
    by_auth = defaultdict(list)

    channels = [
        "claude_code",
        "claude_desktop",
        "codex",
        "openclaw",
        "chatgpt",
        "claude_ai",
        "ch1tty"
    ]

    for c in caps:
        summary = {
            "id": c.get("capability_id", ""),
            "name": c.get("name", ""),
            "group": c.get("capability_group", ""),
            "execution_class": c.get("execution_class", ""),
            "visibility": c.get("visibility", ""),
            "group_assignment_source": c.get("group_assignment_source", "unknown")
        }

        exclusions = c.get("runtime_exclusions", {})
        for ch in channels:
            # Include when no exclusion exists, or when the only exclusion is write.
            # Example: OpenClaw read support remains compatible while write requires elevation.
            if ch not in exclusions or (
                isinstance(exclusions[ch], list)
                and "write" in exclusions[ch]
                and len(exclusions[ch]) == 1
            ):
                by_channel[ch].append(summary)

        cost = c.get("execution", {}).get("context_cost", "medium")
        by_cost[cost].append(summary)

        auth = c.get("authority", {})
        auth_flags = [
            k
            for k, v in auth.items()
            if v is True and k != "requires_chittyid"
        ]
        if not auth_flags:
            by_auth["requires_chittyid_only (default)"].append(summary)
        for flag in auth_flags:
            by_auth[flag].append(summary)

    VIEWS_DIR.mkdir(parents=True, exist_ok=True)

    views = [
        ("by-channel", "Capabilities grouped by supported channel", by_channel),
        ("by-context-cost", "Capabilities grouped by execution context cost", by_cost),
        ("by-authority", "Capabilities grouped by required authority scope", by_auth)
    ]

    for name, desc, view_data in views:
        sorted_groups = {
            g: sorted(items, key=lambda x: x["name"])
            for g, items in sorted(view_data.items())
        }
        out = {
            "version": "1.1.0",
            "generated_at": "2026-05-11",
            "view": name,
            "description": desc,
            "counts": {k: len(v) for k, v in sorted_groups.items()},
            "groups": sorted_groups
        }
        with open(VIEWS_DIR / f"{name}.json", "w") as f:
            json.dump(out, f, indent=2)
        print(f"Generated {name}.json ({len(view_data)} groups)")


if __name__ == "__main__":
    main()
```

Run:

```bash
python3 /tmp/run_phase1_views.py
```

---

# 11. Final Phase 1 Commit Bundle

```bash
cd ~/.claude/plugins/marketplaces/chittymarket

git add docs/audits/ \
        docs/overrides/ \
        docs/architecture/CHITTYMARKET_CAPABILITY_ROUTER.md \
        capabilities.generated.json \
        views/

git commit -m "feat(architecture): Phase 0/1 Capability Router Migration

- Perform Phase 0 artifact and physical plugin package audits
- Establish chittycanon:// URI schemas and bare JTBD group names
- Generate Phase 1 capabilities.generated.json metadata overlay
- Generate capability views (by-job, by-channel, by-cost, by-authority)
- Solidify architectural specification for ChittyMarket as a Capability Router
- Set strict discovery, execution class, and zero-trust auth parameters"
```

---

# 12. Final Operating Principle

ChittyMarket is no longer a folder browser.

It is a capability router.

The user sees the job. Ch1tty owns registration. ChittyMCP and local tools execute only where appropriate. Projections inherit canonical truth. Migration preserves the old world until the new overlay proves it can carry production traffic.

