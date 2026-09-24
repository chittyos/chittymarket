#!/usr/bin/env python3
"""Exercise the real generator CLI on temporary files; no network/backend mocks."""

import json
import pathlib
import shutil
import subprocess
import sys
import tempfile
import unittest

SOURCE = pathlib.Path(__file__).resolve().parents[1] / "generate-openai-marketplace.py"


class OpenAIMarketplaceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = pathlib.Path(self.temp.name) / "repo"
        (self.root / "scripts").mkdir(parents=True)
        shutil.copy2(SOURCE, self.root / "scripts" / SOURCE.name)
        self.source = self.root / ".claude-plugin/marketplace.json"
        self.source.parent.mkdir()
        self.output = self.root / ".agents/plugins/marketplace.json"
        self.output.parent.mkdir(parents=True)
        self.output.write_bytes(b"previous projection\n")
        self.entries = [{"name": "fixture-mcp", "source": "./plugins/fixture-mcp", "category": "ecosystem"}]
        self.plugin = self.root / "plugins/fixture-mcp"
        (self.plugin / ".claude-plugin").mkdir(parents=True)
        (self.plugin / ".claude-plugin/plugin.json").write_text('{"name":"fixture-mcp"}\n')
        (self.plugin / ".mcp.json").write_text('{"mcpServers":{}}\n')
        self.write_catalog()

    def write_catalog(self, value=None):
        self.source.write_text(json.dumps({"plugins": self.entries} if value is None else value))

    def run_cli(self, *args):
        return subprocess.run([sys.executable, str(self.root / "scripts" / SOURCE.name), *args], capture_output=True, text=True, timeout=10)

    def assert_rejected(self):
        before = self.output.read_bytes()
        result = self.run_cli()
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("ERROR:", result.stderr)
        self.assertEqual(self.output.read_bytes(), before)

    def test_legacy_components_and_source_are_unchanged(self):
        self.entries.append({"name": "fixture-external", "source": {"source": "github", "repo": "example/fixture"}})
        self.write_catalog()
        originals = {p: p.read_bytes() for p in self.plugin.rglob("*") if p.is_file()}
        source_bytes = self.source.read_bytes()
        result = self.run_cli()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("held non-local entries: fixture-external", result.stdout)
        self.assertEqual(json.loads(self.output.read_bytes()), {
            "name": "chittymarket", "interface": {"displayName": "ChittyMarket"},
            "plugins": [{"name": "fixture-mcp", "source": {"source": "local", "path": "./plugins/fixture-mcp"},
                         "policy": {"installation": "AVAILABLE", "authentication": "ON_INSTALL"}, "category": "Ecosystem"}],
        })
        self.assertEqual(self.source.read_bytes(), source_bytes)
        self.assertEqual({p: p.read_bytes() for p in self.plugin.rglob("*") if p.is_file()}, originals)
        self.assertFalse((self.plugin / "plugin.json").exists())
        first = self.output.read_bytes()
        self.assertEqual(self.run_cli().returncode, 0)
        self.assertEqual(self.output.read_bytes(), first)
        self.assertEqual(self.run_cli("--check").returncode, 0)

    def test_check_is_read_only_when_stale_or_missing(self):
        self.assertEqual(self.run_cli("--check").returncode, 1)
        self.assertEqual(self.output.read_bytes(), b"previous projection\n")
        shutil.rmtree(self.root / ".agents")
        self.assertEqual(self.run_cli("--check").returncode, 1)
        self.assertFalse((self.root / ".agents").exists())

    def test_later_missing_source_does_not_replace_output(self):
        self.entries.append({"name": "missing", "source": "./plugins/missing"})
        self.write_catalog()
        self.assert_rejected()

    def test_bad_catalogs_do_not_replace_output(self):
        for value in ({}, {"plugins": {}}, {"plugins": [None]}, {"plugins": [{}]}, {"plugins": self.entries * 2},
                      {"plugins": [dict(self.entries[0], category=None)]}):
            with self.subTest(value=value):
                self.write_catalog(value)
                self.assert_rejected()
        self.source.write_text('{"plugins":[],"plugins":[]}')
        self.assert_rejected()
        self.source.write_text('{invalid JSON')
        self.assert_rejected()

    def test_path_traversal_is_rejected(self):
        for path in ("./plugins/../private", "./plugins/./fixture-mcp", "./plugins//fixture-mcp", "./plugins/fixture\\other"):
            with self.subTest(path=path):
                self.entries[0]["source"] = path
                self.write_catalog()
                self.assert_rejected()

    def test_plugin_symlink_is_rejected(self):
        outside = pathlib.Path(self.temp.name) / "outside"
        outside.mkdir()
        (self.root / "plugins/link").symlink_to(outside, target_is_directory=True)
        self.entries[0]["source"] = "./plugins/link"
        self.write_catalog()
        self.assert_rejected()

    def test_authoring_symlink_is_rejected(self):
        outside = pathlib.Path(self.temp.name) / "catalog.json"
        outside.write_bytes(self.source.read_bytes())
        self.source.unlink()
        self.source.symlink_to(outside)
        self.assert_rejected()

    def test_output_symlink_is_rejected(self):
        outside = pathlib.Path(self.temp.name) / "outside.json"
        outside.write_bytes(b"private sentinel\n")
        self.output.unlink()
        self.output.symlink_to(outside)
        self.assert_rejected()
        self.assertEqual(outside.read_bytes(), b"private sentinel\n")

    def test_output_parent_symlink_is_rejected(self):
        outside = pathlib.Path(self.temp.name) / "outside"
        (outside / "plugins").mkdir(parents=True)
        (outside / "plugins/marketplace.json").write_bytes(b"private sentinel\n")
        shutil.rmtree(self.root / ".agents")
        (self.root / ".agents").symlink_to(outside, target_is_directory=True)
        self.assert_rejected()


if __name__ == "__main__":
    unittest.main(verbosity=2)
