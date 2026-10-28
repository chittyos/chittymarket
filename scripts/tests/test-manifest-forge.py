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
    print("manifest-forge tests: ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
