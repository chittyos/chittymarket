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
skill_fm = {
    "name": name,
    "description": description.strip(),
}
canon_uri = fm.get("canon_uri") or fm.get("canonical_uri")
if canon_uri:
    skill_fm["metadata"] = {"canon_uri": str(canon_uri)}

class BlockStr(str):
    pass

def block_str_representer(dumper, data):
    return dumper.represent_scalar("tag:yaml.org,2002:str", data, style="|")

yaml.add_representer(BlockStr, block_str_representer)
if "\n" in skill_fm["description"]:
    skill_fm["description"] = BlockStr(skill_fm["description"])

skill_yaml = yaml.dump(
    skill_fm,
    sort_keys=False,
    default_flow_style=False,
    allow_unicode=True,
    width=100000,
).rstrip() + "\n"
out_path.write_text(f"---\n{skill_yaml}---\n\n{body}", encoding="utf-8")

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

display_name = interface.pop("display_name", None) or name.replace("-", " ").title()
short_description = interface.pop("short_description", None)
if not short_description:
    short_description = " ".join(description.strip().split())
    if len(short_description) > 180:
        short_description = short_description[:177].rstrip() + "..."

openai = {
    "interface": {
        "display_name": display_name,
        "short_description": short_description,
        **interface,
    },
    "policy": {
        "products": policy.pop("products", ["chatgpt"]),
        "allow_implicit_invocation": policy.pop("allow_implicit_invocation", True),
        **policy,
    },
}

# Never emit dangling icon references. Runtime overrides may request icons only
# when the projected asset exists in the package.
for key in ("icon_small", "icon_large"):
    value = openai["interface"].get(key)
    if value and not (out_path.parent / str(value)).exists():
        openai["interface"].pop(key, None)

(out_path.parent / "agents" / "openai.yaml").write_text(
    yaml.dump(openai, sort_keys=False, allow_unicode=True, width=100000),
    encoding="utf-8",
)
PY

echo "[chatgpt-skill] projected $canonical -> $out"
