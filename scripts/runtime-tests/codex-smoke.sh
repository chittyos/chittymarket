#!/usr/bin/env bash
# codex-smoke.sh — runtime load test for projected Codex SKILL.md files.
#
# Purpose (adversarial review #4):
#   The "universal projection" claim is unverified bytes until we actually
#   try to load each projection in its target runtime. This script does so
#   for every plugins/<plug>/codex-skills/<name>/SKILL.md.
#
# Strategy:
#   1. If the `codex` CLI is available and a real load command exists, use it.
#      (As of codex-cli 0.114.0 there is no `codex skills validate` subcommand,
#      so this path is currently a no-op stub — kept for future use.)
#   2. Fallback: strict schema validation that mimics codex's SKILL.md loader.
#      Real codex skills under ~/.codex/skills/* universally have:
#         - YAML frontmatter delimited by `---` lines
#         - `name` (lowercase-hyphen, matches dirname)
#         - `description` (non-empty string)
#         - non-empty markdown body
#         - frontmatter parses as valid YAML
#
# Exit code: 0 if all skills load; non-zero if any fail.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PLUGINS_DIR="$REPO_DIR/plugins"

# ---------- runtime detection ----------
HAVE_CODEX_RUNTIME=0
CODEX_LOAD_MODE="schema-only"
if command -v codex >/dev/null 2>&1; then
  CODEX_VERSION="$(codex --version 2>/dev/null | head -1 || echo unknown)"
  # No public `codex skills load` subcommand exists in 0.114.x. If/when one
  # ships, we flip HAVE_CODEX_RUNTIME=1 and add an invocation branch.
  echo "[codex-smoke] codex CLI present ($CODEX_VERSION) — no skill-load subcommand exposed; falling back to schema-mimic loader"
else
  echo "[codex-smoke] codex CLI not on PATH — falling back to schema-mimic loader"
fi
echo "[codex-smoke] mode: $CODEX_LOAD_MODE"
echo ""

# ---------- validator ----------
PASS=0
FAIL=0
FAILED_LIST=()

validate_skill() {
  local skill_path="$1"
  local skill_dir
  local skill_name
  skill_dir="$(dirname "$skill_path")"
  skill_name="$(basename "$skill_dir")"

  python3 - "$skill_path" "$skill_name" <<'PY'
import sys, re, yaml

path = sys.argv[1]
dir_name = sys.argv[2]

try:
    src = open(path, "r", encoding="utf-8").read()
except OSError as e:
    print(f"ERROR: cannot read file: {e}")
    sys.exit(1)

# Frontmatter must start at byte 0 with `---` and have a closing `---`.
m = re.match(r"^---\n(.*?\n)---\n(.*)$", src, re.DOTALL)
if not m:
    print("ERROR: missing or malformed YAML frontmatter (must start with '---' and close with '---')")
    sys.exit(1)

try:
    fm = yaml.safe_load(m.group(1)) or {}
except yaml.YAMLError as e:
    print(f"ERROR: frontmatter YAML parse failed: {e}")
    sys.exit(1)

if not isinstance(fm, dict):
    print(f"ERROR: frontmatter must be a YAML mapping, got {type(fm).__name__}")
    sys.exit(1)

# Required keys.
for req in ("name", "description"):
    if req not in fm:
        print(f"ERROR: frontmatter missing required key '{req}'")
        sys.exit(1)
    if not isinstance(fm[req], str) or not fm[req].strip():
        print(f"ERROR: frontmatter key '{req}' must be non-empty string")
        sys.exit(1)

# Name must match directory and follow codex convention (lowercase, hyphens, alnum).
name = fm["name"].strip()
if name != dir_name:
    print(f"ERROR: frontmatter name '{name}' does not match directory '{dir_name}'")
    sys.exit(1)
if not re.match(r"^[a-z0-9][a-z0-9-]*[a-z0-9]$", name):
    print(f"ERROR: name '{name}' violates codex convention (lowercase alnum + hyphens)")
    sys.exit(1)

# Body must be non-empty (codex needs instructions).
body = m.group(2).strip()
if not body:
    print("ERROR: SKILL.md body is empty — codex skills must contain instructions")
    sys.exit(1)

# Description length sanity check (codex truncates display, but empty/tiny is suspicious).
if len(fm["description"].strip()) < 20:
    print(f"ERROR: description too short ({len(fm['description'].strip())} chars) — codex requires meaningful trigger prose")
    sys.exit(1)

print("OK")
PY
}

echo "--- scanning $PLUGINS_DIR for codex SKILL.md files ---"
mapfile -t SKILL_FILES < <(find "$PLUGINS_DIR" -path "*/codex-skills/*/SKILL.md" -type f | sort)
TOTAL=${#SKILL_FILES[@]}
echo "[codex-smoke] found $TOTAL projected codex skills"
echo ""

if [ "$TOTAL" -eq 0 ]; then
  echo "[codex-smoke] no codex skills to validate — exiting OK"
  exit 0
fi

for skill_file in "${SKILL_FILES[@]}"; do
  rel="${skill_file#$REPO_DIR/}"
  result="$(validate_skill "$skill_file" 2>&1)"
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
echo "=== codex-smoke summary ==="
echo "  passed: $PASS / $TOTAL"
echo "  failed: $FAIL / $TOTAL"
echo "  mode:   $CODEX_LOAD_MODE"

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "--- failures ---"
  for line in "${FAILED_LIST[@]}"; do
    echo "  - $line"
  done
  exit 1
fi

exit 0
