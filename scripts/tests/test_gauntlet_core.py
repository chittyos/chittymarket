#!/usr/bin/env python3
"""Regression tests for the gauntlet's single-source core.

Covers the inline-include projection (adapter), drift detection on an include
(dispatch.sh audit and the pre-commit hook, run against a scratch git repo that
carries a copy of the real dispatch scripts), the committed projection being
exactly core + orchestration, and the golden-fixture runner itself (green on
the real core, red on a broken one). Nothing is mocked; node and git are
required, and missing either is a failure, not a skip.
"""
import hashlib
import os
import re
import shutil
import subprocess
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DISPATCH_DIR = ROOT / "plugins/chittyagent-dispatch/scripts"
ADAPTER = DISPATCH_DIR / "adapters/claude-code-workflow.sh"
CORE = ROOT / "canonical/workflows/gauntlet.core.js"
CANONICAL = ROOT / "canonical/workflows/gauntlet.md"
PROJECTED = ROOT / "plugins/chittyos-core/workflows/gauntlet.js"
RUNNER = ROOT / "scripts/tests/run_gauntlet_fixtures.mjs"
FIXTURES = ROOT / "canonical/workflows/gauntlet.fixtures.json"
NODE = shutil.which("node")
GIT = shutil.which("git")

FM = textwrap.dedent("""\
    ---
    name: probe
    kind: workflow
    description: |
      probe workflow
    plugin: probe-plugin
    runtimes: [claude-code]
    ---
    prose
    """)
CORE_OK = "// probe core\nexport const K = 1\nexport function f(x) {\n  return x + K\n}\nconst internal = 2\n"
SCRIPT = "export const meta = { name: 'probe', description: 'x' }\n// @inline probe.core.js\nreturn { v: f(internal) }\n"


def adapt(canonical_text, includes, td):
    can = Path(td) / "probe.md"
    can.write_text(canonical_text, encoding="utf-8")
    for name, text in includes.items():
        (Path(td) / name).write_text(text, encoding="utf-8")
    out = Path(td) / "out" / "probe.js"
    p = subprocess.run([str(ADAPTER), str(can), str(out)], capture_output=True, text=True)
    return p, (out.read_text(encoding="utf-8") if out.exists() else None)


class InlineIncludeAdapter(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(NODE, "node is required")

    def block(self, script=SCRIPT):
        return FM + "````js\n" + script + "````\n"

    def test_marker_is_replaced_by_the_include_with_exports_stripped(self):
        with tempfile.TemporaryDirectory() as td:
            p, out = adapt(self.block(), {"probe.core.js": CORE_OK}, td)
            self.assertEqual(p.returncode, 0, p.stderr)
            digest = hashlib.sha256(CORE_OK.encode()).hexdigest()
            self.assertTrue(out.startswith("export const meta"))
            self.assertIn(f"// ── BEGIN inlined probe.core.js (sha256 {digest})", out)
            self.assertIn("const K = 1\nfunction f(x) {", out)
            self.assertNotIn("export const K", out)
            self.assertNotIn("// @inline", out)
            self.assertEqual(out.count("export "), 1, "only `export const meta` may survive")
            self.assertTrue(out.endswith("return { v: f(internal) }\n"))

    def test_projection_is_byte_stable(self):
        with tempfile.TemporaryDirectory() as td:
            _, a = adapt(self.block(), {"probe.core.js": CORE_OK}, td)
            _, b = adapt(self.block(), {"probe.core.js": CORE_OK}, td)
            self.assertEqual(a, b)

    def test_include_violations_fail_and_write_nothing(self):
        cases = {
            "export default": ("probe.core.js", "export default function () {}\n", "unsupported export form"),
            "export list": ("probe.core.js", "const a = 1\nexport { a }\n", "unsupported export form"),
            "export star": ("probe.core.js", "export * from './x.js'\n", "unsupported export form"),
            "import": ("probe.core.js", "import fs from 'node:fs'\nexport const a = 1\n", "has an import"),
            "nested marker": ("probe.core.js", "// @inline other.js\n", "nesting is not supported"),
            "missing file": (None, None, "not found next to the canonical"),
        }
        for label, (name, text, needle) in cases.items():
            with self.subTest(label), tempfile.TemporaryDirectory() as td:
                p, out = adapt(self.block(), {name: text} if name else {}, td)
                self.assertNotEqual(p.returncode, 0)
                self.assertIn(needle, p.stderr)
                self.assertIsNone(out)

    def test_column0_export_inside_a_string_or_comment_is_rejected_not_rewritten(self):
        # The export strip is line-based; node's own export list is the independent oracle, so a
        # template-literal or comment line that starts with `export const` can never be silently edited.
        for label, text in {
            "template literal": "export const help = `\nexport const usage = 1\n`\n",
            "block comment": "/*\nexport function old() {}\n*/\nexport const a = 1\n",
        }.items():
            with self.subTest(label), tempfile.TemporaryDirectory() as td:
                p, out = adapt(self.block(SCRIPT.replace("f(internal)", "1")), {"probe.core.js": text}, td)
                self.assertNotEqual(p.returncode, 0)
                self.assertIn("do not match the module's real exports", p.stderr)
                self.assertIsNone(out)

    def test_marker_names_are_bare_sibling_files(self):
        for bad in ("../probe.core.js", "sub/probe.core.js", ".hidden.js", "probe.core.ts"):
            with self.subTest(bad), tempfile.TemporaryDirectory() as td:
                script = SCRIPT.replace("probe.core.js", bad)
                p, out = adapt(self.block(script), {"probe.core.js": CORE_OK}, td)
                self.assertNotEqual(p.returncode, 0)
                self.assertIn("bare sibling file name", p.stderr)
                self.assertIsNone(out)

    def test_duplicate_marker_rejected(self):
        with tempfile.TemporaryDirectory() as td:
            script = SCRIPT.replace("// @inline probe.core.js\n", "// @inline probe.core.js\n// @inline probe.core.js\n")
            p, out = adapt(self.block(script), {"probe.core.js": CORE_OK}, td)
            self.assertNotEqual(p.returncode, 0)
            self.assertIn("more than once", p.stderr)

    def test_name_declared_by_both_include_and_script_fails_node_check(self):
        with tempfile.TemporaryDirectory() as td:
            script = SCRIPT.replace("return {", "const K = 3\nreturn {")
            p, out = adapt(self.block(script), {"probe.core.js": CORE_OK}, td)
            self.assertNotEqual(p.returncode, 0)
            self.assertIn("node --check", p.stderr)
            self.assertIsNone(out)


class CommittedProjectionIsCorePlusOrchestration(unittest.TestCase):
    def test_projected_gauntlet_inlines_the_canonical_core_exactly(self):
        core = CORE.read_text(encoding="utf-8")
        proj = PROJECTED.read_text(encoding="utf-8")
        m = re.search(r"^// ── BEGIN inlined gauntlet\.core\.js \(sha256 ([0-9a-f]{64})\)[^\n]*\n(.*?)\n// ── END inlined gauntlet\.core\.js$",
                      proj, re.S | re.M)
        self.assertIsNotNone(m, "projection has no inlined core block")
        self.assertEqual(m.group(1), hashlib.sha256(CORE.read_bytes()).hexdigest(), "banner sha256 is not the core's")
        self.assertEqual(m.group(2), re.sub(r"(?m)^export (?=(?:const|let|function|async function)\b)", "", core).strip("\n"))

    def test_canonical_block_carries_no_core_declarations(self):
        # The orchestration must not re-declare anything the core owns; if it did, node --check of
        # the projection would fail, but this names the offender.
        core_names = set(re.findall(r"(?m)^export (?:const|let|function|async function) (\w+)", CORE.read_text(encoding="utf-8")))
        block = CANONICAL.read_text(encoding="utf-8").split("\n````js\n", 1)[1]
        declared = set(re.findall(r"(?m)^(?:const|let|function) (\w+)", block))
        self.assertGreater(len(core_names), 30)
        self.assertEqual(core_names & declared, set())

    def test_core_has_no_host_globals(self):
        core = CORE.read_text(encoding="utf-8")
        code = re.sub(r"`(?:\\.|[^`\\])*`", "``", core)            # drop template-literal prose
        code = re.sub(r"(?m)//.*$", "", code)
        code = re.sub(r"/\*.*?\*/", "", code, flags=re.S)
        for g in ("agent(", "parallel(", "phase(", "log("):
            self.assertNotRegex(code, r"(?<![\w.])" + re.escape(g), f"core calls host global {g}")


def git(cwd, *a):
    return subprocess.run([GIT, *a], cwd=cwd, capture_output=True, text=True, check=True).stdout


class IncludeDriftIsCaught(unittest.TestCase):
    """A scratch repo with a copy of the real dispatch scripts, one workflow canonical with an include."""

    def setUp(self):
        self.assertIsNotNone(GIT, "git is required")
        self.assertIsNotNone(NODE, "node is required")
        self.td = tempfile.mkdtemp()
        r = Path(self.td)
        shutil.copytree(DISPATCH_DIR, r / "plugins/chittyagent-dispatch/scripts")
        (r / "canonical/workflows").mkdir(parents=True)
        (r / "canonical/workflows/probe.md").write_text(FM + "````js\n" + SCRIPT + "````\n", encoding="utf-8")
        (r / "canonical/workflows/probe.core.js").write_text(CORE_OK, encoding="utf-8")
        shutil.copy(ROOT / "canonical/.gitignore", r / "canonical/.gitignore")   # the real repo's ignores
        git(r, "init", "-q")
        git(r, "config", "user.email", "t@chitty.cc")
        git(r, "config", "user.name", "t")
        self.dispatch = str(r / "plugins/chittyagent-dispatch/scripts/dispatch.sh")
        p = subprocess.run(["bash", self.dispatch, "sync", "probe"], cwd=r, capture_output=True, text=True)
        self.assertEqual(p.returncode, 0, p.stderr)
        git(r, "add", "-A")
        git(r, "commit", "-qm", "seed")
        self.r = r

    def tearDown(self):
        shutil.rmtree(self.td, ignore_errors=True)

    def audit(self):
        return subprocess.run(["bash", self.dispatch, "audit"], cwd=self.r, capture_output=True, text=True)

    def test_audit_clean_after_sync(self):
        p = self.audit()
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)

    def test_audit_flags_core_edit_without_resync(self):
        with open(self.r / "canonical/workflows/probe.core.js", "a", encoding="utf-8") as f:
            f.write("export const ADDED = 3\n")
        p = self.audit()
        self.assertEqual(p.returncode, 1, p.stdout)
        self.assertIn("CANON_AHEAD", p.stdout)
        self.assertIn("inlined include was edited", p.stdout)
        # and a re-sync heals it
        subprocess.run(["bash", self.dispatch, "sync", "probe"], cwd=self.r, check=True, capture_output=True)
        self.assertEqual(self.audit().returncode, 0)

    def test_audit_reports_a_broken_include_instead_of_crashing(self):
        (self.r / "canonical/workflows/probe.core.js").write_text("export default 1\n", encoding="utf-8")
        p = self.audit()
        self.assertEqual(p.returncode, 1, p.stdout + p.stderr)
        self.assertIn("re-projection with inlined includes failed", p.stdout)

    def test_pre_commit_blocks_a_staged_core_edit_without_reprojection(self):
        hook = self.r / "plugins/chittyagent-dispatch/scripts/pre-commit-drift.sh"
        with open(self.r / "canonical/workflows/probe.core.js", "a", encoding="utf-8") as f:
            f.write("export const ADDED = 3\n")
        git(self.r, "add", "canonical/workflows/probe.core.js")
        p = subprocess.run(["bash", str(hook)], cwd=self.r, capture_output=True, text=True)
        self.assertNotEqual(p.returncode, 0, p.stdout + p.stderr)
        self.assertIn("BLOCKED", p.stderr)
        self.assertIn("plugins/probe-plugin/workflows/probe.js", p.stderr)
        # staging the regenerated projection + state clears it
        git(self.r, "add", "-A")
        p = subprocess.run(["bash", str(hook)], cwd=self.r, capture_output=True, text=True)
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)


class FixtureRunner(unittest.TestCase):
    def run_fixtures(self, core_path=CORE):
        return subprocess.run([NODE, str(RUNNER), str(core_path), str(FIXTURES)], capture_output=True, text=True)

    def test_green_on_the_canonical_core(self):
        p = self.run_fixtures()
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIn("cases green", p.stdout)
        self.assertRegex(p.stdout, r"27/27 blocker kinds")

    def test_red_when_a_blocker_is_removed_from_the_core(self):
        core = CORE.read_text(encoding="utf-8")
        line = "  if (claimMismatch.length) blockers.push(`claim_mismatch in round(s) ${claimMismatch.map((m) => m.round).join(', ')}`)\n"
        self.assertEqual(core.count(line), 1)
        with tempfile.TemporaryDirectory() as td:
            broken = Path(td) / "core.js"
            broken.write_text(core.replace(line, ""), encoding="utf-8")
            p = self.run_fixtures(broken)
        self.assertEqual(p.returncode, 1, p.stdout)
        self.assertIn("FAIL convergence/fabricated-pass-every-round", p.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
