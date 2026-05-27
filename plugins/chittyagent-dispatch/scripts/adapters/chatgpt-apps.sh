#!/usr/bin/env bash
# chatgpt-apps.sh — project a canonical `kind: tool` definition into a
# ChatGPT Apps SDK tool descriptor (JSON, per OpenAI Apps SDK + MCP spec).
#
# Usage:
#   chatgpt-apps.sh <canonical-path> <output-path>
#
# ChatGPT Apps SDK descriptor shape:
#
#   {
#     "name": "<tool-slug>",
#     "description": "<single-line description>",
#     "inputSchema": { ... },
#     "outputSchema": { ... },
#     "annotations": {
#       "readOnlyHint": <bool>,
#       "openWorldHint": <bool>,
#       "destructiveHint": <bool>
#     },
#     "_meta": {
#       "ui": { "visibility": [...], "resourceUri": "<uri>" },
#       "openai/outputTemplate": "<uri>",                 # alias of ui.resourceUri
#       "openai/widgetDescription": "<prose>",
#       "openai/widgetCSP": { "connectDomains":[...], "resourceDomains":[...], "frameDomains":[...], "redirect_domains":[...] },
#       "openai/widgetDomain": "<domain>",
#       "openai/fileParams": [ "...field_name..." ],
#       "openai/toolInvocation/invoking": "<status text>",
#       "openai/toolInvocation/invoked":  "<status text>",
#       "openai/locale": "<bcp47>",
#       "chittycanon/canon_uri": "...",
#       "chittycanon/visibility": "..."
#     }
#   }
#
# Optional canonical frontmatter (additive to PR #48 schema):
#
#   chatgpt:
#     widget_template:    "ui://widget/foo.html"
#     widget_description: "..."
#     widget_csp:
#       connectDomains:   ["https://api.example.com"]
#       resourceDomains:  ["https://cdn.example.com"]
#       frameDomains:     []
#       redirect_domains: []
#     widget_domain: "https://app.example.com"
#     invocation:
#       invoking: "Searching..."
#       invoked:  "Done."
#     locale_default: "en"
#
# All `chatgpt.*` fields are optional. The adapter works whether they are
# present or absent. Safety-class / world-class translation mirrors
# claude-skills.sh (same MCP annotation vocabulary).
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
    sys.exit(f"chatgpt-apps adapter requires kind=tool, got kind={fm.get('kind')!r}")

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
    "destructiveHint": SAFETY_MAP[safety]["destructiveHint"],
}

# Description: collapse multi-line block scalars to a single line.
desc_raw = fm["description"]
if not isinstance(desc_raw, str):
    sys.exit("description must be a string (use `description: |` block scalar)")
desc_oneline = " ".join(desc_raw.split()).strip()

# ---- _meta vocabulary ----
meta = {}
ui = {}

tv = fm.get("target_visibility")
if tv:
    if not isinstance(tv, list) or not all(isinstance(x, str) for x in tv):
        sys.exit("target_visibility must be a list of strings")
    ui["visibility"] = list(tv)

# ChatGPT-specific extension block (all optional).
chatgpt = fm.get("chatgpt") or {}
if chatgpt and not isinstance(chatgpt, dict):
    sys.exit("chatgpt extension block must be a mapping")

widget_template = chatgpt.get("widget_template")
if widget_template is not None:
    if not isinstance(widget_template, str) or not widget_template.strip():
        sys.exit("chatgpt.widget_template must be a non-empty string (e.g. ui://widget/foo.html)")
    ui["resourceUri"] = widget_template
    meta["openai/outputTemplate"] = widget_template

widget_description = chatgpt.get("widget_description")
if widget_description is not None:
    if not isinstance(widget_description, str):
        sys.exit("chatgpt.widget_description must be a string")
    meta["openai/widgetDescription"] = widget_description

widget_csp = chatgpt.get("widget_csp")
if widget_csp is not None:
    if not isinstance(widget_csp, dict):
        sys.exit("chatgpt.widget_csp must be a mapping")
    csp_out = {}
    for key in ("connectDomains", "resourceDomains", "frameDomains", "redirect_domains"):
        if key in widget_csp:
            v = widget_csp[key]
            if not isinstance(v, list) or not all(isinstance(x, str) for x in v):
                sys.exit(f"chatgpt.widget_csp.{key} must be a list of strings")
            csp_out[key] = list(v)
    if csp_out:
        meta["openai/widgetCSP"] = csp_out

widget_domain = chatgpt.get("widget_domain")
if widget_domain is not None:
    if not isinstance(widget_domain, str) or not widget_domain.strip():
        sys.exit("chatgpt.widget_domain must be a non-empty string")
    meta["openai/widgetDomain"] = widget_domain

invocation = chatgpt.get("invocation")
if invocation is not None:
    if not isinstance(invocation, dict):
        sys.exit("chatgpt.invocation must be a mapping with optional `invoking`/`invoked`")
    if "invoking" in invocation:
        v = invocation["invoking"]
        if not isinstance(v, str):
            sys.exit("chatgpt.invocation.invoking must be a string")
        meta["openai/toolInvocation/invoking"] = v
    if "invoked" in invocation:
        v = invocation["invoked"]
        if not isinstance(v, str):
            sys.exit("chatgpt.invocation.invoked must be a string")
        meta["openai/toolInvocation/invoked"] = v

locale_default = chatgpt.get("locale_default")
if locale_default is not None:
    if not isinstance(locale_default, str) or not locale_default.strip():
        sys.exit("chatgpt.locale_default must be a non-empty BCP-47 string")
    meta["openai/locale"] = locale_default

# file_params shared with claude-skills adapter (canonical, not chatgpt-scoped).
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

if ui:
    meta["ui"] = ui

descriptor = {
    "name": fm["name"],
    "description": desc_oneline,
    "inputSchema": fm["input_schema"],
    "outputSchema": fm["output_schema"],
    "annotations": annotations,
}
if meta:
    descriptor["_meta"] = meta

out_json = json.dumps(descriptor, indent=2, sort_keys=True) + "\n"
open(out_path, "w", encoding="utf-8").write(out_json)
PY

echo "[chatgpt-apps] projected $canonical -> $out"
