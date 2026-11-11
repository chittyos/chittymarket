#!/usr/bin/env python3
"""Manifest Forge — generate and validate cross-runtime agent plugin manifests.

Uses existing SKILL.md frontmatter as the source of truth. No registry or schema
is created. Generated files are deterministic and safe to diff in CI.
"""
from __future__ import annotations

import argparse
import difflib
import json
import re
import sys
from pathlib import Path
from typing import Any

TARGET_FILES = {
    "claude": Path(".claude-plugin/plugin.json"),
    "codex": Path(".codex-plugin/plugin.json"),
    "agent": Path(".agent-plugin/plugin.json"),
}
PLUGIN_TARGETS = set(TARGET_FILES)
KNOWN_TARGETS = PLUGIN_TARGETS | {"skills-sh"}


def _strip_quotes(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {"\"", "'"}:
        return value[1:-1]
    return value


def read_frontmatter(path: Path) -> dict[str, Any]:
    text = path.read_text(encoding="utf-8")
    match = re.match(r"^---\s*\n(.*?)\n---\s*(?:\n|$)", text, re.S)
    if not match:
        raise ValueError(f"{path}: missing YAML frontmatter")
    lines = match.group(1).splitlines()
    data: dict[str, Any] = {}
    i = 0
    while i < len(lines):
        line = lines[i]
        if not line or line.startswith((" ", "\t")) or ":" not in line:
            i += 1
            continue
        key, raw = line.split(":", 1)
        key, value = key.strip(), raw.strip()
        if value in {">", ">-", "|", "|-"}:
            parts: list[str] = []
            i += 1
            while i < len(lines) and (not lines[i] or lines[i].startswith((" ", "\t"))):
                if lines[i].strip():
                    parts.append(lines[i].strip())
                i += 1
            data[key] = " ".join(parts)
            continue
        if value == "":
            nested: dict[str, str] = {}
            i += 1
            while i < len(lines) and lines[i].startswith((" ", "\t")) and ":" in lines[i]:
                sub_key, sub_value = lines[i].split(":", 1)
                nested[sub_key.strip()] = _strip_quotes(sub_value)
                i += 1
            data[key] = nested
            continue
        data[key] = _strip_quotes(value)
        i += 1
    return data


def discover_skills(root: Path) -> list[tuple[Path, dict[str, Any]]]:
    candidates: list[Path] = []
    if (root / "SKILL.md").is_file():
        # A package-root skill is the authored source. A generated skills.sh
        # projection may also exist under skills/<name>/SKILL.md; do not
        # rediscover that projection as a second source.
        candidates.append(root / "SKILL.md")
    else:
        skills_dir = root / "skills"
        if skills_dir.is_dir():
            candidates.extend(sorted(skills_dir.glob("*/SKILL.md")))
    if not candidates:
        raise ValueError(f"{root}: no SKILL.md at package root or skills/*/SKILL.md")

    skills: list[tuple[Path, dict[str, Any]]] = []
    names: set[str] = set()
    for path in candidates:
        fm = read_frontmatter(path)
        name = str(fm.get("name", "")).strip()
        desc = str(fm.get("description", "")).strip()
        if not name or not desc:
            raise ValueError(f"{path}: frontmatter requires name and description")
        if name in names:
            raise ValueError(f"{path}: duplicate skill name {name!r}")
        names.add(name)
        skills.append((path, fm))
    return skills


def relative_skill_paths(root: Path, skills: list[tuple[Path, dict[str, Any]]]) -> list[str]:
    paths = []
    for skill_md, _ in skills:
        parent = skill_md.parent.relative_to(root)
        paths.append("./" if str(parent) == "." else f"./{parent.as_posix()}")
    return paths


def package_metadata(root: Path, skills: list[tuple[Path, dict[str, Any]]]) -> tuple[str, str, str]:
    if len(skills) == 1:
        fm = skills[0][1]
        name = str(fm["name"])
        desc = str(fm["description"])
    else:
        name = root.name
        desc = f"Agent skill package containing {len(skills)} skills: " + ", ".join(str(fm["name"]) for _, fm in skills)
    author = ""
    for _, fm in skills:
        raw_author = fm.get("author") or fm.get("developer") or ""
        if isinstance(raw_author, dict):
            raw_author = raw_author.get("name", "")
        author = str(raw_author).strip()
        if author:
            break
    return name, desc, author or "Package maintainer"


def plugin_manifest(runtime: str, root: Path, skills: list[tuple[Path, dict[str, Any]]]) -> dict[str, Any]:
    name, desc, author = package_metadata(root, skills)
    skill_paths = relative_skill_paths(root, skills)
    base: dict[str, Any] = {
        "name": name,
        "version": "1.0.0",
        "description": desc,
        "skills": skill_paths[0] if len(skill_paths) == 1 else skill_paths,
    }
    if runtime == "claude":
        base["author"] = {"name": author}
    else:
        base["interface"] = {
            "displayName": name.replace("-", " ").title(),
            "shortDescription": desc[:160],
            "developerName": author,
            "category": "Productivity",
            "capabilities": [],
        }
    return base


def _yaml_quote(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


def openai_yaml(fm: dict[str, Any]) -> str:
    name = str(fm["name"])
    desc = str(fm["description"])
    return (
        "interface:\n"
        f"  display_name: {_yaml_quote(name.replace('-', ' ').title())}\n"
        f"  short_description: {_yaml_quote(desc[:160])}\n"
    )


def generated_files(root: Path, targets: list[str], preserve_native: bool = False) -> dict[Path, str]:
    skills = discover_skills(root)
    out: dict[Path, str] = {}
    for target in targets:
        if target in PLUGIN_TARGETS:
            path = root / TARGET_FILES[target]
            manifest = plugin_manifest(target, root, skills)
            if preserve_native:
                # Native package identity and presentation metadata are authored,
                # while skill discovery paths remain generated from frontmatter.
                source = path if path.exists() else root / TARGET_FILES["codex"]
                if source.exists():
                    authored = json.loads(source.read_text(encoding="utf-8"))
                    if not isinstance(authored, dict):
                        raise ValueError(f"{source}: expected a JSON object")
                    manifest.update(authored)
                    manifest["skills"] = relative_skill_paths(root, skills)
            out[path] = json.dumps(manifest, indent=2, ensure_ascii=False) + "\n"
    for skill_md, fm in skills:
        agent_path = skill_md.parent / "agents/openai.yaml"
        if preserve_native and agent_path.exists():
            out[agent_path] = agent_path.read_text(encoding="utf-8")
        else:
            out[agent_path] = openai_yaml(fm)
        if "skills-sh" in targets and skill_md.parent == root:
            projected = root / "skills" / str(fm["name"]) / "SKILL.md"
            out[projected] = skill_md.read_text(encoding="utf-8")
    return out


def marketplace_entry(root: Path) -> dict[str, Any]:
    skills = discover_skills(root)
    name, desc, _ = package_metadata(root, skills)
    return {
        "name": name,
        "description": desc,
        "source": ".",
        "strict": False,
    }


def upsert_marketplace(path: Path, entry: dict[str, Any]) -> None:
    if path.exists():
        data = json.loads(path.read_text(encoding="utf-8"))
    else:
        data = {"plugins": []}
    plugins = data.setdefault("plugins", [])
    if not isinstance(plugins, list):
        raise ValueError(f"{path}: plugins must be a list")
    replaced = False
    for i, plugin in enumerate(plugins):
        if isinstance(plugin, dict) and plugin.get("name") == entry["name"]:
            plugins[i] = entry
            replaced = True
            break
    if not replaced:
        plugins.append(entry)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def diff_files(files: dict[Path, str]) -> tuple[bool, str]:
    clean = True
    chunks: list[str] = []
    for path, expected in sorted(files.items(), key=lambda item: str(item[0])):
        actual = path.read_text(encoding="utf-8") if path.exists() else ""
        if actual != expected:
            clean = False
            chunks.extend(difflib.unified_diff(
                actual.splitlines(True), expected.splitlines(True),
                fromfile=str(path), tofile=f"{path} (generated)"
            ))
    return clean, "".join(chunks)


def write_files(files: dict[Path, str]) -> None:
    for path, content in files.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        print(path)


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate cross-runtime plugin manifests from SKILL.md")
    parser.add_argument("mode", choices=("generate", "validate", "diff", "repair"))
    parser.add_argument("path", nargs="?", default=".")
    parser.add_argument("--targets", default="claude,codex,agent,skills-sh", help="comma-separated: claude,codex,agent,skills-sh")
    parser.add_argument("--marketplace", help="optional marketplace JSON to upsert")
    parser.add_argument("--preserve-native", action="store_true", help="preserve authored native manifest metadata and skill agent descriptions; regenerate skill discovery paths")
    args = parser.parse_args()

    root = Path(args.path).expanduser().resolve()
    targets = [x.strip() for x in args.targets.split(",") if x.strip()]
    unknown = sorted(set(targets) - KNOWN_TARGETS)
    if unknown:
        parser.error(f"unknown targets: {', '.join(unknown)}")

    try:
        files = generated_files(root, targets, preserve_native=args.preserve_native)
        clean, patch = diff_files(files)
        if args.mode in {"generate", "repair"}:
            write_files(files)
            if args.marketplace:
                upsert_marketplace(Path(args.marketplace).expanduser().resolve(), marketplace_entry(root))
            return 0
        if args.mode == "diff":
            if patch:
                sys.stdout.write(patch)
            return 0 if clean else 1
        if args.mode == "validate":
            if not clean:
                sys.stderr.write(patch)
                return 1
            print(f"ok: {root} manifests are in sync")
            return 0
    except (ValueError, OSError, json.JSONDecodeError) as exc:
        print(f"manifest-forge: {exc}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
