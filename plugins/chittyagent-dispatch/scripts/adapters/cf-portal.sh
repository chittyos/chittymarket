#!/usr/bin/env bash
# cf-portal.sh — project a canonical MCP portal definition (kind: mcp-portal-server or
# mcp-portal) into the JSON the Cloudflare MCP-portal builder reads.
#
# Usage:
#   cf-portal.sh <canonical-path> <output-path>
#
# The output is the canonical frontmatter as JSON (key order preserved, 2-space indent).
# Idempotent and deterministic. It validates the shape the plan script relies on, so a
# malformed definition fails at sync time rather than at plan time.
set -euo pipefail

canonical="${1:-}"
out="${2:-}"
[ -n "$canonical" ] && [ -n "$out" ] || { echo "usage: $0 <canonical-path> <output-path>" >&2; exit 2; }
[ -f "$canonical" ] || { echo "canonical not found: $canonical" >&2; exit 2; }

mkdir -p "$(dirname "$out")"

python3 - "$canonical" "$out" <<'PY'
import sys, re, json, yaml

canonical_path, out_path = sys.argv[1], sys.argv[2]
src = open(canonical_path, encoding="utf-8").read()
m = re.match(r"^---\n(.*?\n)---\n", src, re.DOTALL)
if not m:
    sys.exit(f"no frontmatter in {canonical_path}")
try:
    fm = yaml.safe_load(m.group(1)) or {}
except yaml.YAMLError as e:
    sys.exit(f"canonical frontmatter is not valid YAML: {e}")

kind = fm.get("kind")
required = {
    "mcp-portal-server": ["name", "server_id", "upstream", "auth", "classification", "portals", "tools", "status"],
    "mcp-portal": ["name", "portal_id", "hostname", "access_app", "status"],
}
if kind not in required:
    sys.exit(f"unsupported kind for cf-portal: {kind!r}")
missing = [k for k in required[kind] if k not in fm]
if missing:
    sys.exit(f"canonical missing required field(s): {', '.join(missing)}")

with open(out_path, "w", encoding="utf-8") as f:
    json.dump(fm, f, indent=2, ensure_ascii=False)
    f.write("\n")
PY
