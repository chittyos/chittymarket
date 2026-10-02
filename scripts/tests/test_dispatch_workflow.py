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
SCRIPT = "export const meta = { name: 'probe', description: 'x' }\nconst s = `a ``` b`\nreturn { ok: true }\n"


def run_adapter(canonical_text):
    with tempfile.TemporaryDirectory() as td:
        can = Path(td) / "probe.md"
        out = Path(td) / "out" / "probe.js"
        can.write_text(canonical_text, encoding="utf-8")
        proc = subprocess.run([str(ADAPTER), str(can), str(out)], capture_output=True, text=True)
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
for (const c of cases) {
  const calls = { agent: 0, logs: [] }
  const agent = async () => { calls.agent++; throw new Error('agent() dispatched in a test') }
  const parallel = async (thunks) => Promise.all(thunks.map((t) => t()))
  const phase = () => {}
  const log = (m) => calls.logs.push(m)
  const args = c.raw ? c.args : (c.stringify ? JSON.stringify(c.args) : c.args)
  try {
    const out = await wf(args, agent, parallel, phase, log)
    results.push({ ok: true, out, agentCalls: calls.agent })
  } catch (e) {
    results.push({ ok: false, error: String(e.message), agentCalls: calls.agent })
  }
}
console.log(JSON.stringify(results))
"""


class GauntletArgsAndDryRun(unittest.TestCase):
    TOKEN = "sk-live-do-not-echo-0123456789"

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
        d = {"target": "/srv/chittyentity/src/gate.ts", "runner": f"cd /srv && TOKEN={self.TOKEN} npx tsx sim.ts", "dryRun": True}
        d.update(extra)
        return d

    def test_dry_run_object_and_string_args_agree(self):
        r = self.run_cases([{"args": self.base()}, {"args": self.base(), "stringify": True}])
        for res in r:
            self.assertTrue(res["ok"], res)
            self.assertEqual(res["agentCalls"], 0)
            out = res["out"]
            self.assertIs(out["started"], False)
            self.assertEqual(out["reason"], "dry-run")
            self.assertEqual(out["config"]["target"], "/srv/chittyentity/src/gate.ts")
            self.assertEqual(out["config"]["agent_budget"]["max"], 4 + 2 * 6 + 1)
            self.assertNotIn(self.TOKEN, json.dumps(out))
        self.assertEqual(r[0]["out"], r[1]["out"])

    def test_dry_run_reports_explicit_model_for_every_role(self):
        r = self.run_cases([{"args": self.base(maxRounds=2, models={"generator": "opus"})}])[0]
        roles = {x["role"]: x["model"] for x in r["out"]["config"]["roles"]}
        self.assertEqual(set(roles), {"contester", "generator", "tracer", "mandate", "feeder", "implementer", "verifier"})
        self.assertEqual(roles["generator"], "opus")
        self.assertEqual(roles["tracer"], "opus")
        self.assertEqual(r["out"]["config"]["agent_budget"]["max"], 9)

    def test_truthy_dry_run_fails_safe(self):
        for v in ("true", 1):
            r = self.run_cases([{"args": self.base(dryRun=v)}])[0]
            self.assertTrue(r["ok"], r)
            self.assertEqual(r["agentCalls"], 0)
            self.assertEqual(r["out"]["reason"], "dry-run")

    def test_default_generator_is_sonnet(self):
        r = self.run_cases([{"args": self.base()}])[0]
        roles = {x["role"]: x["model"] for x in r["out"]["config"]["roles"]}
        self.assertEqual(roles["generator"], "sonnet")

    def test_early_returns_do_not_dispatch(self):
        cases = [
            {"args": None, "raw": True},
            {"args": "", "raw": True},
            {"args": {}},
            {"args": {"runner": "x"}},
            {"args": {"target": "/t"}, "stringify": True},
            {"args": self.base(models={"nonsense": "opus"})},
            {"args": self.base(models={"tracer": ""})},
            {"args": self.base(maxRounds=0)},
        ]
        want = ["no-args", "no-args", "no-args", "missing-target", "missing-runner", "bad-models", "bad-models", "bad-rounds"]
        for res, reason in zip(self.run_cases(cases), want):
            self.assertTrue(res["ok"], res)
            self.assertEqual(res["agentCalls"], 0)
            self.assertIs(res["out"]["started"], False)
            self.assertEqual(res["out"]["reason"], reason)
            self.assertTrue(res["out"]["next"])

    def test_malformed_and_non_object_args_throw_without_echo(self):
        bad_json = '{"target": "/t", "runner": "' + self.TOKEN + '"'
        r = self.run_cases([
            {"args": bad_json, "raw": True},
            {"args": [1, 2], "raw": True},
            {"args": "[1,2]", "raw": True},
            {"args": 42, "raw": True},
        ])
        for res in r:
            self.assertFalse(res["ok"], res)
            self.assertEqual(res["agentCalls"], 0)
            self.assertNotIn(self.TOKEN, res["error"])
        self.assertIn("not valid JSON", r[0]["error"])
        self.assertIn("got array", r[1]["error"])
        self.assertIn("got array", r[2]["error"])
        self.assertIn("got number", r[3]["error"])

    def test_real_run_reaches_agent_dispatch_with_models(self):
        # Without dryRun the script must try to dispatch; the harness agent() throws, and
        # parallel() surfaces it. Proves dryRun is the only thing standing between args and spend.
        r = self.run_cases([{"args": {k: v for k, v in self.base().items() if k != "dryRun"}}])[0]
        self.assertGreaterEqual(r["agentCalls"], 1)

    def test_every_agent_call_carries_explicit_model(self):
        src = GAUNTLET.read_text(encoding="utf-8")
        calls = src.count("agent(`")
        self.assertEqual(calls, 7)
        self.assertEqual(src.count("model: MODELS."), calls)


if __name__ == "__main__":
    unittest.main(verbosity=2)
