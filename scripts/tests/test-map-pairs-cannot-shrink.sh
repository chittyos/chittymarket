#!/usr/bin/env bash
# _MAP in resolve_output.py is the SINGLE (runtime, kind) -> (template, adapter) mapping that
# dispatch.sh sync|audit|reconcile all share. KNOWN_RUNTIMES is derived FROM _MAP, so the
# vocabulary of known runtimes shrinks whenever a pair is deleted — and an audit then reports
# everything in sync, because the pair it would have checked no longer exists. A self-derived
# check cannot detect its own narrowing.
#
# This is not hypothetical: branch feat/chittyagent-serv-fleet-caretaker deletes
# ("claude-code","workflow"), the estate's ONLY workflow projection route, and nothing in the
# dispatch toolchain reports it. This test pins the floor so a deletion fails loudly.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MAP="${MAP_FILE:-$ROOT/plugins/chittyagent-dispatch/scripts/lib/resolve_output.py}"
[[ -f "$MAP" ]] || { echo "FAIL - mapping not found: $MAP" >&2; exit 1; }

fails=0
ok()   { echo "ok - $1"; }
bad()  { echo "FAIL - $1" >&2; fails=$((fails+1)); }

# Floor, not an exact set: pairs may be ADDED freely; none of these may be removed.
REQUIRED=(
  '"claude-code", "agent"'      '"claude-code", "skill"'   '"claude-code", "command"'
  '"claude-code", "hook"'       '"claude-code", "mcp-server"'
  '"claude-code", "workflow"'
  '"codex", "agent"'            '"codex", "skill"'
  '"openclaw", "agent"'         '"openclaw", "skill"'\n  '"anthropic-managed", "agent"'
  '"universal", "skill"'        '"claude-skills", "tool"'  '"chatgpt-apps", "tool"'
)
for pair in "${REQUIRED[@]}"; do
  if grep -Fq "($pair)" "$MAP"; then ok "pair present: ($pair)"
  else bad "($pair) removed from _MAP; dispatch audit cannot report this because KNOWN_RUNTIMES is derived from _MAP"; fi
done

n="$(grep -cE '^\s*\("[a-z-]+", "[a-z-]+"\):' "$MAP" || true)"
if (( n >= ${#REQUIRED[@]} )); then ok "pair count $n >= floor ${#REQUIRED[@]}"
else bad "pair count $n is below the floor ${#REQUIRED[@]}"; fi

if grep -q 'KNOWN_RUNTIMES *= *sorted({rt for rt, _ in _MAP})' "$MAP"; then
  ok "KNOWN_RUNTIMES still derived from _MAP (so this floor also pins the runtime vocabulary)"
else
  bad "KNOWN_RUNTIMES derivation changed; re-check whether this test still pins the runtime vocabulary"
fi

(( fails == 0 )) || { echo "$fails _MAP floor check(s) failed" >&2; exit 1; }
echo "_MAP floor intact"
