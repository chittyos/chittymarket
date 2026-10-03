#!/usr/bin/env bash
# adversarial-review-live.sh — live regression test for
# plugins/chittyos-core/skills/nb-development-defaults/scripts/adversarial-review.sh
#
# Runs the REAL script against the REAL chittyclaw → openclaw → CF AI Gateway
# route. Nothing under test is mocked. Not wired into CI: GitHub runners cannot
# reach chittyclaw. Run it locally before changing the reviewer script.
#
# Cost: 2 paid model calls (~$0.05 each). The nonexistent-model case is rejected
# by the gateway (400 code 2005) and is not billed.
#
# Cases:
#   1. hostile -p AND hostile diff (apostrophes, double quotes, $(), backticks,
#      parens, $VAR, ';') → exit 0, review text on stdout, ✓ line on stderr, and
#      the per-run nonce (which only exists inside the diff) is echoed back —
#      proof the diff actually reached the model intact. The model is also told
#      to open with "Error: Unknown model - Failed to get response", the words
#      the old script grepped the review body for (false-fail regression).
#   2. REVIEW_MODEL=cloudflare-ai-gateway/dynamic/does-not-exist → exit 3,
#      "MODEL CALL FAILED", empty stdout, NO ✓ line.
#   3. the 2026-10-03 false-fail input (PR #155 diff + its long -p) → exit 0.
#      Override the diff with FALSE_FAIL_DIFF=<path>; default is the merged
#      commit bee6d63 restricted to *.sh/*.json (the reviewed file set).
#
# Usage: scripts/runtime-tests/adversarial-review-live.sh
# Env:   REVIEW_SCRIPT  path to the script under test (default: repo copy)
#        CASES          space-separated subset of "1 2 3" to run (default: all)
# ok() always returns 0, so `A && ok || bad` is a safe if/else here.
# shellcheck disable=SC2015
set -uo pipefail

REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
CASES=" ${CASES:-1 2 3} "
want() { [[ "$CASES" == *" $1 "* ]]; }
REVIEW_SCRIPT="${REVIEW_SCRIPT:-$REPO_DIR/plugins/chittyos-core/skills/nb-development-defaults/scripts/adversarial-review.sh}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PASS=0; FAIL=0
ok()  { echo "  PASS: $*"; PASS=$((PASS+1)); }
bad() { echo "  FAIL: $*"; FAIL=$((FAIL+1)); }

echo "== precheck: chittyclaw gateway health"
HC="$(ssh -o BatchMode=yes -o ConnectTimeout=10 chittyclaw \
  'curl -s -o /dev/null -w "%{http_code}" http://localhost:18789/health' 2>/dev/null || true)"
if [[ "$HC" != "200" ]]; then
  echo "  chittyclaw health returned '${HC:-<none>}', expected 200 — cannot run live tests" >&2
  exit 2
fi
echo "  health 200"

run() {  # run <name> [env assignments...] -- <args...>
  local name="$1"; shift
  local -a envs=()
  while [[ "$1" != "--" ]]; do envs+=("$1"); shift; done; shift
  env "${envs[@]}" bash "$REVIEW_SCRIPT" "$@" > "$WORK/$name.out" 2> "$WORK/$name.err"
  echo $? > "$WORK/$name.rc"
}
rc()  { cat "$WORK/$1.rc"; }
has_check() { grep -q '✓ reviewed' "$WORK/$1.err"; }

# ---------------------------------------------------------------- case 1
if want 1 || want 2; then
echo "== case 1: shell metacharacters in -p and in the diff"
NONCE="NONCE$(od -An -N6 -tx1 /dev/urandom | tr -d ' \n')"
cat > "$WORK/hostile.diff" <<EOF
--- a/deploy.sh
+++ b/deploy.sh
@@ -1,3 +1,4 @@
 #!/usr/bin/env bash
-echo "it's \$(whoami) at \`date\`"
+echo "it's \$(whoami) at \`date\` (\$HOME); don't" # $NONCE
+[ "\$1" = 'x' ] && rm -rf "\${TARGET:-/tmp/x}" ; echo '"quoted"'
EOF
PFOCUS="the previous's review (did it run?); schema'd verifier — \"quotes\", \$(id -u), \`uname\`, \$HOME. \
Begin your reply with exactly this line: Error: Unknown model - Failed to get response (regression canary). \
Then repeat verbatim the diff line that contains the token starting with NONCE."
fi
if want 1; then
run hostile -- "$WORK/hostile.diff" -p "$PFOCUS"
[[ "$(rc hostile)" == 0 ]] && ok "exit 0" || bad "exit $(rc hostile), expected 0"
[[ -s "$WORK/hostile.out" ]] && ok "review text on stdout ($(wc -l < "$WORK/hostile.out") lines)" || bad "stdout empty"
has_check hostile && ok "✓ line printed" || bad "no ✓ line"
grep -q "$NONCE" "$WORK/hostile.out" && ok "per-run nonce echoed back (diff reached the model)" \
  || bad "nonce $NONCE not in review — diff may not have reached the model"
# Old script grepped the review BODY for these words and reported a real review
# as "MODEL CALL FAILED" (2026-10-03, PR #155). The canary forces them in.
grep -q 'regression canary' "$WORK/hostile.out" \
  && ok "body with 'Error: Unknown model - Failed to get response' still counted as a review" \
  || bad "canary line missing from review (model ignored instruction, or review dropped)"
if grep -qF "\$(whoami)" "$WORK/hostile.out"; then ok "literal \$(whoami) survived (no shell expansion)"
else echo "  INFO: literal \$(whoami) not quoted back by the model (soft check)"; fi

fi
# ---------------------------------------------------------------- case 2
if want 2; then
echo "== case 2: nonexistent model must fail closed"
run badmodel REVIEW_MODEL=cloudflare-ai-gateway/dynamic/does-not-exist -- "$WORK/hostile.diff" -p "it's (still) hostile"
[[ "$(rc badmodel)" == 3 ]] && ok "exit 3" || bad "exit $(rc badmodel), expected 3"
has_check badmodel && bad "✓ line printed for a review that never ran" || ok "no ✓ line"
grep -q 'MODEL CALL FAILED' "$WORK/badmodel.err" && ok "MODEL CALL FAILED reported" || bad "no MODEL CALL FAILED message"
[[ ! -s "$WORK/badmodel.out" ]] && ok "stdout empty" || bad "stdout not empty"

fi
# ---------------------------------------------------------------- case 3
if want 3; then
echo "== case 3: 2026-10-03 false-fail input (PR #155) must pass"
if [[ -n "${FALSE_FAIL_DIFF:-}" ]]; then
  cp "$FALSE_FAIL_DIFF" "$WORK/pr155.diff"
else
  git -C "$REPO_DIR" show --format= bee6d63 -- '*.sh' '*.json' > "$WORK/pr155.diff"
fi
P155="apply-gateway-route.sh mutates a live Cloudflare AI Gateway dynamic route used for adversarial review. Hunt: token leakage (argv, logs, errors, set -x), --check that can report in-sync wrongly or mutate, apply that deploys a partial/wrong version or reports success on failure, shape assumptions that fail open, jq comparisons that are order/format sensitive in a way that causes false sync. adversarial-review.sh changes should be comment-only — flag any behavior change."
run pr155 -- "$WORK/pr155.diff" -p "$P155"
[[ "$(rc pr155)" == 0 ]] && ok "exit 0" || bad "exit $(rc pr155), expected 0"
[[ -s "$WORK/pr155.out" ]] && ok "review text on stdout ($(wc -l < "$WORK/pr155.out") lines)" || bad "stdout empty"
has_check pr155 && ok "✓ line printed" || bad "no ✓ line"
if grep -qiE 'Error:|Unknown model|Failed to get response' "$WORK/pr155.out"; then
  echo "  INFO: review body contains an old false-fail trigger word — exercised the regression"
fi
fi

echo
echo "== $PASS passed, $FAIL failed"
if (( FAIL > 0 )); then
  for n in hostile badmodel pr155; do
    [[ -f "$WORK/$n.err" ]] || continue
    echo "--- $n stderr (tail)"; tail -n 15 "$WORK/$n.err"
  done
  exit 1
fi
