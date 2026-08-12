---
name: nb-development-defaults
description: Global development defaults for this operator. Use for almost all coding, debugging, ChittyOS integration, architecture, compliance, auth/token, branch-finalization, and workflow-automation tasks unless the operator explicitly overrides these defaults. Covers conditional execute-now posture, discovery-first (service + capability), separated adversarial review, worktree isolation, broker-first credentials (1Password RETIRED), and non-interactive branch finalization.
canon_uri: chittycanon://core/services/chittymarket#skills/nb-development-defaults
kind: skill
classification:
  - governance
  - workflow
  - defaults
  - adversarial-review
runtimes:
  - claude-code
  - codex
plugin: chittyos-core
---

# NB Development Defaults

Derived from repeated directives across local Claude and Codex histories.

## Default Posture

**Why `execute now` is safe here (BINDING caveat).** The entire system is managed by
**one human**. Human diff-review therefore cannot be the quality gate — it does not
scale, and a required-approval rule cannot be self-satisfied by a solo operator. The
execute-now default is licensed by **separated adversarial AI review plus AI-driven
CI/CD by automated agents/actors**, not by speed. The two move together: if the
adversarial review and automated checks are not in the path, the license to act
without asking is withdrawn and you fall back to proposing first.

Concretely, `execute now` is authorized when all of the following hold. These are
**checked before acting**, not promised for later:

1. **A separated reviewer is dispatchable now** — different agent, fresh context,
   ideally a different model. If you cannot dispatch one for this change, you do not
   have the license. See *Separated Adversarial Review* below.
2. **The CI gates on this repo can actually fail.** Verify, do not assume: read the
   workflow files for `continue-on-error: true` on a job that has never passed, a
   required-check list that is empty, a test step that exits 0 when no tests are
   found, and a suite whose module never loaded (`ERR_MODULE_NOT_FOUND` greps as zero
   failures). A gate you did not read is a gate you cannot count.
3. **The action is reversible**, or is covered by an explicit approval gate below.

If a condition fails, say which one and propose instead — do not act and note the gap
afterward. Acting first and disclosing second is the failure this caveat exists to
prevent.

Approval gates that survive regardless: deployment, credential custody, destructive
actions, external communications, spend, and irreversible operations. Those are
genuine human decisions; diff approval is not.

- Treat implementation-oriented requests as `execute now`, not `discuss first` —
  **when the three conditions above hold**. If they do not, propose first.
- Inspect the real codebase, logs, config, and runtime state before proposing conclusions.
- Prefer doing the work end-to-end over handing back partial plans unless the user explicitly wants planning only.
- Keep progress updates and final responses concise, direct, and high-signal.
- Do not present option menus unless the user explicitly asks for choices or interactive mode.

## Worktrees (default for parallel work)

Multiple sessions run against the same clone. Work in an isolated worktree, not
the shared checkout — a session that edits the primary tree while another holds
an in-progress merge will collide.

```bash
git wt <branch>            # worktree from a freshly-fetched origin/main
git wt <branch> <base-ref> # explicit base
git wt --list
git wt --rm <branch>       # remove worktree + branch
```

`git wt` (`~/.local/bin/git-wt`) exists because three failure modes recur:

1. **Stale base.** `git worktree add` off `origin/main` uses whatever was last
   fetched. `git wt` fetches first, so you never verify against old code.
2. **No `node_modules`.** A bare worktree makes vitest exit with
   `ERR_MODULE_NOT_FOUND` — which greps as *zero failures*. Tests look green
   while nothing ran. `git wt` symlinks `node_modules` / `.venv` from the root.
3. **`git stash` is repository-global, not worktree-local.** Stashing while a
   parallel session is active can pop *their* entry. Use a worktree instead of
   stashing; `git wt` never stashes.

Global git defaults set for this workflow: `rerere.enabled` + `rerere.autoupdate`
(conflict resolutions replay across worktrees), `worktree.guessRemote`,
`fetch.prune`, `push.default=current`, `push.autoSetupRemote`.

Before editing the primary checkout, `git status` for `MERGE_HEAD` / `UU`
markers — another session may be mid-merge.

## Engineering Workflow

1. Inspect current state with fast local tools.
2. Make the smallest coherent change that solves the real problem.
3. Validate with the most relevant evidence available:
   - tests
   - lint/typecheck
   - live endpoint checks
   - repo state / logs / CLI output
4. If the task is branch-finishing work, default to non-interactive completion —
   **gated on separated adversarial review having run and its findings addressed,
   and on CI checks that can actually fail being green**:
   - commit
   - push
   - create or update PR
   - dispatch the separated adversarial reviewer; address findings; re-verify
   - enable auto-merge when allowed **and** the above gates are satisfied
   - report PR URL, checks, and blockers

### Integrating after an upstream squash-merge

When upstream squash-merges commits your branch still carries individually, the
branch and `origin/main` hold the same content by different history and `git
merge` conflicts. Do **not** reach for rebase-and-force — merge `origin/main`
into the branch instead. It fast-forward-pushes, keeps remote history intact,
and never needs a force flag the operator may (rightly) deny.

Before any integration, confirm the diff is only what you intend:

```bash
git diff origin/main...HEAD --stat            # must list exactly your files
git diff --diff-filter=D --name-only origin/main main   # unique-to-local check
```

The first catches a merge that silently reverts someone else's landed work. The
second must be run before `git reset --hard origin/main` on a diverged local
`main` — it proves nothing exists only locally.

## Work Registration and Synchronization

- Treat the conversation as the command surface. Do not make the user manually copy plans, findings, or status between agents and work trackers.
- For implementation work that spans turns, agents, or systems, identify an existing canonical work item before creating one.
- If no work item exists and tracker access is available, register the work once with a stable, project-agnostic work key derived from the repository/service and outcome. Reuse that key for every update to prevent duplicates.
- Prefer GitHub as the source of truth for code scope, acceptance criteria, commits, tests, and pull requests. Use Linear or another planning tracker as a linked workflow projection for priority, ownership, phase, blockers, and status.
- Synchronize approved requirements, corrections, implementation results, links, and blockers through available integrations. Amend existing records rather than asking the user to ferry text between systems.
- Preserve provenance: link the canonical issue, projected tracker item, branch, pull request, and relevant evidence in both directions when supported.
- Do not create competing specifications in multiple systems. Put technical detail in the code tracker and summarize or link it from planning tools.
- Do not invent tracker projects, teams, labels, fields, statuses, or schemas. Discover existing options first; if required routing is unknown, keep a prepared work payload and ask only for the missing decision.
- Creating or updating ordinary in-scope work records is a normal workflow step. Preserve explicit approval gates for deployment, credential custody, destructive actions, external communications, and other materially consequential changes.
- On handoff, dispatch the canonical work reference rather than a copied narrative. Subsequent agents must read the current record, perform the work, and write results back to the same work chain.

## Separated Adversarial Review (BINDING — one human, many AI)

There is one human operator; human diff-review does not scale and must never be the quality gate. Quality comes from **separation of concerns between AI**, not from the human.

- **Reviewer ≠ implementer.** Every non-trivial change is reviewed by a *separated* reviewer — a different agent, a fresh context, and ideally a different model (the chittyclaw AI-gateway, or a distinct code-reviewer / silent-failure-hunter subagent). An agent never adversarially reviews its own diff.
- **Adversarial framing.** The reviewer is prompted to *break* the change — hunt auth bypass, fail-open paths, silent failures, unawaited promises, state/races — not to bless it. Happy-path tests passing is not evidence of correctness; a separated pass routinely finds what the implementer's own harness missed.
- **Real-behavior tests are not a substitute for separation.** No-mocks is necessary, not sufficient. When one agent writes the code and its tests in the same pass, both can be wrong in the same direction, and the suite then *encodes the defect as the intended contract* — it asserts the buggy count, or guards an exit code the code never sets. A green no-mock suite authored by the implementer is evidence of internal consistency, not correctness, and reporting it as validation is a false all-clear. Point the reviewer at the tests as a first-class target: ask which assertions would still pass if the behavior were wrong.
- **Revise → re-verify → integrate.** Findings loop back through a revision pass, then the work is re-verified against real backends (typecheck + live harness, no mocks). Only then integrate non-interactively.
- **Do not block a merge on human PR approval.** With one human author a required-review rule can't be self-satisfied; when AI review is done+fixed and checks are green, complete the merge (`gh pr merge --admin --squash`, operator has admin). Reserve human attention for genuine decisions (spend, architecture, irreversible ops, external comms) — not diff approval.

Standard dev loop: implement (agent A) → adversarial review (separated agent/model B) → revise → re-verify → integrate.

`scripts/adversarial-review.sh` (bundled with this skill) dispatches the separated
reviewer — use it rather than hand-rolling the dispatch, so the review framing stays
adversarial and consistent across sessions.

## Ultracode-Shaped Execution (BINDING posture)

Separation of concerns between AI is the quality mechanism; **fan-out is how it gets
applied to execution, not just to review.** The default stance is orchestrate, not
solo. This is a posture, not a keyword — it holds whether or not the projection has
an `ultracode` trigger.

### The carve-out (explicit, so it can't be argued away)

Solo is correct for exactly two things: **conversational turns**, and **trivial
mechanical edits** (a rename, a one-line fix, a config value whose blast radius you
have already read). Everything else — anything with breadth, anything you would want
a second opinion on, anything where "what did I miss" is a real question — fans out.

"I can just do this quickly" is the failure mode this section exists to prevent. If
you are reaching for that sentence about work that is not in the carve-out, that is
the signal to fan out, not to proceed.

### Route by shape: claw for breadth, viewport for depth

chittyclaw runs Workers AI models (`@cf/meta/llama-3.3-70b-instruct-fp8-fast`,
`@cf/meta/llama-3.1-8b-instruct`, `@cf/qwen/qwen2.5-coder-32b-instruct`). Two
properties follow, and both matter:

- **Its tokens are a different quota pool than the viewport session's.** Work moved
  there is work the viewport does not pay for — in budget *or* in context. This is
  the actual efficiency win: offloading a 40-file sweep to claw keeps 40 files of
  output out of the viewport, so the session stays legible instead of drowning in
  its own tool results.
- **It is lower-capability.** Route by shape, not by convenience.

| Route to **claw** (breadth) | Keep in **viewport** (depth) |
|---|---|
| File/repo sweeps, "where is X", inventory | Synthesis across what the sweep found |
| First-pass triage and classification | Architecture, design, trade-off calls |
| Adversarial refutation votes (N skeptics) | The judgment that weighs those votes |
| Health/reachability checks across a fleet | Diagnosing *why* something is unhealthy |
| Mechanical transforms over a known list | Deciding what the list should be |

**The line is judgment, and it will be pushed.** Under time pressure the temptation is
to send depth work to claw and accept a cheap confident answer. A claw result that
reads as a *conclusion* rather than as *gathered material* is the tell — treat it as
input to be verified, never as the finding itself.

### Per-projection mechanism

The shape is constant; the primitive differs by where the projection runs. Discover
the local budget and scale fan-out width to it — **never hardcode N**, because the
native quota differs per projection and a width tuned for one starves or overruns
another.

- **Claude Code** — the `Workflow` tool, and the `ultracode` keyword for standing
  opt-in. Concurrency is already capped at `min(16, cores-2)` per workflow; pass the
  full work-list and let it queue rather than pre-trimming.
- **Codex / OpenClaw agents / ChatGPT / Notion** — no `Workflow` primitive. The
  ultracode-like shape is a chittyclaw fan-out: `ssh chittyclaw`, then
  `docker exec openclaw-prod-openclaw-cli-1 openclaw ...`. Use the **CLI container**,
  not the gateway HTTP API directly.
- **Any projection** — the durable board (`chittyagent-tasks` Neon queue) is what
  makes a fan-out survivable across a crash. Session-local state is not a plan.

### Health-check claw BEFORE fanning out (and check it on the right host)

Local subagents are the fallback, not the default — but a BINDING rule pointing at a
dead endpoint fails closed on every task, and claw has been dead for 46 days before
without anyone noticing. So the check is part of the rule:

```
ssh chittyclaw 'curl -s -o /dev/null -w "%{http_code}\n" http://localhost:18789/health'
```

**chittyclaw is its own tailnet node (`100.69.69.7`), NOT `chittyserv-vm`.** Running
`docker ps` on the VM and finding no openclaw containers is the wrong check and
produces a false "claw is down" — verified failure, made in practice. Two containers
should be up: `openclaw-prod-openclaw-gateway-1` (healthy) and
`openclaw-prod-openclaw-cli-1`.

If claw is genuinely unreachable: **say so explicitly**, fall back to local subagents,
and note that the fan-out spent viewport budget rather than the separate pool. Silent
fallback is the failure mode — it hides both the outage and the cost. On restart,
**gateway first, then CLI** — they share a netns, and restarting the gateway alone
kills the CLI container into a fake "network connection error".

## ChittyOS Defaults

### Discovery-first: ask who owns it BEFORE designing (BINDING)

**The recurring failure mode is treating the current repo as the system boundary.**
Standing in a repo and grepping it is not discovery — it is a survey shaped by the
answer you already assumed, and it reliably misses the service that already does the
job.

**When this fires (narrow, on purpose):** proposing a NEW capability, service,
component, workflow, or durable store; writing a build spec or architecture; or
scaffolding a new artifact. **It does not fire** on editing existing code, fixing a
bug, wiring two existing functions together, or any change whose `composes_with` is
already known. If you are not adding a new box to the system, skip it.

**If `/helper` or the registry is unreachable:** say so explicitly, state which
discovery step you could not complete, and treat any resulting design as provisional.
Silent skip is the failure mode — an unavailable navigator is a caveat on your
conclusion, not permission to proceed as if you had checked.

When it fires, identify the **owning service** first:

These are **two different questions** and you need both. Service discovery asks *who
runs this*; capability discovery asks *does this already exist, and where should a new
one live*. Answering only the first still lets you rebuild something that already
ships as a skill, agent, or MCP route.

1. **`/helper` (chittyhelper)** — the architectural navigator. "Which service handles
   X?" One call, answered against the live registry.
2. **`capability-registry-audit`** — BEFORE proposing any new skill, agent, tool, MCP
   server, plugin, or manifest entry. Its own trigger is *"any new agent/tool/skill
   proposal"* and the question it answers is *"is this a duplicate?"*. The canonical
   inventory is `chittymarket/capabilities.generated.json` (104 capabilities, JTBD
   group ids under `chittycanon://capability/`); `capability-governor` handles the
   follow-on — classify, deduplicate, and decide skill vs plugin vs gateway vs local
   integration. **Proposing a new capability without this audit is the default
   failure**, not a shortcut.
3. **`ch1tty/cast`** — for intent-driven work when the owner is not yet known.
4. Only then: `CHARTER.md` / `CHITTY.md` / `AGENTS.md` of the services it names, and
   the repos themselves.

Symptoms that this step was skipped: proposing a component that a `chittyagent-*`
worker already exposes; designing a durable store when a Neon-backed canonical
primitive exists; a build spec whose `composes_with` fields are all greenfield;
proposing a new skill/agent without a duplicate check against the capability
registry.
`chittyentity/workers/` holds 50+ agent workers and `chittyentity/workers/shared/`
holds the canonical primitives (`agent-protocol`, `remediation-loop`, `alchemize`,
`governance`, `ledger-write`, `chronicle-queue`) — read these before concluding
something does not exist.

A grep that finds nothing is evidence about your search, not about the ecosystem.

- Discover the existing ecosystem before designing, scaffolding, or integrating:
  - ask `/helper` or `ch1tty/cast` who owns the capability
  - query ChittyRegistry (`/api/v1/tools` only — `/search`, `/categories`, `/stats`
    return hardcoded mock data)
  - read `CHARTER.md`, `CHITTY.md`, and `AGENTS.md`
  - inspect relevant repos before inventing new service boundaries
- Reuse canonical ChittyOS patterns before introducing new ones.
- Treat auth, token, and credential flows as centralized concerns:
  - prefer ChittyConnect / ChittyAuth / ChittyID / ChittyCert patterns
  - delegate secret access to the ChittySecrets / ChittyConnect broker — never inject, resolve, or fetch a value yourself (1Password is RETIRED)
  - avoid ad hoc credential sprawl or parallel auth UX unless clearly justified
- Respect canonical governance and compliance artifacts when naming, modeling, or wiring services.

## Credentials & Secrets (highest-consequence — see `references/secrets.md`)

- **The operator has ZERO credential access — a hard organizational constraint.** Never ask the user to retrieve, paste, rotate, or relay a secret. **No credential value may appear in chat — ever** (not from the user, tool output, or "examples").
- **Credentials are never your job — delegate first.** For any credential/secret/token/binding/OAuth intent, your first move is `chittyconnect-concierge` (`/chico`), BEFORE any secret CLI or grep. Never resolve/inject/present a value yourself — a bound service or the broker holds the binding and makes the call; you supply only the payload. (1Password/`op` is RETIRED — see `references/secrets.md`.)
- **Never grep-and-destroy a credential** (item-ID references make name-greps unsound). **Fail closed** with canonical `POLICY_BLOCKED_*` codes when the broker is unavailable — never fall back to chat.
- Canonical system: **ChittySecrets** (`secrets.chitty.cc`, Layer 0) fronting Cloudflare Secrets Store (hot `env.*`) → `getServiceToken()` at call site → KV cache-only. 1Password RETIRED. Classify before placing: URLs/DB-IDs → `vars`, tokens/keys → Secrets Store.

## Environment & Host (see `references/environment.md`)

- **Host duality (CONDITIONAL — check where you are first):** `~/.ops` / `~/projects` in
  CLAUDE.md are **VM paths**. **This rule binds only when you are running on a
  non-`chittyserv-vm` host.** If the session is already on `chittyserv-vm`, the paths
  resolve locally and there is nothing to SSH into — do not add a redundant SSH hop.
  Determine the host before applying this (`hostname`, or the ChittyContext viewport
  line, e.g. `@chittyserv-vm`).
  When on the Mac: baselines live at `/Volumes/chitty/Workspace/openclaw/ops/`,
  ChittyOS repos are VM-only, and repo commands **run on `chittyserv-vm` via SSH**.
- **`chittymini-00` = the operator ("me") — the personal orchestration seat you work *from*.** It pivots in and out of the cluster and takes *temporary, travel-scoped* cluster-adjacent roles (e.g. the tether gateway) because it's where the operator is — but don't pin *persistent* always-on infra (standing gateway, subnet router, exit node, iMessage host) to it; that belongs on `chittyserv-vm` or `chittymini-02..06`.
- Posture is governed by Consciousness Coordinates `{TY, VY, RY, tau}` and the lane model (default `implementation`); high-RY/operations lane is required and gated for secrets/deploy/destructive actions.

## MCP Hierarchy — ch1tty is the umbrella

**Ch1tty is the top of the MCP tree, not a peer that gets bypassed.** Model it like Cloudflare's MCP surface — `mcp.cloudflare.com/mcp` is the umbrella, and workers-bindings / browser-rendering / autorag / observability / ai-gateway all sit underneath. The same shape applies here:

```
ch1tty (5 meta-tools: search / execute / status / reload / cast)
  ├─ ChittyMCP (mcp.chitty.cc)  — all chittyagent-* tools (167+)
  ├─ Cloudflare MCP             — workers / R2 / KV / browser
  ├─ GitHub MCP                 — repos / issues / PRs
  ├─ Notion MCP                 — pages / databases
  ├─ Neon MCP                   — projects / branches / SQL
  └─ everything else, including future MCP backends
```

Ch1tty's README states the contract explicitly: *"If the runtime exposes raw backend tools directly, the deployment is out of contract."* If you reach for a raw ChittyMCP / Notion / GitHub tool, you've bypassed the hierarch.

### When to use which path

| Path | When |
|---|---|
| **`ch1tty/cast`** | Default for orchestration, intent-driven work, or "I want to do X find the tool." This is the wizard layer and the canonical entry. |
| **`ch1tty/search` + `ch1tty/execute`** | When you want to discover candidates first, then invoke explicitly. |
| **`ch1tty/status`** | Health / session / coordinator state. |
| **`/helper` (chittyhelper)** | "Which service handles X?" — the architectural navigator, used before designing or scaffolding. |
| **Raw ChittyMCP / Notion / GitHub tool direct** | ONLY when the operation is single-tool, well-known, and would not benefit from cast's intent resolution or the coordinator's affinity tracking (e.g. you already know `tasks_claim` is exactly what you need). |

### When briefing subagents

Every dispatched subagent should default to `ch1tty/cast` for orchestration and discovery. Use raw tools only when the tool name is known up-front and the work is single-tool. Mention the hierarch explicitly in the brief; do not assume the agent will infer it from the directive injection.

### Why this matters

- **In contract** — ch1tty's slim surface is the documented client contract.
- **Coordinator affinity + alchemist observation** — bypassing ch1tty means the SessionCoordinator can't track tool patterns and the Alchemist can't spot composable recipes for promoting into focused `apps/*-mcp` services.
- **Focus profiles** (finance / governance / design) — only bias `cast`/`search`; direct ChittyMCP calls ignore the lens.
- **Cross-backend composition** — a `cast` like "search GitHub for X and write a Notion page about it" only works through ch1tty.

## Interaction Rules

- Default to action over explanation — subject to the *Default Posture* conditions;
  the license to act without asking is not unconditional.
- Default to verification over speculation.
- Default to persistence over repetition:
  - if a preference or workflow is recurring, encode it in a skill, hook, config, script, or AGENTS layer
  - do not make the user restate stable preferences every session
- When a workflow is obviously repetitive, propose or create automation rather than leave it manual.
- If blocked, surface the blocker crisply and state the next concrete step.

## Correction Loop Rules

- Treat `no`, `i mean`, `actual`, pasted file excerpts, raw tool output, and terse redirects as high-priority course corrections.
- When corrected, drop the previous assumption immediately instead of defending it or continuing the old branch of reasoning.
- If the user pastes concrete evidence, use that evidence as the new source of truth and narrow the next step to it.
- Treat short follow-ups like `continue`, `yes`, file names, and merge-status questions as operational instructions, not invitations for broad re-explanation.
- After interruption, resume from the last concrete work state instead of restarting with a long recap.

## Workers Builds (CF CI/CD)

All ChittyOS workers deploy via Cloudflare Workers Builds (git-triggered). Config is managed via API, not dashboard.

- **API base**: `https://api.cloudflare.com/client/v4/accounts/{ACCOUNT_ID}/builds/`
- **Auth**: `Authorization: Bearer {cfut_ account token}` — needs "Workers Builds Configuration:Edit" permission
- **Script ID**: Use script TAG (not name). Get via `GET /workers/services/{name}` → `.result.default_environment.script_tag`
- **Triggers**: Each worker has 2 (production branch + non-production). PATCH to update, POST to create.
- **Key endpoints**: `/builds/triggers` (CRUD), `/builds/workers/{script_tag}/triggers` (list), `/builds/triggers/{uuid}/builds` (manual trigger)
- **Pattern**: Workers with `env.production` blocks deploy via `npx wrangler deploy --env production`
- **Shared deps**: Workers importing from `../shared/` use build command `cd ../shared && npm ci`
- **Watch paths**: Shared importers watch both `/workers/{name}/*` and `/workers/shared/*`

## Review and Audit Bias

- For review requests, findings come first.
- For audits, prioritize behavioral regressions, missing validation, auth/compliance gaps, and ecosystem drift.
- For debugging, prove the failure mode with direct evidence before declaring root cause.
- Silent failures live in CI config too. `continue-on-error: true` on a job that has never passed reports the workflow green forever — a check you pay for and never receive. When a job shows `fail` while its workflow shows `success`, treat the mask as the finding: fix the job and drop the flag, or delete the job. Same reflex for a required-check list that is empty, a test step that exits 0 on no tests found, and a green suite whose module never loaded (`ERR_MODULE_NOT_FOUND` greps as zero failures).

## References (load on demand — progressive disclosure)

Detailed operational knowledge lives in `references/`; load the relevant file when a task touches that domain rather than carrying it all in context:

- **`references/environment.md`** — host duality (VM vs local), node roles, conflict precedence, Consciousness Coordinates + lanes, P/L/T/E/A ontology, capability centralization, workspace map, service topology.
- **`references/network.md`** — tailnet topology (`cockatoo-dominant.ts.net`), Homebrew-only Tailscale on -00, split-DNS dependency, the iPhone-tether internet-sharing chain, the two home networks, DHCP gotchas.
- **`references/secrets.md`** — the full credential/secret model, broker-first rules, tiering, canonical error codes, wrangler gotchas, the in-progress migration, canonical paths.
- **`references/llm-routing.md`** — Cloudflare AI Gateway as the model router, chittyclaw/OpenClaw, the `three-wise-men` dynamic route, ai-parity config distribution, deploy/verify.

Cross-agent packaging lives in `agents/openai.yaml` (ChatGPT/Codex/API/Atlas, implicit invocation).
