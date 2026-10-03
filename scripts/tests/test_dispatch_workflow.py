#!/usr/bin/env python3
"""Regression tests for the `workflow` projection kind and the gauntlet workflow.

Everything here runs the real adapter and the real projected script; nothing is
mocked. The gauntlet harness supplies the Workflow host's script globals
(args/agent/parallel/phase/log) and makes agent() throw, so any path that would
dispatch an agent fails the test instead of spending one.

Requires: python3 + PyYAML, node >= 18. Missing node is a failure, not a skip.
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LIB = ROOT / "plugins/chittyagent-dispatch/scripts/lib"
ADAPTER = ROOT / "plugins/chittyagent-dispatch/scripts/adapters/claude-code-workflow.sh"
GAUNTLET = ROOT / "plugins/chittyos-core/workflows/gauntlet.js"
sys.path.insert(0, str(LIB))
from resolve_output import resolve  # noqa: E402

NODE = shutil.which("node")

FM = textwrap.dedent("""\
    ---
    name: probe
    kind: workflow
    description: |
      probe workflow
    plugin: probe-plugin
    runtimes: [claude-code]
    ---
    prose that must not be projected
    """)
SCRIPT = "export const meta = { name: 'probe', description: 'x' }\nconst s = `a \\`\\`\\` b`\nreturn { ok: true }\n"


def run_adapter(canonical_text, existing=None, info=None):
    """Run the real adapter. `existing` pre-seeds the output file; `info` (a dict) receives
    whether the output directory exists afterwards and what else is in it."""
    with tempfile.TemporaryDirectory() as td:
        can = Path(td) / "probe.md"
        out = Path(td) / "out" / "probe.js"
        can.write_text(canonical_text, encoding="utf-8")
        if existing is not None:
            out.parent.mkdir()
            out.write_bytes(existing)
        proc = subprocess.run([str(ADAPTER), str(can), str(out)], capture_output=True, text=True)
        if info is not None:
            info["out_dir_exists"] = out.parent.exists()
            info["out_dir_entries"] = sorted(x.name for x in out.parent.iterdir()) if out.parent.exists() else []
        return proc, (out.read_bytes() if out.exists() else None)


def node_wrapped(script_text):
    """Rewrite the host-only module shape into something node can import."""
    assert script_text.startswith("export const meta"), "workflow must start with export const meta"
    body = "const meta" + script_text[len("export const meta"):]
    return "export default async function (args, agent, parallel, phase, log) {\n" + body + "\n}\n"


class WorkflowKindResolution(unittest.TestCase):
    def test_claude_code_workflow_resolves_to_plugin_workflows_dir(self):
        out, adapter = resolve(str(ROOT), "chittyos-core", "gauntlet", "workflow", "claude-code")
        self.assertEqual(Path(out), ROOT / "plugins/chittyos-core/workflows/gauntlet.js")
        self.assertEqual(Path(adapter), ADAPTER)

    def test_workflow_kind_has_no_other_runtime(self):
        with self.assertRaises(KeyError):
            resolve(str(ROOT), "p", "n", "workflow", "codex")


class WorkflowAdapter(unittest.TestCase):
    def test_single_block_projects_verbatim_and_stably(self):
        text = FM + "\n````js\n" + SCRIPT + "````\n\ntrailing prose\n"
        p1, b1 = run_adapter(text)
        p2, b2 = run_adapter(text)
        self.assertEqual(p1.returncode, 0, p1.stderr)
        self.assertEqual(b1.decode(), SCRIPT)
        self.assertEqual(b1, b2)
        self.assertNotIn(b"prose", b1)

    def test_zero_blocks_rejected(self):
        p, out = run_adapter(FM + "no code here\n")
        self.assertNotEqual(p.returncode, 0)
        self.assertIn("found 0", p.stderr)
        self.assertIsNone(out)

    def test_two_blocks_rejected(self):
        p, out = run_adapter(FM + "````js\n" + SCRIPT + "````\n```javascript\nx\n```\n")
        self.assertNotEqual(p.returncode, 0)
        self.assertIn("found 2", p.stderr)

    def test_non_js_blocks_ignored(self):
        p, out = run_adapter(FM + "```bash\necho hi\n```\n````js\n" + SCRIPT + "````\n")
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(out.decode(), SCRIPT)

    def test_unterminated_fence_rejected(self):
        p, _ = run_adapter(FM + "````js\n" + SCRIPT)
        self.assertNotEqual(p.returncode, 0)
        self.assertIn("unterminated", p.stderr)

    def test_must_start_with_meta(self):
        p, _ = run_adapter(FM + "````js\n// banner\n" + SCRIPT + "````\n")
        self.assertNotEqual(p.returncode, 0)
        self.assertIn("export const meta", p.stderr)

    def test_meta_name_must_match_frontmatter(self):
        p, _ = run_adapter(FM + "````js\n" + SCRIPT.replace("'probe'", "'other'") + "````\n")
        self.assertNotEqual(p.returncode, 0)
        self.assertIn("meta.name", p.stderr)

    def test_wrong_kind_rejected(self):
        p, _ = run_adapter(FM.replace("kind: workflow", "kind: agent") + "````js\n" + SCRIPT + "````\n")
        self.assertNotEqual(p.returncode, 0)

    # M1: a fence-looking line inside a template literal must not truncate the script.
    FENCE_IN_TEMPLATE = (
        "export const meta = { name: 'probe', description: 'x' }\n"
        "const doc = `\n"
        "````\n"
        "inside the template\n"
        "`\n"
        "return { doc }\n"
    )

    def test_fence_line_inside_template_literal_extracts_whole_script(self):
        p, out = run_adapter(FM + "````js\n" + self.FENCE_IN_TEMPLATE + "````\n\nprose after\n")
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(out.decode(), self.FENCE_IN_TEMPLATE)

    def test_later_same_fence_block_with_info_string_rejected(self):
        # A later ```` block would be swallowed by the last-close rule; with an info string it is
        # detectable, so it is rejected structurally before any syntax check.
        text = FM + "````js\n" + SCRIPT + "````\n\nsome prose.\n\n````text\nnot code\n````\n"
        info = {}
        p, out = run_adapter(text, info=info)
        self.assertNotEqual(p.returncode, 0)
        self.assertIn("would be swallowed", p.stderr)
        self.assertIsNone(out)
        self.assertFalse(info["out_dir_exists"], "output dir must not be created before validation")

    def test_misextraction_fails_loudly_and_writes_nothing(self):
        # A later BARE ```` block is not structurally detectable; overrunning into the prose must
        # fail node --check: non-zero exit, no output file, no output dir created.
        text = FM + "````js\n" + SCRIPT + "````\n\nsome prose.\n\n````\nnot code\n````\n"
        info = {}
        p, out = run_adapter(text, info=info)
        self.assertNotEqual(p.returncode, 0)
        self.assertIn("node --check", p.stderr)
        self.assertIsNone(out)
        self.assertFalse(info["out_dir_exists"], "output dir must not be created before validation")

    def test_meta_name_need_not_be_first_key(self):
        script = "export const meta = {\n  description: 'has name: inside a string',\n  phases: [{ name: 'nested' }],\n  name: 'probe',\n}\nreturn 1\n"
        p, out = run_adapter(FM + "````js\n" + script + "````\n")
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(out.decode(), script)

    def test_nested_or_quoted_name_is_not_meta_name(self):
        script = "export const meta = {\n  description: \"name: 'probe'\",\n  phases: [{ name: 'probe' }],\n}\nreturn 1\n"
        p, out = run_adapter(FM + "````js\n" + script + "````\n")
        self.assertNotEqual(p.returncode, 0)
        self.assertIn("meta.name None", p.stderr)
        self.assertIsNone(out)

    def test_failed_projection_leaves_existing_output_untouched(self):
        prior = b"// previous good projection\n"
        info = {}
        p, out = run_adapter(FM + "````js\nexport const meta = { name: 'probe' }\nconst = 1\n````\n",
                             existing=prior, info=info)
        self.assertNotEqual(p.returncode, 0)
        self.assertEqual(out, prior)
        self.assertEqual(info["out_dir_entries"], ["probe.js"], "no temp file may be left behind")

    def test_syntax_error_in_script_rejected(self):
        p, out = run_adapter(FM + "````js\nexport const meta = { name: 'probe' }\nconst = 1\n````\n")
        self.assertNotEqual(p.returncode, 0)
        self.assertIn("node --check", p.stderr)
        self.assertIsNone(out)


class CanonicalNameUniqueAcrossKinds(unittest.TestCase):
    LINT = ROOT / "scripts/lint-plugins.sh"

    def run_lint(self, layout):
        with tempfile.TemporaryDirectory() as td:
            for rel in layout:
                f = Path(td) / rel
                f.parent.mkdir(parents=True, exist_ok=True)
                f.write_text("---\nname: x\n---\n", encoding="utf-8")
            env = dict(os.environ, LINT_CANONICAL_DIR=td)
            return subprocess.run(["bash", str(self.LINT)], capture_output=True, text=True, env=env)

    def test_same_name_under_two_kinds_fails_lint(self):
        p = self.run_lint(["agents/dupe.md", "workflows/dupe.md", "skills/other.md"])
        self.assertNotEqual(p.returncode, 0)
        self.assertIn("canonical name 'dupe' exists under two kinds", p.stdout)

    def test_unique_names_pass_the_check(self):
        p = self.run_lint(["agents/a.md", "workflows/b.md", "README.md"])
        self.assertNotIn("exists under two kinds", p.stdout)
        self.assertEqual(p.returncode, 0, p.stdout[-2000:])


class ProjectedWorkflowsParse(unittest.TestCase):
    def test_node_available(self):
        self.assertIsNotNone(NODE, "node is required to validate workflow scripts")

    def test_every_projected_workflow_parses(self):
        files = sorted(ROOT.glob("plugins/*/workflows/*.js"))
        self.assertGreaterEqual(len(files), 1, "expected at least one projected workflow")
        for f in files:
            with tempfile.TemporaryDirectory() as td:
                mod = Path(td) / "wf.mjs"
                mod.write_text(node_wrapped(f.read_text(encoding="utf-8")), encoding="utf-8")
                p = subprocess.run([NODE, "--check", str(mod)], capture_output=True, text=True)
                self.assertEqual(p.returncode, 0, f"{f}: {p.stderr}")

    def test_wrapper_catches_real_syntax_errors(self):
        # Prove the check above is not vacuous: a broken script must fail it.
        with tempfile.TemporaryDirectory() as td:
            mod = Path(td) / "wf.mjs"
            mod.write_text(node_wrapped("export const meta = { name: 'x' }\nconst = 1\n"), encoding="utf-8")
            p = subprocess.run([NODE, "--check", str(mod)], capture_output=True, text=True)
            self.assertNotEqual(p.returncode, 0)


HARNESS = r"""
import wf from './wf.mjs'
const cases = JSON.parse(process.argv[2])
const results = []
const GOOD_VERDICT = { verdict: 'converged', runner_exit_code: 0, runner_output_tail: '42 passed, 0 failed', vacuous_assertions: [], unaddressed_trace_findings: [], remaining_gaps: [], report: 'checked' }
for (const c of cases) {
  const calls = []
  const logs = []
  // Without c.fake, agent() throws: any path that would dispatch fails the case instead of spending.
  // With c.fake, agent() plays every role with canned, schema-shaped results so the loop runs for real.
  // Knobs: dead (labels returning null), yield, anythingNew, stillFailing (implementer claim),
  // witnessExit (number, or {label: exit}), witnessCommand, strategies ([per round]), verify (raw
  // value returned by the verifier), retrace (findings array). Every call records label/model/prompt.
  const f = c.fake
  const runner = typeof c.args === 'object' && c.args ? c.args.runner : ''
  const agent = async (prompt, opts) => {
    calls.push({ label: opts?.label ?? null, model: opts?.model ?? null, prompt })
    if (!f) throw new Error('agent() dispatched in a test')
    const L = opts?.label ?? ''
    if ((f.dead ?? []).includes(L)) return null
    if (L === 'contest') return { contested: [] }
    if (L === 'generate') return { cases: [] }
    if (L === 'trace') return { findings: f.trace ?? [] }
    if (L === 'mandates') return { mandates: [] }
    if (L.startsWith('feed-')) {
      const n = Number(L.slice(5))
      return { strategy: (f.strategies ?? [])[n - 1] ?? 'strategy ' + L, why_this_strategy: 'w', gap_targeted: 'g', expected_yield: f.yield ?? 'low', cases: [] }
    }
    if (L.startsWith('fix-')) return { runner_output: 'all cases passed', changes_made: [], cases_added: [], still_failing: f.stillFailing ?? [], anything_new: !!f.anythingNew }
    if (L.startsWith('witness-')) {
      const exit = typeof f.witnessExit === 'object' && f.witnessExit ? (f.witnessExit[L] ?? 0) : (f.witnessExit ?? 0)
      return { exit_code: exit, output_tail: exit === 0 ? '42 passed, 0 failed' : '41 passed, 1 failed', command: f.witnessCommand ?? runner }
    }
    if (L === 'retrace') return { findings: f.retrace ?? [] }
    if (L === 'verify') return 'verify' in f ? f.verify : GOOD_VERDICT
    throw new Error('unexpected label ' + L)
  }
  const parallel = async (thunks) => Promise.all(thunks.map((t) => t()))
  const phase = () => {}
  const log = (m) => logs.push(m)
  const args = c.raw ? c.args : (c.stringify ? JSON.stringify(c.args) : c.args)
  try {
    const out = await wf(args, agent, parallel, phase, log)
    results.push({ ok: true, out, calls })
  } catch (e) {
    results.push({ ok: false, error: String(e.message), calls })
  }
}
console.log(JSON.stringify(results))
"""

ALLOWED_MODELS = {"opus", "sonnet", "fable"}
CHALLENGE = ["contest", "generate", "trace", "mandates"]
ROLES = {"contester", "generator", "tracer", "mandate", "feeder", "implementer", "witness", "retrace", "verifier"}


def budget(rounds):
    # 4 challenge + (feeder + implementer + witness) per round + (final witness + retrace + verifier)
    return 4 + 3 * rounds + 3


class GauntletHarness(unittest.TestCase):
    TOKEN = "sk-live-do-not-echo-0123456789"
    TARGET = "/srv/chittyentity/src/gate.ts"

    def run_cases(self, cases):
        self.assertIsNotNone(NODE, "node is required")
        with tempfile.TemporaryDirectory() as td:
            (Path(td) / "wf.mjs").write_text(node_wrapped(GAUNTLET.read_text(encoding="utf-8")), encoding="utf-8")
            (Path(td) / "h.mjs").write_text(HARNESS, encoding="utf-8")
            p = subprocess.run([NODE, str(Path(td) / "h.mjs"), json.dumps(cases)],
                               capture_output=True, text=True, cwd=td)
            self.assertEqual(p.returncode, 0, p.stderr)
            return json.loads(p.stdout)

    def base(self, **extra):
        d = {"target": self.TARGET, "runner": f"cd /srv && TOKEN={self.TOKEN} npx tsx sim.ts", "dryRun": True}
        d.update(extra)
        return d

    def real(self, **extra):
        d = self.base(**extra)
        del d["dryRun"]
        return d

    def assert_models(self, calls):
        self.assertTrue(calls, "expected dispatched calls")
        for c in calls:
            self.assertIn(c["model"], ALLOWED_MODELS, f"{c['label']} dispatched with model {c['model']!r}")
            if c["label"] == "generate" or str(c["label"]).startswith("witness-"):
                continue
            self.assertIn(c["model"], {"opus", "fable"}, f"judgment role {c['label']} on {c['model']!r}")

    def check_early_returns(self, pairs):
        res = self.run_cases([{"args": a, **({"raw": True} if raw else {})} for a, _, raw in pairs])
        for (a, reason, _), r in zip(pairs, res):
            with self.subTest(args=a, want=reason):
                self.assertTrue(r["ok"], r)
                self.assertEqual(r["calls"], [], "an early return must dispatch nothing")
                self.assertIs(r["out"]["started"], False)
                self.assertEqual(r["out"]["reason"], reason)
                self.assertTrue(r["out"]["next"])


class GauntletArgsAndDryRun(GauntletHarness):
    def test_dry_run_object_and_string_args_agree(self):
        r = self.run_cases([{"args": self.base()}, {"args": self.base(), "stringify": True}])
        for res in r:
            self.assertTrue(res["ok"], res)
            self.assertEqual(res["calls"], [])
            out = res["out"]
            self.assertIs(out["started"], False)
            self.assertEqual(out["reason"], "dry-run")
            self.assertEqual(out["config"]["target"], self.TARGET)
            self.assertEqual(out["config"]["agent_budget"]["max"], budget(6))
            self.assertEqual(out["config"]["agent_budget"]["transitive_spawning"], "forbidden")
            self.assertIs(out["config"]["can_converge"], True)
            self.assertIsNone(out["config"]["smoke_run"])
            self.assertNotIn(self.TOKEN, json.dumps(out))
        self.assertEqual(r[0]["out"], r[1]["out"])

    def test_dry_run_reports_explicit_model_for_every_role(self):
        r = self.run_cases([{"args": self.base(maxRounds=3, models={"generator": "opus", "verifier": "fable"})}])[0]
        roles = {x["role"]: x["model"] for x in r["out"]["config"]["roles"]}
        self.assertEqual(set(roles), ROLES)
        self.assertEqual(roles["generator"], "opus")
        self.assertEqual(roles["verifier"], "fable")
        self.assertEqual(roles["witness"], "sonnet")
        self.assertEqual(roles["retrace"], "opus")
        self.assertEqual(r["out"]["config"]["agent_budget"]["max"], budget(3))

    def test_truthy_dry_run_fails_safe(self):
        for v in ("true", 1):
            r = self.run_cases([{"args": self.base(dryRun=v)}])[0]
            self.assertTrue(r["ok"], r)
            self.assertEqual(r["calls"], [])
            self.assertEqual(r["out"]["reason"], "dry-run")

    def test_default_generator_is_sonnet(self):
        r = self.run_cases([{"args": self.base()}])[0]
        roles = {x["role"]: x["model"] for x in r["out"]["config"]["roles"]}
        self.assertEqual(roles["generator"], "sonnet")

    def test_empty_typecheck_means_not_configured(self):
        r = self.run_cases([{"args": self.base(typecheck="")}, {"args": self.base(typecheck="npx tsc --noEmit")}])
        self.assertEqual(r[0]["out"]["reason"], "dry-run")
        self.assertIs(r[0]["out"]["config"]["typecheck_configured"], False)
        self.assertIs(r[1]["out"]["config"]["typecheck_configured"], True)

    def test_round_bounds_accept_edges(self):
        r = self.run_cases([
            {"args": self.base(maxRounds=12)},
            {"args": self.base(maxRounds=1)},             # default dryRounds clamps to maxRounds
            {"args": self.base(maxRounds=3, dryRounds=2)},
        ])
        for res in r:
            self.assertEqual(res["out"]["reason"], "dry-run", res)
        self.assertEqual(r[0]["out"]["config"]["agent_budget"]["max"], budget(12))
        self.assertEqual(r[1]["out"]["config"]["dryRounds"], 1)
        self.assertIs(r[2]["out"]["config"]["can_converge"], True)

    def test_smoke_runs_are_labelled_non_converging_in_dry_run(self):
        r = self.run_cases([
            {"args": self.base(maxRounds=1)},
            {"args": self.base(maxRounds=6, dryRounds=1)},
            {"args": self.base(maxRounds=2)},              # 2 rounds cannot hold baseline + streak of 2
        ])
        for res in r:
            self.assertEqual(res["out"]["reason"], "dry-run", res)
            self.assertIs(res["out"]["config"]["can_converge"], False)
            self.assertIn("smoke run", res["out"]["config"]["smoke_run"])
            self.assertIn("SMOKE", res["out"]["next"])

    def test_early_returns_do_not_dispatch(self):
        self.check_early_returns([
            (None, "no-args", True),
            ("", "no-args", True),
            ({}, "no-args", False),
            ({"runner": "x"}, "missing-target", False),
            (json.dumps({"target": "/t"}), "missing-runner", True),
            (self.base(models={"nonsense": "opus"}), "bad-models", False),
            (self.base(models={"tracer": ""}), "bad-models", False),
        ])

    def test_model_allow_list_rejects_downgrades(self):
        cases = [(self.base(models={r: m}), "bad-models", False)
                 for r in ("contester", "tracer", "mandate", "feeder", "implementer", "verifier", "retrace")
                 for m in ("sonnet", "haiku", "some-cheap-model")]
        cases += [(self.base(models={r: m}), "bad-models", False)
                  for r in ("generator", "witness") for m in ("haiku", "fable", "x")]
        cases += [(self.real(models={"verifier": "haiku"}), "bad-models", False)]
        self.check_early_returns(cases)
        ok = self.run_cases([{"args": self.base(models={"witness": "opus", "generator": "sonnet", "verifier": "fable"})}])[0]
        self.assertEqual(ok["out"]["reason"], "dry-run")

    def test_round_bounds_rejected_even_under_dry_run(self):
        self.check_early_returns([
            (self.base(maxRounds=0), "bad-rounds", False),
            (self.base(maxRounds=-1), "bad-rounds", False),
            (self.base(maxRounds=13), "bad-rounds", False),
            (self.base(maxRounds=10 ** 9), "bad-rounds", False),
            (self.base(maxRounds="6"), "bad-rounds", False),
            (self.base(maxRounds=2.5), "bad-rounds", False),
            (self.base(dryRounds=0), "bad-dry-rounds", False),
            (self.base(dryRounds=7), "bad-dry-rounds", False),          # > default maxRounds 6
            (self.base(maxRounds=3, dryRounds=4), "bad-dry-rounds", False),
            (self.base(dryRounds="2"), "bad-dry-rounds", False),
        ])

    def test_wrong_typed_args_rejected_with_zero_dispatch(self):
        cases = []
        for k in ("files", "invariants", "probes", "rules", "knownFailures"):
            cases += [(self.base(**{k: "src/a.ts"}), "bad-args", False),
                      (self.base(**{k: ["ok", 1]}), "bad-args", False),
                      (self.base(**{k: {"0": "x"}}), "bad-args", False)]
        for k in ("corpus", "what", "typecheck"):
            cases += [(self.base(**{k: 5}), "bad-args", False),
                      (self.base(**{k: ["x"]}), "bad-args", False)]
        cases.append((self.base(sameAuthor="no"), "bad-args", False))
        self.check_early_returns(cases)
        # and the same wrong types without dryRun must not dispatch either
        self.check_early_returns([(self.real(files="src/a.ts"), "bad-args", False),
                                  (self.real(maxRounds=100), "bad-rounds", False)])

    def test_oracle_author_validated(self):
        self.check_early_returns([
            (self.base(oracleAuthor="Olmec"), "bad-args", False),
            (self.base(oracleAuthor="implementer"), "bad-args", False),
            (self.base(oracleAuthor=True), "bad-args", False),
            (self.real(oracleAuthor="me"), "bad-args", False),
        ])
        r = self.run_cases([{"args": self.base(oracleAuthor="olmec")}, {"args": self.base(oracleAuthor="independent")}])
        self.assertEqual(r[0]["out"]["config"]["oracleAuthor"], "olmec")
        self.assertEqual(r[1]["out"]["config"]["oracleAuthor"], "independent")

    def test_relative_target_rejected(self):
        self.check_early_returns([
            (self.base(target="src/gate.ts"), "relative-target", False),
            (self.base(target="./gate.ts"), "relative-target", False),
            (self.base(target="~/gate.ts"), "relative-target", False),
        ])

    def test_unknown_keys_rejected_so_a_typo_cannot_launch(self):
        a = self.real(dryrun=True)          # misspelled dryRun
        self.check_early_returns([(a, "unknown-args", False)])

    def test_malformed_and_non_object_args_throw_without_echo(self):
        bad_json = '{"target": "/t", "runner": "' + self.TOKEN + '"'
        prefix_leak = "TOKEN=" + self.TOKEN + " npx tsx sim.ts"     # V8 echoes an input PREFIX
        r = self.run_cases([
            {"args": bad_json, "raw": True},
            {"args": prefix_leak, "raw": True},
            {"args": [1, 2], "raw": True},
            {"args": "[1,2]", "raw": True},
            {"args": 42, "raw": True},
        ])
        for res in r:
            self.assertFalse(res["ok"], res)
            self.assertEqual(res["calls"], [])
            self.assertNotIn(self.TOKEN, res["error"])
            self.assertNotIn("TOKEN=", res["error"])
        for res in r[:2]:
            self.assertIn("not valid JSON", res["error"])
            self.assertNotIn("Unexpected", res["error"])   # no V8 message at all
        self.assertIn(f"{len(prefix_leak)} bytes", r[1]["error"])
        self.assertIn("got array", r[2]["error"])
        self.assertIn("got array", r[3]["error"])
        self.assertIn("got number", r[4]["error"])

    def test_real_run_without_dry_run_dispatches_the_challenge_phase(self):
        # agent() throws here; the four challenge roles are dispatched together, then parallel() rejects.
        # Proves dryRun is the only thing standing between valid args and spend.
        r = self.run_cases([{"args": self.real()}])[0]
        self.assertFalse(r["ok"])
        self.assertEqual(sorted(c["label"] for c in r["calls"]), sorted(CHALLENGE))
        self.assert_models(r["calls"])

    def test_every_prompt_forbids_subagent_spawning(self):
        r = self.run_cases([{"args": self.real(), "fake": {}}])[0]
        self.assertTrue(r["ok"], r)
        for c in r["calls"]:
            self.assertIn("Do NOT spawn subagents and do NOT use the Agent or Workflow tools", c["prompt"], c["label"])


class GauntletLoop(GauntletHarness):
    """Drives the real fix loop with canned role results and checks the outcome and exact spend."""

    def run_one(self, fake, **args):
        r = self.run_cases([{"args": self.real(**args), "fake": fake}])[0]
        self.assertTrue(r["ok"], r)
        self.assert_models(r["calls"])
        return r["out"], r["calls"]

    def labels(self, calls):
        return [c["label"] for c in calls]

    def assert_not_converged(self, out, needle=None):
        self.assertIs(out["converged"], False)
        self.assertNotIn("converged (", out["stopped_because"])
        self.assertTrue(out["not_converged_reasons"])
        if needle:
            self.assertTrue(any(needle in x for x in out["not_converged_reasons"]), out["not_converged_reasons"])

    def test_converged_path(self):
        out, calls = self.run_one({})
        self.assertEqual(out["stopped_because"], "converged (dry rounds, witnessed, verified)")
        self.assertIs(out["converged"], True)
        self.assertEqual(out["not_converged_reasons"], [])
        self.assertEqual(out["dead_roles"], [])
        self.assertEqual(out["claim_mismatch"], [])
        self.assertEqual(out["rounds"], 3)                   # round 1 is the baseline, then 2 dry
        self.assertEqual(len(calls), budget(3))
        self.assertEqual(self.labels(calls)[4:], [
            "feed-1", "fix-1", "witness-1", "feed-2", "fix-2", "witness-2", "feed-3", "fix-3", "witness-3",
            "witness-final", "retrace", "verify"])
        self.assertEqual(out["contested_expectations"], [])     # ran and found nothing, not null
        self.assertEqual([w["exit_code"] for w in out["runner_witness"]], [0, 0, 0])

    def test_witness_prompt_is_gathering_only(self):
        _, calls = self.run_one({})
        p = next(c["prompt"] for c in calls if c["label"] == "witness-1")
        self.assertIn("FORBIDDEN: editing", p)
        self.assertIn("Run exactly this command, byte for byte", p)
        self.assertEqual(next(c["model"] for c in calls if c["label"] == "witness-1"), "sonnet")

    def test_fabricated_implementer_pass_contradicted_by_witness(self):
        out, calls = self.run_one({"witnessExit": 1})          # implementer says nothing failing
        self.assert_not_converged(out, "claim_mismatch")
        self.assertEqual([m["round"] for m in out["claim_mismatch"]], list(range(1, 7)))
        self.assertEqual(out["claim_mismatch"][0]["witness_exit_code"], 1)
        self.assertEqual(out["stopped_because"], "hit maxRounds — NOT converged")
        self.assertEqual(len(calls), budget(6))

    def test_single_late_mismatch_still_blocks(self):
        out, _ = self.run_one({"witnessExit": {"witness-2": 1}})
        self.assert_not_converged(out, "claim_mismatch in round(s) 2")

    def test_implementer_still_failing_but_runner_green_is_a_mismatch(self):
        out, _ = self.run_one({"stillFailing": ["case-7"]}, maxRounds=3)
        self.assertEqual([m["round"] for m in out["claim_mismatch"]], [1, 2, 3])
        self.assert_not_converged(out)

    def test_final_witness_failure_blocks(self):
        out, _ = self.run_one({"witnessExit": {"witness-final": 2}})
        self.assert_not_converged(out, "final runner witness exit 2")

    def test_witness_running_a_different_command_blocks(self):
        out, _ = self.run_one({"witnessCommand": "true"})
        self.assert_not_converged(out, "different command")

    def test_verifier_free_text_is_not_a_verification(self):
        for v in ("ok", {"verdict": "converged"}, {"verdict": "converged", "runner_exit_code": "0", "runner_output_tail": "",
                                                    "vacuous_assertions": [], "unaddressed_trace_findings": []}):
            with self.subTest(verify=v):
                out, _ = self.run_one({"verify": v})
                self.assert_not_converged(out, "verifier output missing required fields")

    def test_verifier_verdict_and_own_exit_gate_convergence(self):
        base = {"verdict": "converged", "runner_exit_code": 0, "runner_output_tail": "x", "vacuous_assertions": [],
                "unaddressed_trace_findings": [], "remaining_gaps": [], "report": "r"}
        for patch, needle in (({"verdict": "not_converged"}, "verifier verdict not_converged"),
                              ({"verdict": "cannot_verify"}, "verifier verdict cannot_verify"),
                              ({"runner_exit_code": 1}, "verifier's own runner exit 1"),
                              ({"vacuous_assertions": ["case-3 passes with check deleted"]}, "vacuous")):
            with self.subTest(patch=patch):
                out, _ = self.run_one({"verify": {**base, **patch}})
                self.assert_not_converged(out, needle)

    def test_max_rounds_one_never_converges(self):
        out, calls = self.run_one({}, maxRounds=1)
        self.assert_not_converged(out, "smoke run")
        self.assertEqual(len(calls), budget(1))

    def test_dry_rounds_one_never_converges(self):
        out, calls = self.run_one({}, dryRounds=1)
        self.assertEqual(out["rounds"], 2)                   # stops after one counted dry round
        self.assert_not_converged(out, "smoke run")
        self.assertTrue(out["stopped_because"].startswith("NOT converged"), out["stopped_because"])

    def test_round_one_never_counts_toward_dry(self):
        out, _ = self.run_one({}, maxRounds=2)              # rounds 1 (baseline) + 2 (dry 1)
        self.assert_not_converged(out)
        self.assertEqual(out["stopped_because"], "hit maxRounds — NOT converged")

    def test_repeated_strategy_does_not_count_toward_dry(self):
        out, calls = self.run_one({"strategies": ["boundary", "metamorphic", "Metamorphic ", "metamorphic", "adversarial", "differential"]})
        self.assertEqual([r["round"] for r in out["repeated_strategies"]], [3, 4])
        # rounds 3 and 4 reset the streak; 5 and 6 are the first two distinct dry rounds after them
        self.assertEqual(out["rounds"], 6)
        self.assertIs(out["converged"], True)
        self.assertEqual(len(calls), budget(6))

    def test_all_strategies_repeated_never_converges(self):
        out, _ = self.run_one({"strategies": ["boundary"] * 6})
        self.assertEqual(len(out["repeated_strategies"]), 5)
        self.assert_not_converged(out, "dry streak 0")

    def test_high_yield_feeder_blocks_convergence_until_max_rounds(self):
        out, calls = self.run_one({"yield": "high"}, maxRounds=3)
        self.assertEqual(out["stopped_because"], "hit maxRounds — NOT converged")
        self.assertIs(out["converged"], False)
        self.assertEqual(out["dead_roles"], [])
        self.assertEqual(len(calls), budget(3))

    def test_max_rounds_exhausted(self):
        out, calls = self.run_one({"anythingNew": True}, maxRounds=3)
        self.assertEqual(out["stopped_because"], "hit maxRounds — NOT converged")
        self.assertEqual(out["rounds"], 3)
        self.assertEqual(len(calls), budget(3))

    def test_retrace_new_silent_finding_blocks(self):
        f = {"axis": "logic", "title": "short-circuit", "file": "src/gate.ts", "line": 40, "observed": "o",
             "should_be": "s", "outcome_still_correct": True, "original_index": -1}
        out, calls = self.run_one({"retrace": [f]})
        self.assert_not_converged(out, "new right-answer-wrong-execution")
        self.assertEqual(len(out["retrace"]["new_right_answer_wrong_execution"]), 1)
        p = next(c["prompt"] for c in calls if c["label"] == "retrace")
        self.assertIn("You are the TRACER", p)
        self.assertIn("THIS IS A RE-TRACE", p)

    def test_retrace_unclosed_original_blocks(self):
        orig = {"axis": "order", "title": "guard after use", "file": "src/gate.ts", "line": 12, "observed": "o",
                "should_be": "s", "outcome_still_correct": True}
        out, _ = self.run_one({"trace": [orig], "retrace": [{**orig, "original_index": 0}]})
        self.assert_not_converged(out, "original right-answer-wrong-execution finding(s) still open")

    def test_retrace_death_blocks(self):
        out, _ = self.run_one({"dead": ["retrace"]})
        self.assertIn("retrace", out["dead_roles"])
        self.assert_not_converged(out)

    def test_implementer_death_stops_loop_and_is_reported(self):
        out, calls = self.run_one({"yield": "high", "dead": ["fix-2"]})
        self.assertEqual(out["dead_roles"], ["implementer (round 2)"])
        self.assertTrue(out["stopped_because"].startswith("incomplete"), out["stopped_because"])
        self.assertIn("implementer (round 2)", out["stopped_because"])
        self.assertIs(out["converged"], False)
        self.assertEqual(len(calls), 4 + 3 + 2 + 3)          # round 1 full, feed-2 + dead fix-2, converge
        self.assertEqual(self.labels(calls)[-1], "verify")

    def test_witness_death_stops_loop(self):
        out, calls = self.run_one({"dead": ["witness-1"]})
        self.assertEqual(out["dead_roles"], ["witness (round 1)"])
        self.assertEqual(len(calls), 4 + 3 + 3)
        self.assert_not_converged(out)

    def test_feeder_death_stops_loop_without_counting_as_low_yield(self):
        # dryRounds=1 + yield low: had the dead feeder counted as low-yield, the loop would stop 'dry'.
        out, calls = self.run_one({"dead": ["feed-1"]}, dryRounds=1)
        self.assertEqual(out["dead_roles"], ["feeder (round 1)"])
        self.assertTrue(out["stopped_because"].startswith("incomplete"), out["stopped_because"])
        self.assertIs(out["converged"], False)
        self.assertNotIn("fix-1", self.labels(calls), "implementer must not run on a dead feed")
        self.assertEqual(len(calls), 4 + 1 + 3)              # challenge + dead feeder + converge
        self.assertEqual(out["strategies"], [])

    def test_feeder_death_mid_run(self):
        out, calls = self.run_one({"yield": "high", "dead": ["feed-3"]})
        self.assertEqual(out["dead_roles"], ["feeder (round 3)"])
        self.assertEqual(len(calls), 4 + 3 * 2 + 1 + 3)

    def test_challenge_death_is_not_run_not_empty(self):
        out, calls = self.run_one({"dead": ["contest", "mandates"]})
        self.assertEqual(out["dead_roles"], ["contester", "mandate"])
        # The loop itself came back dry, and that must still not read as converged.
        self.assertTrue(out["stopped_because"].startswith("incomplete"), out["stopped_because"])
        self.assertIs(out["converged"], False)
        self.assertIsNone(out["contested_expectations"])
        self.assertIsNone(out["standing_mandates"])
        self.assertIsNone(out["unenforced_mandates"])
        self.assertEqual(out["execution_findings"], [])     # tracer ran
        self.assertEqual(len(calls), budget(3))
        by = {c["label"]: c["prompt"] for c in calls}
        for label in ("fix-1", "verify"):
            p = by[label]
            self.assertIn("NOT RUN — the mandate auditor agent returned nothing", p)
            self.assertNotIn("not a suggestion:\n[]", p, "a dead mandate auditor must not render as an empty list")
        self.assertIn("NOT RUN — the contester agent returned nothing", by["fix-1"])
        self.assertIn("ROLES THAT DIED", by["verify"])

    def test_generator_death_reaches_feeder_as_not_run(self):
        out, calls = self.run_one({"dead": ["generate"]})
        by = {c["label"]: c["prompt"] for c in calls}
        self.assertIn("NOT RUN — the generator agent returned nothing", by["feed-1"])
        self.assertIsNone(out["proposed_cases"])
        self.assertEqual(out["dead_roles"], ["generator"])

    def test_verifier_death_blocks_convergence_claim(self):
        out, calls = self.run_one({"dead": ["verify"]})
        self.assertEqual(out["dead_roles"], ["verifier"])
        self.assertTrue(out["stopped_because"].startswith("incomplete"), out["stopped_because"])
        self.assertIs(out["converged"], False)
        self.assertIsNone(out["independent_verification"])
        self.assertEqual(len(calls), budget(3))

    def test_model_overrides_reach_dispatch(self):
        out, calls = self.run_one({}, models={"generator": "opus", "verifier": "fable", "witness": "opus"})
        m = {c["label"]: c["model"] for c in calls}
        self.assertEqual(m["generate"], "opus")
        self.assertEqual(m["verify"], "fable")
        self.assertEqual(m["witness-1"], "opus")
        self.assertEqual(m["trace"], "opus")

    def test_oracle_author_olmec_points_contester_and_witness_at_the_oracle(self):
        _, calls = self.run_one({}, oracleAuthor="olmec")
        by = {c["label"]: c["prompt"] for c in calls}
        self.assertIn("ORACLE PROVENANCE WARNING", by["contest"])
        self.assertIn("written by the reviewing agent itself", by["contest"])
        self.assertIn("zero cases executed", by["witness-1"])
        _, calls = self.run_one({})
        by = {c["label"]: c["prompt"] for c in calls}
        self.assertNotIn("ORACLE PROVENANCE WARNING", by["contest"])
        self.assertIn("contest the ORACLE itself", by["contest"])   # always contested, louder when olmec


if __name__ == "__main__":
    unittest.main(verbosity=2)
