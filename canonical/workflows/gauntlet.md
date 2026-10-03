---
name: gauntlet
kind: workflow
description: |
  Recursive adversarial convergence for any decision surface with code, a fixture corpus, and a
  runner (validators, gates, parsers, routers, policy engines, schedulers). Contests the
  expectations, hunts missing cases, traces execution, audits standing mandates, then loops an
  adaptive feeder against a separated implementer until dry, verified by an agent told not to
  trust either. Invoke from any Claude Code session as
  `Workflow({name: "chittyos-core:gauntlet", args: {target, runner, ...}})`; pass `dryRun: true`
  first to validate args and see the agent budget without dispatching anything.
canon_uri: chittycanon://core/services/chittymarket#workflows/gauntlet
classification:
  - verification
  - adversarial-review
  - testing
runtimes:
  - claude-code
plugin: chittyos-core
canonical_capability_ref: chittycanon://capability/build/gauntlet
overlay:
  title: Gauntlet
  capability_group: build
  group_assignment_source: override
  execution_class: '@chitty/reasoning'
  canonical_version: 1.0.0
  projection_version_policy: inherit-canonical
  ontology:
    primary:
      - E
    secondary:
      - T
  authority:
    requires_chittyid: false
  execution:
    default_surface: local
    local_allowed: true
    context_cost: high
    mutation_risk: medium
  discovery:
    indexable: true
    session_index: summary
    ambient_by_intent: false
    verbs:
      - gauntlet
      - harden
      - adversarial-test
      - verify
    fallback_search: true
  auth_flow:
    mode: local-only
    stores_credentials_in: n/a
    fail_closed_if_unavailable: false
  runtime_exclusions: {}
  phase0_audit:
    job_to_be_done: verify
    environmental_footprint: write-capable
    evidentiary_risk: low
    advisory_disposition: local-only
  legacy_category: code
  deprecated_aliases:
    - workflow-gauntlet
  visibility: advanced
  access: write
  compatible_channels:
    - claude_code
  source_links:
    - local://plugins/chittyos-core/workflows/gauntlet.js
---

# Gauntlet (Claude Code plugin workflow)

Tier 1 of the gauntlet: a Claude Code plugin workflow, projected by
`dispatch.sh sync gauntlet` to `plugins/chittyos-core/workflows/gauntlet.js` and resolved by the
host as `chittyos-core:gauntlet`. Tier 2 (a remote, all-channel Cloudflare Agent Workflow) is
designed in `docs/design/gauntlet-as-agent-workflow.md` and not built. The gauntlet is one function
of the `chittyagent-olmec` agent (the separated reviewer), which establishes its preconditions,
invokes it, and reports the result.

Promoted from `CHITTYOS/chittyentity` `.claude/workflows/gauntlet.js` (origin/main), with the
string-args fix from chittyentity PR #736 folded in. The chittyentity copy is retired once this lands.

Changes from the chittyentity copy:

- **Args.** A JSON-string `args` is parsed; objects pass through; malformed JSON and non-object
  shapes throw without echoing the raw input (`runner` may carry a token). Empty args, a missing
  `target`, or a missing `runner` return `{started: false, reason, next}` instead of throwing.
- **Models.** Every `agent()` call carries an explicit `model`. Judgment roles (contester, tracer,
  mandate auditor, feeder, implementer, verifier) default to `opus`; the generator defaults to
  `sonnet` because the feeder re-selects its output and the implementer and runner check it.
  Override per role with `args.models`.
- **Dry run.** `args.dryRun: true` returns the validated config (target, maxRounds, roles and
  models, agent budget `4 + 3*maxRounds + 3`, `can_converge`) with `started: false`. No agent is dispatched.
- **Validation before any dispatch.** `target` must be an absolute path. `maxRounds` is an integer
  in 1..12 (hard ceiling: at most 43 agents); `dryRounds` is an integer in 1..maxRounds. List args
  (`files`, `invariants`, `probes`, `rules`, `knownFailures`) must be arrays of strings; `corpus`,
  `what`, `typecheck` must be strings (an empty `typecheck` means not configured); `sameAuthor` must
  be a boolean. Unknown keys are rejected, so a misspelled `dryRun` cannot launch the fleet. Every
  violation returns `{started: false, reason, next}` with zero agents dispatched, including under
  `dryRun`. A JSON parse failure reports only the byte length: the V8 error message echoes a prefix
  of the input, and `runner` may carry a token.
- **Dead roles.** An agent that returns nothing is a failure, not an empty result. Each one is
  recorded in `dead_roles`; its output is rendered to later prompts as `NOT RUN`, never as `[]`, and
  returned as `null`. A dead feeder or implementer stops the loop (a dead feeder is not a low-yield
  signal). The verifier still runs after a loop death, because it checks real state. If any role
  died, `stopped_because` reads `incomplete — roles died: ...` and `converged` is false.

- **Observed, not claimed (second review).** The script has no shell, so a gathering-only RUNNER
  WITNESS (sonnet, schema `{exit_code, output_tail, command}`, forbidden to edit anything) runs the
  runner verbatim after every implementer round and once in Converge. A round is clean only if the
  witnessed exit is 0 AND the implementer reports nothing failing; any disagreement is recorded in
  `claim_mismatch` and blocks convergence. The verifier has a required schema (`verdict`,
  `runner_exit_code`, `runner_output_tail`, `vacuous_assertions`, `unaddressed_trace_findings`, ...)
  checked in code; free text or missing fields is not a verification. A RETRACE (opus, the tracer's
  brief against the post-fix code) blocks convergence on any new or still-open
  right-answer-wrong-execution finding, and on any original finding still open.
- **Convergence rules (in code).** Round 1 is the baseline and never counts as dry. A dry round needs
  a witnessed exit 0, nothing failing, nothing new, a low-yield feeder, AND a strategy not used in any
  earlier round (a repeated strategy is recorded in `repeated_strategies` and resets the streak). The
  dry streak must be at least 2 rounds with at least 2 distinct strategies. `maxRounds` 1-2 or
  `dryRounds` 1 are accepted only as smoke runs that can never report convergence; the dry run says so.
- **Model allow-list.** Judgment roles (contester, tracer, mandate, feeder, implementer, retrace,
  verifier) accept only `opus` or `fable`; generator and witness accept `opus` or `sonnet`.
- **No transitive spawning.** Every prompt forbids subagents and the Agent/Workflow tools. The budget
  `4 + 3*maxRounds + 3` counts direct agent() calls only.
- **Blind-oracle gate (third review).** The witness and the verifier report a required integer
  `cases_executed` counted from the runner output (`-1` = undeterminable). A round whose witness
  reports `0` or `-1` is recorded in `blind_oracle` and is never clean; `0`/`-1` from the final
  witness or the verifier, or the two disagreeing, blocks convergence. A null final witness, retrace
  or verifier is an explicit blocker (not only a `dead_roles` side effect), and any role output whose
  list fields are not arrays is `malformed`: recorded in `dead_roles`, listed as a blocker, treated as
  missing, never allowed to throw.
- **`oracleAuthor: 'olmec'`** marks a runner and corpus written by the reviewing agent; the contester
  and the witness are then pointed at the oracle explicitly. The contester always contests the oracle.

Everything else (known failures, role prompts, loop-until-dry rule) is unchanged.

## One core, two tiers

The gauntlet's data and pure logic live in `canonical/workflows/gauntlet.core.js`: argument
validation (`validateArgs`, which returns `{ok, config}` or `{ok: false, reason, next, log}`),
`DEFAULT_MODELS` and the allow-lists, `MAX_ROUNDS_CEILING`, `MIN_DRY_STREAK`, the
`CAN_CONVERGE`/`SMOKE_REASON` rule, `DEFAULT_KNOWN_FAILURES`, the `CTX` builder, every role prompt and
`TRACER_BRIEF`, every schema, the per-round rule (`assessRound`), and
`computeConvergence(state) -> {converged, blockers, stopped_because, ...}`. It is a plain ES module with
no imports and no host globals, so tier 2 (the remote `chittyagent-olmec` worker) can vendor the same
file.

The fenced block below keeps only orchestration: the `agent()`/`parallel()`/`phase()`/`log()` calls and
the bookkeeping between them. Workflow scripts cannot import, so the projection inlines the core at the
`// @inline gauntlet.core.js` marker (see `adapters/claude-code-workflow.sh` and
`lib/inline_includes.py`). `plugins/chittyos-core/workflows/gauntlet.js` is therefore core plus
orchestration in one file. Never edit it; edit the core or the block below, then
`dispatch.sh sync gauntlet`. `dispatch.sh audit`, the CI sync-then-no-diff gate and the pre-commit
hook each fail on a core edit that was not re-projected.

`canonical/workflows/gauntlet.fixtures.json` holds the golden cases: convergence states with their
exact blockers, per-round judgments, and `validateArgs` inputs with their early returns. The expected
values were derived by running the pre-refactor script (origin/main `8190213`) through the simulation
harness in `scripts/tests/test_dispatch_workflow.py`, not written by hand
(`scripts/tests/derive_gauntlet_fixtures.py`). `scripts/tests/run_gauntlet_fixtures.mjs` asserts every
case against the core in CI, and tier 2 runs the same file.

````js
export const meta = {
  name: 'gauntlet',
  description: 'Recursive adversarial convergence: contest expectations, trace execution, audit standing mandates, then loop an adaptive feeder against a separated implementer until dry — verified by an agent told not to trust either',
  whenToUse: 'Any decision surface with code, a fixture corpus, and a runner — validators, gates, parsers, routers, policy engines, schedulers. Run it when correctness matters more than speed and when the same context wrote both the code and its tests. Invoke as Workflow({name: "chittyos-core:gauntlet", args: {target, runner, ...}}); pass dryRun: true first to validate args and see the agent budget without dispatching anything.',
  phases: [
    { title: 'Challenge', detail: 'contest expectations, hunt missing cases, trace execution, audit standing mandates' },
    { title: 'Fix', detail: 'adaptive feeder picks a new testing logic each round; separated implementer closes findings' },
    { title: 'Converge', detail: 'independent verification that refuses to trust the fixer' },
  ],
}

/**
 * THE GAUNTLET
 *
 * A pattern, not a script for one service.
 *
 * It exists because of a specific, repeatable failure: when one context writes the code AND the
 * tests, both can be wrong in the same direction, and the suite then encodes the defect as the
 * intended contract. It asserts the buggy count. It guards an exit code the code never sets. It goes
 * green, and the green is meaningless.
 *
 * The gauntlet breaks that by separating seven roles that usually collapse into one:
 *   1. CONTESTER   — argues the expectations themselves are wrong
 *   2. GENERATOR   — hunts inputs the corpus never considered
 *   3. TRACER      — judges the EXECUTION, not the outcome
 *   4. MANDATE     — finds what this was ALREADY required to do and never encoded
 *   5. FEEDER      — per round, picks a DIFFERENT testing logic and selects what gets tested
 *   6. IMPLEMENTER — fixes, and is explicitly permitted to fix the FIXTURE instead of the code
 *   7. VERIFIER    — re-runs everything and is told not to trust the implementer's report
 *
 * THE FEEDER IS ADAPTIVE ON PURPOSE. It runs inside the loop, sees every fix already made, and is
 * forbidden from reusing a strategy. More cases of the kind already in the corpus have near-zero
 * marginal yield after round one; changing the KIND of probe is what keeps finding things. A gap that
 * survives N rounds of fixing survives because every probe so far shared an assumption — the feeder's
 * job is to name that assumption and attack it, narrowing each round.
 *
 * OUTCOME IS NOT ENOUGH. A case asserting only the final answer passes when the right answer was
 * reached for entirely the wrong reason — the intended check never ran, a different one short-
 * circuited first, an error was swallowed on the way, or the result is right today and accidental
 * tomorrow. An assertion that does not pin the REASON is close to vacuous: delete the logic it
 * claims to cover and it still goes green. The tracer exists to close that gap.
 *
 * AND OUTCOME IS NOT THE ONLY CONTRACT. A thing can be internally consistent and still fail to do
 * what it was ALREADY required to do — a rule written in a charter, a canon doc, or an ADR that
 * nobody encoded. Requirements drift is silent: there is no test for a rule that was never written
 * down as code, so nothing ever goes red. The mandate auditor goes and reads what was already
 * decided, and an unenforced standing mandate outranks anything invented during the run.
 *
 * AND KNOWN FAILURES ARE FED IN, not rediscovered. A failure that has already happened once in a
 * codebase happens again — in a new location, wearing different clothes. Every agent is handed the
 * catalogue of what has actually gone wrong here and asked whether this artifact has the same disease
 * in a new place. Testing the CLASS rather than the instance is what turns an incident into permanent
 * pressure instead of a war story.
 *
 * Loop-until-dry rather than a fixed round count: unknown-size discovery has a tail, and a counter
 * stops in the middle of it.
 *
 * ARGS (all optional except target and runner):
 * {
 *   target:     "/abs/path/to/thing"            // required, absolute — what is under test
 *   runner:     "cd <dir> && npx tsx sim.ts"    // required — must exit non-zero on failure
 *   typecheck:  "cd <dir> && npx tsc --noEmit"  // optional
 *   what:       "one paragraph: what this is and what it guarantees"
 *   files:      ["src/a.ts", "fixtures/cases.json"]
 *   corpus:     "fixtures/cases.json"           // the fixture corpus the generator extends
 *   invariants: ["things that must hold no matter what"]
 *   probes:     ["directions worth attacking — the generator goes beyond these"]
 *   rules:      ["binding project rules: no mocks, canonical formats, etc"]
 *   knownFailures: ["domain-specific failures that have ACTUALLY happened — extends the defaults"]
 *   sameAuthor: true                            // did one context write both code and tests?
 *   oracleAuthor: "olmec"                       // 'olmec' if the reviewing agent wrote the runner/corpus; or 'independent'
 *   maxRounds:  6                               // integer 1..12 (hard ceiling)
 *   dryRounds:  2                               // consecutive empty rounds before stopping; 1..maxRounds
 *   dryRun:     true                            // validate + return the resolved config; dispatch NO agents
 *   models:     { generator: "opus" }           // per-role override; judgment roles opus|fable, generator/witness opus|sonnet
 * }
 *
 * Pass args as a JSON object. The Workflow host may deliver it JSON-encoded as a string; both
 * shapes are accepted. Missing target/runner returns {started:false, reason, next} rather than
 * throwing, so a bare invocation reads as "nothing to do", not as a launch fault.
 *
 * MODELS. Every agent() call carries an explicit model — an omitted model silently inherits the
 * session model, which is how a fan-out ends up all-Opus by accident. Judgment roles (their output
 * is acted on, not re-checked) default to opus. The generator defaults to sonnet: its cases are raw
 * material that the feeder re-selects and the implementer + runner check downstream.
 */

// The pure core (validation, models, known failures, CTX, schemas, role prompts, the round rule and
// computeConvergence) is canonical/workflows/gauntlet.core.js. Workflow scripts cannot import, so the
// claude-code-workflow adapter inlines it at the marker below. Edit the core there, never here or in
// the projection; tier 2 (chittyagent-olmec remote) runs the same file and the same golden fixtures.
// @inline gauntlet.core.js

// ── Validation. Missing target/runner and every malformed arg return {started:false, reason, next}
//    with nothing dispatched, including under dryRun; unreadable args throw without echoing them.
const validated = validateArgs(args)
if (!validated.ok) {
  log(validated.log)
  return { started: false, reason: validated.reason, next: validated.next }
}
const cfg = validated.config
const { a, TARGET, RUNNER, MODELS, MAX_ROUNDS, DRY_ROUNDS, SMOKE_REASON, ORACLE_AUTHOR, TYPECHECK } = cfg
const CTX = buildCtx(cfg)
// ── Everything above is validated. Nothing below dispatches until the dryRun return has been passed.

if (a.dryRun) {  // truthy on purpose: a mistyped dryRun ("true", 1) must fail safe, not launch the fleet
  const dryRunReport = dryRunResult(cfg)
  log(dryRunReport.log)
  return dryRunReport.result
}

// ── Dead roles. agent() returns null/undefined when a role dies. That is a FAILURE, not an empty
//    result. Deaths are recorded, rendered as NOT RUN (core: render/NOT_RUN), and block any
//    convergence claim.
const deadRoles = []
const alive = (x, role) => {
  if (x === null || x === undefined) { deadRoles.push(role); return false }
  return true
}
// A role that returns an object whose list fields are not arrays is MALFORMED: its output cannot be
// read without throwing or misreading, so it is recorded like a death (dead_roles) and as an explicit
// blocker, and its output is treated as missing. Never let a bad shape throw mid-run.
const malformedRoles = []
const malformed = (role, why) => { deadRoles.push(`${role}: malformed (${why})`); malformedRoles.push(`${role}: ${why}`) }

// ── Phase 1 — two independent attacks, run together. One argues the corpus is
//    WRONG; the other argues it is INCOMPLETE. Different failure modes, so they
//    must not be the same agent.
phase('Challenge')
let [contested, generated, traced, mandated] = await parallel([
  () => agent(contesterPrompt({ CTX, ORACLE_AUTHOR }),
    { label: 'contest', phase: 'Challenge', schema: CONTEST_SCHEMA, model: MODELS.contester }),
  () => agent(generatorPrompt({ CTX, a }),
    { label: 'generate', phase: 'Challenge', schema: CASES_SCHEMA, model: MODELS.generator }),
  () => agent(tracerPrompt({ CTX }),
    { label: 'trace', phase: 'Challenge', schema: TRACE_SCHEMA, model: MODELS.tracer }),
  () => agent(mandatePrompt({ CTX }),
    { label: 'mandates', phase: 'Challenge', schema: MANDATE_SCHEMA, model: MODELS.mandate }),
])

alive(contested, 'contester'); alive(generated, 'generator'); alive(traced, 'tracer'); alive(mandated, 'mandate')
// Shape-check every list a later step reads. A malformed role is nulled so it renders as NOT RUN.
if (contested && badArrays(contested, ['contested'], true).length) { malformed('contester', 'contested is not an array of objects'); contested = null }
if (generated && badArrays(generated, ['cases'], true).length) { malformed('generator', 'cases is not an array of objects'); generated = null }
if (traced && badArrays(traced, ['findings'], true).length) { malformed('tracer', 'findings is not an array of objects'); traced = null }
if (mandated && badArrays(mandated, ['mandates'], true).length) { malformed('mandate', 'mandates is not an array of objects'); mandated = null }
if (deadRoles.length) log(`challenge phase: ${deadRoles.length} role(s) died (${deadRoles.join(', ')}) — their output is passed on as NOT RUN`)
const silentTrace = (traced?.findings ?? []).filter((f) => f.outcome_still_correct)
const unenforced = (mandated?.mandates ?? []).filter((m) => m.enforced !== 'yes')
log(`${contested?.contested?.length ?? 0} expectations contested · ${generated?.cases?.length ?? 0} new cases · ${traced?.findings?.length ?? 0} execution findings (${silentTrace.length} invisible to outcome tests) · ${unenforced.length} standing mandates not fully enforced`)

// ── Phase 2 — recursive fix. Loop until rounds come back dry, not until a
//    counter runs out: discovery has a tail and a fixed count stops inside it.
phase('Fix')
const history = []
const feeds = []
const witnesses = []          // one per round, in round order
const claimMismatch = []      // implementer claims the runner contradicts
const witnessFaults = []      // witness reported a command other than the runner
const repeatedStrategies = [] // feeder reused a strategy (a feeder defect)
const seenStrategies = new Set()
let dryStreak = []            // strategies of the current consecutive dry rounds
let dry = 0
let round = 0
const blindOracle = []        // rounds whose witness saw zero or an unknown number of cases

while (dry < DRY_ROUNDS && round < MAX_ROUNDS) {
  round++
  const prior = priorRounds(history, witnesses)

  // ── FEEDER. Runs before the implementer, every round, and is privy to every
  //    fix already made. Its job is not "more cases" — it is a DIFFERENT testing
  //    logic each round, aimed at the residual gap the previous rounds reveal.
  const feed = await agent(feederPrompt({ CTX, round, feeds, prior, generated }),
    { label: `feed-${round}`, phase: 'Fix', schema: FEED_SCHEMA, model: MODELS.feeder })

  // A dead feeder stops the loop. It must NOT fall through to the implementer with an empty feed,
  // and must NOT count as a low-yield signal: silence is not evidence the surface is exhausted.
  if (!alive(feed, `feeder (round ${round})`)) { log(`round ${round}: feeder died — stopping`); break }
  if (badArrays(feed, ['cases']).length || typeof feed.strategy !== 'string') {
    malformed(`feeder (round ${round})`, 'cases is not an array or strategy is not a string'); log(`round ${round}: feeder report malformed — stopping`); break
  }
  feeds.push(feed)
  log(`round ${round} feeder: ${feed.strategy} → ${feed.cases.length} cases (yield ${feed.expected_yield}) targeting: ${feed.gap_targeted}`)

  const result = await agent(implementerPrompt({ CTX, RUNNER, TYPECHECK, round, contested, feed, mandated, traced, silentTrace, prior }),
    { label: `fix-${round}`, phase: 'Fix', schema: ROUND_SCHEMA, model: MODELS.implementer })

  if (!alive(result, `implementer (round ${round})`)) { log(`round ${round}: implementer died — stopping`); break }
  const badRound = badArrays(result, ['still_failing', 'changes_made', 'cases_added'])
  if (badRound.length) {
    malformed(`implementer (round ${round})`, `${badRound.join(', ')} not an array`); log(`round ${round}: implementer report malformed — stopping`); break
  }
  history.push(result)
  log(`round ${round}: ${result.changes_made.length} changes · ${result.cases_added.length} cases · ${result.still_failing.length} failing (claimed)`)

  const witness = await agent(witnessPrompt({ CTX, RUNNER, ORACLE_AUTHOR }, `after round ${round}`),
    { label: `witness-${round}`, phase: 'Fix', schema: WITNESS_SCHEMA, model: MODELS.witness })
  if (!alive(witness, `witness (round ${round})`) || !witnessOk(witness)) {
    if (witness != null && !witnessOk(witness)) malformed(`witness (round ${round})`, 'missing or mistyped exit_code/output_tail/command/cases_executed')
    log(`round ${round}: runner witness returned no usable observation — stopping`)
    break
  }
  witnesses.push(witness)

  // The round rule (witness fault, blind oracle, claim mismatch, repeated strategy, dry) is the
  // core's assessRound; this loop only records what it returns, in the order it always has.
  const judged = assessRound({ round, RUNNER, feed, result, witness, seenStrategies })
  if (judged.witnessFault) witnessFaults.push(judged.witnessFault)
  if (judged.blind) {
    blindOracle.push(judged.blind)
    log(`round ${round}: BLIND ORACLE — runner witness reports cases_executed ${witness.cases_executed}`)
  }
  if (judged.mismatch) {
    claimMismatch.push(judged.mismatch)
    log(`round ${round}: CLAIM MISMATCH — implementer reports ${result.still_failing.length} failing, runner exited ${witness.exit_code}`)
  }
  if (judged.repeated) repeatedStrategies.push({ round, strategy: feed.strategy })
  seenStrategies.add(judged.strat)
  if (judged.exhausted) { dry++; dryStreak.push(judged.strat) } else { dry = 0; dryStreak = [] }
}

// ── Phase 3 — the implementer does not get to certify itself. The verifier runs even after a role
//    died: it checks the real state of the target, which is exactly what is needed when the loop's
//    own record is incomplete.
phase('Converge')
const originalFindings = traced?.findings ?? []
const [finalWitness, retraced] = await parallel([
  () => agent(witnessPrompt({ CTX, RUNNER, ORACLE_AUTHOR }, 'final, Converge phase'),
    { label: 'witness-final', phase: 'Converge', schema: WITNESS_SCHEMA, model: MODELS.witness }),
  // ── RETRACE. The tracer's findings are a Challenge-phase snapshot. A fix can close one
  //    right-answer-wrong-execution defect and introduce another, and no outcome test will notice,
  //    so the same brief is run again against the post-fix code.
  () => agent(retracePrompt({ CTX, traced, history }),
    { label: 'retrace', phase: 'Converge', schema: RETRACE_SCHEMA, model: MODELS.retrace }),
])
alive(finalWitness, 'witness (final)')
alive(retraced, 'retrace')

const verification = await agent(verifierPrompt({ CTX, RUNNER, TYPECHECK, round, deadRoles, history, witnesses, claimMismatch, feeds, mandated, traced }),
  { label: 'verify', phase: 'Converge', schema: VERIFY_SCHEMA, model: MODELS.verifier })
alive(verification, 'verifier')

// ── Convergence is computed by the core from observations, never taken from any agent's word alone.
const cv = computeConvergence({
  RUNNER, SMOKE_REASON, DRY_ROUNDS, round, dry, dryStreak, deadRoles, malformedRoles,
  blindOracle, claimMismatch, witnessFaults, originalFindings, finalWitness, retraced, verification,
})
return {
  target: TARGET,
  rounds: round,
  converged: cv.converged,
  stopped_because: cv.stopped_because,
  not_converged_reasons: cv.not_converged_reasons,
  dead_roles: cv.dead_roles,
  claim_mismatch: claimMismatch,
  witness_faults: witnessFaults,
  blind_oracle: blindOracle,
  repeated_strategies: repeatedStrategies,
  runner_witness: witnesses.map((w, i) => ({ round: i + 1, exit_code: w.exit_code, cases_executed: w.cases_executed })),
  final_runner_witness: finalWitness ?? null,
  retrace: cv.retrace_findings === null ? null : { new_right_answer_wrong_execution: cv.new_silent, unclosed_original: cv.unclosed_original, findings: cv.retrace_findings },
  // null = the role died (missing); [] = the role ran and found nothing.
  contested_expectations: contested ? contested.contested ?? [] : null,
  proposed_cases: generated ? generated.cases ?? [] : null,
  standing_mandates: mandated ? mandated.mandates ?? [] : null,
  unenforced_mandates: mandated ? unenforced : null,
  execution_findings: traced ? traced.findings ?? [] : null,
  right_answer_wrong_execution: traced ? silentTrace : null,
  history,
  strategies: feeds.map((f) => ({ strategy: f.strategy, gap_targeted: f.gap_targeted, expected_yield: f.expected_yield, cases: f.cases.length })),
  independent_verification: verification ?? null,
}
````
