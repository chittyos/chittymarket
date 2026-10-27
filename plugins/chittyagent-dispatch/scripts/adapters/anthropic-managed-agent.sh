#!/usr/bin/env bash
# anthropic-managed-agent.sh — project a canonical agent into a provider intent.
#
# Pure projection only. This script never calls Anthropic and never handles a
# provider credential. Runtime mutation is performed separately through the
# authenticated chittyagent-dispatch runtime seam.
set -euo pipefail

canonical="${1:-}"
out="${2:-}"
[ -n "$canonical" ] && [ -n "$out" ] || { echo "usage: $0 <canonical-path> <output-path>" >&2; exit 2; }
[ -f "$canonical" ] || { echo "canonical not found: $canonical" >&2; exit 2; }

mkdir -p "$(dirname "$out")"

python3 - "$canonical" "$out" <<'PY'
import json, re, sys, yaml

canonical_path, out_path = sys.argv[1], sys.argv[2]
src = open(canonical_path, encoding="utf-8").read()
m = re.match(r"^---\n(.*?\n)---\n(.*)$", src, re.S)
if not m:
    sys.exit(f"no frontmatter in {canonical_path}")

fm = yaml.safe_load(m.group(1)) or {}
body = m.group(2).lstrip("\n").rstrip() + "\n"
overrides = (fm.get("runtime_overrides") or {}).get("anthropic-managed") or {}

name = overrides.get("name") or fm.get("name")
canonical_id = (
    overrides.get("canonical_agent_id")
    or fm.get("canon_uri")
    or fm.get("canonical_agent_id")
)
model = overrides.get("model") or fm.get("model")
if not name:
    sys.exit("canonical missing required field: name")
if not canonical_id:
    sys.exit("anthropic-managed projection requires canon_uri or canonical_agent_id")
if not model:
    sys.exit("anthropic-managed projection requires model or runtime_overrides.anthropic-managed.model")

metadata = dict(overrides.get("metadata") or {})
metadata.setdefault("chittyos_source", canonical_path)

spec = {
    "canonicalAgentId": str(canonical_id),
    "name": str(name),
    "model": model,
    "description": overrides.get("description", fm.get("description")),
    "system": overrides.get("system", body),
    "tools": overrides.get("tools", []),
    "mcpServers": overrides.get("mcp_servers", []),
    "skills": overrides.get("skills", []),
    "multiagent": overrides.get("multiagent"),
    "metadata": metadata,
}
# Omit only nullable fields where absence is semantically distinct from clearing.
if spec["description"] is None:
    spec.pop("description")
if spec["multiagent"] is None:
    spec.pop("multiagent")

doc = {
    "runtime": "anthropic-managed",
    "spec": spec,
}
open(out_path, "w", encoding="utf-8").write(
    json.dumps(doc, indent=2, sort_keys=True, ensure_ascii=False) + "\n"
)
PY

echo "[anthropic-managed-agent] projected $canonical -> $out"
