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
    # Real implementation for the `claude-code` runtime. Other runtimes still skip
    # with a notice until their adapters land.
    targets=("$@")
    if [ "${#targets[@]}" -eq 0 ]; then
      mapfile -t targets < <(find "$CANONICAL_DIR" -maxdepth 1 -name "*.md" -not -name "README.md" -printf "%f\n" | sed 's/\.md$//')
    fi
    for name in "${targets[@]}"; do
      can="$CANONICAL_DIR/${name}.md"
      [ -f "$can" ] || { echo "[dispatch] canonical not found: $can" >&2; exit 1; }
      eval "$(python3 - "$can" <<'PY'
import sys, re, shlex
src = open(sys.argv[1]).read()
m = re.match(r"^---\n(.*?\n)---\n", src, re.DOTALL)
fm = m.group(1) if m else ""
plugin_m = re.search(r"^plugin:\s*(\S.*)$", fm, re.MULTILINE)
plugin = plugin_m.group(1).strip() if plugin_m else ""
runtimes = []
rt_m = re.search(r"^runtimes:\s*\n((?:[ \t]+-\s*\S.*\n)+)", fm, re.MULTILINE)
if rt_m:
    runtimes = [ln.strip().lstrip("-").strip() for ln in rt_m.group(1).splitlines() if ln.strip()]
print(f"plugin={shlex.quote(plugin)}")
print(f"runtimes={shlex.quote(' '.join(runtimes))}")
PY
)"
      [ -n "$plugin" ] || { echo "[dispatch] $name: missing plugin field" >&2; exit 1; }
      can_sha=$(git hash-object "$can")
      targets_json="{}"
      for runtime in $runtimes; do
        case "$runtime" in
          claude-code)
            out="$REPO_ROOT/plugins/${plugin}/agents/${name}.md"
            "$ADAPTER_DIR/claude-code-agent.sh" "$can" "$out"
            proj_sha=$(git hash-object "$out")
            targets_json=$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); d[sys.argv[2]]=sys.argv[3]; print(json.dumps(d))" "$targets_json" "$runtime" "$proj_sha")
            ;;
          codex)
            out="$REPO_ROOT/plugins/${plugin}/codex-skills/${name}/SKILL.md"
            "$ADAPTER_DIR/codex-skill.sh" "$can" "$out"
            proj_sha=$(git hash-object "$out")
            targets_json=$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); d[sys.argv[2]]=sys.argv[3]; print(json.dumps(d))" "$targets_json" "$runtime" "$proj_sha")
            ;;
          openclaw)
            out="$REPO_ROOT/plugins/${plugin}/openclaw-agents/${name}.yaml"
            "$ADAPTER_DIR/openclaw-agent.sh" "$can" "$out"
            proj_sha=$(git hash-object "$out")
            targets_json=$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); d[sys.argv[2]]=sys.argv[3]; print(json.dumps(d))" "$targets_json" "$runtime" "$proj_sha")
            ;;
          *)
            echo "[dispatch] $name: runtime '$runtime' adapter not yet implemented — skipping"
            ;;
        esac
      done
      python3 -c "
import json, sys
open(sys.argv[1], 'w').write(json.dumps({
    'canonical_sha': sys.argv[2],
    'projected_at': sys.argv[3],
    'targets': json.loads(sys.argv[4]),
}, indent=2, sort_keys=True))
" "$STATE_DIR/${name}.json" "$can_sha" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$targets_json"
      echo "[dispatch] sync $name: canonical=$can_sha targets=$targets_json"
    done
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
status="ok"
[ "$mode" = "sync" ] || status="stub"
printf '{"ts":"%s","mode":"%s","args":"%s","status":"%s"}\n' "$ts" "$mode" "$*" "$status" >> "$LOG"
