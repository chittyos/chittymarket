## Capability audit — `session-wake` (2026-11-11)

**Under audit:** a slim, environment-independent, authority-gated session bootstrap served as a decision tree (identity → registration → bundle hash → location → trust → intent → escalation), proposed as the successor to the 21 local SessionStart hooks on chittyserv-vm.

### 1. Existing-first search

| Where | Found |
|---|---|
| `capabilities.generated.json` (overlay) | `govern/session-identity-card`, `workspace/chittycontext-checkpoints`, `workspace/chittyxl-session-manager`, `workspace/checkpoint-manager`, `workspace/context-resume`, `workspace/orphaned-task-reclaim`. **No record for policy-bundle, doctrine seed, sessions/sync or channel register/sync.** No "wake"/"bootstrap" record. |
| `registry.chitty.cc/api/v1/tools` | `chittyauth`, `chittycontextual`, `chittyregister` registered; no bootstrap/session capability. |
| `marketplace.json` names | none matching session/bootstrap/wake. |
| ChittyConnect (live) | `GET /api/v1/doctrine/seed` → 200 (public orchestrator directive); `GET /api/v1/identity/{chittyId}/policy-bundle[/check]` (ETag, sha256; "policy travels with the ChittyID, not the channel"); `POST /api/v1/sessions/sync` (session binding, ContextConsciousness). Consumed today by `fetch-policy-bundle.sh` and `chittycontext-session-start.sh`. Route source not located in the local `chittyconnect` checkout — gap noted. |
| Orchestrator (live, verified 2026-10-25) | `POST agent.chitty.cc/orchestrator/api/v1/channels/register`, `GET …/channels/:id/sync` — authenticated, DID must equal `caller_chitty_id`. |
| ch1tty `servers.json` | ChittyOS Session Coordinator, Viewport (`viewport.chitty.cc/mcp`), Context Agent, ChittyAgent Orchestrator. |
| Local | 9 user SessionStart hooks + 12 plugin hooks; `arias-session-start` (matter-scoped leaf, not general). No prior artifact named "wake-up sequence" in canon, hooks, memory, buffers, or Notion. |

**Gate result:** every node of the tree already has an owner. Nodes 1 (ChittyAuth), 2 (orchestrator channels), 3 (ChittyConnect policy-bundle), 4 (ChittyConnect sessions/sync + Viewport), 5 (ChittyTrust), 6 (operating-defaults skills), 7 (ChittyConnect broker). What does not exist is the **composition**: one call that walks them in order and returns a tiered payload. That is a projection over existing capabilities, not a new root.

### 1b. Lineage (recovered by the operator from prior conversations, 2026-11-11)

The original is **"The Wake-Up Sequence"** (2025-08-17): `WAKE UP → WHO AM I? → WHERE AM I? → WHEN AM I? → WHAT DO I DO? → MISSILE — EXECUTE`, with `.claude/hooks/wake_up.sh`, `/wake`, `/project/wake`, SessionStart init, statusline + persistent memory, registry/project orientation, post-tool cleanup and self-review. A 2025-10-21 conversation gave the conceptual frame: identity reconstruction (Memento) — wake, look around, where/what/when/who am I. **None of the August artifacts exist on chittyserv-vm, in canon, or in the git history of chittyentity / ch1tty / chittymarket / chittyops** (searched 2026-11-11); the reported implementation was never committed here. Status of that claim: unverified, treated as lost.

Mapping onto the tree: WHO AM I = nodes 1–2 (identity, registration) · WHERE AM I = node 4 (host, lane) · **WHEN AM I = restored as node 4b** (clock, billing period, session/checkpoint position, task-board state — the tier-0 payload carries `now`, `period`, `last_checkpoint`) · WHAT DO I DO = node 6 (intent) · MISSILE = node 7 (execute, with lane gates re-checked). Nodes 3 and 5 (bundle hash, trust) are the authority insertions the operator asked for. `canonical_id` keeps the recovered name: `wake-up-sequence`, display "Wake-Up Sequence"; `session-wake` is an alias.

### 2. Classification

- **A. Job-to-be-done:** `govern` (resolve who/where/with-what-authority before any work; secondary: `remember`)
- **B. Environmental footprint:** `network-service` (one authenticated GET; no filesystem writes beyond a cache)
- **C. Evidentiary risk:** `medium` — it decides which lanes a session may enter; a wrong answer fails open. No matter facts are carried (legal leaves require their case parameter).
- **D. Runtime projection:** `gateway-search-execute` via ch1tty for agents; a plain HTTPS route for runtimes without MCP (Codex, ChatGPT, OpenClaw, fresh host).
- **E. Entity mapping:** P (the synthetic Person waking — `claude-person-not-thing`), A (authority: trust level + policy bundle), L (host/lane), E (session-start event, telemetry row).

### 3. Matrix walk

Step 1 — *already exists under another name?* **Yes, in parts** (policy-bundle, sessions/sync, channels/sync, doctrine seed, viewport). → **merge**: compose into ChittyConnect's session capability as a single route; retire the local hook sprawl behind it. Step 3 (genuinely new) does not fire; the novelty is ordering and tiering, which belong to the owner of the pieces.

### 4. Outputs

**Taxonomy entry**
```yaml
canonical_id: wake-up-sequence   # alias: session-wake
display_name: Session Wake (authority-gated bootstrap)
job_to_be_done: govern — resolve identity, registration, policy, location, trust and intent in order, returning only the context those checks license
entity_mapping: [P, A, L, E]
source_of_truth: chittyos/chittyconnect — /api/v1/sessions/wake (to be added; composes doctrine/seed, identity/{id}/policy-bundle, sessions/sync, orchestrator channels/:id/sync, ChittyTrust evaluate)
environmental_footprint: network-service
evidentiary_risk: medium
canonical_version: 0.1.0
runtime_exclusions: []
allowed_projections: [claude-code, codex, openclaw, chatgpt, universal, plain-https]
restricted_projections: [notion]   # no execution context to gate
non_repudiation_required: false     # telemetry row per wake is required; hash chain is not
slim_mcp_hint: "wake: who am I / where am I / what may I do — call first, <1 KB, tiers unlock per check"
owner: chittyagent-connect (ChittyConnect); trust node delegated to ChittyTrust
status: experimental
```

**Disposition**
```yaml
decision_id: CAP-2026-11-11-session-wake
date: 2026-11-11
capability_name: session-wake
canonical_id: wake-up-sequence   # alias: session-wake
decision: merge
rationale: Matrix step 1 — every node already exists (ChittyAuth, orchestrator channels, ChittyConnect policy-bundle + sessions/sync + doctrine seed, Viewport, ChittyTrust). The missing piece is the composition and the tiering, which is a route on the owner of the majority of the pieces, not a new root. The 21 local SessionStart hooks are a projection of this and collapse to one fetch.
duplicates_found: [fetch-policy-bundle.sh, chittycontext-session-start.sh, viewport-hydration.sh, team/card.sh, govern/session-identity-card (partial)]
migration_required: yes
next_action: ChittyConnect CHARTER amendment + build spec for GET /api/v1/sessions/wake; then replace the 9 user hooks with one fetch; plugin hooks untouched
review_date: 2026-12-11
```

**Migration queue item**
```yaml
migration_item: session-wake-route
from_artifact: ~/.claude/hooks/{fetch-policy-bundle,chittycontext-session-start,viewport-hydration,can-safe authenticate-context}.sh + team/card.sh
to_canonical_capability: session-wake (ChittyConnect /api/v1/sessions/wake)
action: merge
blocking_dependencies:
  - ChittyTrust /v1/evaluate returned 500 on 2026-09-18 (TRUST_CACHE binding undefined) — node 5 fails closed until fixed
  - orchestrator mint_proof stored but not verified (#826) — listed as a known hole, not a blocker
  - route source for doctrine/seed + policy-bundle not located in local chittyconnect checkout — confirm the deployed worker's repo before writing the spec
risk_level: medium
owner: chittyagent-connect
status: backlog
completion_evidence: (pending)
```

### 5. Quality gates

- [x] Existing inventory searched first (overlay, registry, marketplace, live endpoints, ch1tty servers, local hooks, Notion)
- [x] Exactly one primary job-to-be-done (govern)
- [x] Entity mapping present (P, A, L, E)
- [x] Exactly one disposition (merge)
- [x] Evidence-touching items routed to Legal space — legal leaves stay matter-scoped (`arias-session-start`), general tree carries no matter facts
- [x] High-privilege items not broadly exposed — tier served by server-side trust, secrets never in payload
- [x] Platform variants tied to one canonical identity (session-wake)
- [ ] Dual-manifest drift — the overlay has no records for policy-bundle / sessions/sync / channels; the upstream generator must add them (not hand-edited)
- [x] Non-repudiation gate — not required; telemetry row per wake required
- [x] Retirement path — hooks retire only after the route serves the same fields; rollback = re-enable hooks
- [x] Decision log includes source links
