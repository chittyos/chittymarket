#!/usr/bin/env python3
"""Regression tests for the cleanup skill's documented safety contract.

Run: python3 -m unittest discover -s scripts/tests -p test_chitty_cleanup.py -v
The skill is prose, not a cleanup executable. These tests check its published
contract and execute only its path guard against disposable fixtures. They do
not invoke cleaners or claim agent/runtime verification.
"""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
CANONICAL = ROOT / "canonical/skills/chitty-cleanup.md"
PROJECTIONS = {
    "claude-code": ROOT / "plugins/chittyos-core/skills/chitty-cleanup/SKILL.md",
    "codex": ROOT / "plugins/chittyos-core/codex-skills/chitty-cleanup/SKILL.md",
}


def document(path):
    _, frontmatter, body = path.read_text().split("---", 2)
    return frontmatter, body


def section(body, title):
    return body.split("## " + title + "\n", 1)[1].split("\n## ", 1)[0]


def table(text):
    return [tuple(re.sub(r"^`([^`]+)`$", r"\1", cell.strip()) for cell in line.strip("|").split("|"))
            for line in text.splitlines() if line.startswith("| ")]


def git_blob(path):
    data = path.read_bytes()
    return hashlib.sha1(f"blob {len(data)}\0".encode() + data).hexdigest()


class CleanupContractTests(unittest.TestCase):
    def setUp(self):
        self.frontmatter, self.body = document(CANONICAL)

    def test_os_detection_and_home_guard_precede_resolution(self):
        setup = section(self.body, "Step 1: guard, detect, measure")
        self.assertIn('${HOME:?HOME unset}', setup)
        self.assertIn('cd "$HOME"', setup)
        self.assertIn("uname -s", setup)
        self.assertIn("Darwin or Linux; use only that OS's rows", setup)
        self.assertIn("df -h /", setup)
        self.assertNotIn("/Users/nb/", self.body)
        self.assertNotIn("cleanup-mac.sh", self.body)

    def test_each_tool_resolves_its_configured_cache_before_cleaning(self):
        rows = {row[0]: row[1:] for row in table(section(
            self.body, "Step 2: resolve each cache's real directory, then check it is inside $HOME"))}
        expected = {
            "npm": ("npm config get cache", "npm cache clean --force"),
            "pnpm": ("pnpm store path", "pnpm store prune"),
            "yarn v1": ("yarn cache dir", "yarn cache clean"),
            "pip": ("pip cache dir", "pip cache purge"),
            "uv": ("uv cache dir", "uv cache clean"),
        }
        for tool, commands in expected.items():
            with self.subTest(tool=tool):
                self.assertEqual(rows[tool], commands)
        for variable in ("npm_config_cache", "PIP_CACHE_DIR", "UV_CACHE_DIR", "XDG_CACHE_HOME"):
            self.assertIn(variable, self.body)
        self.assertIn("If a tool isn't installed, skip its row", self.body)

    def test_berry_and_homebrew_do_not_clean_project_or_shared_prefix(self):
        rows = table(self.body)
        berry = next(row for row in rows if row[0].startswith("yarn Berry"))
        self.assertEqual(berry[1], "yarn config get cacheFolder")
        self.assertIn("`yarn cache clean --mirror`", berry[2])
        self.assertIn("**Never plain `yarn cache clean`**", berry[2])
        brew = next(row for row in rows if row[0] == "Homebrew downloads")
        self.assertEqual(brew[1], "brew --cache")
        self.assertIn('rm -rf -- "$(brew --cache)"', brew[2])
        for rule in ("**Never `brew cleanup`** unless", "owned by `$USER`",
                     "stat -c %U", "stat -f %Su"):
            self.assertIn(rule, brew[2])

    def test_fixed_paths_are_os_specific_cache_directories(self):
        rows = table(self.body.split("Fixed-path rows", 1)[1])
        self.assertEqual(rows[0], ("Cache", "macOS", "Linux"))
        expected = {
            "node-gyp": ("~/Library/Caches/node-gyp", "~/.cache/node-gyp"),
            "TypeScript": ("~/Library/Caches/typescript", "~/.cache/typescript"),
            "Chrome": ("~/Library/Caches/Google/Chrome", "~/.cache/google-chrome"),
            "Chromium": ("n/a", "~/.cache/chromium"),
            "Brave": ("~/Library/Caches/BraveSoftware", "~/.cache/BraveSoftware"),
            "Firefox": ("~/Library/Caches/Firefox", "~/.cache/mozilla"),
        }
        self.assertEqual({row[0]: row[1:] for row in rows[1:7]}, expected)
        self.assertIn("Skip a browser if it's running", self.body)
        self.assertIn("`pgrep -x`", self.body)

    def test_dry_run_and_deletion_contract(self):
        self.assertIn("**Run no clean command and no `rm`.**", self.body)
        deletion = section(self.body, "Step 3: delete, exact paths only")
        self.assertIn("**Never use globs or brace expansion with `rm`.**", deletion)
        self.assertIn('rm -rf -- "$d"', deletion)
        self.assertIn('du -sh -- "$d"', deletion)
        self.assertIn("`--dry-run`", deletion)
        self.assertIn("`brew cleanup -n`", deletion)
        self.assertIn("and stop", deletion)

    def test_trash_logs_and_protected_state_are_not_automatic_targets(self):
        reporting = section(self.body, "Step 4: Trash and logs: report, ask, never automatic")
        trash, logs = table(reporting)[1:]
        self.assertIn("~/.Trash", trash[1])
        self.assertIn("~/.local/share/Trash", trash[1])
        self.assertIn("don't retry", trash[1])
        self.assertIn("only after explicit confirmation", trash[2])
        self.assertIn("Report the size only", logs[2])
        safety = section(self.body, "Safety: never touched")
        for protected in ("outside `$HOME`", "sudo", "Docker images, volumes and build cache",
                          "~/.claude/", "~/.cache/claude*", "~/.config/", ".yarn/cache",
                          "node_modules", "Downloads", "documents"):
            with self.subTest(protected=protected):
                self.assertIn(protected, safety)
        report = section(self.body, "Step 5: report")
        for requirement in ('df -h /', 'du -xsh "$HOME"', 'freed size per target',
                            'before and after', "Don't scan other users' homes"):
            self.assertIn(requirement, report)

    def test_core_release_version_matches_marketplace(self):
        plugin = json.loads((ROOT / "plugins/chittyos-core/.claude-plugin/plugin.json").read_text())
        marketplace = json.loads((ROOT / ".claude-plugin/marketplace.json").read_text())
        entries = [entry for entry in marketplace["plugins"] if entry["name"] == "chittyos-core"]
        self.assertEqual(len(entries), 1)
        self.assertEqual(entries[0]["version"], plugin["version"])

    def test_runtime_projections_and_dispatch_hashes_match_source(self):
        state = json.loads((ROOT / "canonical/.dispatch-state/skills/chitty-cleanup.json").read_text())
        self.assertEqual(state["canonical_sha"], git_blob(CANONICAL))
        self.assertEqual(state["dispatch"]["canonical_sha"], git_blob(CANONICAL))
        for runtime, path in PROJECTIONS.items():
            with self.subTest(runtime=runtime):
                metadata, body = document(path)
                self.assertEqual(body, self.body)
                for field in ("name", "description", "canon_uri"):
                    value = re.search(rf"^{field}: (.+)$", self.frontmatter, re.M)[1]
                    self.assertIn(f"{field}: {value}\n", metadata)
                self.assertEqual(state["targets"][runtime], git_blob(path))
                self.assertEqual(state["dispatch"]["targets"][runtime], git_blob(path))


class CleanupPathGuardTests(unittest.TestCase):
    def test_guard_accepts_only_resolved_descendants_of_home(self):
        # Exercise the published snippet itself, not a reimplementation.
        body = document(CANONICAL)[1]
        guard = re.search(r"\*\*Guard .*?```bash\n(.*?)```", body, re.S)[1]
        self.assertEqual(guard.count('"<resolved dir>"'), 1)
        guard = guard.replace('"<resolved dir>"', '"$1"')
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            home = base / "user home"
            home.mkdir()
            cache = home / "cache with spaces"
            cache.mkdir()
            outside = base / "shared"
            outside.mkdir()
            (home / "escape").symlink_to(outside, target_is_directory=True)
            (home / "local-link").symlink_to(cache, target_is_directory=True)
            cases = [
                (cache, True), (home / "missing-cache", True),
                (home / "local-link", True), (home, False), (base, False),
                (base / "user home-other/cache", False), (outside, False),
                (home / "escape", False), (home / "escape/missing", False),
                (home / "../shared", False), (Path("/"), False),
            ]
            for candidate, allowed in cases:
                with self.subTest(candidate=str(candidate)):
                    result = subprocess.run(
                        ["bash", "-eu", "-c", 'for candidate in "$1"; do\n' + guard
                         + '\nprintf "ALLOW:%s\\n" "$d"\ndone', "guard-test", str(candidate)],
                        env={**os.environ, "HOME": str(home)}, capture_output=True,
                        text=True, timeout=5, check=True,
                    )
                    prefix = "ALLOW:" if allowed else "SKIP "
                    self.assertTrue(result.stdout.startswith(prefix), result.stdout)
                    self.assertIn(str(candidate.resolve()), result.stdout)


if __name__ == "__main__":
    unittest.main()
