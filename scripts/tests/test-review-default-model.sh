#!/usr/bin/env bash
# Guard: the adversarial reviewer must never dispatch to a `dynamic/<name>` AI
# Gateway route, and its default must never be empty.
#
# Why: a `dynamic/<name>` model id for an undeployed route fails with 400 code 2005.
# adversarial-review.sh then errors, no review runs, and an empty-looking review
# reads as "nothing found" - the review lane dies silently. The retired
# `dynamic/three-wise-men` default did exactly this (fixed by 9e88235). Stale
# branches still carry it; this test makes that revert unmergeable.
#
# Two checks, in order of strength:
#   G1 RUNTIME. Ask the script for its resolved model (`--print-model`), which
#      runs its own resolution and rejection and stops before dispatch. Covers
#      the default and any override, and cannot be fooled by how the assignment
#      is spelled. Never reaches the network.
#   G2 TEXT. The literal default, resolved from its own assignment lines, is
#      non-empty and not a dynamic route. Weaker by construction - an assignment
#      built by interpolation resolves differently here than at runtime - so it
#      is a second line behind G1, never the only one.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="${REVIEW_SCRIPT:-$ROOT/plugins/chittyos-core/skills/nb-development-defaults/scripts/adversarial-review.sh}"
[[ -f "$SCRIPT" ]] || { echo "FAIL - script not found: $SCRIPT" >&2; exit 1; }

FAILS=0
ok()   { echo "ok   - $1"; }
fail() { echo "FAIL - $1"; FAILS=$((FAILS + 1)); }

# --- G1: the RESOLVED model, read from the script itself ----------------------
# `--print-model` runs the script's own resolution and rejection, then stops
# before any dispatch. Asserting on its output tests what a real run would use,
# so a default assembled by interpolation cannot read clean here and dispatch to
# a dynamic route in production — the bypass a grep-based check cannot see.
set +e
DEFAULT_OUT="$(timeout 30 bash "$SCRIPT" --print-model 2>&1)"
DEFAULT_RC=$?
set -e
if (( DEFAULT_RC != 0 )); then
  fail "the script will not resolve a usable default model (exit $DEFAULT_RC): $DEFAULT_OUT"
elif [[ -z "${DEFAULT_OUT//[[:space:]]/}" ]]; then
  fail "resolved default is empty (an unset default is a silent review failure)"
elif [[ "$DEFAULT_OUT" == *dynamic/* ]]; then
  fail "resolved default '$DEFAULT_OUT' is a dynamic route; undeployed routes 400 (code 2005) and kill the review lane silently"
else
  ok "resolved default is a direct model: $DEFAULT_OUT"
fi

# The rejection must hold for an override too, not just the default.
for m in dynamic/three-wise-men cloudflare-ai-gateway/dynamic/three-wise-men; do
  set +e
  out="$(REVIEW_MODEL="$m" timeout 30 bash "$SCRIPT" --print-model 2>&1)"
  rc=$?
  set -e
  if (( rc == 0 )); then
    fail "script accepted dynamic route '$m' (exit 0, printed '$out') - it would dispatch and die silently"
  else
    ok "runtime rejects override '$m' (exit $rc)"
  fi
done

# A directly-named override must still resolve, or a guard that refused every
# model would pass the cases above.
set +e
out="$(REVIEW_MODEL=cloudflare-ai-gateway/anthropic/claude-opus-4-8 timeout 30 bash "$SCRIPT" --print-model 2>&1)"
rc=$?
set -e
if (( rc != 0 )) || [[ "$out" != "cloudflare-ai-gateway/anthropic/claude-opus-4-8" ]]; then
  fail "direct model override did not resolve (exit $rc): $out"
else
  ok "direct model override resolves unchanged"
fi

# --- G2: the literal default ---------------------------------------------------
n_default="$(grep -c '^DEFAULT_MODEL=' "$SCRIPT" || true)"
n_model="$(grep -c '^MODEL=' "$SCRIPT" || true)"
if [[ "$n_default" == 1 && "$n_model" == 1 ]]; then
  ok "one DEFAULT_MODEL= and one MODEL= assignment"
else
  fail "expected exactly one DEFAULT_MODEL= and one MODEL= (got $n_default / $n_model)"
fi

# Evaluate only those two assignment lines in a clean shell. A failure to resolve
# is reported, never swallowed: an empty RESOLVED that came from a broken
# evaluation is a different fact from an empty default, and conflating them is
# how a text proxy goes quiet.
ASSIGN="$(grep -E '^(DEFAULT_MODEL|MODEL)=' "$SCRIPT")"
set +e
RESOLVED="$(env -i bash -c "$ASSIGN"$'\nprintf %s "$MODEL"' 2>"$ROOT/.resolve.err")"
RRC=$?
set -e
if (( RRC != 0 )); then
  fail "could not resolve the default (exit $RRC): $(head -c 300 "$ROOT/.resolve.err")"
fi
rm -f "$ROOT/.resolve.err"
echo "resolved default: '${RESOLVED}'"

if [[ -n "$RESOLVED" ]]; then ok "default model is non-empty"; else fail "default model is empty (unset default is a silent review failure)"; fi

if [[ "$RESOLVED" == *dynamic/* ]]; then
  fail "default model '$RESOLVED' is a dynamic route (dynamic/...); undeployed routes 400 (code 2005) and kill the review lane silently"
else
  ok "default model is not a dynamic route"
fi

if (( FAILS > 0 )); then echo "$FAILS review-default-model test(s) failed"; exit 1; fi
echo "all review-default-model tests passed"
