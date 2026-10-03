#!/usr/bin/env node
// Golden-fixture runner for the gauntlet core. Node built-ins only, no dependencies.
//
//   node scripts/tests/run_gauntlet_fixtures.mjs [core.js] [fixtures.json]
//
// Loads canonical/workflows/gauntlet.core.js (the single source tier 1 inlines and tier 2 vendors)
// and asserts every case in canonical/workflows/gauntlet.fixtures.json:
//   convergence    computeConvergence(state) -> converged, blockers, stopped_because,
//                  not_converged_reasons, dead_roles (exact, order included)
//   rounds         assessRound(input) -> the per-round judgment
//   validate_args  validateArgs(args) -> the early return, the thrown message, or (accepted args)
//                  dryRunResult(config) -> the dry-run log and return value
//
// It also gates COVERAGE, because an empty or shrunken fixture set would otherwise read as green:
// every blocker kind the core can emit, every stopped_because form, every validateArgs reason, and
// every per-round judgment must be exercised by at least one case, and every blocker a fixture
// expects must belong to a known kind (a new blocker cannot ship uncatalogued).
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '../..')
const corePath = process.argv[2] ?? resolve(ROOT, 'canonical/workflows/gauntlet.core.js')
const fixturesPath = process.argv[3] ?? resolve(ROOT, 'canonical/workflows/gauntlet.fixtures.json')

// Imported from its source text, so the .js extension and the absence of a package.json do not
// decide whether node parses it as a module.
const core = await import('data:text/javascript;base64,' + Buffer.from(readFileSync(corePath, 'utf8')).toString('base64'))
const fx = JSON.parse(readFileSync(fixturesPath, 'utf8'))

const BLOCKER_KINDS = {
  'final-witness-null': /^final runner witness returned nothing$/,
  'retrace-null': /^retrace returned nothing$/,
  'verifier-null': /^verifier returned nothing$/,
  'malformed-role': /^malformed role output: /,
  'blind-oracle-round': /^blind_oracle in round\(s\) /,
  'final-witness-zero-cases': /^final runner witness: runner executed zero cases$/,
  'final-witness-unknown-cases': /^final runner witness: case count unknown$/,
  'verifier-zero-cases': /^verifier: runner executed zero cases$/,
  'verifier-unknown-cases': /^verifier: case count unknown$/,
  'case-count-disagreement': /^case count disagreement: final witness \d+, verifier \d+$/,
  'smoke-run': /^smoke run: /,
  'dry-streak-short': /^dry streak \d+ < dryRounds \d+$/,
  'dry-streak-strategies': /^dry streak used \d+ distinct strateg(y|ies); \d+ required$/,
  'no-productive-round': /^no productive round preceded the dry streak$/,
  'claim-mismatch': /^claim_mismatch in round\(s\) /,
  'witness-command-round': /^runner witness ran a different command in round\(s\) /,
  'final-witness-exit': /^final runner witness exit -?\d+$/,
  'final-witness-malformed': /^final runner witness report malformed$/,
  'final-witness-command': /^final runner witness ran a different command$/,
  'verifier-malformed': /^verifier output missing required fields /,
  'verifier-verdict': /^verifier verdict (not_converged|cannot_verify)$/,
  'verifier-own-exit': /^verifier's own runner exit -?\d+$/,
  'vacuous-assertions': /^\d+ vacuous assertion\(s\)$/,
  'retrace-malformed': /^retrace output missing findings$/,
  'retrace-new-silent': /^retrace found \d+ new right-answer-wrong-execution finding\(s\)$/,
  'original-silent-open': /^\d+ original right-answer-wrong-execution finding\(s\) still open$/,
  'original-open': /^\d+ original execution finding\(s\) still open$/,
}
const STOPPED_FORMS = {
  incomplete: /^incomplete — roles died: /,
  converged: /^converged \(dry rounds, witnessed, verified\)$/,
  'max-rounds': /^hit maxRounds — NOT converged$/,
  'not-converged': /^NOT converged — /,
}
const ARG_OUTCOMES = ['no-args', 'missing-target', 'missing-runner', 'relative-target', 'unknown-args', 'bad-args',
  'bad-models', 'bad-rounds', 'bad-dry-rounds', 'throws', 'dry-run']
const ROUND_JUDGMENTS = ['exhausted', 'not-exhausted', 'repeated', 'blind', 'mismatch', 'witnessFault', 'clean', 'not-clean']

const failures = []
const hit = { blocker: new Set(), stopped: new Set(), args: new Set(), round: new Set() }
const check = (id, fn) => {
  try { fn() } catch (e) { failures.push(`${id}: ${e.message.split('\n').slice(0, 12).join('\n    ')}`) }
}
const kindOf = (b) => Object.entries(BLOCKER_KINDS).filter(([, re]) => re.test(b)).map(([k]) => k)

for (const c of fx.convergence) {
  check(`convergence/${c.id}`, () => {
    const got = core.computeConvergence(structuredClone(c.state))
    const pick = { converged: got.converged, blockers: got.blockers, stopped_because: got.stopped_because,
      not_converged_reasons: got.not_converged_reasons, dead_roles: got.dead_roles }
    assert.deepStrictEqual(pick, c.expected)
  })
  for (const b of c.expected.blockers) {
    const kinds = kindOf(b)
    if (kinds.length !== 1) failures.push(`convergence/${c.id}: blocker ${JSON.stringify(b)} matches ${kinds.length} known kinds (want exactly 1)`)
    kinds.forEach((k) => hit.blocker.add(k))
  }
  for (const [form, re] of Object.entries(STOPPED_FORMS)) if (re.test(c.expected.stopped_because)) hit.stopped.add(form)
}

for (const c of fx.rounds) {
  check(`rounds/${c.id}`, () => {
    assert.deepStrictEqual(core.assessRound(structuredClone(c.input)), c.expected)
  })
  const e = c.expected
  hit.round.add(e.exhausted ? 'exhausted' : 'not-exhausted')
  hit.round.add(e.clean ? 'clean' : 'not-clean')
  if (e.repeated) hit.round.add('repeated')
  if (e.blind) hit.round.add('blind')
  if (e.mismatch) hit.round.add('mismatch')
  if (e.witnessFault) hit.round.add('witnessFault')
}

for (const c of fx.validate_args) {
  const args = structuredClone(c.args)   // exactly what the harness passed (raw: as-is, JSON null included)
  const exp = c.expected
  check(`validate_args/${c.id}`, () => {
    if ('throws' in exp) {
      assert.throws(() => core.validateArgs(args), (e) => e instanceof Error && e.message === exp.throws)
      return
    }
    const v = core.validateArgs(args)
    if (exp.ok) {
      assert.equal(v.ok, true, `expected accepted args, got ${JSON.stringify(v)}`)
      assert.deepStrictEqual(core.dryRunResult(v.config), exp.dry_run)
    } else {
      assert.deepStrictEqual(v, { ok: false, reason: exp.reason, next: exp.next, log: exp.log })
    }
  })
  hit.args.add('throws' in exp ? 'throws' : exp.ok ? 'dry-run' : exp.reason)
}

const missing = (want, got, what) => want.filter((k) => !got.has(k)).forEach((k) => failures.push(`coverage: no fixture exercises ${what} '${k}'`))
missing(Object.keys(BLOCKER_KINDS), hit.blocker, 'blocker kind')
missing(Object.keys(STOPPED_FORMS), hit.stopped, 'stopped_because form')
missing(ARG_OUTCOMES, hit.args, 'validateArgs outcome')
missing(ROUND_JUDGMENTS, hit.round, 'round judgment')

const total = fx.convergence.length + fx.rounds.length + fx.validate_args.length
if (failures.length) {
  console.error(`gauntlet fixtures: ${failures.length} failure(s) across ${total} cases`)
  for (const f of failures) console.error(`  FAIL ${f}`)
  process.exit(1)
}
console.log(`gauntlet fixtures: ${total} cases green (convergence ${fx.convergence.length}, rounds ${fx.rounds.length}, ` +
  `validate_args ${fx.validate_args.length}); coverage: ${hit.blocker.size}/${Object.keys(BLOCKER_KINDS).length} blocker kinds, ` +
  `${hit.stopped.size}/4 stopped forms, ${hit.args.size}/${ARG_OUTCOMES.length} arg outcomes, ${hit.round.size}/${ROUND_JUDGMENTS.length} round judgments` +
  ` — derived from ${fx.derived_from.ref} (${fx.derived_from.blob_sha.slice(0, 7)})`)
