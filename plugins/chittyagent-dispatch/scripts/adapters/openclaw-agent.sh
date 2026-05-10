#!/usr/bin/env bash
# openclaw-agent.sh — project a canonical agent definition to an OpenClaw YAML agent.
#
# Usage:
#   openclaw-agent.sh <canonical-path> <output-path>
#
# Behavior:
#   - Strict YAML round-trip via PyYAML. Canonical descriptions MUST use a block
#     scalar (`description: |`) — see canonical/README.md.
#   - Emits a single YAML document (no Markdown frontmatter wrapper); OpenClaw
#     consumes pure YAML.
#   - Top-level fields: name, description, instructions (markdown body),
#     plus any runtime_overrides.openclaw additions.
#   - Strips canonical-only and Claude/Codex-only keys.
#   - Idempotent: stable key order, no timestamps in output.
set -euo pipefail

canonical="${1:-}"
out="${2:-}"
[ -n "$canonical" ] && [ -n "$out" ] || { echo "usage: $0 <canonical-path> <output-path>" >&2; exit 2; }
[ -f "$canonical" ] || { echo "canonical not found: $canonical" >&2; exit 2; }

mkdir -p "$(dirname "$out")"

python3 - "$canonical" "$out" <<'PY'
import sys, re, yaml

canonical_path, out_path = sys.argv[1], sys.argv[2]
src = open(canonical_path, "r", encoding="utf-8").read()

m = re.match(r"^---\n(.*?\n)---\n(.*)$", src, re.DOTALL)
if not m:
    sys.exit(f"no frontmatter in {canonical_path}")

try:
    fm = yaml.safe_load(m.group(1)) or {}
except yaml.YAMLError as e:
    sys.exit(
        f"canonical frontmatter is not valid YAML: {e}\n"
        f"Hint: descriptions with prose/colons/<example> blocks must use a block scalar:\n"
        f"  description: |\n"
        f"    Your prose here..."
    )
body = m.group(2).lstrip("\n").rstrip() + "\n"

for req in ("name", "description"):
    if not fm.get(req):
        sys.exit(f"canonical missing required field: {req}")

CANONICAL_ONLY = {"kind", "classification", "runtimes", "plugin", "runtime_overrides"}
CLAUDE_CODE_ONLY = {"model", "color", "tools"}
STRIP = CANONICAL_ONLY | CLAUDE_CODE_ONLY

overrides = (fm.get("runtime_overrides") or {}).get("openclaw") or {}
projected = {k: v for k, v in fm.items() if k not in STRIP}
projected["instructions"] = body
projected.update(overrides)

# Stable order: name, description, instructions, then any overrides last.
preferred = ["name", "description", "instructions"]
ordered = {k: projected[k] for k in preferred if k in projected}
for k, v in projected.items():
    if k not in ordered:
        ordered[k] = v

class BlockStr(str):
    pass

def block_str_representer(dumper, data):
    return dumper.represent_scalar("tag:yaml.org,2002:str", data, style="|")

yaml.add_representer(BlockStr, block_str_representer)

for k, v in list(ordered.items()):
    if isinstance(v, str) and "\n" in v:
        ordered[k] = BlockStr(v)

doc = yaml.dump(ordered, sort_keys=False, default_flow_style=False, allow_unicode=True, width=100000).rstrip() + "\n"
open(out_path, "w", encoding="utf-8").write(doc)
PY

echo "[openclaw-agent] projected $canonical -> $out"
