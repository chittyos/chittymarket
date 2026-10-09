#!/usr/bin/env bash
# Regression tests for market.sh office commands (preflight / publish / retire).
# Builds a tiny synthetic repo with stub check scripts so it runs in seconds and never
# touches the real tree. Each case is a negative gate: it must FAIL if the guard is removed
# (bash disables `set -e` inside `cmd || ...`, which once made a failing check read as PASS).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MARKET="${MARKET_SH:-$HERE/plugins/chittymarket-manager/skills/market/market.sh}"
[[ -f "$MARKET" ]] || { echo "market.sh not found: $MARKET"; exit 1; }
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "ok   - $1"; }
bad()  { FAIL=$((FAIL+1)); echo "FAIL - $1"; }
expect_rc() { # name want got
  if [[ "$3" == "$2" ]]; then ok "$1 (exit $3)"; else bad "$1: want exit $2, got $3"; fi; }
expect_out() { # name needle haystack want(0=present,1=absent)
  if grep -q -- "$2" <<<"$3"; then [[ "$4" == 0 ]] && ok "$1" || bad "$1: unexpected '$2'"
  else [[ "$4" == 1 ]] && ok "$1" || bad "$1: missing '$2'"; fi; }

make_repo() { # dir
  local r="$1"; mkdir -p "$r" && cd "$r" || exit 1
  git init -q . && git config user.email t@t && git config user.name t
  printf '__pycache__/\n' >.gitignore   # mirrors the real repo; py_compile writes it
  local sh_stubs=(scripts/lint-plugins.sh scripts/test-plugins.sh scripts/check-overlay-coverage.sh
    scripts/check-source-freshness.sh scripts/tests/test-market-reconcile.sh
    scripts/tests/test-gateway-route-lookup.sh scripts/tests/test-market-office.sh
    scripts/generate-marketplace.sh scripts/generate-bootstrap-pointers.sh
    plugins/chittyagent-dispatch/scripts/dispatch.sh)
  local py_stubs=(scripts/validate-openai-workspace.py scripts/check-matter-leak.py
    scripts/validate-overlay-schema.py scripts/overlay-provenance.py scripts/check-document-contract.py
    scripts/tests/test_dispatch_state.py scripts/check-agent-identity.py scripts/market-reconcile.py
    scripts/tests/test_dispatch_workflow.py scripts/generate-capability-views.py
    plugins/chittyagent-dispatch/scripts/lib/state.py)
  local f
  for f in "${sh_stubs[@]}"; do mkdir -p "$(dirname "$f")"; printf '#!/usr/bin/env bash\nexit 0\n' >"$f"; done
  for f in "${py_stubs[@]}"; do mkdir -p "$(dirname "$f")"; printf 'import sys\nsys.exit(0)\n' >"$f"; done
  printf '{"artifacts":[{"id":"demo","name":"Demo","type":"skill","enabled":true,"installMode":"standalone"}]}\n' >marketplace.json
  printf '{"total":1,"capabilities":[{"capability_id":"chittycanon://capability/market/demo","legacy_id":"demo"}]}\n' >capabilities.generated.json
  git add -A && git commit -qm init
}
run() { # repo args... ; sets OUT and RC
  local r="$1"; shift
  local h="$WORK/home"; rm -rf "$h"; mkdir -p "$h/.claude"
  ln -s "$r/marketplace.json" "$h/.claude/marketplace.json"
  OUT="$(cd "$r" && HOME="$h" MARKET_OVERLAY="$r/capabilities.generated.json" bash "$MARKET" "$@" 2>&1)"; RC=$?
}

R1="$WORK/r1"; make_repo "$R1"; cd "$HERE"
run "$R1" preflight;                expect_rc "clean preflight passes" 0 "$RC"; expect_out "clean preflight says PASS" "PREFLIGHT PASS" "$OUT" 0
run "$R1" publish demo;             expect_rc "publish known id is HOLD" 2 "$RC"; expect_out "publish known id reports READY then HOLD" "READY: preflight passed" "$OUT" 0
run "$R1" publish does-not-exist;   expect_rc "publish unknown id is HOLD" 2 "$RC"; expect_out "unknown id never READY" "READY" "$OUT" 1
run "$R1" publish /etc;             expect_rc "publish path outside repo is HOLD" 2 "$RC"; expect_out "outside path never READY" "READY" "$OUT" 1
run "$R1" publish "";               expect_rc "publish empty arg is HOLD" 2 "$RC"
run "$R1" retire demo;              expect_rc "retire is HOLD" 2 "$RC"
run "$R1" retire "";                expect_rc "retire empty arg is HOLD" 2 "$RC"
[[ "$(git -C "$R1" worktree list | wc -l)" == 1 ]] && ok "no leaked worktree" || bad "leaked worktree"
[[ -z "$(git -C "$R1" status --porcelain)" ]] && ok "repo tree untouched" || bad "repo tree modified"

# Negative gate: a failing check MUST fail preflight and block READY.
R2="$WORK/r2"; make_repo "$R2"; cd "$R2"
printf 'import sys\nsys.exit(1)\n' >scripts/check-matter-leak.py; git commit -qam "failing check"; cd "$HERE"
run "$R2" preflight;                expect_rc "failing check fails preflight" 1 "$RC"; expect_out "failing check never PASS" "PREFLIGHT PASS" "$OUT" 1
run "$R2" publish demo;             expect_rc "failing check makes publish HOLD" 2 "$RC"; expect_out "failing check never READY" "READY" "$OUT" 1

# Dirty tree: HOLD and the uncommitted edit survives.
R3="$WORK/r3"; make_repo "$R3"; echo "# uncommitted" >>"$R3/scripts/lint-plugins.sh"
run "$R3" preflight;                expect_rc "dirty tree is HOLD" 2 "$RC"
grep -q "# uncommitted" "$R3/scripts/lint-plugins.sh" && ok "uncommitted edit preserved" || bad "uncommitted edit destroyed"

# Non-idempotent generation: HOLD, real tree untouched.
R4="$WORK/r4"; make_repo "$R4"; cd "$R4"
printf '#!/usr/bin/env bash\necho x >>generated.out\nexit 0\n' >scripts/generate-marketplace.sh; git add -A; git commit -qm drift; cd "$HERE"
run "$R4" preflight;                expect_rc "non-idempotent generation is HOLD" 2 "$RC"; expect_out "drift is reported" "not idempotent" "$OUT" 0
[[ -z "$(git -C "$R4" status --porcelain)" ]] && ok "drift did not leak into real tree" || bad "drift leaked into real tree"

# Path identity: only publishable sources inside the repo count; root and stray files do not.
run "$R1" publish "$R1/plugins/chittyagent-dispatch"; expect_rc "publish a plugin source path is HOLD (never exit 0)" 2 "$RC"; expect_out "plugin source path resolves to READY" "READY: preflight passed" "$OUT" 0
run "$R1" publish "$R1";            expect_rc "publish repo root is HOLD" 2 "$RC"; expect_out "repo root never READY" "READY" "$OUT" 1
run "$R1" publish "$R1/.gitignore"; expect_rc "publish stray repo file is HOLD" 2 "$RC"; expect_out "stray file never READY" "READY" "$OUT" 1

# Signal mid-generation must END the run (a trap that only returns lets later steps run in the
# real tree and read as PASS). Generator 1 TERMs preflight; generator 2 would write MARKER.
R5="$WORK/r5"; make_repo "$R5"; cd "$R5"
printf '#!/usr/bin/env bash\nkill -TERM "$(cat "$PIDF")"\nsleep 2\nexit 0\n' >scripts/generate-marketplace.sh
printf 'open("MARKER","w").write("x")\n' >scripts/generate-capability-views.py
git add -A; git commit -qm "term"; cd "$HERE"
H5="$WORK/h5"; mkdir -p "$H5/.claude"; ln -s "$R5/marketplace.json" "$H5/.claude/marketplace.json"
OUT="$(cd "$R5" && PIDF="$WORK/pid5" HOME="$H5" MARKET_OVERLAY="$R5/capabilities.generated.json" MARKET="$MARKET" \
  bash -c 'echo $$ >"$PIDF"; exec bash "$MARKET" publish demo' 2>&1)"; RC=$?
expect_rc "SIGTERM mid-run terminates the run (143), never success" 143 "$RC"; expect_out "SIGTERM never READY" "READY" "$OUT" 1; expect_out "SIGTERM never PASS" "PREFLIGHT PASS" "$OUT" 1
[[ ! -e "$R5/MARKER" ]] && ok "SIGTERM did not let later generators write into the real tree" || bad "later generator ran in real tree after SIGTERM"
[[ "$(git -C "$R5" worktree list | wc -l)" == 1 ]] && ok "SIGTERM leaves no worktree" || bad "SIGTERM leaked worktree"

# Unknown is never clean: if git status of the idempotency worktree fails, that is HOLD, not PASS.
R6="$WORK/r6"; make_repo "$R6"; cd "$R6"
printf '#!/usr/bin/env bash\nrm -f .git\nexit 0\n' >scripts/generate-bootstrap-pointers.sh; git add -A; git commit -qm "break git"; cd "$HERE"
run "$R6" preflight;                expect_rc "unreadable worktree status is HOLD" 2 "$RC"; expect_out "unreadable status never PASS" "PREFLIGHT PASS" "$OUT" 1
run "$R6" publish demo;             expect_rc "unreadable worktree status makes publish HOLD" 2 "$RC"; expect_out "unreadable status never READY" "READY" "$OUT" 1

# Repo without scripts/: publish must still HOLD with exit 2 (not die with 1).
R7="$WORK/r7"; mkdir -p "$R7"; cd "$R7"; git init -q .; git config user.email t@t; git config user.name t
printf '{"artifacts":[{"id":"demo"}]}\n' >marketplace.json
printf '{"total":1,"capabilities":[{"capability_id":"chittycanon://capability/market/demo","legacy_id":"demo"}]}\n' >capabilities.generated.json
git add -A; git commit -qm init; cd "$HERE"
run "$R7" publish demo;             expect_rc "publish with no scripts/ is HOLD not die" 2 "$RC"

echo; echo "$PASS passed, $FAIL failed"; [[ "$FAIL" -eq 0 ]]
