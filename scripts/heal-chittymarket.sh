#!/usr/bin/env bash
# heal-chittymarket.sh — Auto-resolve known drift surfaces in the chittymarket repo.
#
# Runs the canonical generators against plugins/ source-of-truth and reports
# what was healed. Use this before opening a PR if scripts/lint-plugins.sh or
# the CI validate-chittymarket workflow flags drift.
#
# Exit codes:
#   0 — nothing to heal (repo was already clean)
#   1 — drift detected and healed; review `git diff` and commit
#   2 — drift detected that this script cannot auto-resolve; manual fix required

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
cd "$REPO_DIR"

red()    { printf '\033[0;31m%s\033[0m\n' "$1"; }
yellow() { printf '\033[0;33m%s\033[0m\n' "$1"; }
green()  { printf '\033[0;32m%s\033[0m\n' "$1"; }
dim()    { printf '\033[0;90m%s\033[0m\n' "$1"; }

echo "=== heal-chittymarket ==="
echo ""

HEALED=0
MANUAL=0

# 1. Regenerate .claude-plugin/marketplace.json from plugins/ source of truth.
echo "1/2 Regenerating .claude-plugin/marketplace.json from plugins/ ..."
bash "$SCRIPT_DIR/generate-marketplace.sh" > /dev/null
if ! git diff --quiet -- .claude-plugin/marketplace.json 2>/dev/null; then
  yellow "  HEALED: .claude-plugin/marketplace.json had drifted from plugins/ — regenerated."
  HEALED=$((HEALED + 1))
else
  dim "  ok: manifest already idempotent"
fi
echo ""

# 2. Surface non-auto-resolvable drift (manual fixes).
echo "2/2 Detecting drift this script cannot auto-resolve..."

# 2a. Top-level plugin.json (canonical location is .claude-plugin/plugin.json)
for plugin_dir in plugins/*/; do
  plugin_name=$(basename "$plugin_dir")
  if [ -f "$plugin_dir/plugin.json" ]; then
    red "  MANUAL: $plugin_name has plugin.json at top-level."
    red "          Move it: mv $plugin_dir/plugin.json $plugin_dir/.claude-plugin/plugin.json"
    MANUAL=$((MANUAL + 1))
  fi
done

# 2b. Missing .claude-plugin/plugin.json
for plugin_dir in plugins/*/; do
  plugin_name=$(basename "$plugin_dir")
  if [ ! -f "$plugin_dir/.claude-plugin/plugin.json" ]; then
    red "  MANUAL: $plugin_name missing .claude-plugin/plugin.json — author one and re-run."
    MANUAL=$((MANUAL + 1))
  fi
done

if [ "$MANUAL" -eq 0 ]; then
  dim "  ok: no manual fixes required"
fi
echo ""

# Summary
echo "=== Summary ==="
if [ "$HEALED" -eq 0 ] && [ "$MANUAL" -eq 0 ]; then
  green "Nothing to heal — repo is clean."
  exit 0
fi
[ "$HEALED" -gt 0 ] && yellow "Auto-healed: $HEALED item(s). Review with 'git diff' and commit."
[ "$MANUAL" -gt 0 ] && red "Manual fixes needed: $MANUAL item(s) — see above."
[ "$MANUAL" -gt 0 ] && exit 2
exit 1
