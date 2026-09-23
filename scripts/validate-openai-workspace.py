#!/usr/bin/env python3
"""Validate the OpenAI workspace-sync projection without external dependencies."""

from __future__ import annotations

import json
import pathlib
import re
import sys


ROOT = pathlib.Path(__file__).resolve().parents[1]
OPENAI_MARKETPLACE = ROOT / ".agents" / "plugins" / "marketplace.json"
CLAUDE_MARKETPLACE = ROOT / ".claude-plugin" / "marketplace.json"
ALLOWED_SKILL_POLICY_KEYS = {"allow_implicit_invocation"}
BOOL_VALUES = {"true", "false"}


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def load_json(path: pathlib.Path) -> dict:
    try:
        return json.loads(path.read_text())
    except FileNotFoundError:
        fail(f"missing {path.relative_to(ROOT)}")
    except json.JSONDecodeError as exc:
        fail(f"invalid JSON in {path.relative_to(ROOT)}: {exc}")
    raise AssertionError("unreachable")


def validate_skill_policy(path: pathlib.Path) -> None:
    lines = path.read_text().splitlines()
    try:
        start = next(i for i, line in enumerate(lines) if line == "policy:")
    except StopIteration:
        return

    keys: dict[str, str] = {}
    for line in lines[start + 1 :]:
        if line and not line.startswith((" ", "\t")):
            break
        match = re.match(r"^  ([A-Za-z_][A-Za-z0-9_-]*):(?:\s*(.*))?$", line)
        if match:
            keys[match.group(1)] = (match.group(2) or "").strip()

    unsupported = sorted(set(keys) - ALLOWED_SKILL_POLICY_KEYS)
    if unsupported:
        fail(
            f"{path.relative_to(ROOT)} policy contains unsupported keys: "
            + ", ".join(unsupported)
        )

    value = keys.get("allow_implicit_invocation")
    if value is not None and value not in BOOL_VALUES:
        fail(
            f"{path.relative_to(ROOT)} allow_implicit_invocation must be true or false"
        )


def main() -> int:
    openai = load_json(OPENAI_MARKETPLACE)
    claude = load_json(CLAUDE_MARKETPLACE)

    claude_local = {
        entry["name"]
        for entry in claude.get("plugins", [])
        if isinstance(entry.get("source"), str)
        and entry["source"].startswith("./plugins/")
    }
    openai_names = {entry.get("name") for entry in openai.get("plugins", [])}

    if openai_names != claude_local:
        missing = sorted(claude_local - openai_names)
        extra = sorted(openai_names - claude_local)
        fail(f"OpenAI marketplace local-plugin set drift; missing={missing}, extra={extra}")

    for entry in openai.get("plugins", []):
        name = entry.get("name", "<unnamed>")
        source = entry.get("source")
        if not isinstance(source, dict) or source.get("source") != "local":
            fail(f"{name}: OpenAI marketplace source must be local")

        rel = source.get("path")
        if not isinstance(rel, str) or not rel.startswith("./plugins/"):
            fail(f"{name}: invalid local source path {rel!r}")

        plugin_dir = ROOT / rel[2:]
        if not plugin_dir.is_dir():
            fail(f"{name}: source directory does not exist: {rel}")

        policy = entry.get("policy")
        if not isinstance(policy, dict):
            fail(f"{name}: marketplace policy must be an object")
        if policy.get("installation") not in {
            "AVAILABLE",
            "INSTALLED_BY_DEFAULT",
            "NOT_AVAILABLE",
        }:
            fail(f"{name}: invalid policy.installation")
        if not isinstance(policy.get("authentication"), str):
            fail(f"{name}: policy.authentication is required")

        manifest_path = plugin_dir / ".claude-plugin" / "plugin.json"
        manifest = load_json(manifest_path)
        author = manifest.get("author")
        if author is not None and not isinstance(author, dict):
            fail(f"{name}: author must be an object when provided")

        for openai_yaml in plugin_dir.rglob("agents/openai.yaml"):
            validate_skill_policy(openai_yaml)

    held = [
        entry.get("name", "<unnamed>")
        for entry in claude.get("plugins", [])
        if not (
            isinstance(entry.get("source"), str)
            and entry["source"].startswith("./plugins/")
        )
    ]
    print(
        f"OK: OpenAI workspace projection validates "
        f"({len(openai_names)} local plugins; held external entries: {', '.join(held) or 'none'})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
