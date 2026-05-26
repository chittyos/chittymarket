#!/usr/bin/env bash
# claude-code-mcp.sh — project a canonical MCP-server definition into a
# plugin's .mcp.json (Claude Code MCP config format).
#
# Usage:
#   claude-code-mcp.sh <canonical-path> <output-path>
#
# Canonical frontmatter shape (kind: mcp-server):
#   ---
#   name: <server-name>
#   kind: mcp-server
#   description: |
#     <prose>
#   plugin: <home-plugin>
#   runtimes: [claude-code]
#   mcp:
#     command: /bin/sh
#     args: [-lc, "exec npx -y mcp-remote https://example.com/mcp"]
#     env: {}
#   ---
#
# The adapter merges the `mcp.*` fields into plugins/<plugin>/.mcp.json under
# mcpServers.<name>, preserving any other servers already present.
# Idempotent.
set -euo pipefail

canonical="${1:-}"
out="${2:-}"
[ -n "$canonical" ] && [ -n "$out" ] || { echo "usage: $0 <canonical-path> <output-path>" >&2; exit 2; }
[ -f "$canonical" ] || { echo "canonical not found: $canonical" >&2; exit 2; }

mkdir -p "$(dirname "$out")"

python3 - "$canonical" "$out" <<'PY'
import sys, re, json, os, yaml

canonical_path, out_path = sys.argv[1], sys.argv[2]
src = open(canonical_path, encoding="utf-8").read()

m = re.match(r"^---\n(.*?\n)---\n(.*)$", src, re.DOTALL)
if not m:
    sys.exit(f"no frontmatter in {canonical_path}")

try:
    fm = yaml.safe_load(m.group(1)) or {}
except yaml.YAMLError as e:
    sys.exit(f"canonical frontmatter is not valid YAML: {e}")

name = fm.get("name")
if not name:
    sys.exit("canonical missing required field: name")

mcp = fm.get("mcp") or {}
if not mcp or not isinstance(mcp, dict):
    sys.exit("canonical missing mcp: block (command/args/env)")

# Read existing .mcp.json if present, else start fresh.
if os.path.exists(out_path):
    with open(out_path, encoding="utf-8") as f:
        existing = json.load(f)
else:
    existing = {"mcpServers": {}}

servers = existing.setdefault("mcpServers", {})
# Merge canonical entry; do not destroy unrelated servers.
servers[name] = {
    "command": mcp.get("command"),
    "args": mcp.get("args", []),
    "env": mcp.get("env", {}),
}
# Drop None values to keep output clean.
servers[name] = {k: v for k, v in servers[name].items() if v is not None}

# Sort server keys for stable output.
existing["mcpServers"] = {k: servers[k] for k in sorted(servers)}

with open(out_path, "w", encoding="utf-8") as f:
    json.dump(existing, f, indent=2, sort_keys=False)
    f.write("\n")
PY

echo "[claude-code-mcp] projected $canonical -> $out"
