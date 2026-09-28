#!/usr/bin/env python3
"""Generate portable Agent Plugins manifests + repo marketplace.

Source metadata remains each local package's existing Claude plugin manifest.
Only packages whose portable behavior is complete in root `skills/` and does
not depend on an unconverted `.mcp.json` enter the first native marketplace.
Excluded packages are explicit policy, not inferred by absence.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PLUGINS = ROOT / "plugins"
MARKETPLACE = ROOT / ".agents" / "plugins" / "marketplace.json"
SCHEMA = "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json"

ELIGIBLE = {
    "chittyagent-autobot",
    "chittymarket-manager",
    "chittyos-core",
    "chittyos-devops",
    "chittyos-governance",
    "chittyos-legal",
    "nowebmaster",
}

EXCLUDED = {
    "ch1tty": "no portable skills/ component yet",
    "chittyagent-dispatch": "agent/projection package; no portable skills/ component",
    "chittymarket-canonical": "internal authoring source; not an installable capability product",
    "chittyos-mcp": "contains Claude .mcp.json; portable mcp.json conversion is separate work",
    "chittyos-proxy-agents": "proxy-agent package; native App/MCP projection is separate work",
    "neon-mcp": "contains Claude .mcp.json; portable mcp.json conversion is separate work",
}


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def dump(data) -> str:
    return json.dumps(data, indent=2, ensure_ascii=False) + "\n"


def source_manifest(name: str) -> dict:
    path = PLUGINS / name / ".claude-plugin" / "plugin.json"
    if not path.exists():
        raise ValueError(f"{name}: missing source manifest {path.relative_to(ROOT)}")
    data = load(path)
    for key in ("name", "version", "description"):
        if not data.get(key):
            raise ValueError(f"{name}: source manifest missing {key}")
    if data["name"] != name:
        raise ValueError(f"{name}: source manifest name mismatch {data['name']!r}")
    return data


def portable_manifest(name: str) -> dict:
    src = source_manifest(name)
    folder = PLUGINS / name
    if not (folder / "skills").is_dir():
        raise ValueError(f"{name}: eligible package has no root skills/ directory")
    if (folder / ".mcp.json").exists() or (folder / "mcp.json").exists():
        raise ValueError(f"{name}: eligible package unexpectedly carries MCP config")

    author = src.get("author")
    if isinstance(author, str):
        author = {"name": author}
    elif not isinstance(author, dict):
        author = {"name": "ChittyOS"}

    manifest = {
        "$schema": SCHEMA,
        "name": name,
        "version": str(src["version"]),
        "description": str(src["description"]),
        "author": author,
        "repository": "https://github.com/chittyos/chittymarket",
    }
    hooks = folder / "hooks" / "hooks.json"
    if hooks.exists():
        manifest["extensions"] = {
            "com.openai": {
                "hooks": "./hooks/hooks.json",
            }
        }
    return manifest


def marketplace() -> dict:
    entries = []
    for name in sorted(ELIGIBLE):
        # Validate manifest source before exposing package.
        portable_manifest(name)
        entries.append(
            {
                "name": name,
                "source": {"source": "local", "path": f"./plugins/{name}"},
                "policy": {
                    "installation": "AVAILABLE",
                    "authentication": "ON_INSTALL",
                },
                "category": "Productivity",
            }
        )
    return {
        "name": "chittymarket",
        "interface": {"displayName": "ChittyMarket"},
        "plugins": entries,
    }


def expected_files() -> dict[Path, str]:
    out = {}
    for name in sorted(ELIGIBLE):
        out[PLUGINS / name / "plugin.json"] = dump(portable_manifest(name))
    out[MARKETPLACE] = dump(marketplace())
    return out


def audit_exclusions() -> list[str]:
    errors = []
    local = {
        p.name
        for p in PLUGINS.iterdir()
        if p.is_dir() and (p / ".claude-plugin" / "plugin.json").exists()
    }
    known = ELIGIBLE | set(EXCLUDED)
    unknown = sorted(local - known)
    missing = sorted(known - local)
    if unknown:
        errors.append(f"unclassified local plugin packages: {unknown}")
    if missing:
        errors.append(f"classified plugin packages missing from disk: {missing}")
    overlap = sorted(ELIGIBLE & set(EXCLUDED))
    if overlap:
        errors.append(f"eligible/excluded overlap: {overlap}")
    return errors


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("mode", choices=("audit", "write"), nargs="?", default="audit")
    args = ap.parse_args()

    errors = audit_exclusions()
    expected = expected_files()
    drift = []
    for path, wanted in expected.items():
        current = path.read_text(encoding="utf-8") if path.exists() else None
        if current != wanted:
            drift.append(str(path.relative_to(ROOT)))

    print("=== Agent Plugins projection ===")
    print(f"eligible: {len(ELIGIBLE)} {sorted(ELIGIBLE)}")
    print(f"excluded: {len(EXCLUDED)}")
    for name, reason in sorted(EXCLUDED.items()):
        print(f"  HOLD {name}: {reason}")
    print(f"drift: {len(drift)} {drift}")
    for error in errors:
        print(f"ERROR: {error}")

    if errors:
        return 1
    if args.mode == "audit":
        return 1 if drift else 0

    for path, wanted in expected.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(wanted, encoding="utf-8")
        print(f"WROTE {path.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
