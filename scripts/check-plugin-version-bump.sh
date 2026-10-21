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

command -v python3 >/dev/null || { echo "ERROR: python3 required" >&2; exit 2; }

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
  # FAIL CLOSED when no manifest is identifiable. The first version printed
  # "skip" and continued, so moving or renaming a manifest -- or using a
  # non-standard filename -- silently exempted every content change in that
  # plugin. A gate that answers "is this plugin governed?" with a pass when it
  # cannot tell is fail-open on its own precondition.
  if ! manifest="$(manifest_for "$p")"; then
    # Only complain when content actually changed; a plugin dir touched only in
    # ways the diff cannot attribute is not evidence of anything.
    if [ "$(git diff --name-only "$BASE" "$HEADREF" -- "plugins/$p" | wc -l | tr -d ' ')" -gt 0 ]; then
      echo "FAIL   $p — content changed but no plugin manifest found at"
      echo "       plugins/$p/.claude-plugin/plugin.json or plugins/$p/plugin.json."
      echo "       If the manifest moved or is named differently, this gate cannot"
      echo "       tell whether clients will refetch. Not skipping."
      rc=1; checked=$((checked + 1))
    fi
    continue
  fi

  # Content = everything in the plugin EXCEPT its own manifest, so a bump on its
  # own is legitimate and never demands a second bump.
  content_changed=$(git diff --name-only "$BASE" "$HEADREF" -- "plugins/$p" ":(exclude)$manifest" | wc -l | tr -d ' ')
  [ "$content_changed" -eq 0 ] && continue

  checked=$((checked + 1))
  before="$(version_at "$BASE" "$manifest")"
  after="$(version_at "$HEADREF" "$manifest")"

  if [ -z "$after" ]; then
    echo "FAIL   $p — manifest has no readable version"; rc=1
  elif [ -z "$before" ]; then
    # No version at BASE under this path. Either a genuinely new plugin (fine) or
    # the manifest MOVED, in which case "" != "$after" would wave it through
    # regardless of whether the version actually advanced.
    if git cat-file -e "$BASE:plugins/$p" 2>/dev/null \
      || [ "$(git diff --name-only "$BASE" "$HEADREF" --diff-filter=D -- "plugins/$p" | wc -l | tr -d ' ')" -gt 0 ]; then
      echo "FAIL   $p — no version at $BASE under $manifest, but the plugin existed."
      echo "       The manifest appears to have moved; compare versions explicitly."
      rc=1
    else
      echo "ok     $p — new plugin at version $after"
    fi
  elif [ "$before" = "$after" ]; then
    echo "FAIL   $p — $content_changed file(s) changed, version still $after"
    echo "       bump $manifest so installed clients refetch; a version that does"
    echo "       not move is indistinguishable from content that did not change."
    rc=1
  elif ! python3 - "$before" "$after" <<'PV'
import sys
def key(v):
    parts=[]
    for seg in str(v).strip().split("."):
        num="".join(c for c in seg if c.isdigit())
        parts.append(int(num) if num else 0)
    return parts + [0]*(3-len(parts))
sys.exit(0 if key(sys.argv[2]) > key(sys.argv[1]) else 1)
PV
  then
    # A version that moved BACKWARD proves a value changed, not that clients will
    # refetch -- a cache keyed on "newer" treats a downgrade as nothing to do.
    echo "FAIL   $p — version went $before -> $after (not forward)"
    echo "       The gate must prove clients WILL refetch, not merely that a"
    echo "       string differs."
    rc=1
  else
    echo "ok     $p — $content_changed file(s) changed, version $before -> $after"
  fi
done

[ "$checked" -eq 0 ] && [ "$rc" -eq 0 ] && echo "no plugin content changed between $BASE and $HEADREF"
exit "$rc"
