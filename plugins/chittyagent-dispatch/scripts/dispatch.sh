#!/usr/bin/env bash
# chittyagent-dispatch entry point.
#
# Usage:
#   dispatch.sh sync [<canonical-name>...]      # default mode; projects updated canonicals
#   dispatch.sh bootstrap <canonical-name>      # first-time projection
#   dispatch.sh reconcile [<canonical-name>...] # detect + integrate direct edits
#   dispatch.sh add-target <runtime>            # onboard a new runtime
#   dispatch.sh audit                           # drift + orphan matrix
#
# This is a v0.1 skeleton. Adapter implementations stubbed; see ./adapters/.
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
CANONICAL_DIR="$REPO_ROOT/canonical"
ADAPTER_DIR="$(dirname "$0")/adapters"
STATE_DIR="$CANONICAL_DIR/.dispatch-state"
LOG="$CANONICAL_DIR/.dispatch-log.jsonl"

mkdir -p "$STATE_DIR"

mode="${1:-sync}"
shift || true

case "$mode" in
  sync|bootstrap|reconcile|audit|add-target)
    echo "[dispatch] mode=$mode args=$*"
    ;;
  *)
    echo "unknown mode: $mode" >&2
    exit 2
    ;;
esac

case "$mode" in
  sync)
    echo "[dispatch] sync — STUB. Will iterate canonicals, parse frontmatter, run adapters per runtime."
    echo "           Implement: see plugins/chittyagent-dispatch/agents/chittyagent-dispatch.md Mode 1."
    ;;
  bootstrap)
    name="${1:-}"
    [ -n "$name" ] || { echo "bootstrap requires <canonical-name>" >&2; exit 2; }
    echo "[dispatch] bootstrap $name — STUB. Will validate frontmatter + run sync + register orchestrator."
    ;;
  reconcile)
    echo "[dispatch] reconcile — STUB. Will three-way-diff projections vs sentinel vs canonical."
    ;;
  audit)
    echo "[dispatch] audit — STUB. Will emit canonical×runtime sync matrix."
    ;;
  add-target)
    runtime="${1:-}"
    [ -n "$runtime" ] || { echo "add-target requires <runtime>" >&2; exit 2; }
    echo "[dispatch] add-target $runtime — STUB. Will register adapter in .runtimes.json + bootstrap all canonicals."
    ;;
esac

# Audit log
ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf '{"ts":"%s","mode":"%s","args":"%s","status":"stub"}\n' "$ts" "$mode" "$*" >> "$LOG"
