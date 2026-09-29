#!/usr/bin/env bash
# claude-code-output-style.sh — project a canonical output-style definition to
# Claude Code's output-styles/ format.
#
# Usage:
#   claude-code-output-style.sh <canonical-path> <output-path>
#
# Behavior:
#   - Output-style files are plain markdown with NO required frontmatter (the
#     Claude Code harness auto-loads output-styles/*.md as body text; see
#     ~/.claude/output-styles/no-smoke-analyst.md for the verified baseline).
#   - Unlike claude-code-agent.sh, this adapter emits ONLY the body: canonical
#     frontmatter (name, description, kind, classification, runtimes, plugin,
#     canon_uri, capability_id, overlay, ...) is dispatch/governance metadata
#     the harness does not expect and must not see.
#   - Still validates `name` + `description` are present so a malformed
#     canonical fails loudly at sync time instead of projecting silently.
#   - Deterministic: same canonical bytes -> same projected bytes, every run
#     (audit.py's reproject_sha depends on this).
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
    sys.exit(f"canonical frontmatter is not valid YAML: {e}")

body = m.group(2).lstrip("\n")

for req in ("name", "description"):
    if not fm.get(req):
        sys.exit(f"canonical missing required field: {req}")

# Body only. No frontmatter in the projection — output styles are plain
# markdown with no required (or expected) frontmatter block.
if not body.endswith("\n"):
    body += "\n"
open(out_path, "w", encoding="utf-8").write(body)
PY

echo "[claude-code-output-style] projected $canonical -> $out"
