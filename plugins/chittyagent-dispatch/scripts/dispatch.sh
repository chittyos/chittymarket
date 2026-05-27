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
# Place the per-canonical-state lock OUTSIDE the repo tree so it never lands
# in `git status` or the pre-commit drift snapshot. Hash the repo root so
# concurrent runs in different checkouts each get their own lock.
LOCK_DIR="${TMPDIR:-/tmp}"
LOCK_FILE="$LOCK_DIR/chittymarket-dispatch-$(printf '%s' "$REPO_ROOT" | shasum | cut -c1-12).lock"

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
      # Discover canonicals across kind-subdirs (canonical/agents/, canonical/skills/, ...)
      mapfile -t targets < <(find "$CANONICAL_DIR" -mindepth 2 -name "*.md" -not -name "README.md" -not -path "*/.dispatch-state/*" -printf "%f\n" | sed 's/\.md$//')
    fi
    for name in "${targets[@]}"; do
      # Resolve canonical: search kind-subdirs (canonical/<kind-plural>/<name>.md)
      can=""
      for sub in agents skills commands mcp hooks tools; do
        if [ -f "$CANONICAL_DIR/$sub/${name}.md" ]; then
          can="$CANONICAL_DIR/$sub/${name}.md"
          break
        fi
      done
      [ -n "$can" ] || { echo "[dispatch] canonical not found for $name (searched canonical/{agents,skills,commands,mcp,hooks,tools}/${name}.md). Flat layout removed; place canonicals in their kind-subdir." >&2; exit 1; }
      # Parse frontmatter via yaml.safe_load (handles both block and flow style).
      # Errors hard if `runtimes:` is present but not a list.
      eval "$(python3 - "$can" <<'PY'
import sys, re, shlex
try:
    import yaml
except ImportError:
    sys.stderr.write("[dispatch] PyYAML is required (pip install pyyaml)\n")
    sys.exit(1)
src = open(sys.argv[1]).read()
m = re.match(r"^---\n(.*?\n)---\n", src, re.DOTALL)
fm_text = m.group(1) if m else ""
try:
    fm = yaml.safe_load(fm_text) or {}
except yaml.YAMLError as e:
    sys.stderr.write(f"[dispatch] {sys.argv[1]}: YAML frontmatter parse error: {e}\n")
    sys.exit(1)
if not isinstance(fm, dict):
    sys.stderr.write(f"[dispatch] {sys.argv[1]}: frontmatter must be a mapping\n")
    sys.exit(1)
plugin = str(fm.get("plugin", "")).strip()
kind = str(fm.get("kind", "agent")).strip() or "agent"
runtimes_val = fm.get("runtimes", [])
if runtimes_val is None:
    runtimes = []
elif isinstance(runtimes_val, list):
    runtimes = [str(r).strip() for r in runtimes_val if str(r).strip()]
else:
    sys.stderr.write(f"[dispatch] {sys.argv[1]}: `runtimes` must be a list, got {type(runtimes_val).__name__}\n")
    sys.exit(1)
print(f"plugin={shlex.quote(plugin)}")
print(f"kind={shlex.quote(kind)}")
print(f"runtimes={shlex.quote(' '.join(runtimes))}")
PY
)"
      [ -n "$plugin" ] || { echo "[dispatch] $name: missing plugin field" >&2; exit 1; }
      can_sha=$(git hash-object "$can")
      sub="$(basename "$(dirname "$can")")"
      mkdir -p "$STATE_DIR/$sub"
      targets_json="{}"
      for runtime in $runtimes; do
        # Resolve output path by (runtime, kind).
        case "$runtime:$kind" in
          claude-code:agent)
            out="$REPO_ROOT/plugins/${plugin}/agents/${name}.md"
            adapter="$ADAPTER_DIR/claude-code-agent.sh"
            ;;
          claude-code:skill)
            out="$REPO_ROOT/plugins/${plugin}/skills/${name}/SKILL.md"
            adapter="$ADAPTER_DIR/claude-code-agent.sh"   # same markdown+frontmatter shape
            ;;
          claude-code:command)
            out="$REPO_ROOT/plugins/${plugin}/commands/${name}.md"
            adapter="$ADAPTER_DIR/claude-code-agent.sh"   # same markdown+frontmatter shape
            ;;
          claude-code:hook)
            out="$REPO_ROOT/plugins/${plugin}/hooks/hooks.json"
            adapter="$ADAPTER_DIR/claude-code-hook.sh"
            ;;
          claude-code:mcp-server)
            out="$REPO_ROOT/plugins/${plugin}/.mcp.json"
            adapter="$ADAPTER_DIR/claude-code-mcp.sh"
            ;;
          codex:agent|codex:skill)
            out="$REPO_ROOT/plugins/${plugin}/codex-skills/${name}/SKILL.md"
            adapter="$ADAPTER_DIR/codex-skill.sh"
            ;;
          openclaw:agent)
            out="$REPO_ROOT/plugins/${plugin}/openclaw-agents/${name}.yaml"
            adapter="$ADAPTER_DIR/openclaw-agent.sh"
            ;;
          claude-skills:tool)
            out="$REPO_ROOT/plugins/${plugin}/claude-skills/${name}.json"
            adapter="$ADAPTER_DIR/claude-skills.sh"
            ;;
          *)
            echo "[dispatch] $name: unknown runtime '$runtime' for kind '$kind' (canonical=$can). Known runtimes: claude-code, codex, openclaw, claude-skills." >&2
            exit 1
            ;;
        esac
        if [ -n "$adapter" ]; then
          "$adapter" "$can" "$out"
          proj_sha=$(git hash-object "$out")
          targets_json=$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); d[sys.argv[2]]=sys.argv[3]; print(json.dumps(d))" "$targets_json" "$runtime" "$proj_sha")
        fi
      done
      # Serialize per-canonical state writes under a flock to prevent concurrent
      # dispatch.sh sync runs from corrupting .dispatch-state/<kind>/<name>.json.
      # Fail fast after 10s.
      (
        flock -w 10 9 || { echo "[dispatch] $name: could not acquire lock $LOCK_FILE within 10s" >&2; exit 1; }
        python3 -c "
import json, sys
open(sys.argv[1], 'w').write(json.dumps({
    'canonical_sha': sys.argv[2],
    'targets': json.loads(sys.argv[3]),
}, indent=2, sort_keys=True))
" "$STATE_DIR/$sub/${name}.json" "$can_sha" "$targets_json"
      ) 9>"$LOCK_FILE"
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
