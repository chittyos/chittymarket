#!/usr/bin/env bash
# claude-skills.sh — project a canonical `kind: tool` definition into a
# Claude Skills app descriptor (JSON, per MCP tool annotation schema).
#
# Usage:
#   claude-skills.sh <canonical-path> <output-path>
#
# Canonical frontmatter shape (kind: tool) — see canonical/tools/README.md
# (or the first concrete entry: canonical/tools/ch1tty-search.md):
#
#   ---
#   name: <tool-slug>
#   canon_uri: chittycanon://core/services/chittymarket#tools/<n>
#   description: |
#     <prose>
#   kind: tool
#   plugin: <home-plugin>
#   runtimes: [claude-skills]
#   safety_class: read_only | idempotent | reversible | destructive
#   world_class: open_world | closed_world
#   visibility: public | private | org
#   target_visibility: [model, app]            # MCP _meta.ui.visibility
#   input_schema: { type: object, properties: {...} }
#   output_schema: { type: object, properties: {...} }
#   file_params: [ ... ]                       # _meta["openai/fileParams"]
#   ---
#
# Output (Claude Skills app descriptor — also a valid MCP tool descriptor):
#
#   {
#     "name": "<tool-slug>",
#     "description": "<single-line description>",
#     "inputSchema": { ... },
#     "outputSchema": { ... },
#     "annotations": {
#       "readOnlyHint": <bool>,
#       "openWorldHint": <bool>,
#       "destructiveHint": <bool>          # only when readOnlyHint=false
#     },
#     "_meta": {
#       "ui": { "visibility": [...] },
#       "openai/fileParams": [...],        # only when file_params non-empty
#       "chittycanon/canon_uri": "...",
#       "chittycanon/visibility": "..."
#     }
#   }
#
# Safety-class → MCP annotation translation:
#   read_only    → readOnlyHint=true,  destructiveHint=false (omitted if no-op)
#   idempotent   → readOnlyHint=false, destructiveHint=false
#   reversible   → readOnlyHint=false, destructiveHint=false
#   destructive  → readOnlyHint=false, destructiveHint=true
#
# World-class → openWorldHint:
#   open_world   → openWorldHint=true
#   closed_world → openWorldHint=false
#
# Strict: required fields missing => exit 2. Output is deterministic
# (sorted keys, no timestamps) so re-runs produce zero diff.
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

m = re.match(r"^---\n(.*?\n)---\n(.*)$", src, re.DOTALL)
if not m:
    sys.exit(f"no frontmatter in {canonical_path}")

try:
    fm = yaml.safe_load(m.group(1)) or {}
except yaml.YAMLError as e:
    sys.exit(f"canonical frontmatter is not valid YAML: {e}")

# ---- Required field validation ----
for req in ("name", "description", "kind", "safety_class", "world_class",
            "input_schema", "output_schema"):
    if fm.get(req) is None:
        sys.exit(f"canonical missing required field: {req}")

if fm.get("kind") != "tool":
    sys.exit(f"claude-skills adapter requires kind=tool, got kind={fm.get('kind')!r}")

SAFETY_MAP = {
    "read_only":   {"readOnlyHint": True,  "destructiveHint": False},
    "idempotent":  {"readOnlyHint": False, "destructiveHint": False},
    "reversible":  {"readOnlyHint": False, "destructiveHint": False},
    "destructive": {"readOnlyHint": False, "destructiveHint": True},
}
WORLD_MAP = {
    "open_world":   True,
    "closed_world": False,
}

safety = fm["safety_class"]
world = fm["world_class"]
if safety not in SAFETY_MAP:
    sys.exit(f"invalid safety_class {safety!r}; must be one of {sorted(SAFETY_MAP)}")
if world not in WORLD_MAP:
    sys.exit(f"invalid world_class {world!r}; must be one of {sorted(WORLD_MAP)}")

annotations = {
    "readOnlyHint":  SAFETY_MAP[safety]["readOnlyHint"],
    "openWorldHint": WORLD_MAP[world],
}
# destructiveHint only meaningful when readOnlyHint=false (per MCP spec),
# but we emit it explicitly for read_only too as False so downstream
# clients don't have to infer. This matches the prompt's translation table.
annotations["destructiveHint"] = SAFETY_MAP[safety]["destructiveHint"]

# Description: collapse multi-line block scalars to a single line for the
# wire descriptor (MCP descriptors expect a string, not a paragraph).
desc_raw = fm["description"]
if not isinstance(desc_raw, str):
    sys.exit("description must be a string (use `description: |` block scalar)")
desc_oneline = " ".join(desc_raw.split()).strip()

# _meta vocabulary
meta = {}
tv = fm.get("target_visibility")
if tv:
    if not isinstance(tv, list) or not all(isinstance(x, str) for x in tv):
        sys.exit("target_visibility must be a list of strings")
    meta["ui"] = {"visibility": list(tv)}

fp = fm.get("file_params") or []
if fp:
    if not isinstance(fp, list) or not all(isinstance(x, str) for x in fp):
        sys.exit("file_params must be a list of strings")
    meta["openai/fileParams"] = list(fp)

canon_uri = fm.get("canon_uri")
if canon_uri:
    meta["chittycanon/canon_uri"] = canon_uri

vis = fm.get("visibility")
if vis:
    meta["chittycanon/visibility"] = vis

descriptor = {
    "name": fm["name"],
    "description": desc_oneline,
    "inputSchema": fm["input_schema"],
    "outputSchema": fm["output_schema"],
    "annotations": annotations,
}
if meta:
    descriptor["_meta"] = meta

# Deterministic output — sort_keys=True at every level.
out_json = json.dumps(descriptor, indent=2, sort_keys=True) + "\n"
open(out_path, "w", encoding="utf-8").write(out_json)
PY

echo "[claude-skills] projected $canonical -> $out"
