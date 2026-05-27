#!/usr/bin/env bash
# openclaw-smoke.sh — runtime load test for projected OpenClaw YAML agent files.
#
# Purpose (adversarial review #4):
#   Every plugins/<plug>/openclaw-agents/<name>.yaml is a projection from a
#   canonical agent. Without actually loading them in an OpenClaw runtime we
#   cannot claim universality. This script attempts a real load, falling
#   back to a schema-mimic validator if the runtime is absent.
#
# Strategy:
#   1. If an `openclaw` CLI is on PATH with a `validate` / `load` subcommand,
#      use it. (Currently the OpenClaw runtime is not publicly distributed as
#      a CLI — kept as a hook for the future.)
#   2. Fallback: schema validation mirroring the openclaw-agent.sh adapter:
#        - file is a single YAML document
#        - top-level is a mapping
#        - required keys: name (lowercase-hyphen), description (non-empty),
#          instructions (non-empty markdown)
#        - filename stem matches `name`
#        - no leaked canonical-only keys (kind, classification, runtimes,
#          plugin, runtime_overrides) and no Claude-only keys (model, color,
#          tools) — those should be stripped by the adapter.
#
# Exit code: 0 if all agents load; non-zero if any fail.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PLUGINS_DIR="$REPO_DIR/plugins"

# ---------- runtime detection ----------
HAVE_OPENCLAW_RUNTIME=0
OPENCLAW_LOAD_MODE="schema-only"
if command -v openclaw >/dev/null 2>&1; then
  OC_VERSION="$(openclaw --version 2>/dev/null | head -1 || echo unknown)"
  # If/when `openclaw validate <file>` ships, flip the flag and branch.
  echo "[openclaw-smoke] openclaw CLI present ($OC_VERSION) — no validate subcommand exposed; falling back to schema-mimic loader"
else
  echo "[openclaw-smoke] openclaw CLI not on PATH — falling back to schema-mimic loader"
fi
echo "[openclaw-smoke] mode: $OPENCLAW_LOAD_MODE"
echo ""

# ---------- validator ----------
PASS=0
FAIL=0
FAILED_LIST=()

validate_agent() {
  local agent_path="$1"
  local agent_file
  local agent_stem
  agent_file="$(basename "$agent_path")"
  agent_stem="${agent_file%.yaml}"

  python3 - "$agent_path" "$agent_stem" <<'PY'
import sys, re, yaml

path = sys.argv[1]
stem = sys.argv[2]

try:
    src = open(path, "r", encoding="utf-8").read()
except OSError as e:
    print(f"ERROR: cannot read file: {e}")
    sys.exit(1)

if not src.strip():
    print("ERROR: file is empty")
    sys.exit(1)

# Must be a single YAML document — no Markdown frontmatter wrapper.
if src.lstrip().startswith("---\n") and src.count("\n---\n") >= 1:
    # PyYAML tolerates a leading `---`, but openclaw-agent.sh emits a bare
    # mapping. A bare `---` is fine; a Markdown frontmatter wrapper (`---`
    # then prose) would fail because the body is not valid YAML.
    pass

try:
    doc = yaml.safe_load(src)
except yaml.YAMLError as e:
    print(f"ERROR: YAML parse failed: {e}")
    sys.exit(1)

if not isinstance(doc, dict):
    print(f"ERROR: top-level must be a YAML mapping, got {type(doc).__name__}")
    sys.exit(1)

# Required keys (per openclaw-agent.sh adapter contract).
for req in ("name", "description", "instructions"):
    if req not in doc:
        print(f"ERROR: missing required key '{req}'")
        sys.exit(1)
    if not isinstance(doc[req], str) or not doc[req].strip():
        print(f"ERROR: key '{req}' must be non-empty string")
        sys.exit(1)

# Name must match filename stem and follow convention.
name = doc["name"].strip()
if name != stem:
    print(f"ERROR: name '{name}' does not match filename stem '{stem}'")
    sys.exit(1)
if not re.match(r"^[a-z0-9][a-z0-9-]*[a-z0-9]$", name):
    print(f"ERROR: name '{name}' violates convention (lowercase alnum + hyphens)")
    sys.exit(1)

# Description sanity.
if len(doc["description"].strip()) < 20:
    print(f"ERROR: description too short ({len(doc['description'].strip())} chars)")
    sys.exit(1)

# Instructions must contain markdown — at minimum a non-trivial body.
if len(doc["instructions"].strip()) < 40:
    print(f"ERROR: instructions too short ({len(doc['instructions'].strip())} chars) — likely missing body")
    sys.exit(1)

# Verify adapter stripped canonical-only and claude-only keys.
LEAKED_CANONICAL = {"kind", "classification", "runtimes", "plugin", "runtime_overrides"}
LEAKED_CLAUDE   = {"model", "color", "tools"}
leaked = sorted((LEAKED_CANONICAL | LEAKED_CLAUDE) & set(doc.keys()))
if leaked:
    print(f"ERROR: leaked non-openclaw keys (adapter bug): {leaked}")
    sys.exit(1)

print("OK")
PY
}

echo "--- scanning $PLUGINS_DIR for openclaw agent YAML files ---"
mapfile -t AGENT_FILES < <(find "$PLUGINS_DIR" -path "*/openclaw-agents/*.yaml" -type f | sort)
TOTAL=${#AGENT_FILES[@]}
echo "[openclaw-smoke] found $TOTAL projected openclaw agents"
echo ""

if [ "$TOTAL" -eq 0 ]; then
  echo "[openclaw-smoke] no openclaw agents to validate — exiting OK"
  exit 0
fi

for agent_file in "${AGENT_FILES[@]}"; do
  rel="${agent_file#$REPO_DIR/}"
  result="$(validate_agent "$agent_file" 2>&1)"
  if [ "$result" = "OK" ]; then
    echo "PASS  $rel"
    PASS=$((PASS + 1))
  else
    echo "FAIL  $rel"
    echo "       $result" | head -1
    FAILED_LIST+=("$rel: $result")
    FAIL=$((FAIL + 1))
  fi
done

echo ""
echo "=== openclaw-smoke summary ==="
echo "  passed: $PASS / $TOTAL"
echo "  failed: $FAIL / $TOTAL"
echo "  mode:   $OPENCLAW_LOAD_MODE"

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "--- failures ---"
  for line in "${FAILED_LIST[@]}"; do
    echo "  - $line"
  done
  exit 1
fi

exit 0
