#!/usr/bin/env bash
# check-plugin-version-bump.sh — a plugin whose CONTENT changed must also change its
# declared version, or no installed client can know to refetch it.
#
# Why this exists. Several PRs rewrote skills inside `plugins/chittyos-core/` without
# touching its `plugin.json`. Every gate passed: the dispatch audit reported every
# cell in sync, because canonical and projection DID match each other. What nothing
# compared was the projection against the version clients key their cache on. The
# result was a cache holding the OLD skill text under the SAME version number —
# a session governed by pre-change guidance while the repository said otherwise, and
# a newly bundled script absent from the cache entirely.
#
# The failure is silent in the only way that matters: no error, no drift, no stale
# marker. A version that does not move is indistinguishable from content that did
# not change.
#
# Usage: check-plugin-version-bump.sh [base-ref] [head-ref]
#        defaults: origin/main HEAD. head-ref is a parameter so the gate can be
#        replayed against a historical commit — a gate that cannot be pointed at a
#        known-bad input cannot be shown to work.
# Exit:  0 every changed plugin bumped · 1 at least one did not · 2 usage/env
set -euo pipefail

BASE="${1:-origin/main}"
HEADREF="${2:-HEAD}"

for r in "$BASE" "$HEADREF"; do
  git rev-parse --verify --quiet "$r" >/dev/null && continue
  # Fail CLOSED on a ref that does not resolve. Passing because the comparison
  # could not be made is the same class of defect this gate exists to catch.
  echo "ERROR: ref '$r' does not resolve — cannot compare, refusing to pass" >&2
  exit 2
done

manifest_for() {
  local p="$1" c
  for c in "plugins/$p/.claude-plugin/plugin.json" "plugins/$p/plugin.json"; do
    git cat-file -e "$HEADREF:$c" 2>/dev/null && { echo "$c"; return 0; }
  done
  return 1
}

version_at() {  # <ref> <path> -> version string, or empty
  git show "$1:$2" 2>/dev/null | python3 -c '
import json,sys
try: print(json.load(sys.stdin).get("version",""))
except Exception: print("")
' 2>/dev/null
}

rc=0
checked=0
for p in $(git diff --name-only "$BASE" "$HEADREF" -- 'plugins/' | awk -F/ 'NF>=2 {print $2}' | sort -u); do
  manifest="$(manifest_for "$p")" || { echo "skip   $p — no plugin manifest"; continue; }

  # Content = everything in the plugin EXCEPT its own manifest, so a bump on its
  # own is legitimate and never demands a second bump.
  content_changed=$(git diff --name-only "$BASE" "$HEADREF" -- "plugins/$p" ":(exclude)$manifest" | wc -l | tr -d ' ')
  [ "$content_changed" -eq 0 ] && continue

  checked=$((checked + 1))
  before="$(version_at "$BASE" "$manifest")"
  after="$(version_at "$HEADREF" "$manifest")"

  if [ -z "$after" ]; then
    echo "FAIL   $p — manifest has no readable version"; rc=1
  elif [ "$before" = "$after" ]; then
    echo "FAIL   $p — $content_changed file(s) changed, version still $after"
    echo "       bump $manifest so installed clients refetch; a version that does"
    echo "       not move is indistinguishable from content that did not change."
    rc=1
  else
    echo "ok     $p — $content_changed file(s) changed, version ${before:-<new>} -> $after"
  fi
done

[ "$checked" -eq 0 ] && echo "no plugin content changed between $BASE and $HEADREF"
exit "$rc"
