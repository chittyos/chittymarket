# Followup to Gemini Deep Think — Locked Answers + Next-Round Brief

Pairs with `docs/gemini-strategy-v1.md`. This is the message to send back to
Gemini for round 2.

---

## A. Answers to the three open questions (binding decisions)

### 1. Slim-MCP discovery tolerance

**Zero tolerance for silent miss.** Two layers, both required:

- **Static capability index injected at SessionStart** — ChittyContext (the
  `SessionStart` hook) pulls a compact cheat-sheet (names + 1-line descriptions
  + trigger hints) from `agent.chitty.cc/api/v1/capabilities/index?channel=<channel>`
  and injects it into the system prompt. Capped at ~50 lines / ~2K tokens.
  Each channel gets a tailored slice. The index is part of the policy bundle,
  not ad-hoc memory.
- **Dynamic broadening** — when `search` returns < N results or the model hits
  a recognized intent verb ("deploy", "audit", "evidence"), the gateway
  auto-expands the next response with a "did you mean…" capability hint list.

The index carries names + hooks only, never full schemas — preserving the
slim-MCP context-cost win.

### 2. Versioning drift across projections

**Strict semver at the canonical Capability level. Projections inherit, never fork.**

- Canonical source owns the version. `chittyagent-dispatch` projections carry
  `canonical_version` + `projected_at`, no independent versioning.
- Runtime exceptions (e.g., OpenClaw security defaults strip a tool) are
  encoded as **canonical-level capability flags** (`runtime_exclusions: [openclaw]`),
  not as forked projection versions.
- CI gate: the pre-commit drift hook (shipped in #17) refuses commits where a
  projection diverges from the canonical hash without a `canonical_version` bump.
- **Why strict**: drift breaks the "one truth, many runtimes" promise. The
  moment Claude Code is v1.2 and OpenClaw is v1.0, users get different behavior
  at different terminals and we lose deterministic reasoning across channels.

### 3. Local CLI auth bridging for `/market add <connector>`

**Always route through Ch1tty OAuth. Never prompt the local CLI for an API key.**

Non-negotiable under the Sensitive Intent Contract: credentials route through
ChittyConnect, never paste-into-chat, never plaintext long-lived secrets.

Flow:

1. `/market add notion` → manager calls
   `agent.chitty.cc/api/v1/connectors/notion/authorize?channel=claude-code&device=<chittyid>`.
2. Server returns a short-lived authorization URL + device-code (like
   `gh auth login`).
3. CLI prints: `Open https://ch1tty.com/auth/device?code=ABCD-1234 — waiting...`
   and polls.
4. User completes OAuth in browser via Ch1tty portal; token lands in
   **ChittyConnect** (1Password-backed), not on disk.
5. Ch1tty registers a Notion backend on `servers.json` scoped to that ChittyID.
6. CLI polls success: "Notion connected. Available via slim-MCP
   `execute({capability: notion.*})`."

Fail-closed: if Ch1tty/ChittyConnect is unavailable, manager returns
`POLICY_BLOCKED_CHITTYCONNECT_UNAVAILABLE`. No local-prompt fallback ever.

---

## B. Constraints to add for round 2

These are not new — they reflect the governance baseline Gemini's draft did
not explicitly account for.

1. **Identity-first, evidence-grade governance**. ChittyMarket is not a
   marketplace cleanup. It is a capability governance system. Every Canonical
   Capability must map to ≥1 entity in the **P/L/T/E/A** canonical ontology
   (Person / Location / Thing / Event / Authority — `chittycanon://gov/governance#core-types`).
   Capabilities with no entity mapping are smell → hold for re-audit.
2. **Non-repudiation gate**. Any capability touching legal, governance,
   valuation, removal docs, claims, filings, custody, or forensic state must
   carry hash + timestamp + source trail before activation. This applies to
   `@chitty/reasoning` legal projections specifically and gates portal exposure.
3. **Dual-manifest drift is treated as an error**, not a warning. Canonical
   definitions and projection manifests are audited together; mismatches block
   merge.
4. **Per-channel projection allow/deny is explicit**, not implicit. Each
   Capability lists `allowed_projections` and `restricted_projections`. The
   compiler refuses to emit a projection into a channel not on the allow list.
5. **Existing-first search is mandatory** at intake. Before any Capability is
   promoted, the registry + ChittyRegistry + Ch1tty `servers.json` + ChittyMCP
   tool list are searched. Closest canonical wins; new entries require
   "genuinely new job-to-be-done" justification.

Full process spec lives in `docs/capability-registry-audit-runbook.md` v0.2.

---

## C. Round 2 — what we need next from Gemini

Given the locked answers above and the governance constraints, produce:

1. **Canonical Capability schema, finalized**. Extend the round-1 example to
   include: `canonical_version`, `entity_mapping` (P/L/T/E/A array), `runtime_exclusions`,
   `allowed_projections`, `non_repudiation_required` (bool), `evidentiary_risk`,
   `environmental_footprint`, `context_cost`, `slim_mcp_hint` (the cheat-sheet
   line that will land in the SessionStart index). Show 3 worked examples
   across the four taxonomy buckets.

2. **`@chitty/reasoning` legal projection design**. How do `chittyos-legal`
   (docket, dispute, evidence) capabilities behave under slim-MCP discovery
   when they also require the non-repudiation gate? Specifically: where does
   the hash/timestamp/citation-map enforcement live — inside the projection,
   inside Ch1tty `execute`, or as a pre-execute middleware? Trade-offs.

3. **Compiler design for the legacy manifest**. The GitHub Action that
   compiles `.claude-plugin/marketplace.json` from the canonical registry —
   give the algorithm: which Canonical Capabilities are emitted into the
   legacy manifest, in what shape, and how plugin-grouping (the legacy plugin
   buckets the `/plugin add` flow expects) maps from the new taxonomy. Include
   how `@chitty/workspace` capabilities surface as plugins while
   `@chitty/reasoning` ones surface as discoverable-only entries.

4. **Slim-MCP cheat-sheet index spec**. Concrete API contract for
   `agent.chitty.cc/api/v1/capabilities/index?channel=<channel>`: payload
   shape, size cap enforcement, refresh cadence, cache key, and what happens
   when the cap is exceeded (priority/ordering rules). Plus: how the
   "did you mean" dynamic broadening triggers without blowing the context
   budget.

5. **Kill list, expanded with concrete migration steps**. For each of the 4
   kill-list items, produce: the canonical replacement, the migration commit
   sequence, the deprecation window, the user-facing communication, and the
   rollback path.

6. **Risk mitigations, concrete**. For each of the 3 risks (Invisible Tool,
   Offline Degradation, Fragmentation of Expectation), give the specific
   technical mitigation we will implement — not "we will rely on UX badging,"
   but the exact badging schema, the exact fallback API, the exact retry/
   resolution flow.

Output format: same as round 1 — exec summary (5 bullets), then each section
with concrete schemas/algorithms/sequences. No new open questions unless they
materially block decisions; if you have them, mark them P0 vs. P2.
