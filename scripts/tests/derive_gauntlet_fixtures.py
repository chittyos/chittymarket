#!/usr/bin/env python3
"""Derive canonical/workflows/gauntlet.fixtures.json from the PRE-REFACTOR gauntlet.

The golden fixtures must encode what the gauntlet actually did before its logic moved into
gauntlet.core.js, not anyone's reading of it. So the expected values come from running the
script as it stood at --from-ref (default PINNED_REF = 8190213, origin/main before the core extraction)
through the simulation harness in scripts/tests/test_dispatch_workflow.py (HARNESS: real
script, canned role outputs, agent() throws when no fake is supplied).

The blob is instrumented with capture-only lines (they write to globalThis and change no
logic) at three points:
  - after the verifier's alive() check: the convergence INPUT state
  - after the last blocker push: the blockers array
  - at the end of each fix round: that round's inputs and its judgment
The script's own return value supplies converged / stopped_because / not_converged_reasons /
dead_roles. validateArgs cases need no instrumentation: the early return, the dry-run return,
the first log line, or the thrown message is the expectation.

One blocker ("no productive round preceded the dry streak") cannot be reached from the
orchestration (round 1 never counts dry, so round - dry >= 1 always). Its fixtures are marked
synthetic: their state is hand-built, but their expected value is still computed by the
pre-refactor convergence code, sliced verbatim from the same blob and evaluated on that state.

Usage:  python3 scripts/tests/derive_gauntlet_fixtures.py [--from-ref REF] [--check]
  --check  regenerate in memory and exit 1 if the committed fixtures differ.
"""
import argparse
import json
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts/tests"))
import test_dispatch_workflow as T  # noqa: E402  (HARNESS, node_wrapped, NODE)

PATH = "plugins/chittyos-core/workflows/gauntlet.js"
OUT = ROOT / "canonical/workflows/gauntlet.fixtures.json"
# origin/main immediately before the core extraction (chittyos-core 1.2.1, PR #157).
PINNED_REF = "81902136ed7c27e99f73517ff43cda8454594185"

TOKEN = "sk-live-do-not-echo-0123456789"
TARGET = "/srv/chittyentity/src/gate.ts"
RUNNER = f"cd /srv && TOKEN={TOKEN} npx tsx sim.ts"


def real(**kw):
    d = {"target": TARGET, "runner": RUNNER}
    d.update(kw)
    return d


def dry(**kw):
    return real(**{"dryRun": True, **kw})


GOOD_V = {"verdict": "converged", "runner_exit_code": 0, "runner_output_tail": "42 passed", "cases_executed": 42,
          "vacuous_assertions": [], "unaddressed_trace_findings": [], "remaining_gaps": [], "report": "r"}
SILENT = {"axis": "logic", "title": "short-circuit", "file": "src/gate.ts", "line": 40, "observed": "o",
          "should_be": "s", "outcome_still_correct": True}
LOUD = {**SILENT, "title": "redundant call", "outcome_still_correct": False}

# (id, fake, args). Every fake knob is the harness's own (see HARNESS in test_dispatch_workflow.py).
LOOP = [
    ("converged", {}, real()),
    ("converged-after-repeats", {"strategies": ["boundary", "metamorphic", "Metamorphic ", "metamorphic", "adversarial", "differential"]}, real()),
    ("fabricated-pass-every-round", {"witnessExit": 1}, real()),
    ("late-claim-mismatch", {"witnessExit": {"witness-2": 1}}, real()),
    ("still-failing-but-green", {"stillFailing": ["case-7"]}, real(maxRounds=3)),
    ("final-witness-exit-2", {"witnessExit": {"witness-final": 2}}, real()),
    ("witness-different-command", {"witnessCommand": "true"}, real()),
    ("final-witness-different-command-only", {"override": {"witness-final": {"exit_code": 0, "output_tail": "42 passed", "command": "true", "cases_executed": 42}}}, real()),
    ("final-witness-malformed", {"override": {"witness-final": {"exit_code": "0", "output_tail": "42 passed", "command": RUNNER, "cases_executed": 42}}}, real()),
    ("verifier-free-text", {"verify": "ok"}, real()),
    ("verifier-missing-fields", {"verify": {"verdict": "converged"}}, real()),
    ("verifier-verdict-not-converged", {"verify": {**GOOD_V, "verdict": "not_converged"}}, real()),
    ("verifier-verdict-cannot-verify", {"verify": {**GOOD_V, "verdict": "cannot_verify"}}, real()),
    ("verifier-own-exit-1", {"verify": {**GOOD_V, "runner_exit_code": 1}}, real()),
    ("verifier-vacuous", {"verify": {**GOOD_V, "vacuous_assertions": ["case-3 passes with check deleted"]}}, real()),
    ("verifier-arrays-malformed", {"verify": {**GOOD_V, "vacuous_assertions": None}}, real()),
    ("smoke-maxrounds-1", {}, real(maxRounds=1)),
    ("smoke-dryrounds-1", {}, real(dryRounds=1)),
    ("smoke-maxrounds-2", {}, real(maxRounds=2)),
    ("all-strategies-repeated", {"strategies": ["boundary"] * 6}, real()),
    ("high-yield-max-rounds", {"yield": "high"}, real(maxRounds=3)),
    ("anything-new-max-rounds", {"anythingNew": True}, real(maxRounds=3)),
    ("retrace-new-silent", {"retrace": [{**SILENT, "original_index": -1}]}, real()),
    ("retrace-new-loud-only", {"retrace": [{**LOUD, "original_index": -1}]}, real()),
    ("retrace-original-silent-open", {"trace": [SILENT], "retrace": [{**SILENT, "original_index": 0}]}, real()),
    ("retrace-original-loud-open", {"trace": [LOUD], "retrace": [{**LOUD, "original_index": 0}]}, real()),
    ("retrace-findings-not-array", {"override": {"retrace": {"findings": "none"}}}, real()),
    ("retrace-findings-null-item", {"retrace": [None]}, real()),
    ("dead-retrace", {"dead": ["retrace"]}, real()),
    ("dead-final-witness", {"dead": ["witness-final"]}, real()),
    ("dead-verifier", {"dead": ["verify"]}, real()),
    ("dead-implementer-round-2", {"yield": "high", "dead": ["fix-2"]}, real()),
    ("dead-witness-round-1", {"dead": ["witness-1"]}, real()),
    ("dead-feeder-round-1", {"dead": ["feed-1"]}, real(dryRounds=1)),
    ("dead-feeder-round-3", {"yield": "high", "dead": ["feed-3"]}, real()),
    ("dead-contester-and-mandate", {"dead": ["contest", "mandates"]}, real()),
    ("dead-generator", {"dead": ["generate"]}, real()),
    ("blind-round-2", {"witnessCases": {"witness-2": 0}}, real()),
    ("blind-every-round", {"witnessCases": 0}, real()),
    ("unknown-count-round-3", {"witnessCases": {"witness-3": -1}}, real(maxRounds=4)),
    ("final-witness-zero-cases", {"witnessCases": {"witness-final": 0}}, real()),
    ("final-witness-unknown-cases", {"witnessCases": {"witness-final": -1}}, real()),
    ("verifier-zero-cases", {"verify": {**GOOD_V, "cases_executed": 0}}, real()),
    ("verifier-unknown-cases", {"verify": {**GOOD_V, "cases_executed": -1}}, real()),
    ("case-count-disagreement", {"verify": {**GOOD_V, "cases_executed": 40}}, real()),
    ("witness-count-negative-2", {"witnessCases": {"witness-1": -2}}, real()),
    ("witness-count-fractional", {"witnessCases": {"witness-1": 1.5}}, real()),
    ("implementer-still-failing-null", {"override": {"fix-2": {"runner_output": "x", "changes_made": [], "cases_added": [], "still_failing": None, "anything_new": False}}}, real()),
    ("feeder-cases-null", {"override": {"feed-1": {"strategy": "boundary", "gap_targeted": "g", "expected_yield": "low", "cases": None}}}, real()),
    ("challenge-malformed", {"override": {"trace": {"findings": "none found"}, "mandates": {"mandates": [None]}}}, real()),
    ("olmec-oracle-converged", {}, real(oracleAuthor="olmec")),
]

# validateArgs: (id, args, raw). raw=True passes args to the script exactly as given (string, null, ...).
ARGS = [
    ("no-args-null", None, True),
    ("no-args-empty-string", "", True),
    ("no-args-whitespace-string", "   ", True),
    ("no-args-empty-object", {}, False),
    ("missing-target", {"runner": "x"}, False),
    ("missing-target-blank", {"target": "  ", "runner": "x"}, False),
    ("missing-runner-json-string", json.dumps({"target": "/t"}), True),
    ("missing-runner-number", {"target": "/t", "runner": 5}, False),
    ("relative-target", dry(target="src/gate.ts"), False),
    ("relative-target-tilde", dry(target="~/gate.ts"), False),
    ("unknown-args-typo-dryrun", real(dryrun=True), False),
    ("unknown-args-two", dry(dry_run=True, rounds=3), False),
    ("bad-args-files-string", dry(files="src/a.ts"), False),
    ("bad-args-invariants-mixed", dry(invariants=["ok", 1]), False),
    ("bad-args-corpus-number", dry(corpus=5), False),
    ("bad-args-sameauthor-string", dry(sameAuthor="no"), False),
    ("bad-args-oracle-author-case", dry(oracleAuthor="Olmec"), False),
    ("bad-args-several", dry(files="a", what=1, sameAuthor="no", oracleAuthor="me"), False),
    ("bad-models-not-object", dry(models=["opus"]), False),
    ("bad-models-null", dry(models=None), False),
    ("bad-models-unknown-role", dry(models={"nonsense": "opus"}), False),
    ("bad-models-judgment-downgrade", dry(models={"verifier": "sonnet"}), False),
    ("bad-models-two-entries", dry(models={"tracer": "haiku", "generator": "fable"}), False),
    ("bad-rounds-zero", dry(maxRounds=0), False),
    ("bad-rounds-over-ceiling", dry(maxRounds=13), False),
    ("bad-rounds-string", dry(maxRounds="6"), False),
    ("bad-rounds-fractional", dry(maxRounds=2.5), False),
    ("bad-dry-rounds-zero", dry(dryRounds=0), False),
    ("bad-dry-rounds-over-default-max", dry(dryRounds=7), False),
    ("bad-dry-rounds-over-max", dry(maxRounds=3, dryRounds=4), False),
    # precedence: the FIRST violation in check order wins
    ("precedence-relative-before-unknown", dry(target="rel", bogus=1), False),
    ("precedence-unknown-before-bad-args", dry(files="a", bogus=1), False),
    ("precedence-bad-args-before-models", dry(files="a", models={"verifier": "haiku"}), False),
    ("precedence-models-before-rounds", dry(models={"verifier": "haiku"}, maxRounds=99), False),
    ("precedence-rounds-before-dry-rounds", dry(maxRounds=0, dryRounds=0), False),
    ("precedence-missing-target-before-runner", {"target": 1}, False),
    # throws
    ("throws-malformed-json", '{"target": "/t", "runner": "' + TOKEN + '"', True),
    ("throws-json-prefix-leak", "TOKEN=" + TOKEN + " npx tsx sim.ts", True),
    ("throws-array", [1, 2], True),
    ("throws-json-array", "[1,2]", True),
    ("throws-number", 42, True),
    ("throws-json-null", "null", True),
    # accepted: the dry-run return is the expectation
    ("ok-default", dry(), False),
    ("ok-string-args", json.dumps(dry()), True),
    ("ok-maxrounds-3-models", dry(maxRounds=3, models={"generator": "opus", "verifier": "fable"}), False),
    ("ok-olmec-files-invariants", dry(oracleAuthor="olmec", files=["src/gate.ts", "fixtures/cases.json"],
                                      invariants=["a rejected document never reaches storage"]), False),
    ("ok-ceiling", dry(maxRounds=12), False),
    ("ok-smoke-maxrounds-1", dry(maxRounds=1), False),
    ("ok-smoke-dryrounds-1", dry(dryRounds=1), False),
    ("ok-smoke-maxrounds-2", dry(maxRounds=2), False),
    ("ok-typecheck-empty", dry(typecheck=""), False),
    ("ok-all-keys", dry(typecheck="npx tsc --noEmit", what="a gate", files=["a.ts"], corpus="c.json", invariants=["i"],
                        probes=["p"], rules=["r"], knownFailures=["k1", "k2"], sameAuthor=False, oracleAuthor="independent",
                        maxRounds=4, dryRounds=3, models={"witness": "opus"}), False),
    ("ok-truthy-dryrun-string", dry(dryRun="true"), False),
]

# Hand-built states for the one blocker the orchestration cannot reach. Expected values are
# computed by the pre-refactor convergence code (sliced from the blob), never written by hand.
_W = {"exit_code": 0, "output_tail": "42 passed", "command": RUNNER, "cases_executed": 42}
_BASE_STATE = {"RUNNER": RUNNER, "SMOKE_REASON": None, "DRY_ROUNDS": 2, "round": 3, "dry": 2,
               "dryStreak": ["a", "b"], "deadRoles": [], "malformedRoles": [], "blindOracle": [],
               "claimMismatch": [], "witnessFaults": [], "originalFindings": [],
               "finalWitness": _W, "retraced": {"findings": []}, "verification": GOOD_V}
SYNTHETIC = [
    ("synthetic-no-productive-round", "unreachable from the orchestration: round 1 never counts dry, so round - dry >= 1",
     {**_BASE_STATE, "round": 2, "dry": 2}),
    ("synthetic-no-productive-round-with-death", "same, plus a recorded death",
     {**_BASE_STATE, "round": 2, "dry": 2, "deadRoles": ["contester"]}),
]


def instrument(src):
    """Insert capture-only lines. Each anchor must match exactly once."""
    def once(text, anchor, insert, after=True):
        n = text.count(anchor)
        if n != 1:
            sys.exit(f"instrument: anchor matched {n} times: {anchor[:70]!r}")
        return text.replace(anchor, anchor + insert if after else insert + anchor)

    # The snapshot is JSON round-tripped into the fixture, so it must be JSON-LOSSLESS: any undefined
    # (outside the three top-level role outputs, where undefined and null are the same "returned
    # nothing" to every check), NaN, Infinity, -0, function, or non-plain object aborts derivation
    # rather than becoming a silently different fixture input.
    snap = ("\nconst __lossless = (v, at) => { if (v === undefined || typeof v === 'function' || typeof v === 'symbol' || typeof v === 'bigint') throw new Error('lossy capture at ' + at);"
            " if (typeof v === 'number' && (!Number.isFinite(v) || Object.is(v, -0))) throw new Error('lossy number at ' + at);"
            " if (v && typeof v === 'object') { if (!Array.isArray(v) && Object.getPrototypeOf(v) !== Object.prototype) throw new Error('non-plain object at ' + at);"
            " for (const [k, x] of Object.entries(v)) __lossless(x, at + '.' + k) } }\n"
            "const __state = { RUNNER, SMOKE_REASON, DRY_ROUNDS, round, dry, dryStreak, "
            "deadRoles, malformedRoles, blindOracle, claimMismatch, witnessFaults, originalFindings, "
            "finalWitness: finalWitness ?? null, retraced: retraced ?? null, verification: verification ?? null }\n"
            "__lossless(__state, 'state')\n"
            "globalThis.__gx = { state: JSON.parse(JSON.stringify(__state)) }\n")
    src = once(src, "alive(verification, 'verifier')\n", snap)
    src = once(src, "if (unclosedOriginal.length) blockers.push(`${unclosedOriginal.length} original execution finding(s) still open`)\n",
               "globalThis.__gx.blockers = JSON.parse(JSON.stringify(blockers))\n")
    pre = ("  const __n = { wf: witnessFaults.length, bo: blindOracle.length, cm: claimMismatch.length }\n"
           "  const __seen = [...seenStrategies]\n")
    src = once(src, "  if (witness.command.trim() !== RUNNER.trim()) witnessFaults.push", pre, after=False)
    post = ("  ;(globalThis.__rounds ??= []).push(JSON.parse(JSON.stringify({ input: { round, RUNNER, feed, result, witness, seenStrategies: __seen }, "
            "expected: { witnessFault: witnessFaults.length > __n.wf ? witnessFaults.at(-1) : null, "
            "blind: blindOracle.length > __n.bo ? blindOracle.at(-1) : null, claimsClean, "
            "mismatch: claimMismatch.length > __n.cm ? claimMismatch.at(-1) : null, strat, repeated, clean, exhausted } })))\n")
    src = once(src, "  if (exhausted) { dry++; dryStreak.push(strat) } else { dry = 0; dryStreak = [] }\n", post)
    return src


def legacy_converge_module(src):
    """The pre-refactor convergence section, sliced verbatim from the blob, as a function of state."""
    lines = src.split("\n")
    def find(prefix):
        hits = [i for i, l in enumerate(lines) if l.startswith(prefix)]
        if len(hits) != 1:
            sys.exit(f"legacy slice: {prefix!r} matched {len(hits)} times")
        return hits[0]
    a = find("const verificationOk = (v) =>")
    b = find("const converged = deadRoles.length === 0 && blockers.length === 0")
    c = find("  stopped_because: deadRoles.length")
    d = find("  not_converged_reasons: converged ? []")
    wk = find("const witnessOk = (w) =>")
    io = find("const isObjArray = (v) =>")
    body = "\n".join(lines[a:b + 1])
    stopped = "\n".join(lines[c:d + 1]).replace("  stopped_because:", "const stopped_because =", 1)
    stopped = stopped.replace(",\n  not_converged_reasons:", "\nconst not_converged_reasons =", 1).rstrip().rstrip(",")
    assert stopped.count("const ") == 2, stopped
    return f"""
const VERDICTS = ['converged', 'not_converged', 'cannot_verify']
const MIN_DRY_STREAK = 2
{lines[io]}
{lines[wk]}
{lines[wk + 1]}
export function legacyConverge(s) {{
  let {{ RUNNER, SMOKE_REASON, DRY_ROUNDS, round, dry, dryStreak, blindOracle, claimMismatch, witnessFaults,
    originalFindings, finalWitness, retraced, verification }} = s
  const deadRoles = [...s.deadRoles]
  const malformedRoles = [...s.malformedRoles]
  const malformed = (role, why) => {{ deadRoles.push(`${{role}}: malformed (${{why}})`); malformedRoles.push(`${{role}}: ${{why}}`) }}
{body}
{stopped}
  return {{ converged, blockers, stopped_because, not_converged_reasons, dead_roles: deadRoles }}
}}
"""


def run_node(td, files, main):
    for name, text in files.items():
        (Path(td) / name).write_text(text, encoding="utf-8")
    p = subprocess.run([T.NODE, str(Path(td) / main)], capture_output=True, text=True, cwd=td)
    if p.returncode:
        sys.exit(f"node failed:\n{p.stderr[-3000:]}")
    return json.loads(p.stdout)


def derive(ref):
    if not T.NODE:
        sys.exit("node is required")
    src = subprocess.check_output(["git", "-C", str(ROOT), "show", f"{ref}:{PATH}"], text=True)
    blob = subprocess.check_output(["git", "-C", str(ROOT), "rev-parse", f"{ref}:{PATH}"], text=True).strip()
    commit = subprocess.check_output(["git", "-C", str(ROOT), "rev-parse", f"{ref}^{{commit}}"], text=True).strip()

    harness = T.HARNESS.replace(
        "results.push({ ok: true, out, calls })",
        "results.push({ ok: true, out, logs, gx: globalThis.__gx ?? null, rounds: globalThis.__rounds ?? [] }); globalThis.__gx = undefined; globalThis.__rounds = undefined").replace(
        "results.push({ ok: false, error: String(e.message), calls })",
        "results.push({ ok: false, error: String(e.message), logs }); globalThis.__gx = undefined; globalThis.__rounds = undefined")
    assert harness.count("globalThis.__gx = undefined") == 2, "HARNESS shape changed; update derive_gauntlet_fixtures.py"

    with tempfile.TemporaryDirectory() as td:
        cases = [{"args": a, "fake": f} for _, f, a in LOOP] + \
                [{"args": a, **({"raw": True} if raw else {})} for _, a, raw in ARGS]
        (Path(td) / "wf.mjs").write_text(T.node_wrapped(instrument(src)), encoding="utf-8")
        (Path(td) / "h.mjs").write_text(harness, encoding="utf-8")
        p = subprocess.run([T.NODE, str(Path(td) / "h.mjs"), json.dumps(cases)], capture_output=True, text=True, cwd=td)
        if p.returncode:
            sys.exit(f"harness failed:\n{p.stderr[-3000:]}")
        res = json.loads(p.stdout)

        legacy = legacy_converge_module(src)
        runner = ("import { legacyConverge } from './legacy.mjs'\n"
                  f"const states = {json.dumps([s for _, _, s in SYNTHETIC])}\n"
                  "console.log(JSON.stringify(states.map(legacyConverge)))\n")
        syn = run_node(td, {"legacy.mjs": legacy, "syn.mjs": runner}, "syn.mjs")

        # Cross-check: the sliced legacy convergence must agree with the full script on every
        # harness-derived state, or the synthetic expectations cannot be trusted.
        check = ("import { legacyConverge } from './legacy.mjs'\n"
                 f"const states = {json.dumps([r['gx']['state'] for r in res[:len(LOOP)]])}\n"
                 "console.log(JSON.stringify(states.map(legacyConverge)))\n")
        cross = run_node(td, {"chk.mjs": check}, "chk.mjs")

    convergence, rounds, seen_rounds = [], [], set()
    for (cid, fake, args), r, lc in zip(LOOP, res[:len(LOOP)], cross):
        if not r["ok"] or not r["gx"] or "blockers" not in r["gx"]:
            sys.exit(f"{cid}: harness run did not reach convergence: {r}")
        out = r["out"]
        exp = {"converged": out["converged"], "blockers": r["gx"]["blockers"], "stopped_because": out["stopped_because"],
               "not_converged_reasons": out["not_converged_reasons"], "dead_roles": out["dead_roles"]}
        if lc != exp:
            sys.exit(f"{cid}: sliced legacy convergence disagrees with the full script:\n{lc}\n{exp}")
        convergence.append({"id": cid, "provenance": "harness", "source": {"fake": fake, "args": args},
                            "state": r["gx"]["state"], "expected": exp})
        for rd in r["rounds"]:
            key = json.dumps([rd["input"], rd["expected"]], sort_keys=True)
            if key in seen_rounds:          # identical round already recorded by an earlier scenario
                continue
            seen_rounds.add(key)
            rounds.append({"id": f"{cid}/round-{rd['input']['round']}", "provenance": "harness",
                           "input": rd["input"], "expected": rd["expected"]})
    for (cid, why, state), exp in zip(SYNTHETIC, syn):
        convergence.append({"id": cid, "provenance": "synthetic", "why_synthetic": why, "state": state,
                            "expected": exp})

    args_cases = []
    for (cid, args, raw), r in zip(ARGS, res[len(LOOP):]):
        entry = {"id": cid, "args": args, "raw": raw}
        if not r["ok"]:
            entry["expected"] = {"throws": r["error"]}
        elif r["out"].get("reason") == "dry-run":
            entry["expected"] = {"ok": True, "dry_run": {"log": r["logs"][0], "result": r["out"]}}
        else:
            o = r["out"]
            if set(o) != {"started", "reason", "next"} or len(r["logs"]) != 1:
                sys.exit(f"{cid}: unexpected early-return shape {o} logs={r['logs']}")
            entry["expected"] = {"ok": False, "reason": o["reason"], "next": o["next"], "log": r["logs"][0]}
        args_cases.append(entry)

    return {
        "_comment": "GENERATED by scripts/tests/derive_gauntlet_fixtures.py from the pre-refactor gauntlet; "
                    "do not hand-edit. Asserted by scripts/tests/run_gauntlet_fixtures.mjs against gauntlet.core.js.",
        "derived_from": {"ref": ref, "commit": commit, "path": PATH, "blob_sha": blob,
                         "harness": "scripts/tests/test_dispatch_workflow.py HARNESS"},
        "convergence": convergence,
        "rounds": rounds,
        "validate_args": args_cases,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--from-ref", default=PINNED_REF)
    ap.add_argument("--check", action="store_true")
    o = ap.parse_args()
    data = json.dumps(derive(o.from_ref), indent=1, ensure_ascii=False) + "\n"
    if o.check:
        if not OUT.exists() or OUT.read_text(encoding="utf-8") != data:
            print(f"{OUT.relative_to(ROOT)} differs from a fresh derivation at {o.from_ref}", file=sys.stderr)
            return 1
        print(f"{OUT.relative_to(ROOT)} matches a fresh derivation at {o.from_ref}")
        return 0
    OUT.write_text(data, encoding="utf-8")
    print(f"wrote {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
