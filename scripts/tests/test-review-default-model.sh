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

# Lanes (operator decision 2026-11-11): the DEFAULT lane is the Claude subscription
# lane, pinned to a full Claude model name; the gateway lane is opt-in and keeps its
# own direct model. Both resolutions are asserted, so neither lane can silently
# change its reviewer.
if [[ "$DEFAULT_OUT" == "claude-opus-4-8" ]]; then
  ok "default lane is subscription, pinned to claude-opus-4-8"
else
  fail "default lane resolved '$DEFAULT_OUT', expected the pinned subscription model claude-opus-4-8"
fi
set +e
out="$(REVIEW_LANE=gateway timeout 30 bash "$SCRIPT" --print-model 2>&1)"
rc=$?
set -e
if (( rc != 0 )) || [[ "$out" != "cloudflare-ai-gateway/anthropic/claude-opus-4-8" ]]; then
  fail "gateway lane did not resolve its direct model (exit $rc): $out"
else
  ok "REVIEW_LANE=gateway resolves the gateway model"
fi

# The rejection holds in the gateway lane too.
set +e
out="$(REVIEW_LANE=gateway REVIEW_MODEL=cloudflare-ai-gateway/dynamic/three-wise-men timeout 30 bash "$SCRIPT" --print-model 2>&1)"
rc=$?
set -e
if (( rc == 0 )); then fail "gateway lane accepted a dynamic route: $out"; else ok "gateway lane rejects a dynamic route (exit $rc)"; fi

# A model alias (e.g. `opus`) would float onto whatever the CLI maps it to — today
# the implementer's own model — so the subscription lane refuses aliases.
set +e
out="$(REVIEW_MODEL=opus timeout 30 bash "$SCRIPT" --print-model 2>&1)"
rc=$?
set -e
if (( rc == 0 )); then fail "subscription lane accepted alias 'opus' ($out)"; else ok "subscription lane refuses a model alias (exit $rc)"; fi

# An unknown lane is a usage error, not a silent fallback to some lane.
set +e
out="$(REVIEW_LANE=nope timeout 30 bash "$SCRIPT" --print-model 2>&1)"
rc=$?
set -e
if (( rc == 0 )); then fail "unknown REVIEW_LANE accepted ($out)"; else ok "unknown REVIEW_LANE rejected (exit $rc)"; fi

# A directly-named override must still resolve in each lane, or a guard that refused
# every model would pass the cases above.
set +e
out="$(REVIEW_LANE=gateway REVIEW_MODEL=cloudflare-ai-gateway/anthropic/claude-opus-4-8 timeout 30 bash "$SCRIPT" --print-model 2>&1)"
rc=$?
out2="$(REVIEW_MODEL=claude-sonnet-5-5 timeout 30 bash "$SCRIPT" --print-model 2>&1)"
rc2=$?
set -e
if (( rc != 0 )) || [[ "$out" != "cloudflare-ai-gateway/anthropic/claude-opus-4-8" ]]; then
  fail "gateway direct model override did not resolve (exit $rc): $out"
else
  ok "gateway direct model override resolves unchanged"
fi
if (( rc2 != 0 )) || [[ "$out2" != "claude-sonnet-5-5" ]]; then
  fail "subscription full-name override did not resolve (exit $rc2): $out2"
else
  ok "subscription full-name override resolves unchanged"
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
