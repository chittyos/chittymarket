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
- **`oracleAuthor: 'olmec'`** marks a runner and corpus written by the reviewing agent; the contester
  and the witness are then pointed at the oracle explicitly. The contester always contests the oracle.

Everything else (known failures, role prompts, loop-until-dry rule) is unchanged.

The fenced block below is the projected script, byte for byte. Edit it here, never in the projection.

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

// The Workflow host can deliver `args` JSON-encoded as a STRING, so `args.target` is undefined no
// matter what the caller passed — the old code then blamed the caller for omitting an arg they did
// supply, failing in ~10ms with 0 agents (reads like a launch fault, not an arg bug).
//
// Every non-object shape (array, number, null) reaches the same misleading error by a different
// door, so the type is checked after parsing rather than trusted. The raw input is NOT echoed:
// `runner` is a shell command and may carry a token.
const USAGE = 'Workflow({name: "chittyos-core:gauntlet", args: {target: "/abs/path", runner: "<command that exits non-zero on failure>", dryRun: true}})'
let a
if (args === undefined || args === null || (typeof args === 'string' && args.trim() === '')) {
  a = {}
} else if (typeof args === 'string') {
  try {
    a = JSON.parse(args)
  } catch {
    // The V8 message echoes a prefix of the input ("Unexpected token 'T', "TOKEN=sk-l"..."), and
    // `runner` may carry a token, so only the length is reported.
    throw new Error(`gauntlet: args arrived as a string but is not valid JSON; ${args.length} bytes (content not echoed)`)
  }
} else {
  a = args
}
if (a === null || typeof a !== 'object' || Array.isArray(a)) {
  throw new Error(`gauntlet: args must be an object (or a JSON string encoding one), got ${Array.isArray(a) ? 'array' : a === null ? 'null' : typeof a}`)
}

if (Object.keys(a).length === 0) {
  log('gauntlet started with no args — nothing to test; no agent was dispatched')
  return {
    started: false,
    reason: 'no-args',
    next: `The gauntlet needs a target and a runner. Nothing failed and nothing ran. Re-invoke as ${USAGE} to validate the config, then without dryRun to run it.`,
  }
}

const TARGET = a.target
const RUNNER = a.runner
if (typeof TARGET !== 'string' || !TARGET.trim()) {
  log('gauntlet: args.target missing or not a string — no agent was dispatched')
  return {
    started: false,
    reason: 'missing-target',
    next: `args.target must be the path of the thing under test. Nothing ran. Re-invoke as ${USAGE}.`,
  }
}
if (typeof RUNNER !== 'string' || !RUNNER.trim()) {
  log('gauntlet: args.runner missing or not a string — no agent was dispatched')
  return {
    started: false,
    reason: 'missing-runner',
    next: `args.runner must be a shell command that exits non-zero on failure. If none exists, build the corpus and runner first (see the chittyagent-olmec agent). Nothing ran. Re-invoke as ${USAGE}.`,
  }
}
// Absolute only: agents run with their own working directories, so a relative target resolves
// against whatever cwd each agent happens to have, and different roles can test different files.
if (!TARGET.startsWith('/')) {
  log('gauntlet: args.target is not an absolute path — no agent was dispatched')
  return { started: false, reason: 'relative-target', next: 'args.target must be an absolute path (starting with /). Nothing ran.' }
}

// Unknown keys are rejected: a misspelled `dryRun` ("dryrun", "dry_run") would otherwise be ignored
// and launch the full fleet.
const KNOWN_KEYS = ['target', 'runner', 'typecheck', 'what', 'files', 'corpus', 'invariants', 'probes', 'rules', 'knownFailures', 'sameAuthor', 'oracleAuthor', 'maxRounds', 'dryRounds', 'dryRun', 'models']
const unknownKeys = Object.keys(a).filter((k) => !KNOWN_KEYS.includes(k))
if (unknownKeys.length) {
  log(`gauntlet: ${unknownKeys.length} unknown arg key(s) — no agent was dispatched`)
  return { started: false, reason: 'unknown-args', next: `Unknown args: ${unknownKeys.join(', ')}. Known: ${KNOWN_KEYS.join(', ')}. Nothing ran.` }
}

// Every value interpolated into a prompt is type-checked here. A string where an array belongs would
// otherwise be iterated character by character, or `.map` would throw mid-run after agents were
// already paid for. null/undefined mean "not supplied".
const isStrArray = (v) => Array.isArray(v) && v.every((x) => typeof x === 'string')
const badTypes = []
for (const k of ['files', 'invariants', 'probes', 'rules', 'knownFailures']) {
  if (a[k] != null && !isStrArray(a[k])) badTypes.push(`${k} (must be an array of strings)`)
}
for (const k of ['corpus', 'what', 'typecheck']) {
  if (a[k] != null && typeof a[k] !== 'string') badTypes.push(`${k} (must be a string)`)
}
if (a.sameAuthor != null && typeof a.sameAuthor !== 'boolean') badTypes.push('sameAuthor (must be a boolean)')
// oracleAuthor names who wrote the runner + corpus (the oracle). 'olmec' means the reviewing agent
// built them itself, which is grading-adjacent: the contester and the witness are then pointed at
// the oracle as well as the code. 'independent' means neither the reviewer nor the implementer.
const ORACLE_AUTHORS = ['olmec', 'independent']
if (a.oracleAuthor != null && !ORACLE_AUTHORS.includes(a.oracleAuthor)) badTypes.push(`oracleAuthor (must be one of: ${ORACLE_AUTHORS.join(', ')})`)
if (badTypes.length) {
  log(`gauntlet: ${badTypes.length} arg(s) have the wrong type — no agent was dispatched`)
  return { started: false, reason: 'bad-args', next: `Wrong-typed args: ${badTypes.join('; ')}. Nothing ran.` }
}

// Per-role models. Override with args.models = { role: model }. Overrides are checked against a
// per-role ALLOW-LIST, not just for shape: judgment roles (their output is acted on, not re-checked)
// accept only opus or stronger, so a caller cannot quietly downgrade the verifier to a cheap model.
// The generator (raw material, re-selected downstream) and the witness (gathering only: run one
// command, report the exit code) may also run on sonnet.
const DEFAULT_MODELS = {
  contester: 'opus',
  generator: 'sonnet',
  tracer: 'opus',
  mandate: 'opus',
  feeder: 'opus',
  implementer: 'opus',
  witness: 'sonnet',
  retrace: 'opus',
  verifier: 'opus',
}
const JUDGMENT_MODELS = ['opus', 'fable']
const GATHERING_MODELS = ['opus', 'sonnet']
const ALLOWED_MODELS = Object.fromEntries(Object.keys(DEFAULT_MODELS).map((r) => [r, r === 'generator' || r === 'witness' ? GATHERING_MODELS : JUDGMENT_MODELS]))
const modelOverrides = a.models ?? {}
if (modelOverrides === null || typeof modelOverrides !== 'object' || Array.isArray(modelOverrides)) {
  log('gauntlet: args.models is not an object — no agent was dispatched')
  return { started: false, reason: 'bad-models', next: `args.models must be an object mapping role -> model; roles: ${Object.keys(DEFAULT_MODELS).join(', ')}.` }
}
const badModelKeys = Object.keys(modelOverrides).filter((k) => !(k in DEFAULT_MODELS) || !ALLOWED_MODELS[k].includes(modelOverrides[k]))
if (badModelKeys.length) {
  log(`gauntlet: args.models has ${badModelKeys.length} invalid entr${badModelKeys.length === 1 ? 'y' : 'ies'} — no agent was dispatched`)
  return { started: false, reason: 'bad-models', next: `Invalid args.models entries: ${badModelKeys.join(', ')}. Allowed: ${Object.entries(ALLOWED_MODELS).map(([r, m]) => `${r}=${m.join('|')}`).join(', ')}. Nothing ran.` }
}
const MODELS = { ...DEFAULT_MODELS, ...modelOverrides }

// Hard ceiling on rounds: the budget is 4 + 3*maxRounds + 3 mostly-Opus agents, so an unbounded
// maxRounds is an unbounded spend. 12 rounds = 43 agents.
const MAX_ROUNDS_CEILING = 12
const MAX_ROUNDS = a.maxRounds ?? 6
if (!Number.isInteger(MAX_ROUNDS) || MAX_ROUNDS < 1 || MAX_ROUNDS > MAX_ROUNDS_CEILING) {
  log(`gauntlet: maxRounds must be an integer in 1..${MAX_ROUNDS_CEILING} — no agent was dispatched`)
  return { started: false, reason: 'bad-rounds', next: `args.maxRounds must be an integer from 1 to ${MAX_ROUNDS_CEILING} (default 6). Nothing ran.` }
}
// The default never exceeds maxRounds (maxRounds: 1 alone is valid); an explicit value is checked.
// dryRounds 1, or a maxRounds too small to hold a productive round plus a dry streak of >= 2, is
// accepted only as a SMOKE run that can never report convergence (see CAN_CONVERGE).
const DRY_ROUNDS = a.dryRounds ?? Math.min(2, MAX_ROUNDS)
// dryRounds > maxRounds can never be satisfied, so the loop could never report convergence.
if (!Number.isInteger(DRY_ROUNDS) || DRY_ROUNDS < 1 || DRY_ROUNDS > MAX_ROUNDS) {
  log('gauntlet: dryRounds must be an integer in 1..maxRounds — no agent was dispatched')
  return { started: false, reason: 'bad-dry-rounds', next: `args.dryRounds must be an integer from 1 to maxRounds (${MAX_ROUNDS}); default 2. Nothing ran.` }
}
// Convergence needs a dry streak of at least 2 rounds (one dry round is indistinguishable from a
// poorly-fitting strategy), and round 1 never counts toward the streak (it is the baseline), so at
// least one round always precedes the streak.
const MIN_DRY_STREAK = 2
const CAN_CONVERGE = DRY_ROUNDS >= MIN_DRY_STREAK && MAX_ROUNDS >= DRY_ROUNDS + 1
const SMOKE_REASON = CAN_CONVERGE ? null
  : DRY_ROUNDS < MIN_DRY_STREAK ? `smoke run: dryRounds ${DRY_ROUNDS} < ${MIN_DRY_STREAK}, so this run can never report convergence`
  : `smoke run: maxRounds ${MAX_ROUNDS} cannot hold a baseline round plus a dry streak of ${DRY_ROUNDS}, so this run can never report convergence`
const ORACLE_AUTHOR = a.oracleAuthor ?? null
const TYPECHECK = typeof a.typecheck === 'string' && a.typecheck.trim() ? a.typecheck : null  // '' = not configured
const CORPUS = typeof a.corpus === 'string' && a.corpus.trim() ? a.corpus : null
// ── Everything above is validated. Nothing below dispatches until the dryRun return has been passed.

/**
 * KNOWN FAILURE MODES — things that have ACTUALLY GONE WRONG, not hypotheticals.
 *
 * Feeding these in is different from asking for creativity. A failure that has already happened once
 * in a codebase happens again, in a new location, wearing different clothes. Testing the CLASS rather
 * than the instance is what turns an incident into permanent pressure.
 *
 * Every entry below was observed in production in this ecosystem. Callers extend with
 * args.knownFailures for domain-specific history.
 */
const DEFAULT_KNOWN_FAILURES = [
  'Silent success: a test suite whose module never loaded (ERR_MODULE_NOT_FOUND) greps as ZERO failures. An empty run exits 0. A test step that finds no tests exits 0.',
  'Declared but unpopulated: metadata fields defined in a schema and written by nothing. The contract looks enforced; five fields declared, one populated, and the boundary was decorative.',
  'Configured but not installed: a plugin/provider listed in config and absent from disk, while the status command reports it available/configured/selected regardless. The listing is not evidence the thing loaded.',
  'Generated file edited by hand: a derived artifact that is regenerated or filtered out at load, so the edit silently does nothing and the real source of truth is elsewhere.',
  'Pointed at a resource that does not exist: a client hard-wired to a slug/bucket/host that 404s, producing an error that is misread as a permissions or routing problem for months.',
  'Running and discarding: a pipeline healthy and delivering into a destination that does not exist, dropping every event since the day it was configured, with no alert.',
  'Fails open: a mint/validate/auth path that returns HTTP 200 with a fallback flag when the real dependency is unavailable, so failure is indistinguishable from success at the call site.',
  'Static health: a /health endpoint returning ok without touching the dependency it exists to report on. It reports healthy while the thing it guards is unreachable.',
  'Masked CI: continue-on-error on a job that has never passed, so the workflow is green forever and the check is paid for and never received.',
  'Error code misread: a status that means content-negotiation or bad-format taken as a fault, and a fault taken as a size limit. The diagnosis survives longer than the bug.',
  'Order-dependent restart: components sharing a namespace or lifecycle where restarting them in the wrong order produces a total-outage signature that has nothing to do with the real fault.',
  'Name where an id belongs: a human-readable name in a field that requires an identifier, producing a binding that resolves to nothing and fails only at runtime.',
  'Author-graded homework: the same context wrote the code, the tests, and the fix, so the suite encodes the author\'s misunderstanding as the contract and passes.',
]

const KNOWN_FAILURES = [...DEFAULT_KNOWN_FAILURES, ...(a.knownFailures ?? [])]

const CTX = `
TARGET: ${TARGET}
${a.files?.length ? `FILES:\n${a.files.map((f) => `  ${f}`).join('\n')}` : ''}
${CORPUS ? `FIXTURE CORPUS: ${CORPUS}` : ''}
RUNNER: ${RUNNER}
${TYPECHECK ? `TYPECHECK: ${TYPECHECK}` : ''}

WHAT THIS IS:
${typeof a.what === 'string' && a.what.trim() ? a.what : '(not described — read the code and the charter/README before judging anything)'}

${a.invariants?.length ? `INVARIANTS — must hold no matter what:\n${a.invariants.map((i) => `  - ${i}`).join('\n')}` : ''}

${a.rules?.length ? `BINDING RULES:\n${a.rules.map((r) => `  - ${r}`).join('\n')}` : ''}

${a.sameAuthor === false ? '' : `PROVENANCE WARNING. The code and its fixtures were written by the SAME context. The suite therefore
encodes that author's beliefs about correctness as if they were the contract. Where the author was
wrong, the fixture asserts the bug as intended behaviour and the suite passes anyway. Treat every
expected value as a CLAIM to be contested, not a given.`}

${ORACLE_AUTHOR === 'olmec' ? `ORACLE PROVENANCE WARNING. The runner and the fixture corpus (the ORACLE that defines pass/fail) were
written by the reviewing agent that launched this run, not by an independent party. Authoring the oracle
is grading-adjacent: whoever wrote it decided what "correct" means. Treat the runner and the corpus as
CLAIMS too. Does the runner actually exercise the real decision code? Does it exit non-zero when a case
fails? Could it pass with the decision logic deleted?` : ''}

KNOWN FAILURE MODES — these have ACTUALLY HAPPENED in this ecosystem, they are not hypotheticals.
A failure that happened once recurs in a new location wearing different clothes. Check this artifact
against the CLASS, not the instance:
${KNOWN_FAILURES.map((k) => `  - ${k}`).join('\n')}

HARD RULES FOR EVERY AGENT IN THIS WORKFLOW:
- Never report a pass you did not observe. Quote real output.
- A skipped, deferred or pending case is NOT a passing case.
- An empty test run also exits 0. Prove a clean typecheck is real by injecting a deliberate error,
  observing the failure, then reverting.
- Read the actual source before judging. Do not reason from the description alone.
- Do NOT spawn subagents and do NOT use the Agent or Workflow tools. This workflow's agent budget counts
  its own direct agent() calls only; any transitive spawning would be unbounded spend, so it is forbidden.
`

const CONTEST_SCHEMA = {
  type: 'object', additionalProperties: false, required: ['contested'],
  properties: {
    contested: {
      type: 'array',
      items: {
        type: 'object', additionalProperties: false,
        required: ['case_name', 'current_expect', 'should_be', 'reasoning', 'confidence'],
        properties: {
          case_name: { type: 'string' },
          current_expect: { type: 'string' },
          should_be: { type: 'string' },
          reasoning: { type: 'string' },
          confidence: { type: 'string', enum: ['high', 'medium', 'low'] },
        },
      },
    },
  },
}

const CASES_SCHEMA = {
  type: 'object', additionalProperties: false, required: ['cases'],
  properties: {
    cases: {
      type: 'array',
      items: {
        type: 'object', additionalProperties: false,
        required: ['name', 'expect', 'why', 'input_description'],
        properties: {
          name: { type: 'string' },
          expect: { type: 'string' },
          why: { type: 'string', description: 'what breaks if this decision is wrong' },
          input_description: { type: 'string', description: 'exact input / mutation from the baseline' },
        },
      },
    },
  },
}

const MANDATE_SCHEMA = {
  type: 'object', additionalProperties: false, required: ['mandates'],
  properties: {
    mandates: {
      type: 'array',
      items: {
        type: 'object', additionalProperties: false,
        required: ['requirement', 'mandated_by', 'quote', 'enforced', 'gap'],
        properties: {
          requirement: { type: 'string' },
          mandated_by: { type: 'string', description: 'file:line or canonical URI of the source that mandates it' },
          quote: { type: 'string', description: 'the actual text that mandates it — not a paraphrase' },
          enforced: { type: 'string', enum: ['yes', 'partially', 'no'] },
          gap: { type: 'string', description: 'what the implementation does instead, and what that allows through' },
        },
      },
    },
  },
}

const TRACE_SCHEMA = {
  type: 'object', additionalProperties: false, required: ['findings'],
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object', additionalProperties: false,
        required: ['axis', 'title', 'file', 'line', 'observed', 'should_be', 'outcome_still_correct'],
        properties: {
          axis: { type: 'string', enum: ['tools', 'logic', 'order', 'measures', 'surface'] },
          title: { type: 'string' },
          file: { type: 'string' },
          line: { type: 'number' },
          observed: { type: 'string', description: 'what the execution actually does' },
          should_be: { type: 'string' },
          outcome_still_correct: {
            type: 'boolean',
            description: 'true = right answer reached the wrong way — the dangerous kind, invisible to outcome tests',
          },
        },
      },
    },
  },
}

const FEED_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['strategy', 'why_this_strategy', 'gap_targeted', 'cases', 'expected_yield'],
  properties: {
    strategy: { type: 'string', description: 'the testing LOGIC used this round — must differ from every prior round' },
    why_this_strategy: { type: 'string', description: 'what about the fix history makes this the right next probe' },
    gap_targeted: { type: 'string', description: 'the specific gap in the loop\'s own reasoning this is aimed at' },
    expected_yield: { type: 'string', enum: ['high', 'medium', 'low'], description: 'low is honest and signals approaching exhaustion' },
    cases: {
      type: 'array',
      maxItems: 8,
      items: {
        type: 'object', additionalProperties: false,
        required: ['name', 'expect', 'why', 'input_description', 'kills_if'],
        properties: {
          name: { type: 'string' },
          expect: { type: 'string' },
          why: { type: 'string' },
          input_description: { type: 'string' },
          kills_if: { type: 'string', description: 'what must be broken for this case to fail — if nothing, the case is vacuous, do not send it' },
        },
      },
    },
  },
}

const ROUND_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['runner_output', 'changes_made', 'cases_added', 'still_failing', 'anything_new'],
  properties: {
    runner_output: { type: 'string', description: 'verbatim final runner output' },
    changes_made: { type: 'array', items: { type: 'string' } },
    cases_added: { type: 'array', items: { type: 'string' } },
    still_failing: { type: 'array', items: { type: 'string' } },
    anything_new: { type: 'boolean', description: 'false only if this round found nothing new at all' },
  },
}

const WITNESS_SCHEMA = {
  type: 'object', additionalProperties: false, required: ['exit_code', 'output_tail', 'command'],
  properties: {
    exit_code: { type: 'integer', description: 'the real exit status of the runner, as the shell reported it' },
    output_tail: { type: 'string', description: 'verbatim last ~60 lines of combined stdout+stderr' },
    command: { type: 'string', description: 'the exact command executed, byte for byte' },
  },
}

const RETRACE_SCHEMA = {
  type: 'object', additionalProperties: false, required: ['findings'],
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object', additionalProperties: false,
        required: [...TRACE_SCHEMA.properties.findings.items.required, 'original_index'],
        properties: {
          ...TRACE_SCHEMA.properties.findings.items.properties,
          original_index: { type: 'integer', description: 'index into the ORIGINAL findings list if this is an original finding still open; -1 if new' },
        },
      },
    },
  },
}

const VERDICTS = ['converged', 'not_converged', 'cannot_verify']
const VERIFY_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['verdict', 'runner_exit_code', 'runner_output_tail', 'vacuous_assertions', 'unaddressed_trace_findings', 'remaining_gaps', 'report'],
  properties: {
    verdict: { type: 'string', enum: VERDICTS },
    runner_exit_code: { type: 'integer', description: 'exit status of YOUR OWN run of the runner' },
    runner_output_tail: { type: 'string', description: 'verbatim tail of YOUR OWN runner output' },
    vacuous_assertions: { type: 'array', items: { type: 'string' } },
    unaddressed_trace_findings: { type: 'array', items: { type: 'string' } },
    remaining_gaps: { type: 'array', items: { type: 'string' } },
    report: { type: 'string' },
  },
}

// ── Dry run: the cheap callability proof. Every arg was validated above, so a dry run can never
//    call an out-of-bounds or wrong-typed config valid. Nothing below this return runs under dryRun.
const AGENT_BUDGET = 4 + 3 * MAX_ROUNDS + 3
const BUDGET_FORMULA = '4 challenge + 3 per round (feeder + implementer + runner witness) x maxRounds + 3 converge (final witness + retrace + verifier)'
if (a.dryRun) {  // truthy on purpose: a mistyped dryRun ("true", 1) must fail safe, not launch the fleet
  log(`gauntlet dry run — config valid; a real run dispatches at most ${AGENT_BUDGET} agents; none dispatched`)
  return {
    started: false,
    reason: 'dry-run',
    config: {
      target: TARGET,
      runner_bytes: RUNNER.length,
      typecheck_configured: TYPECHECK !== null,
      corpus: CORPUS,
      files: a.files ?? [],
      maxRounds: MAX_ROUNDS,
      dryRounds: DRY_ROUNDS,
      sameAuthor: a.sameAuthor !== false,
      oracleAuthor: ORACLE_AUTHOR,
      can_converge: CAN_CONVERGE,
      smoke_run: SMOKE_REASON,
      known_failures: KNOWN_FAILURES.length,
      roles: Object.entries(MODELS).map(([role, model]) => ({ role, model })),
      agent_budget: { max: AGENT_BUDGET, formula: BUDGET_FORMULA, transitive_spawning: 'forbidden' },
    },
    next: CAN_CONVERGE
      ? 'Config is valid. Re-invoke with the same args minus dryRun to run the gauntlet.'
      : `Config is valid as a SMOKE run only (${SMOKE_REASON}). Re-invoke minus dryRun to run it anyway, or raise maxRounds/dryRounds to allow convergence.`,
  }
}

// ── Dead roles. agent() returns null/undefined when a role dies. That is a FAILURE, not an empty
//    result: rendering it as [] would tell every later role "the contester found nothing", which is
//    a clean bill of health nobody issued. Deaths are recorded, rendered as NOT RUN, and block any
//    convergence claim.
const deadRoles = []
const alive = (x, role) => {
  if (x === null || x === undefined) { deadRoles.push(role); return false }
  return true
}
const NOT_RUN = (role) => `NOT RUN — the ${role} agent returned nothing. Its output is MISSING, not empty; do not read this as "no findings".`
const render = (x, key, role) => (x === null || x === undefined ? NOT_RUN(role) : JSON.stringify(x[key] ?? [], null, 1))

// The tracer's brief is shared by the Challenge-phase TRACER and the Converge-phase RETRACE, so the
// re-trace judges the post-fix code by exactly the same axes.
const TRACER_BRIEF = `You are the TRACER. Everyone else judges OUTCOMES. You judge EXECUTION — how the answer is reached.

A right answer reached the wrong way is the dangerous case, because no outcome test can see it. The
assertion goes green, the logic it claims to cover could be deleted, and nothing notices until the
conditions shift. Read the actual code paths and judge three axes:

TOOLS — is it using the right ones?
  The right API, binding, client, or library for the job; not a working-but-wrong substitute. A call
  that happens to return the right shape today via the wrong mechanism. Reaching past an abstraction
  the project already has. A cheap call standing in for the correct expensive one, or vice versa.
  Redundant calls where one would do. Anything with a side effect the caller does not expect.

LOGIC — is the reasoning right, or right by luck?
  Does the predicate actually express the intended rule? Boundary and off-by-one. Inverted or
  short-circuited conditions that produce the correct answer on the tested inputs and the wrong one
  just outside them. Dead branches. Conditions that can never be false. A check whose result is
  computed and then ignored. Error paths that swallow rather than surface, so a failure returns a
  plausible value instead of failing closed.

ORDER — does the sequence matter, and is it right?
  Which check runs first, and would a different order change the answer or the reason for it?
  Cheap-and-decisive before expensive. Fail-closed before any default. Validation before use.
  Guard before the operation it guards. Anything order-dependent that reads as order-independent, or
  a dependency between steps that is real but unstated. Concurrency and interleaving where relevant.

MEASURES — is it measuring the right thing, in the right unit, against the right threshold?
  Does the quantity being measured actually stand for the property that matters, or is it a proxy
  that breaks at the edges? Units and their silent conversions — bytes vs KB vs MB vs MiB, seconds vs
  ms, tokens vs characters, count vs rate. Thresholds: where did the number come from, is it
  inclusive or exclusive at the boundary, and does it still hold if the underlying system changed it?
  Limits asserted in the code that the real dependency enforces differently — or does not enforce at
  all, silently. Any constant that is really a remote system's contract copied by hand, which drifts
  the moment that system moves. And what is NOT measured: the failure that produces no signal, the
  path with no counter, the error that increments nothing.

SURFACE — is it measuring the right SURFACE of the thing, or a surface that merely accompanies it?
  Most artifacts present several surfaces, and they can disagree. A document has declared metadata
  (filename, content-type, size, submitted hash), container structure, an embedded text layer, and
  what OCR actually renders. A scanned PDF has no text layer at all and is indistinguishable from a
  rich one if you only read metadata. A file named .pdf may not be a PDF. A declared hash is an
  assertion about bytes, not the bytes.

  Ask specifically: is the system judging the ARTIFACT, or the SUBMITTER'S CLAIMS ABOUT the artifact?
  Those are different surfaces and only one of them is evidence of anything. A gate built entirely on
  declared metadata cannot detect a mislabelled, empty, corrupt, or substituted file — every check
  passes because every check reads the same unverified assertion.

  Where surfaces can disagree, say which one is authoritative and whether the code agrees. Where the
  cheap surface is being used as a proxy for the expensive one (metadata standing in for content,
  extension for format, declared hash for computed hash), name the substitution and what it misses.

For each finding set outcome_still_correct=true when the current answer is RIGHT despite the flaw —
those are the ones the corpus structurally cannot catch and are the highest-value output of this
phase. Cite file and line. Report nothing you have not traced in the real source.`

// ── Phase 1 — two independent attacks, run together. One argues the corpus is
//    WRONG; the other argues it is INCOMPLETE. Different failure modes, so they
//    must not be the same agent.
phase('Challenge')
const [contested, generated, traced, mandated] = await parallel([
  () => agent(`${CTX}

You are the CONTESTER. Read the code and the fixture corpus. Argue that the EXPECTATIONS are wrong.

Not "the code fails its tests" — that the tests assert the wrong thing. For every case ask: did the
author encode their own mistake as the contract? Pay special attention to any case whose own comment
admits doubt; the author flagging uncertainty is not the same as the author resolving it.

Then contest the SILENT assumptions — the ones no case tests because the author never questioned
them. Scope, defaults, which values are allowed at all, what is rejected without argument, and where
a strictness that reads as rigour is actually a bug that will reject legitimate input.

Then contest the ORACLE itself — the runner and the corpus that define pass/fail. Does the runner
exercise the real decision code, or a stub? Does it exit non-zero when a case fails, or can it go green
on an empty or skipped run? Would it still pass with the decision logic deleted? Report an oracle defect
as a contested expectation whose case_name starts with "ORACLE:".${ORACLE_AUTHOR === 'olmec' ? `
The oracle was written by the reviewing agent itself (see ORACLE PROVENANCE WARNING): give it the same
scrutiny you give the code, not less.` : ''}

Report only expectations you believe are WRONG, with reasoning and a confidence. Empty array if the
corpus is genuinely right — do not manufacture disagreement.`,
    { label: 'contest', phase: 'Challenge', schema: CONTEST_SCHEMA, model: MODELS.contester }),

  () => agent(`${CTX}

You are the GENERATOR. Read the corpus, then find what it MISSES.

You are hunting for inputs that pass when they should not, or fail when they should not. Think about
true edge cases and exceptions the author did not consider — boundaries, empty and absent, malformed
in a way that is still technically valid, encoding and normalisation, adversarial keys, size extremes,
and what a REAL production caller actually sends versus what the tests assume.

${a.probes?.length ? `Directions worth probing — go beyond these, do not merely tick them off:\n${a.probes.map((p) => `  - ${p}`).join('\n')}` : ''}

For each case give the exact input or mutation. Only propose cases whose expected outcome you can
justify — a case you are unsure about pollutes the corpus permanently.`,
    { label: 'generate', phase: 'Challenge', schema: CASES_SCHEMA, model: MODELS.generator }),

  () => agent(`${CTX}

${TRACER_BRIEF}`,
    { label: 'trace', phase: 'Challenge', schema: TRACE_SCHEMA, model: MODELS.tracer }),

  () => agent(`${CTX}

You are the MANDATE AUDITOR. Everyone else asks whether this thing is internally consistent. You ask
whether it does what it was ALREADY REQUIRED to do, by rules written down somewhere else.

Requirements drift is silent: a policy is set, the implementation is written later by someone who did
not read it, and nothing ever fails. There is no test for a rule nobody encoded. The gap is invisible
from inside the code and invisible from inside the test suite — it is only visible by going and
reading what was already decided.

GO AND LOOK. Do not reason from memory or from this brief. Search for standing requirements that
apply to this artifact, in roughly this order of authority:
  - its own CHARTER / CHITTY / CLAUDE / README / SECURITY / AGENTS docs — a service that violates its
    own charter is the cheapest finding available and the most embarrassing to ship
  - the project's canonical governance (chittycanon://, canon docs, ontology definitions)
  - sibling and upstream services that already solved the same problem, and the contract they expose
  - prior decisions in docs/, ADRs, runbooks, skills, and commit history — a rule stated once and
    never encoded is exactly the target
  - the ecosystem registry and compliance triads of services this one depends on or feeds

For each standing requirement you find that is RELEVANT to this artifact, report whether the
implementation enforces it: yes, partially, or no. Quote the mandating text verbatim with a
file:line or canonical URI — a paraphrase is not evidence, and a requirement you cannot cite did not
survive as a requirement. For anything less than "yes", say concretely what the implementation does
instead and what that lets through.

Report only mandates you actually located and read. An empty array is a legitimate answer and is far
better than an invented one. Do NOT report general best practice — only rules this project already
committed to.`,
    { label: 'mandates', phase: 'Challenge', schema: MANDATE_SCHEMA, model: MODELS.mandate }),
])

alive(contested, 'contester'); alive(generated, 'generator'); alive(traced, 'tracer'); alive(mandated, 'mandate')
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
const normStrategy = (x) => String(x ?? '').trim().toLowerCase().replace(/\s+/g, ' ')

// ── RUNNER WITNESS. Workflow scripts have no shell, so the runner's exit code can only be observed by
//    an agent. The witness is gathering-only: it runs the runner VERBATIM, edits nothing, interprets
//    nothing, and reports the real exit status. It is a different agent from the implementer, so an
//    implementer that fabricates "all cases pass" is contradicted by an observation it did not make.
const witnessPrompt = (when) => `${CTX}

You are the RUNNER WITNESS (${when}). You are a GATHERING role: you observe, you do not judge or fix.

1. Run exactly this command, byte for byte, from the target's repository: ${RUNNER}
2. Report its REAL exit status as exit_code (the integer the shell reports, e.g. from \`echo $?\` run
   immediately after). Do not infer it from the output. Do not round a failure to 0.
3. Report the verbatim last ~60 lines of combined stdout+stderr as output_tail, including any pass/fail
   and case counts, so a reader can see how many cases actually ran.
4. Report the exact command you executed as command.

FORBIDDEN: editing, creating, deleting or reverting ANY file; running any other command that changes
state; re-running with different flags to get a better result; spawning subagents. If you cannot run
the command at all, report exit_code 127 and say why in output_tail.${ORACLE_AUTHOR === 'olmec' ? `
The oracle was written by the reviewing agent: if the output shows zero cases executed, or no case
counts at all, say so plainly at the top of output_tail.` : ''}`

const witnessOk = (w) => w && Number.isInteger(w.exit_code) && typeof w.output_tail === 'string' && typeof w.command === 'string'

while (dry < DRY_ROUNDS && round < MAX_ROUNDS) {
  round++
  const prior = history.length
    ? history.map((h, i) =>
        `ROUND ${i + 1}: changed [${h.changes_made.join(', ') || 'nothing'}] · added [${h.cases_added.join(', ') || 'nothing'}] · failing [${h.still_failing.join(', ') || 'none'}] · witnessed runner exit ${witnesses[i]?.exit_code ?? 'NOT OBSERVED'}`).join('\n')
    : '(first round)'

  // ── FEEDER. Runs before the implementer, every round, and is privy to every
  //    fix already made. Its job is not "more cases" — it is a DIFFERENT testing
  //    logic each round, aimed at the residual gap the previous rounds reveal.
  //    Adding more of the same kind of case has diminishing yield immediately;
  //    changing the kind of probe is what keeps finding things.
  const feed = await agent(`${CTX}

You are the FEEDER for round ${round}. You do not fix anything. You decide WHAT GETS TESTED NEXT, and
by what logic.

Your job is NOT to produce more cases of the kind already in the corpus — that has near-zero marginal
yield after the first round. Your job is to choose a testing LOGIC that is purposefully DIFFERENT from
every strategy already tried, aim it at the narrowest gap still standing, and send through only the
cases that logic actually justifies.

STRATEGIES ALREADY USED — you may not repeat one:
${feeds.length ? feeds.map((f, i) => `  ROUND ${i + 1}: ${f.strategy}\n     targeted: ${f.gap_targeted}\n     yield: ${f.expected_yield}`).join('\n') : '  (none yet — this is the first round)'}

WHAT THE LOOP HAS ALREADY FIXED (you are privy to this on purpose — use it):
${prior}

${feeds.length ? `The fixes above tell you where the implementer's attention has been, and therefore where it has NOT.
A gap that survived N rounds of fixing survived because every probe so far shared an assumption.
Name that assumption and attack it.` : ''}

INITIAL POOL from the cold-start generator — treat as raw material, not a queue to drain. Re-select,
reshape, or discard:
${render(generated, 'cases', 'generator')}

KNOWN FAILURE MODES are listed above. "Regression against known failures" is itself a legitimate
strategy for one round — take the catalogue and ask, for each entry, whether THIS artifact has the
same disease in a new place. Prefer it early if the artifact has never been checked against them.
Do not spread them thinly across every round; that is how a strategy becomes a ritual.

CHOOSING A LOGIC. Pick one that fits what is left, not one from a list — these are illustrative of
how DIFFERENT consecutive strategies should be:
  - boundary and equivalence partitioning around every threshold
  - metamorphic: pairs of inputs whose RELATIVE outcomes must hold even when the absolute answer is
    unknown (change one field, the verdict must/must not change)
  - differential: compare against a sibling implementation, an upstream contract, or a prior version
  - property/invariant: assert something true of ALL inputs rather than enumerating cases
  - adversarial: an attacker who has read the source and is trying to get something admitted
  - production-shaped: what the real upstream caller actually sends, including its malformed days
  - state-sequence: order and interleaving of multiple operations rather than one call in isolation
  - negative-space: inputs the corpus structurally cannot express, which is where blind spots live

SELECT, do not dump. At most 8 cases, and fewer is better if fewer is what the logic justifies. For
each, state kills_if — what must be broken for this case to FAIL. If you cannot name something, the
case is vacuous and you must not send it. A vacuous case costs more than it returns: it makes the
suite look stronger while testing nothing.

Set expected_yield honestly. Reporting 'low' when the surface is genuinely close to exhausted is
useful signal and will not be held against you — inflating it wastes a whole round.`,
    { label: `feed-${round}`, phase: 'Fix', schema: FEED_SCHEMA, model: MODELS.feeder })

  // A dead feeder stops the loop. It must NOT fall through to the implementer with an empty feed,
  // and must NOT count as a low-yield signal: silence is not evidence the surface is exhausted.
  if (!alive(feed, `feeder (round ${round})`)) { log(`round ${round}: feeder died — stopping`); break }
  feeds.push(feed)
  log(`round ${round} feeder: ${feed.strategy} → ${feed.cases.length} cases (yield ${feed.expected_yield}) targeting: ${feed.gap_targeted}`)

  const result = await agent(`${CTX}

You are the IMPLEMENTER for round ${round}. Different agents wrote this code and contested it. Your
job is to make it correct, then PROVE it with the runner.

CONTESTED EXPECTATIONS (weigh, do not obey — if you disagree, say so in changes_made and leave it):
${render(contested, 'contested', 'contester')}

THIS ROUND'S FEED — selected by the feeder using the strategy "${feed.strategy}", aimed at:
${feed.gap_targeted}
Each case carries kills_if — what must be broken for it to fail. If a case's kills_if is not actually
true of the code, say so rather than adding a case that tests nothing:
${JSON.stringify(feed.cases ?? [], null, 1)}

STANDING MANDATES this artifact was already required to satisfy (from the mandate auditor). A rule
this project already committed to and never encoded outranks anything invented in this run — treat an
unenforced mandate as a defect, not a suggestion:
${render(mandated, 'mandates', 'mandate auditor')}

EXECUTION FINDINGS — tools / logic / order / measures / surface (from the tracer):
${render(traced, 'findings', 'tracer')}

${silentTrace.length ? `${silentTrace.length} of those have outcome_still_correct=true — the answer is RIGHT and the execution is
WRONG. The corpus cannot catch these by asserting outcomes, so fixing them without adding an
assertion that pins the REASON just means the next author reintroduces them. Prioritise these.` : ''}

PRIOR ROUNDS:
${prior}

DO, in order:
1. Run \`${RUNNER}\` first. See where it actually stands before changing anything.
2. Add sound new cases to the corpus. Every case needs a note saying what breaks if the decision is wrong.
3. Fix genuine defects — in outcomes AND in execution. When the EXPECTATION is wrong rather than the
   code, fix the fixture and say so explicitly in changes_made — that is a legitimate outcome, not a
   cop-out.
4. Where the corpus asserts only a final answer, strengthen it to pin the REASON — which check fired,
   which path ran, what was actually measured. An assertion that would still pass with the relevant
   logic deleted is close to worthless; say so and strengthen it rather than adding another like it.
5. Re-run \`${RUNNER}\`${TYPECHECK ? `, then \`${TYPECHECK}\`` : ''}. Report the VERBATIM final output.

Do not commit; the orchestrator handles that. Set anything_new=false ONLY if this round genuinely
found nothing — no fix, no case, no insight.`,
    { label: `fix-${round}`, phase: 'Fix', schema: ROUND_SCHEMA, model: MODELS.implementer })

  if (!alive(result, `implementer (round ${round})`)) { log(`round ${round}: implementer died — stopping`); break }
  history.push(result)
  log(`round ${round}: ${result.changes_made.length} changes · ${result.cases_added.length} cases · ${result.still_failing.length} failing (claimed)`)

  const witness = await agent(witnessPrompt(`after round ${round}`),
    { label: `witness-${round}`, phase: 'Fix', schema: WITNESS_SCHEMA, model: MODELS.witness })
  if (!alive(witness, `witness (round ${round})`) || !witnessOk(witness)) {
    if (witness && !witnessOk(witness)) deadRoles.push(`witness (round ${round}): malformed report`)
    log(`round ${round}: runner witness returned no usable observation — stopping`)
    break
  }
  witnesses.push(witness)
  if (witness.command.trim() !== RUNNER.trim()) witnessFaults.push({ round, reported_command: witness.command })

  // The implementer's claim and the witnessed exit code must agree. Either direction of disagreement
  // is recorded: "nothing failing" with a non-zero exit is a fabricated pass; "still failing" with
  // exit 0 means the runner cannot see a failure the implementer can, i.e. the oracle is blind.
  const claimsClean = result.still_failing.length === 0
  if (claimsClean !== (witness.exit_code === 0)) {
    claimMismatch.push({ round, implementer_still_failing: result.still_failing, witness_exit_code: witness.exit_code, witness_output_tail: witness.output_tail })
    log(`round ${round}: CLAIM MISMATCH — implementer reports ${result.still_failing.length} failing, runner exited ${witness.exit_code}`)
  }

  // Strategies must be distinct. A repeated strategy is a feeder defect: recorded, and the round does
  // not count toward dry (it would let one probe, relabelled, certify its own exhaustion).
  const strat = normStrategy(feed.strategy)
  const repeated = seenStrategies.has(strat)
  if (repeated) repeatedStrategies.push({ round, strategy: feed.strategy })
  seenStrategies.add(strat)

  // A round is dry only when ALL of these hold: it is not round 1 (the baseline); the witnessed
  // runner exited 0; the implementer reports nothing failing and nothing new; the feeder expected
  // little; and the strategy was new. The feeder's self-reported yield is one input, never the only one.
  const clean = witness.exit_code === 0 && claimsClean
  const exhausted = round > 1 && clean && !result.anything_new && feed.expected_yield === 'low' && !repeated
  if (exhausted) { dry++; dryStreak.push(strat) } else { dry = 0; dryStreak = [] }
}

// ── Phase 3 — the implementer does not get to certify itself. The verifier runs even after a role
//    died: it checks the real state of the target, which is exactly what is needed when the loop's
//    own record is incomplete.
phase('Converge')
const originalFindings = traced?.findings ?? []
const [finalWitness, retraced] = await parallel([
  () => agent(witnessPrompt('final, Converge phase'),
    { label: 'witness-final', phase: 'Converge', schema: WITNESS_SCHEMA, model: MODELS.witness }),
  // ── RETRACE. The tracer's findings are a Challenge-phase snapshot. A fix can close one
  //    right-answer-wrong-execution defect and introduce another, and no outcome test will notice,
  //    so the same brief is run again against the post-fix code.
  () => agent(`${CTX}

${TRACER_BRIEF}

THIS IS A RE-TRACE of the code AFTER the fix loop, not a first look. Judge the code as it is now.

ORIGINAL TRACER FINDINGS (indexed from 0) — for each one that is STILL present, report it again with
original_index set to its index. Do not report an original finding as closed because the implementer
said so; check the source:
${render(traced, 'findings', 'tracer')}

WHAT THE IMPLEMENTER CLAIMS TO HAVE CHANGED, round by round:
${JSON.stringify(history.map((h, i) => ({ round: i + 1, changes_made: h.changes_made })), null, 1)}

Report every NEW finding introduced or exposed by those changes with original_index -1. An empty
findings array means you traced the post-fix code and every original finding is closed.`,
    { label: 'retrace', phase: 'Converge', schema: RETRACE_SCHEMA, model: MODELS.retrace }),
])
alive(finalWitness, 'witness (final)')
alive(retraced, 'retrace')

const verification = await agent(`${CTX}

An implementation fleet ran ${round} round(s). Do NOT trust its report — verify it.
${deadRoles.length ? `\nROLES THAT DIED (returned nothing — their output is missing, not empty): ${deadRoles.join(', ')}.\nThe run is INCOMPLETE. Do not describe it as converged; say what the dead roles would have covered.\n` : ''}
ITS CLAIMS:
${JSON.stringify(history, null, 1)}

WHAT THE RUNNER WITNESS OBSERVED (exit codes are observations, the claims above are not):
${JSON.stringify(witnesses.map((w, i) => ({ round: i + 1, exit_code: w.exit_code })), null, 1)}
${claimMismatch.length ? `CLAIM MISMATCHES — rounds where the implementer's report contradicts the runner: ${JSON.stringify(claimMismatch.map((m) => m.round))}` : ''}

VERIFY INDEPENDENTLY:
1. Run \`${RUNNER}\` yourself. Quote the real output.
${TYPECHECK ? `2. Run \`${TYPECHECK}\`, and prove it is real: inject a deliberate error, observe the failure, revert.` : '2. (no typecheck configured)'}
3. Read what changed. Ask of every assertion: WOULD THIS STILL PASS IF THE BEHAVIOUR WERE WRONG?
   The concrete test: mentally delete the logic the assertion claims to cover. Does it still go
   green? Then it is vacuous. Name every such case.
4. Check EXECUTION, not just outcomes. For a sample of cases, confirm the right answer is reached for
   the right REASON — the intended check fired, in the intended order, measuring the intended
   surface. A case that passes because an unrelated check happened to reject first is a false pass.
5. Were the tracer's execution findings actually addressed, or only the outcome failures? Findings
   with outcome_still_correct=true are the ones most likely to have been quietly skipped, because
   nothing goes red when they are ignored.
6. Are any cases skipped, deferred or pending? Those are NOT passing — count and name them.
7. Judge the CURRICULUM itself. The feeder was required to use a different testing logic each round:
${JSON.stringify(feeds.map((f) => ({ strategy: f.strategy, gap_targeted: f.gap_targeted, yield: f.expected_yield })), null, 1)}
   Were they genuinely different, or the same probe relabelled? Which strategy was never tried, and
   would it have found something? A convergence reached by running out of ideas is not convergence.
8. Was the artifact checked against the KNOWN FAILURE MODES catalogue at all? Name any entry that
   plainly applies here and was never probed. These are the cheapest findings available and the
   least forgivable to miss, because someone already paid for the lesson.
9. What did all of this still miss?

MANDATE AUDITOR'S FINDINGS — verify each 'no'/'partially' was actually closed, or explicitly and
defensibly declined. A mandate quietly left unenforced is the failure mode this role exists to catch:
${render(mandated, 'mandates', 'mandate auditor')}

TRACER'S ORIGINAL FINDINGS, to check against:
${render(traced, 'findings', 'tracer')}

Report as structured fields: verdict ('converged' only if you ran the runner yourself, it exited 0, and
you found nothing that blocks; 'cannot_verify' if you could not run it), runner_exit_code and
runner_output_tail from YOUR OWN run, every vacuous assertion, every unaddressed execution finding, and
the remaining gaps. Do not congratulate.`,
  { label: 'verify', phase: 'Converge', schema: VERIFY_SCHEMA, model: MODELS.verifier })
alive(verification, 'verifier')

// ── Convergence is computed here from observations, never taken from any agent's word alone.
const verificationOk = (v) => v && typeof v === 'object' && VERDICTS.includes(v.verdict) &&
  Number.isInteger(v.runner_exit_code) && typeof v.runner_output_tail === 'string' &&
  Array.isArray(v.vacuous_assertions) && Array.isArray(v.unaddressed_trace_findings)
const retraceFindings = Array.isArray(retraced?.findings) ? retraced.findings : null
const newSilent = (retraceFindings ?? []).filter((f) => f.outcome_still_correct && f.original_index === -1)
const unclosedOriginal = (retraceFindings ?? []).filter((f) => Number.isInteger(f.original_index) && f.original_index >= 0)
const unclosedSilent = unclosedOriginal.filter((f) => originalFindings[f.original_index]?.outcome_still_correct || f.outcome_still_correct)

const blockers = []
if (SMOKE_REASON) blockers.push(SMOKE_REASON)
if (dry < DRY_ROUNDS) blockers.push(`dry streak ${dry} < dryRounds ${DRY_ROUNDS}`)
if (dry >= DRY_ROUNDS && new Set(dryStreak).size < MIN_DRY_STREAK) blockers.push(`dry streak used ${new Set(dryStreak).size} distinct strateg${new Set(dryStreak).size === 1 ? 'y' : 'ies'}; ${MIN_DRY_STREAK} required`)
if (round - dry < 1) blockers.push('no productive round preceded the dry streak')
if (claimMismatch.length) blockers.push(`claim_mismatch in round(s) ${claimMismatch.map((m) => m.round).join(', ')}`)
if (witnessFaults.length) blockers.push(`runner witness ran a different command in round(s) ${witnessFaults.map((f) => f.round).join(', ')}`)
if (finalWitness && witnessOk(finalWitness) && finalWitness.exit_code !== 0) blockers.push(`final runner witness exit ${finalWitness.exit_code}`)
if (finalWitness && !witnessOk(finalWitness)) blockers.push('final runner witness report malformed')
if (finalWitness && witnessOk(finalWitness) && finalWitness.command.trim() !== RUNNER.trim()) blockers.push('final runner witness ran a different command')
if (verification != null && !verificationOk(verification)) blockers.push('verifier output missing required fields (verdict, runner_exit_code, runner_output_tail, ...)')
if (verificationOk(verification)) {
  if (verification.verdict !== 'converged') blockers.push(`verifier verdict ${verification.verdict}`)
  if (verification.runner_exit_code !== 0) blockers.push(`verifier's own runner exit ${verification.runner_exit_code}`)
  if (verification.vacuous_assertions.length) blockers.push(`${verification.vacuous_assertions.length} vacuous assertion(s)`)
}
if (retraced != null && retraceFindings === null) blockers.push('retrace output missing findings')
if (newSilent.length) blockers.push(`retrace found ${newSilent.length} new right-answer-wrong-execution finding(s)`)
if (unclosedSilent.length) blockers.push(`${unclosedSilent.length} original right-answer-wrong-execution finding(s) still open`)
if (unclosedOriginal.length) blockers.push(`${unclosedOriginal.length} original execution finding(s) still open`)

// Death outranks everything: a run with a dead role never reports convergence, even if the loop
// happened to come back dry, because the dry signal was produced without that role's input.
const converged = deadRoles.length === 0 && blockers.length === 0
return {
  target: TARGET,
  rounds: round,
  converged,
  stopped_because: deadRoles.length
    ? `incomplete — roles died: ${deadRoles.join(', ')}`
    : converged ? 'converged (dry rounds, witnessed, verified)'
    : dry < DRY_ROUNDS ? 'hit maxRounds — NOT converged'
    : `NOT converged — ${blockers.join('; ')}`,
  not_converged_reasons: converged ? [] : [...deadRoles.map((r) => `role died: ${r}`), ...blockers],
  dead_roles: deadRoles,
  claim_mismatch: claimMismatch,
  witness_faults: witnessFaults,
  repeated_strategies: repeatedStrategies,
  runner_witness: witnesses.map((w, i) => ({ round: i + 1, exit_code: w.exit_code })),
  final_runner_witness: finalWitness ?? null,
  retrace: retraceFindings === null ? null : { new_right_answer_wrong_execution: newSilent, unclosed_original: unclosedOriginal, findings: retraceFindings },
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
