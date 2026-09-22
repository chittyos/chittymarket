#!/usr/bin/env python3
"""Validate native ChatGPT Skill projections in plugins/*/chatgpt-skills/*."""

from __future__ import annotations

import re
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
PACKAGES = sorted(ROOT.glob("plugins/*/chatgpt-skills/*"))
ALLOWED = {"name", "description", "license", "allowed-tools", "metadata"}
NAME_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")


def load_frontmatter(path: Path) -> dict:
    text = path.read_text(encoding="utf-8")
    match = re.match(r"^---\n(.*?)\n---(?:\n|$)", text, re.DOTALL)
    if not match:
        raise ValueError("missing YAML frontmatter")
    data = yaml.safe_load(match.group(1))
    if not isinstance(data, dict):
        raise ValueError("frontmatter must be a mapping")
    return data


def fail(errors: list[str], path: Path, message: str) -> None:
    errors.append(f"{path.relative_to(ROOT)}: {message}")


def main() -> int:
    errors: list[str] = []

    for package in PACKAGES:
        if not package.is_dir():
            continue
        skill = package / "SKILL.md"
        meta = package / "agents" / "openai.yaml"

        if not skill.is_file():
            fail(errors, package, "missing SKILL.md")
            continue

        try:
            fm = load_frontmatter(skill)
        except Exception as exc:
            fail(errors, skill, str(exc))
            continue

        extra = sorted(set(fm) - ALLOWED)
        if extra:
            fail(errors, skill, f"unsupported frontmatter keys: {', '.join(extra)}")

        name = fm.get("name")
        description = fm.get("description")
        if not isinstance(name, str) or not name:
            fail(errors, skill, "name must be a non-empty string")
        else:
            if name != package.name:
                fail(errors, skill, f"name {name!r} does not match package directory {package.name!r}")
            if len(name) > 64 or not NAME_RE.fullmatch(name):
                fail(errors, skill, "name must be <=64 chars and lower-case hyphen-case")

        if not isinstance(description, str) or not description.strip():
            fail(errors, skill, "description must be a non-empty string")
        elif len(description.strip()) > 1024:
            fail(errors, skill, "description exceeds 1024 characters")
        elif "<" in description or ">" in description:
            fail(errors, skill, "description may not contain angle brackets")

        if not meta.is_file():
            fail(errors, package, "missing agents/openai.yaml")
            continue

        try:
            openai = yaml.safe_load(meta.read_text(encoding="utf-8"))
        except Exception as exc:
            fail(errors, meta, f"invalid YAML: {exc}")
            continue

        if not isinstance(openai, dict):
            fail(errors, meta, "must be a mapping")
            continue

        interface = openai.get("interface")
        if not isinstance(interface, dict):
            fail(errors, meta, "missing interface mapping")
            continue

        for key in ("display_name", "short_description"):
            if not isinstance(interface.get(key), str) or not interface[key].strip():
                fail(errors, meta, f"interface.{key} must be a non-empty string")

        for key in ("icon_small", "icon_large"):
            value = interface.get(key)
            if value and not (package / str(value)).is_file():
                fail(errors, meta, f"interface.{key} references missing file {value!r}")

    if errors:
        print(f"ChatGPT Skill validation failed: {len(errors)} error(s)")
        for error in errors:
            print(f"ERROR: {error}")
        return 1

    print(f"ChatGPT Skill validation passed: {sum(p.is_dir() for p in PACKAGES)} package(s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
