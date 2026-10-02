# The gauntlet as a Cloudflare Agent Workflow

> **Status (2026-10-02): this is the tier-2 plan.** Moved here from
> `CHITTYOS/chittyentity` `docs/design/gauntlet-as-agent-workflow.md`.
>
> - **Tier 1 (shipped):** a Claude Code plugin workflow. The canonical is
>   `canonical/workflows/gauntlet.md`, projected to `plugins/chittyos-core/workflows/gauntlet.js`,
>   and any Claude Code session invokes it as `Workflow({name: "chittyos-core:gauntlet", args})`
>   (`dryRun: true` validates without dispatching). The runner persona is
>   `canonical/agents/chittyagent-gauntlet.md`. Capability: `chittycanon://capability/build/gauntlet`.
> - **Tier 2 (this document, not built):** a remote Cloudflare Agent Workflow reachable from every
>   channel (ChatGPT, Notion, mobile, API), with durable steps and approval gates.
>
> References below to `.claude/workflows/gauntlet.js` mean the chittyentity session-local copy that
> tier 1 replaced.

Doc-verified against `/agents/concepts/workflows/` and the 2026-02-03 Agents↔Workflows integration,
read 2026-08-09. Design only — nothing built.

## Why move it off the local script

`.claude/workflows/gauntlet.js` works, but it is **session-local**. That collides directly with the
standing rule that capabilities register centrally and are reachable from every channel — Claude Code,
ChatGPT, Notion, mobile, API — rather than living in one client's config. A gauntlet that only exists
inside one Claude Code session cannot be invoked by anything else, cannot survive that session, and
leaves no durable record.

Four properties of Agent Workflows fix that, and each maps onto a real weakness the local version has:

| local script today | Agent Workflow |
|---|---|
| a killed session loses all rounds | **step completion is permanent** — finished rounds never re-execute |
| a dead subagent drops a finding silently | **automatic retries** with configurable backoff and timeout per step |
| the implementer's fixes apply unreviewed | **`waitForApproval()`** — pause before touching a protected target |
| progress visible only in this terminal | **`reportProgress()` / `broadcastToClients()`** — live to any connected UI |
| results live in a transcript | **workflow tracking in the Agent's own database** |

## Role → step mapping

Each of the seven roles becomes a durable `step.do()` with its own retry policy. The critical property
is exactly-once: a round that completed before a restart is not re-run, so the loop resumes mid-flight
rather than starting over.

```ts
import { AgentWorkflow } from "agents/workflows";

export class GauntletWorkflow extends AgentWorkflow<GauntletAgent, GauntletParams> {
  async run(event, step) {
    // ── Challenge: four independent probes, each durable
    const [contested, generated, traced, mandated] = await Promise.all([
      step.do("contest",  RETRY, () => this.probe("contester", event.payload)),
      step.do("generate", RETRY, () => this.probe("generator", event.payload)),
      step.do("trace",    RETRY, () => this.probe("tracer",    event.payload)),
      step.do("mandate",  RETRY, () => this.probe("mandate",   event.payload)),
    ]);

    // ── Fix: loop until dry. Each round is two durable steps.
    let dry = 0;
    for (let round = 1; dry < 2 && round <= 6; round++) {
      const feed = await step.do(`feed-${round}`, RETRY, () => this.feeder(round, history, feeds));
      await this.reportProgress({ step: `round-${round}`, percent: round / 6,
        message: `${feed.strategy} → ${feed.cases.length} cases` });

      const result = await step.do(`fix-${round}`, RETRY, () => this.implementer(feed, ...));
      await step.mergeAgentState({ rounds: round, failing: result.still_failing.length });

      dry = (!result.anything_new && !result.still_failing.length && feed.expected_yield === "low")
        ? dry + 1 : 0;
    }

    // ── Converge: verification, then a human gate before anything lands
    const verdict = await step.do("verify", RETRY, () => this.verifier(history, traced, mandated));

    if (event.payload.protectedTarget) {
      await this.waitForApproval({ summary: verdict, changes: history });  // may wait up to a year
    }

    await step.reportComplete(verdict);
  }
}

const RETRY = { retries: { limit: 3, delay: "10 seconds", backoff: "exponential" }, timeout: "5 minutes" };
```

## Durability discipline — and the trap in it

The docs draw a hard line, and getting it wrong reintroduces exactly the failure class this workflow
exists to catch:

- **Durable, exactly-once:** `step.do()`, `step.reportComplete()`, `step.reportError()`,
  `step.sendEvent()`, `step.updateAgentState()`, `step.mergeAgentState()`
- **Non-durable, may repeat on retry:** `this.reportProgress()`, `this.broadcastToClients()`, direct
  RPC to `this.agent`

**Every mutation of the target must be inside `step.do()`.** A fix applied via a non-durable path
re-executes on retry — so an edit lands twice, or a corpus case is appended three times, and the
suite still passes because nothing asserts on cardinality. That is the "silent success" mode with a
new coat of paint. Progress chatter is fine to repeat; work is not.

## Code Mode changes the execution model — and supersedes the gate above

`createCodemodeRuntime` + `DynamicWorkerExecutor` + connectors + a durable execution log
(`@cloudflare/codemode`, Agents SDK v0.16.1). Three things it does that matter here:

**1. It is the structural fix for the payload problem.** From the changelog, verbatim: *"This lets you
give a model one `codemode` tool instead of a large prompt full of tool definitions."* The model
discovers capability with `codemode.search()` and inspects signatures with `codemode.describe()`,
rather than carrying every schema in the prompt.

That is exactly the failure that killed chittyclaw's inference on 2026-08-09 — tool definitions from
5 MCP servers (95 + 19 + 12 tools) exceeded a 32k model's capacity before any user content, returning
HTTP 413. That was worked around by buying a 200k-context BYOK model. Code Mode removes the cause
instead of paying for the symptom, and would likely let a Workers AI model serve the same agent.

**2. Per-method approval beats a single end-of-run gate.** Mark a connector method
`requiresApproval: true` and the runtime pauses model-generated code *before* it invokes that tool.
On approval, **completed calls replay from the durable execution log**, the approved action runs, and
the same code continues.

This supersedes the `waitForApproval()` design sketched below. A single gate at the end is
all-or-nothing: approve every change the implementer made, or reject the whole round. Per-method
approval gates the specific mutation — write to the corpus, edit the target, publish a finding —
while leaving reads ungated. For the gauntlet that means the implementer's *analysis* runs freely and
only its *writes* stop for a human.

**3. There is already a worked example of exactly our privilege pattern.**
`/ai-search/how-to/human-in-the-loop-knowledge-base/` builds an agent with a read-only `search`
method and a `saveDocument` method that requires approval. That is the knowledge-lane and
evidence-gate shape, written down by Cloudflare: reads are free, admissions are gated.

**Caveat, stated plainly:** the docs say *"Code Mode is experimental and may introduce breaking
changes. Use caution in production."* It should not sit in front of a confidentiality boundary on
that basis alone. Prove it on the free-to-be-wrong corpus first — the same ordering the retrieval
audit found inverted.

State lives in a **Durable Object facet** — a durable child of the Agent with its own SQLite —
managed by `createCodemodeRuntime()`. Executor and connector instances stay transient and are
re-provided when a later approval or request arrives.

## The human gate is the feature, not the ceremony

`waitForApproval()` with year-long event persistence means the gauntlet can run against a protected
target — the evidence corpus gate, a privilege classifier, anything where an unreviewed automated fix
is unacceptable — pause with its findings, and resume days later on `approveWorkflow()` /
`rejectWorkflow()`. Rejection throws `WorkflowRejectedError`, which is a real outcome to record, not
an error to swallow.

This is the missing piece for running the gauntlet on anything that guards a boundary. Today the
local version's implementer edits files unreviewed; that is acceptable for a scaffold and not
acceptable for a gate.

## What it needs that already exists

- **A model rail.** The gauntlet's roles are model calls. The `central` AI Gateway was repointed and
  verified working on 2026-08-09 (`docs/ai-gateway-retrieval-audit-2026-08-09.md` §7), with a BYOK
  large-context primary and a fallback chain. The tracer and verifier read whole files and diffs, so
  context window is a correctness requirement — a 32k model returns HTTP 413 on this class of payload
  before user content is even added.
- **A UI.** `reportProgress` and `broadcastToClients` have a consumer as soon as the ChittyCommand
  surface exists — live round-by-round progress, current strategy, findings as they land.
- **Dynamic Workers**, if role execution should be sandboxed. `chittyagent-sandbox` already binds
  `worker_loaders` and reports `worker_loader: {ok: true}`, and `@cloudflare/dynamic-workflows`
  connects a Worker Loader to the Workflows engine for durable steps in runtime-loaded code.

## Open questions — decide before building

1. **New worker or existing?** A `chittyagent-gauntlet`, or a workflow on `chittyagent-command`
   (which is the Tier-2 command layer and already the orchestration surface)? Adding it to command
   keeps the fleet smaller; splitting it keeps command's charter clean.
2. **Does the local script stay?** Two implementations of one pattern will drift. Either the local
   one becomes a thin client that starts the remote workflow, or it is retired once the remote works.
   Keeping both "for now" is how the two-orchestrator problem starts.

   **Decided (2026-10-02):** the chittyentity copy (`.claude/workflows/gauntlet.js` and
   `.claude/agents/gauntlet-runner.md`) is retired once the ChittyMarket plugin workflow lands.
   The single tier-1 implementation is `canonical/workflows/gauntlet.md` in ChittyMarket. When
   tier 2 is built, that plugin workflow becomes the thin client that starts the remote run.
3. **Where do findings persist?** ChittyTasks is the durable board and already holds this session's
   work items; the Agent's own workflow tracking is per-instance. Probably both, with the task as the
   canonical record.
4. **Approval routing.** Who approves, through which surface, and what happens on timeout — a gate
   that silently expires into "approved" would be the worst possible version of this.

## Not built

Design only. Building it is a new worker or a substantial addition to an existing one, plus a DO
binding, a `new_sqlite_classes` migration, and a model-rail credential — all of which need
authorisation per the CHARTER rule that no new infrastructure is provisioned without it.
