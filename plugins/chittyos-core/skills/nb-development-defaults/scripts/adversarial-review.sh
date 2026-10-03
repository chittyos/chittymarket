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
#   REVIEW_MODEL   override the model (default: DEFAULT_MODEL below, a directly-named
#                  large-context BYOK frontier model via the `central` gateway)
#   REVIEW_TIMEOUT seconds before the remote call is abandoned (default 600). A hung
#                  ssh must end as a FAILED review, never block forever.
#
# Exit codes: 0 review returned | 1 usage/input | 2 chittyclaw unreachable
#             3 model call failed (route broken / provider error)
# On exit 2 or 3 the caller MUST report the review as NOT performed — never as
# "reviewed" or "no findings".
set -euo pipefail

NODE="chittyclaw"
CLI_CONTAINER="openclaw-prod-openclaw-cli-1"

# NOTE: --model wants <provider>/<catalog-id>. `openclaw infer model list` prints
# the catalog id (e.g. `anthropic/claude-opus-4-8`); the working argument is
# `cloudflare-ai-gateway/<catalog-id>`. A bare id fails "Unknown model". Verified 2026-07-30.
#
# The review lane is a CAPABLE DIRECT MODEL, not a dynamic route. Verified live
# 2026-10-03 by the operator: this default returns a review (exit 0, ✓).
DEFAULT_MODEL="cloudflare-ai-gateway/anthropic/claude-opus-4-8"

# The `dynamic/three-wise-men` route (a catch-all "curated trio of frontier models"
# from the old chittyclaw gateway) was RETIRED DELIBERATELY by the operator on
# 2026-10-03 and must NOT be recreated — not under that name, not as the reviewer.
# Dynamic routes, when they come, are designed strategically: one purpose-built
# route per job, codified under ai-gateway-routes/, drift-checked with
# apply-gateway-route.sh --check. Until such a route is deliberately designed for
# review, keep this lane on a direct model.
# `dynamic/adversarial-reviewer` no longer exists on any gateway and must not be
# used: it was a $0.00 / 32k-context route — the inadequate-reviewer failure mode
# (confident empty findings that get ignored).
#
# Large-context BYOK models ON PURPOSE: Workers AI models return HTTP 413 on this
# agent's own baseline payload (tool defs from several MCP servers + skills) before
# any diff is added — llama-3.3-70b is 24k context, qwen2.5-coder 32k. Context window
# is a correctness requirement here, not a preference. (The gateway is `central`;
# there is no `chittyclaw` gateway — see references/llm-routing.md.)
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
command -v timeout >/dev/null || { echo "timeout(1) is required (bounds the remote call)" >&2; exit 1; }
REVIEW_TIMEOUT="${REVIEW_TIMEOUT:-600}"
[[ "$REVIEW_TIMEOUT" =~ ^[1-9][0-9]*$ ]] && (( REVIEW_TIMEOUT <= 3600 )) \
  || { echo "invalid REVIEW_TIMEOUT: integer seconds in 1..3600" >&2; exit 1; }

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
# flag, so the container-side sh lands stdin in a file and passes it as ONE argv
# element.)
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

# Delivery handshake: what the container must report having received before it
# is allowed to call the model. Byte-exact (the container hashes the file it
# wrote from stdin, before any $(...) newline stripping), so a stream cut short
# by a network blip cannot be reviewed as if it were the whole diff.
EXPECT_BYTES="$PROMPT_BYTES"
EXPECT_SHA="$(sha256sum < "$PROMPT" | cut -d' ' -f1)"

# Runs under the container's /bin/sh (dash). $1=model $2=expected bytes
# $3=expected sha256. Prints "ADV_REVIEW_RECEIVED <bytes> <sha256>" to stderr and
# exits 97 WITHOUT calling the model if either differs from what was sent.
# shellcheck disable=SC2016  # expanded by the remote sh, not here
REMOTE_PROG='
f=$(mktemp) || exit 97
cat > "$f" || { rm -f "$f"; exit 97; }
n=$(wc -c < "$f"); n=$((n + 0))
h=$(sha256sum < "$f" | cut -d " " -f1)
printf "ADV_REVIEW_RECEIVED %s %s\n" "$n" "$h" >&2
if [ "$n" != "$2" ] || [ "$h" != "$3" ]; then rm -f "$f"; exit 97; fi
p=$(cat "$f"); rm -f "$f"
exec openclaw infer model run --json --model "$1" --prompt "$p"'

# INJECTION SINK. Two independent layers keep caller data out of shell syntax:
#   1. MODEL_RE (above) restricts MODEL to [A-Za-z0-9._-] path segments;
#   2. every word of the remote command — including MODEL — is quoted with
#      printf %q for the remote login shell (bash on chittyclaw), and the
#      container sh receives MODEL as positional $1, never as program text.
# Loosening MODEL_RE alone therefore cannot reintroduce injection. The prompt
# and diff never appear in the command at all (stdin only).
REMOTE_CMD="$(printf '%q ' docker exec -i "$CLI_CONTAINER" sh -c "$REMOTE_PROG" \
  adv-review "$MODEL" "$EXPECT_BYTES" "$EXPECT_SHA")"

set +e
timeout -k 10 "$REVIEW_TIMEOUT" ssh -o BatchMode=yes -o ServerAliveInterval=15 \
  "$NODE" "$REMOTE_CMD" < "$PROMPT" > "$RESP" 2> "$ERRF"
RC=$?
set -e

fail() {
  echo "MODEL CALL FAILED — review NOT performed: $1" >&2
  echo "  Do not report this change as reviewed." >&2
  if [[ -s "$ERRF" ]]; then echo "--- remote stderr (tail) ---" >&2; tail -n 20 "$ERRF" >&2; fi
  if [[ -s "$RESP" ]]; then echo "--- remote stdout (head) ---" >&2; head -n 20 "$RESP" >&2; fi
  exit 3
}

delivery_fail() {
  echo "prompt delivery incomplete — review NOT performed: $1" >&2
  echo "  sent ${EXPECT_BYTES} bytes sha256 ${EXPECT_SHA}" >&2
  echo "  Do not report this change as reviewed." >&2
  if [[ -s "$ERRF" ]]; then echo "--- remote stderr (tail) ---" >&2; tail -n 20 "$ERRF" >&2; fi
  exit 3
}

# A timeout is a failed review whatever else arrived: 124 = TERM after the deadline,
# 137 = KILL 10s later (-k) when TERM was ignored. Any other non-zero RC still fails
# below at "remote exit status" — success requires RC 0.
(( RC != 124 && RC != 137 )) || fail "timed out after ${REVIEW_TIMEOUT}s (rc $RC)"

# Delivery is verified BEFORE anything else is believed. No handshake line means
# the container program never got as far as reading the prompt.
RECV="$(grep -m1 '^ADV_REVIEW_RECEIVED ' "$ERRF" || true)"
[[ -n "$RECV" ]] || fail "remote exit status $RC; container never confirmed prompt receipt"
read -r _ RECV_BYTES RECV_SHA <<<"$RECV"
if [[ "$RECV_BYTES" != "$EXPECT_BYTES" || "$RECV_SHA" != "$EXPECT_SHA" ]]; then
  delivery_fail "container received ${RECV_BYTES} bytes sha256 ${RECV_SHA}"
fi
(( RC != 97 )) || delivery_fail "container refused (exit 97)"
echo "→ prompt delivery verified: ${RECV_BYTES} bytes, sha256 ${RECV_SHA}" >&2

# Success is decided POSITIVELY, never by grepping the review text for error
# words (a review that discussed an "unknown model" used to be reported as a
# failed call, and lines mentioning e.g. "plugin" were silently deleted):
#   0. prompt delivery verified (handshake above), 1. remote exit status 0,
#   2. a JSON result with ok=true, 3. answered by the requested provider/model,
#   4. non-blank output text.
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
