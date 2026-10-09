#!/usr/bin/env bash
# Guard: the adversarial reviewer's DEFAULT model must be a direct model, never a
# dynamic AI Gateway route, and never empty.
#
# Why: a `dynamic/<name>` model id for an undeployed route fails with 400 code 2005.
# adversarial-review.sh then errors, no review runs, and an empty-looking review
# reads as "nothing found" - the review lane dies silently. The retired
# `dynamic/three-wise-men` default did exactly this (fixed by 9e88235). Stale
# branches still carry it; this test makes that revert unmergeable.
#
# Asserts the CLASS (no `dynamic/` anywhere in the resolved default), not one name.
# The script is only read, never executed (it would dispatch a remote review).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="${REVIEW_SCRIPT:-$ROOT/plugins/chittyos-core/skills/nb-development-defaults/scripts/adversarial-review.sh}"
[[ -f "$SCRIPT" ]] || { echo "FAIL - script not found: $SCRIPT" >&2; exit 1; }

FAILS=0
ok()   { echo "ok   - $1"; }
fail() { echo "FAIL - $1"; FAILS=$((FAILS + 1)); }

# Exactly one top-level DEFAULT_MODEL= and one MODEL= assignment, else the
# resolution below could be reading the wrong line.
n_default="$(grep -c '^DEFAULT_MODEL=' "$SCRIPT" || true)"
n_model="$(grep -c '^MODEL=' "$SCRIPT" || true)"
if [[ "$n_default" == 1 && "$n_model" == 1 ]]; then
  ok "one DEFAULT_MODEL= and one MODEL= assignment"
else
  fail "expected exactly one DEFAULT_MODEL= and one MODEL= (got $n_default / $n_model)"
fi

# Resolve the default the way the script does with REVIEW_MODEL unset: evaluate
# only those two assignment lines in a clean shell.
ASSIGN="$(grep -E '^(DEFAULT_MODEL|MODEL)=' "$SCRIPT")"
RESOLVED="$(env -i bash -c "$ASSIGN"$'\nprintf %s "$MODEL"' 2>/dev/null || true)"
echo "resolved default: '${RESOLVED}'"

if [[ -n "$RESOLVED" ]]; then ok "default model is non-empty"; else fail "default model is empty (unset default is a silent review failure)"; fi

if [[ "$RESOLVED" == *dynamic/* ]]; then
  fail "default model '$RESOLVED' is a dynamic route (dynamic/...); undeployed routes 400 (code 2005) and kill the review lane silently"
else
  ok "default model is not a dynamic route"
fi

if (( FAILS > 0 )); then echo "$FAILS review-default-model test(s) failed"; exit 1; fi
echo "all review-default-model tests passed"
