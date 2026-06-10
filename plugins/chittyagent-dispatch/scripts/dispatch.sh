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
    # Banner to stderr so `audit --json` stdout stays machine-parseable.
    echo "[dispatch] mode=$mode args=$*" >&2
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
        # Resolve (out path, adapter) via the shared resolver — the SAME mapping
        # audit/reconcile use, so the three can never disagree about where a
        # canonical projects to. Unknown (runtime,kind) exits 3.
        if ! resolved="$(python3 "$(dirname "$0")/lib/resolve_output.py" "$REPO_ROOT" "$plugin" "$name" "$kind" "$runtime")"; then
          echo "[dispatch] $name: unknown runtime '$runtime' for kind '$kind' (canonical=$can)." >&2
          exit 1
        fi
        out="${resolved%%$'\t'*}"
        adapter="${resolved#*$'\t'}"
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
    # Safe-by-default. Re-projection from canonical is LOSSLESS only when the
    # on-disk projection carries no content the canonical lacks. So we split:
    #
    #   SAFE   (CANON_AHEAD, MISSING_PROJ, NEVER_SYNCED) — canonical is the only
    #          source of truth; re-syncing cannot lose information. Auto-healed.
    #   UNSAFE (PROJ_DRIFT) — the projection was edited directly and now contains
    #          bytes the canonical does not. Re-syncing would DISCARD that edit.
    #          We refuse to do that silently: report it and stop. The fix is to
    #          port the edit UP into canonical/ then re-sync — NOT to overwrite.
    #          `--accept-canonical` opts into discarding the projection edit.
    #
    # Orphans are reported, never auto-deleted. `--report-only` mutates nothing.
    report_only=0; accept_canonical=0
    for a in "$@"; do
      [ "$a" = "--report-only" ] && report_only=1
      [ "$a" = "--accept-canonical" ] && accept_canonical=1
    done

    findings_json="$(python3 "$(dirname "$0")/lib/audit.py" --json || true)"

    # Orphans → stderr, advisory only.
    printf '%s' "$findings_json" | python3 -c "
import json, sys
d = json.load(sys.stdin)
orphans = [f for f in d['findings'] if f['cls'].startswith('ORPHAN')]
for o in orphans:
    print(f\"[dispatch] ORPHAN ({o['cls']}): {o.get('canonical','-')} {o['runtime']} — {o['detail']}\", file=sys.stderr)
if orphans:
    print(f'[dispatch] {len(orphans)} orphan(s) reported; reconcile does not auto-delete. Resolve manually.', file=sys.stderr)
"
    safe_names="$(printf '%s' "$findings_json" | python3 -c "
import json, sys
d = json.load(sys.stdin)
SAFE = {'CANON_AHEAD', 'MISSING_PROJ', 'NEVER_SYNCED'}
names = []
for f in d['findings']:
    if f['cls'] in SAFE and f['canonical'] != '-':
        n = f['canonical'].split('/', 1)[1]
        if n not in names: names.append(n)
print('\n'.join(names))
")"
    drift_names="$(printf '%s' "$findings_json" | python3 -c "
import json, sys
d = json.load(sys.stdin)
names = []
for f in d['findings']:
    if f['cls'] == 'PROJ_DRIFT' and f['canonical'] != '-':
        n = f['canonical'].split('/', 1)[1]
        if n not in names: names.append(n)
print('\n'.join(names))
")"
    # Report PROJ_DRIFT (the unsafe class) loudly with the actual diff.
    has_unsafe=0
    if [ -n "$drift_names" ]; then
      has_unsafe=1
      echo "[dispatch] reconcile: PROJ_DRIFT — projection edited directly (canonical does NOT contain the '+' lines):" >&2
      # Show the real canonical-body vs projection-body diff for each drifted cell.
      printf '%s' "$findings_json" | python3 -c "
import json, sys, re, subprocess, os
d = json.load(sys.stdin); repo = d['repo']
def body(p):
    s = open(os.path.join(repo, p), encoding='utf-8').read()
    m = re.match(r'^---\n.*?\n---\n(.*)', s, re.S)
    return (m.group(1) if m else s)
for f in d['findings']:
    if f['cls'] != 'PROJ_DRIFT': continue
    print(f\"  {f['canonical']} -> {f['runtime']}  ({f['out_path']})\", file=sys.stderr)
    import tempfile
    ca, pr = body(f['canonical_path']), body(f['out_path'])
    with tempfile.NamedTemporaryFile('w', suffix='.canon', delete=False) as a, \
         tempfile.NamedTemporaryFile('w', suffix='.proj', delete=False) as b:
        a.write(ca); b.write(pr); an, bn = a.name, b.name
    diff = subprocess.run(['diff', '-u', '--label', 'canonical', '--label', 'projection', an, bn],
                          capture_output=True, text=True).stdout
    os.unlink(an); os.unlink(bn)
    sys.stderr.write('\n'.join('    ' + l for l in diff.splitlines()) + '\n')
"
    fi

    if [ "$report_only" = "1" ]; then
      echo "[dispatch] reconcile --report-only:"
      [ -n "$safe_names" ]  && { echo "  would auto-heal (lossless):"; printf '    %s\n' $safe_names; }
      [ -n "$drift_names" ] && { echo "  would REFUSE (needs port-to-canonical or --accept-canonical):"; printf '    %s\n' $drift_names; }
      [ -z "$safe_names$drift_names" ] && echo "  nothing to do."
    else
      if [ -n "$safe_names" ]; then
        echo "[dispatch] reconcile: auto-healing $(printf '%s' "$safe_names" | wc -w | tr -d ' ') lossless canonical(s)..."
        # shellcheck disable=SC2086
        "$0" sync $safe_names
      fi
      if [ -n "$drift_names" ] && [ "$accept_canonical" = "1" ]; then
        echo "[dispatch] reconcile: --accept-canonical — discarding projection edits, re-syncing from canonical..." >&2
        # shellcheck disable=SC2086
        "$0" sync $drift_names
        has_unsafe=0
      fi
      if [ -z "$safe_names$drift_names" ]; then
        echo "[dispatch] reconcile: no drift."
      elif [ "$has_unsafe" = "1" ]; then
        echo "[dispatch] reconcile: STOPPED — direct projection edits above were NOT discarded." >&2
        echo "[dispatch]   Fix: port the edit into the canonical/ source, then run 'dispatch.sh reconcile' again." >&2
        echo "[dispatch]   Or:  re-run with --accept-canonical to discard the projection edits (canonical wins)." >&2
        exit 1
      else
        echo "[dispatch] reconcile: verifying clean..."
        python3 "$(dirname "$0")/lib/audit.py" >/dev/null \
          && echo "[dispatch] reconcile: repo is now in sync." \
          || { echo "[dispatch] reconcile: drift remains after re-sync — investigate." >&2; exit 1; }
      fi
    fi
    ;;
  audit)
    # Read-only canonical×runtime drift + orphan matrix. Exit 1 if any drift.
    exec python3 "$(dirname "$0")/lib/audit.py" "$@"
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
case "$mode" in
  sync|reconcile|audit) status="ok" ;;
  *) status="stub" ;;
esac
printf '{"ts":"%s","mode":"%s","args":"%s","status":"%s"}\n' "$ts" "$mode" "$*" "$status" >> "$LOG"
