#!/usr/bin/env python3
"""Generate the existing repo-local OpenAI marketplace, not plugin contents.

Legacy plugin packages remain supported. Adding a portable root plugin.json
changes component discovery and requires a separate, lossless migration. This
compiler must never create or rewrite plugin manifests, skills, or MCP configs.
"""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import sys
import tempfile


def no_duplicate_keys(pairs: list[tuple[str, object]]) -> dict:
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def contained_path(root: pathlib.Path, relative: str) -> pathlib.Path:
    """Reject traversal and symlinks before reading or writing a package path.

This is a trusted, isolated build-workspace check, not a sandbox against a
concurrent malicious filesystem writer.
"""
    parts = relative.split("/")
    if not relative or "\\" in relative or any(p in {"", ".", ".."} for p in parts):
        raise ValueError(f"unsafe repository path: {relative!r}")
    current = root
    for part in parts:
        current = current / part
        if current.is_symlink():
            raise ValueError(f"symlink in repository path: {relative!r}")
    if not current.resolve().is_relative_to(root):
        raise ValueError(f"path escapes repository: {relative!r}")
    return current


def build_projection(root: pathlib.Path) -> tuple[str, list[str]]:
    source_path = contained_path(root, ".claude-plugin/marketplace.json")
    source = json.loads(source_path.read_text(encoding="utf-8"), object_pairs_hook=no_duplicate_keys)
    if not isinstance(source, dict) or not isinstance(source.get("plugins"), list):
        raise ValueError("authoring marketplace must contain a plugins array")
    plugins = []
    held = []
    names = set()
    for entry in source["plugins"]:
        if not isinstance(entry, dict):
            raise ValueError("every plugin entry must be an object")
        name = entry.get("name")
        if not isinstance(name, str) or not name.strip():
            raise ValueError("every plugin entry must have a nonempty name")
        if name in names:
            raise ValueError(f"duplicate plugin name: {name}")
        names.add(name)
        source_value = entry.get("source")
        if isinstance(source_value, str) and source_value.startswith("./plugins/"):
            plugin_dir = contained_path(root, source_value[2:])
            if not plugin_dir.is_dir():
                raise ValueError(f"{name}: local source directory does not exist")
            category = entry.get("category", "ecosystem")
            if not isinstance(category, str) or not category.strip():
                raise ValueError(f"{name}: category must be a nonempty string")
            plugins.append({
                "name": name,
                "source": {"source": "local", "path": source_value},
                "policy": {"installation": "AVAILABLE", "authentication": "ON_INSTALL"},
                "category": category.replace("-", " ").replace("_", " ").title(),
            })
        else:
            held.append(name)
    output = {"name": "chittymarket", "interface": {"displayName": "ChittyMarket"}, "plugins": plugins}
    return json.dumps(output, indent=2) + "\n", held


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="check projection bytes without writing")
    args = parser.parse_args()
    root = pathlib.Path(__file__).resolve().parents[1]
    try:
        rendered, held = build_projection(root)
        output = contained_path(root, ".agents/plugins/marketplace.json")
        if args.check:
            if not output.is_file() or output.read_bytes() != rendered.encode("utf-8"):
                raise ValueError("OpenAI marketplace is missing or stale; run scripts/generate-marketplace.sh")
        else:
            if output.exists() and not output.is_file():
                raise ValueError("OpenAI marketplace output is not a regular file")
            output.parent.mkdir(parents=True, exist_ok=True)
            temporary = None
            try:
                with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", newline="\n", dir=output.parent, delete=False) as handle:
                    temporary = pathlib.Path(handle.name)
                    handle.write(rendered)
                # Preserve ordinary access bits; never propagate executable/set-ID bits.
                mode = (output.stat().st_mode & 0o666) if output.exists() else 0o644
                temporary.chmod(mode)
                os.replace(temporary, output)
            finally:
                if temporary is not None:
                    temporary.unlink(missing_ok=True)
        print(f"[openai-marketplace] {'checked' if args.check else 'wrote'} {output.relative_to(root)}")
        if held:
            print("[openai-marketplace] held non-local entries: " + ", ".join(held))
        return 0
    except (OSError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
