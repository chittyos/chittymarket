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
#   REVIEW_MODEL   override the model (default: the three-wise-men route; it is codified in
#                  ai-gateway-routes/ and applied with apply-gateway-route.sh)
#
# Exit codes: 0 review returned | 1 usage/input | 2 chittyclaw unreachable
#             3 model call failed (route broken / provider error)
# On exit 2 or 3 the caller MUST report the review as NOT performed — never as
# "reviewed" or "no findings".
set -euo pipefail

NODE="chittyclaw"
CLI_CONTAINER="openclaw-prod-openclaw-cli-1"

# NOTE: --model wants <provider>/<catalog-id>, and the catalog id ITSELF contains
# a slash. `openclaw infer model list` prints `dynamic/three-wise-men`, but the
# bare id fails "Unknown model". Verified 2026-07-30.
DEFAULT_MODEL="cloudflare-ai-gateway/dynamic/three-wise-men"

# three-wise-men is codified in ai-gateway-routes/three-wise-men.json and applied /
# drift-checked with apply-gateway-route.sh (routes live only server-side in CF AI
# Gateway and vanished once, causing 400 code 2005 on every review).
# `dynamic/adversarial-reviewer` no longer exists on any gateway and must not be
# used: it was a $0.00 / 32k-context route — the inadequate-reviewer failure mode
# (confident empty findings that get ignored).
MODEL="${REVIEW_MODEL:-$DEFAULT_MODEL}"

# MODEL is the ONLY caller-controlled value that reaches the remote command line,
# so it is held to a strict charset: <provider>/<id>[/<id>...], [A-Za-z0-9._-] per
# segment, no leading dash. Anything else is a usage error, never "quoted harder".
MODEL_RE='^[A-Za-z0-9][A-Za-z0-9._-]*(/[A-Za-z0-9._-]+)+$'
if [[ ! "$MODEL" =~ $MODEL_RE ]]; then
  echo "invalid REVIEW_MODEL: must match $MODEL_RE" >&2
  exit 1
fi

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

command -v jq >/dev/null || { echo "jq is required (parses the openclaw --json result)" >&2; exit 1; }

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

PROMPT_HEAD="You are an ADVERSARIAL code reviewer. Your job is to BREAK this change, not bless it. \
Hunt for: auth bypass, fail-open paths, silent failures, unawaited promises, races/TOCTOU, \
deploy-breaking changes, and controls that are documented but not actually enforced. \
Passing tests are NOT evidence of correctness. Cite specific lines. Rank findings by severity. \
If you believe it is safe, state what would have to be true for that to hold. ${EXTRA}"

# The full prompt (head + -p focus + diff) is assembled LOCALLY into a file and
# streamed over ssh STDIN. It is never interpolated into a shell command string:
# an apostrophe, quote, $(), backtick or paren in -p or in the diff used to break
# the remote quoting, the model was never called, and the old pattern-based check
# still printed "✓ reviewed". (`openclaw infer model run` has no stdin/file prompt
# flag, so the container-side sh reads stdin into a single quoted argv element.)
PROMPT="$(mktemp)"; RESP="$(mktemp)"; ERRF="$(mktemp)"
trap 'rm -f "$TMP" "$PROMPT" "$RESP" "$ERRF"' EXIT
{ printf '%s\n\n' "$PROMPT_HEAD"; cat "$TMP"; } > "$PROMPT"

# --prompt is ONE argv element; Linux caps a single element at 128 KiB
# (MAX_ARG_STRLEN). Refuse up front instead of failing opaquely remotely.
PROMPT_BYTES=$(wc -c < "$PROMPT")
if (( PROMPT_BYTES > 131000 )); then
  echo "prompt is ${PROMPT_BYTES} bytes; single-argv limit is 128 KiB — split the diff" >&2
  exit 1
fi

# Remote command: constants + the charset-validated MODEL only. Inside the
# container, sh receives the program in single quotes and MODEL as $1.
set +e
ssh -o BatchMode=yes "$NODE" \
  "docker exec -i $CLI_CONTAINER sh -c 'exec openclaw infer model run --json --model \"\$1\" --prompt \"\$(cat)\"' adv-review $MODEL" \
  < "$PROMPT" > "$RESP" 2> "$ERRF"
RC=$?
set -e

fail() {
  echo "MODEL CALL FAILED — review NOT performed: $1" >&2
  echo "  Do not report this change as reviewed." >&2
  if [[ -s "$ERRF" ]]; then echo "--- remote stderr (tail) ---" >&2; tail -n 20 "$ERRF" >&2; fi
  if [[ -s "$RESP" ]]; then echo "--- remote stdout (head) ---" >&2; head -n 20 "$RESP" >&2; fi
  exit 3
}

# Success is decided POSITIVELY, never by grepping the review text for error
# words (a review that discussed an "unknown model" used to be reported as a
# failed call, and lines mentioning e.g. "plugin" were silently deleted):
#   1. remote exit status 0, 2. a JSON result with ok=true, 3. answered by the
#   requested provider/model, 4. non-blank output text.
(( RC == 0 )) || fail "remote exit status $RC"
# Tolerate CLI chrome before the JSON object; the object itself must parse.
JSON="$(sed -n '/^{/,$p' "$RESP")"
printf '%s' "$JSON" | jq -e 'type == "object"' >/dev/null 2>&1 || fail "no JSON result from openclaw"
printf '%s' "$JSON" | jq -e '.ok == true' >/dev/null || fail "openclaw result ok != true"
ANSWERED_BY="$(printf '%s' "$JSON" | jq -r '"\(.provider)/\(.model)"')" || fail "malformed openclaw result"
[[ "$ANSWERED_BY" == "$MODEL" ]] || fail "answered by $ANSWERED_BY, not requested $MODEL"
REVIEW="$(printf '%s' "$JSON" | jq -r '[.outputs[]?.text // empty] | join("\n")')" || fail "malformed openclaw outputs"
[[ "$REVIEW" =~ [^[:space:]] ]] || fail "model returned no review text"

printf '%s\n' "$REVIEW"
echo >&2
echo "✓ reviewed by ${MODEL} (separated host+model; reviewer ≠ implementer)" >&2
