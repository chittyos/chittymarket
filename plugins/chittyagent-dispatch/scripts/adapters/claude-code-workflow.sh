#!/usr/bin/env bash
# claude-code-workflow.sh — project a canonical workflow definition to a Claude Code
# plugin workflow script (plugins/<plugin>/workflows/<name>.js), invoked from any
# session as Workflow({name: "<plugin>:<name>"}).
#
# Usage:
#   claude-code-workflow.sh <canonical-path> <output-path>
#
# Canonical shape (canonical/workflows/<name>.md, kind: workflow):
#   ---
#   name: <name>
#   kind: workflow
#   description: |
#     <prose>
#   plugin: <home-plugin>
#   runtimes: [claude-code]
#   ---
#   <prose explaining the design — NOT projected>
#
#   ````js
#   export const meta = { name: '<name>', ... }
#   ...script body...
#   ````
#
# Why markdown + one fenced block rather than a bare .js canonical: every canonical
# discoverer (dispatch.sh, lib/audit.py, scripts/market-reconcile.py,
# scripts/check-agent-identity.py) globs *.md and reads YAML frontmatter for
# kind/plugin/runtimes/identity/overlay. A .js canonical would need a second
# metadata parser in each of them.
#
# Contract:
#   - Exactly ONE fenced block whose info string is `js` or `javascript`. The fence
#     may be ``` or longer (use ```` because workflow scripts contain backticks);
#     it closes on a line of the SAME fence. Zero or several blocks is an error.
#   - The block is written verbatim, nothing prepended: the Workflow host expects the
#     file to begin with `export const meta`, so the adapter enforces that too.
#   - Output always ends with exactly one newline — byte-stable for audit re-projection.
set -euo pipefail

canonical="${1:-}"
out="${2:-}"
[ -n "$canonical" ] && [ -n "$out" ] || { echo "usage: $0 <canonical-path> <output-path>" >&2; exit 2; }
[ -f "$canonical" ] || { echo "canonical not found: $canonical" >&2; exit 2; }

mkdir -p "$(dirname "$out")"

python3 - "$canonical" "$out" <<'PY'
import sys, re, yaml

canonical_path, out_path = sys.argv[1], sys.argv[2]
src = open(canonical_path, encoding="utf-8").read()

m = re.match(r"^---\n(.*?\n)---\n(.*)$", src, re.DOTALL)
if not m:
    sys.exit(f"no frontmatter in {canonical_path}")
try:
    fm = yaml.safe_load(m.group(1)) or {}
except yaml.YAMLError as e:
    sys.exit(f"canonical frontmatter is not valid YAML: {e}")
if not isinstance(fm, dict):
    sys.exit(f"{canonical_path}: frontmatter must be a mapping")
for req in ("name", "description"):
    if not fm.get(req):
        sys.exit(f"canonical missing required field: {req}")
if str(fm.get("kind", "")).strip() != "workflow":
    sys.exit(f"{canonical_path}: kind must be 'workflow' for this adapter, got {fm.get('kind')!r}")

body = m.group(2)
blocks = []
lines = body.split("\n")
i = 0
while i < len(lines):
    open_m = re.match(r"^(`{3,})\s*([A-Za-z0-9_-]*)\s*$", lines[i])
    if open_m:
        fence, info = open_m.group(1), open_m.group(2).lower()
        j = i + 1
        while j < len(lines) and lines[j].rstrip() != fence:
            j += 1
        if j >= len(lines):
            sys.exit(f"{canonical_path}: unterminated {fence} fence opened at body line {i + 1}")
        if info in ("js", "javascript"):
            blocks.append("\n".join(lines[i + 1:j]))
        i = j + 1
        continue
    i += 1

if len(blocks) != 1:
    sys.exit(f"{canonical_path}: expected exactly one ```js fenced block, found {len(blocks)}")

script = blocks[0].strip("\n") + "\n"
if not script.startswith("export const meta"):
    sys.exit(f"{canonical_path}: workflow script must begin with `export const meta` (the Workflow host requires it)")

meta_name = re.search(r"^export const meta\s*=\s*\{\s*name:\s*['\"]([^'\"]+)['\"]", script, re.M)
if not meta_name or meta_name.group(1) != fm["name"]:
    sys.exit(f"{canonical_path}: meta.name {meta_name.group(1) if meta_name else None!r} != frontmatter name {fm['name']!r}")

with open(out_path, "w", encoding="utf-8") as f:
    f.write(script)
PY

echo "[claude-code-workflow] projected $canonical -> $out"
