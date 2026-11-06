#!/usr/bin/env python3
import json
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FORGE = ROOT / "scripts/manifest-forge.py"


def run(*args: str, cwd: Path):
    return subprocess.run(["python3", str(FORGE), *args], cwd=cwd, text=True, capture_output=True)


def main() -> int:
    with tempfile.TemporaryDirectory() as tmp:
        pkg = Path(tmp) / "demo"
        pkg.mkdir()
        (pkg / "SKILL.md").write_text(
            "---\nname: demo-skill\ndescription: Demo package for manifest generation.\n---\n\n# Demo\n",
            encoding="utf-8",
        )
        first = run("generate", str(pkg), cwd=ROOT)
        assert first.returncode == 0, first.stderr
        for rel in [
            ".claude-plugin/plugin.json",
            ".codex-plugin/plugin.json",
            ".agent-plugin/plugin.json",
            "agents/openai.yaml",
            "skills/demo-skill/SKILL.md",
        ]:
            assert (pkg / rel).is_file(), rel
        codex = json.loads((pkg / ".codex-plugin/plugin.json").read_text())
        assert codex["skills"] == "./"
        assert codex["name"] == "demo-skill"
        valid = run("validate", str(pkg), cwd=ROOT)
        assert valid.returncode == 0, valid.stderr
        (pkg / ".codex-plugin/plugin.json").write_text("{}\n", encoding="utf-8")
        drift = run("diff", str(pkg), cwd=ROOT)
        assert drift.returncode == 1
        assert ".codex-plugin/plugin.json" in drift.stdout
        repaired = run("repair", str(pkg), cwd=ROOT)
        assert repaired.returncode == 0, repaired.stderr
        assert run("validate", str(pkg), cwd=ROOT).returncode == 0
    with tempfile.TemporaryDirectory() as tmp:
        pkg = Path(tmp) / "nb-dev"
        skill = pkg / "skills" / "example"
        skill.mkdir(parents=True)
        (skill / "SKILL.md").write_text("---\nname: example\ndescription: Example skill.\n---\n")
        codex = pkg / ".codex-plugin" / "plugin.json"
        codex.parent.mkdir(parents=True)
        codex.write_text(json.dumps({"name": "nb-dev", "version": "0.4.0", "description": "Authored description", "interface": {"displayName": "ChittyOS Development"}}))
        agent = skill / "agents" / "openai.yaml"
        agent.parent.mkdir()
        agent.write_text('interface:\n  display_name: "Authored Example"\n')
        generated = run("generate", str(pkg), "--preserve-native", cwd=ROOT)
        assert generated.returncode == 0, generated.stderr
        for target in (".claude-plugin/plugin.json", ".codex-plugin/plugin.json", ".agent-plugin/plugin.json"):
            manifest = json.loads((pkg / target).read_text())
            assert manifest["version"] == "0.4.0"
            assert manifest["interface"]["displayName"] == "ChittyOS Development" if target != ".claude-plugin/plugin.json" else manifest["name"] == "nb-dev"
            assert manifest["skills"] == ["./skills/example"]
        assert agent.read_text() == 'interface:\n  display_name: "Authored Example"\n'
        assert run("validate", str(pkg), "--preserve-native", cwd=ROOT).returncode == 0
    print("manifest-forge tests: ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
