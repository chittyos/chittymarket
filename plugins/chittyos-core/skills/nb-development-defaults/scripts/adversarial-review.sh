#!/usr/bin/env bash
# Separated adversarial review via chittyclaw.
#
# Encodes the BINDING "reviewer ≠ implementer" loop from nb-development-defaults
# so it stops being reconstructed by hand every session. Reads a diff (file or
# stdin), sends it to a model on a DIFFERENT host and provider than the agent
# that wrote the code, and prints the review.
#
# Usage:
#   adversarial-review.sh <diff-file> [-p "extra focus instructions"]
#   git diff main...HEAD -- src/ | adversarial-review.sh - -p "focus on auth bypass"
#
# Env:
#   REVIEW_MODEL   override the model (default: the working three-wise-men route)
#
# Exit codes: 0 review returned | 1 usage/input | 2 chittyclaw unreachable
#             3 model call failed (route broken / provider error)
set -euo pipefail

NODE="chittyclaw"
CLI_CONTAINER="openclaw-prod-openclaw-cli-1"

# NOTE: --model wants <provider>/<catalog-id>, and the catalog id ITSELF contains
# a slash. `openclaw infer model list` prints `dynamic/three-wise-men`, but the
# bare id fails "Unknown model". Verified 2026-07-30.
DEFAULT_MODEL="cloudflare-ai-gateway/dynamic/three-wise-men"

# `adversarial-reviewer/dynamic/adversarial-reviewer` is the purpose-built route.
# It advertises itself as configured+available but returns
# 400 {"code":2005,"message":"Failed to get response from provider"} — the route
# definition is server-side in CF AI Gateway. Do NOT make it the default until
# that is fixed; a silently-degraded reviewer is worse than an explicit one.
MODEL="${REVIEW_MODEL:-$DEFAULT_MODEL}"

DIFF_FILE="${1:-}"
EXTRA=""
shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    -p) EXTRA="${2:-}"; shift 2 ;;
    *)  echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$DIFF_FILE" ]]; then
  echo "usage: $(basename "$0") <diff-file|-> [-p 'extra focus']" >&2
  exit 1
fi

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

if [[ "$DIFF_FILE" == "-" ]]; then
  cat > "$TMP"
else
  [[ -r "$DIFF_FILE" ]] || { echo "cannot read: $DIFF_FILE" >&2; exit 1; }
  cp "$DIFF_FILE" "$TMP"
fi

[[ -s "$TMP" ]] || { echo "diff is empty — nothing to review" >&2; exit 1; }

LINES=$(wc -l < "$TMP")
echo "→ reviewing ${LINES} diff lines via ${MODEL}" >&2

# Reachability first, so a dead node reports as such instead of surfacing as an
# empty review that might be mistaken for "no findings".
ssh -o BatchMode=yes -o ConnectTimeout=10 "$NODE" \
  "docker ps --format '{{.Names}}' | grep -qx '$CLI_CONTAINER'" 2>/dev/null || {
  echo "POLICY_BLOCKED_CHITTYCLAW_UNAVAILABLE: $CLI_CONTAINER not running on $NODE" >&2
  echo "  Review NOT performed. Do not report this change as reviewed." >&2
  exit 2
}

scp -q "$TMP" "$NODE:/tmp/adv-review-diff.txt"
ssh -o BatchMode=yes "$NODE" \
  "docker cp /tmp/adv-review-diff.txt $CLI_CONTAINER:/tmp/adv-review-diff.txt >/dev/null"

PROMPT_HEAD="You are an ADVERSARIAL code reviewer. Your job is to BREAK this change, not bless it. \
Hunt for: auth bypass, fail-open paths, silent failures, unawaited promises, races/TOCTOU, \
deploy-breaking changes, and controls that are documented but not actually enforced. \
Passing tests are NOT evidence of correctness. Cite specific lines. Rank findings by severity. \
If you believe it is safe, state what would have to be true for that to hold. ${EXTRA}"

OUT="$(ssh -o BatchMode=yes "$NODE" "docker exec $CLI_CONTAINER sh -lc '
D=\$(cat /tmp/adv-review-diff.txt)
openclaw infer model run --model $MODEL --prompt \"$(printf '%s' "$PROMPT_HEAD" | sed 's/"/\\\\"/g')

\$D\"
'" 2>&1)" || true

# Strip the CLI's config/doctor warning chrome, which is noise on every call.
CLEAN="$(printf '%s' "$OUT" | grep -viE 'plugin|state-migrations|model catalog|config-health|Doctor warnings|Config warnings|^[│├◇╮╯─[:space:]]*$' || true)"

if printf '%s' "$CLEAN" | grep -qiE 'Error:|Unknown model|Failed to get response'; then
  echo "MODEL CALL FAILED — review NOT performed:" >&2
  printf '%s\n' "$CLEAN" >&2
  exit 3
fi

printf '%s\n' "$CLEAN"
echo >&2
echo "✓ reviewed by ${MODEL} (separated host+model; reviewer ≠ implementer)" >&2
