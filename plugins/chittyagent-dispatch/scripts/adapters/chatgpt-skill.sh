#!/usr/bin/env bash
# chatgpt-skill.sh — project a canonical skill into a native ChatGPT Skill package.
#
# Usage:
#   chatgpt-skill.sh <canonical-path> <output-skill-md>
#
# Produces:
#   <package>/SKILL.md
#   <package>/agents/openai.yaml
#   plus scripts/references/assets copied from the Claude Code package when present.
set -euo pipefail

canonical="${1:-}"
out="${2:-}"
[ -n "$canonical" ] && [ -n "$out" ] || { echo "usage: $0 <canonical-path> <output-skill-md>" >&2; exit 2; }
[ -f "$canonical" ] || { echo "canonical not found: $canonical" >&2; exit 2; }

mkdir -p "$(dirname "$out")/agents"

python3 - "$canonical" "$out" <<'PY'
import json
import os
import re
import shutil
import sys
from pathlib import Path

import yaml

canonical_path = Path(sys.argv[1])
out_path = Path(sys.argv[2])
src = canonical_path.read_text(encoding="utf-8")

m = re.match(r"^---\n(.*?\n)---\n(.*)$", src, re.DOTALL)
if not m:
    sys.exit(f"no frontmatter in {canonical_path}")

fm = yaml.safe_load(m.group(1)) or {}
body = m.group(2).lstrip("\n")
name = str(fm.get("name") or "").strip()
description = fm.get("description")
if not name or not isinstance(description, str) or not description.strip():
    sys.exit("canonical skill requires name and description")

# ChatGPT Skill frontmatter is intentionally narrower than ChittyMarket canonical
# frontmatter. Preserve Chitty identity under supported metadata instead of
# leaking canonical-only keys such as canon_uri at the top level.
canon_uri = fm.get("canon_uri") or fm.get("canonical_uri")
skill_lines = [
    "---",
    f"name: {name}",
    "description: |",
]
skill_lines.extend(f"  {line}" for line in description.strip().splitlines())
if canon_uri:
    skill_lines.extend([
        "metadata:",
        f"  canon_uri: {json.dumps(str(canon_uri), ensure_ascii=False)}",
    ])
skill_lines.extend(["---", "", body])
out_path.write_text("\n".join(skill_lines), encoding="utf-8")

# Copy supporting package resources from the governed Claude Code projection.
# SKILL.md and agents/ are regenerated for this runtime; everything else is data
# shared by the capability and copied deterministically.
parts = out_path.parts
try:
    i = parts.index("chatgpt-skills")
    source_dir = Path(*parts[:i], "skills", parts[i + 1])
except (ValueError, IndexError):
    source_dir = None

if source_dir and source_dir.exists():
    for child in source_dir.iterdir():
        if child.name in {"SKILL.md", "SKILL.md.disabled", "agents"}:
            continue
        dest = out_path.parent / child.name
        if dest.exists():
            if dest.is_dir():
                shutil.rmtree(dest)
            else:
                dest.unlink()
        if child.is_dir():
            shutil.copytree(child, dest)
        else:
            shutil.copy2(child, dest)

override = ((fm.get("runtime_overrides") or {}).get("chatgpt") or {})
interface = dict(override.get("interface") or {})
policy = dict(override.get("policy") or {})

display_name = interface.get("display_name") or name.replace("-", " ").title()
short_description = interface.get("short_description")
if not short_description:
    short_description = " ".join(description.strip().split())
    if len(short_description) > 180:
        short_description = short_description[:177].rstrip() + "..."

lines = [
    "interface:",
    f"  display_name: {json.dumps(str(display_name), ensure_ascii=False)}",
    f"  short_description: {json.dumps(str(short_description), ensure_ascii=False)}",
]
primary_color = interface.get("primary_color")
if primary_color:
    lines.append(f"  primary_color: {json.dumps(str(primary_color), ensure_ascii=False)}")

for key in ("icon_small", "icon_large"):
    value = interface.get(key)
    if value and (out_path.parent / str(value)).is_file():
        lines.append(f"  {key}: {json.dumps(str(value), ensure_ascii=False)}")

products = policy.get("products") or ["chatgpt"]
lines.append("policy:")
lines.append("  products:")
for product in products:
    lines.append(f"  - {json.dumps(str(product), ensure_ascii=False)}")
implicit = policy.get("allow_implicit_invocation", True)
lines.append(f"  allow_implicit_invocation: {'true' if implicit else 'false'}")

(out_path.parent / "agents" / "openai.yaml").write_text(
    "\n".join(lines) + "\n",
    encoding="utf-8",
)
PY

echo "[chatgpt-skill] projected $canonical -> $out"
