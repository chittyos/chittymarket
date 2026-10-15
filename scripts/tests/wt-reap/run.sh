#!/usr/bin/env bash
# THE GAUNTLET — fixture runner for scripts/wt-reap.sh
#
# Exercises the REAL script (never a reimplementation) against synthetic
# worktree trees in a temp dir, with `gh` stubbed by PATH injection.
#
#   scripts/tests/wt-reap/run.sh                 # all cases
#   scripts/tests/wt-reap/run.sh 01 07           # only cases whose name matches
#   GAUNTLET_SABOTAGE=<case> scripts/tests/wt-reap/run.sh   # invert one case's
#                                                           # verdict, to prove
#                                                           # the runner can fail
#   GAUNTLET_KEEP=1 ...                          # keep temp dirs for inspection
#
# Exit status: 0 only if every selected case PASSED. DEFERRED cases are
# reported separately and never counted as passes.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$(cd "$HERE/../../.." && pwd)/scripts/wt-reap.sh"
STUB_DIR="$HERE/stubs"
CORPUS="$HERE/corpus"

[ -x "$TARGET" ] || { echo "target not executable: $TARGET" >&2; exit 2; }
[ -x "$STUB_DIR/gh" ] || chmod +x "$STUB_DIR/gh"

# ---------------------------------------------------------------------------
# ISOLATION GUARD. A test that escapes into the real worktree root is worse
# than no test. Every case runs under a fresh mktemp dir and this function
# refuses any root that is not demonstrably inside it.
# ---------------------------------------------------------------------------
FORBIDDEN_ROOTS=(
  "$HOME/projects/worktrees"
  "$HOME/projects/github.com"
)
assert_isolated() {
  local root="$1" rp f rpf
  [ -n "$root" ] || { echo "FATAL: empty GIT_WT_ROOT" >&2; exit 3; }
  rp="$(realpath -m "$root")"
  case "$rp" in
    /tmp/*|/var/tmp/*|/dev/shm/*) ;;
    *) echo "FATAL: synthetic root is not under a temp dir: $rp" >&2; exit 3 ;;
  esac
  for f in "${FORBIDDEN_ROOTS[@]}"; do
    rpf="$(realpath -m "$f")"
    case "$rp" in
      "$rpf"|"$rpf"/*) echo "FATAL: synthetic root is inside a real tree: $rp" >&2; exit 3 ;;
    esac
  done
}
# Snapshot the real worktree root so we can prove afterwards it was untouched.
REAL_ROOT="$HOME/projects/worktrees"
real_snapshot() { [ -d "$REAL_ROOT" ] && { ls -1 "$REAL_ROOT" | sort; find "$REAL_ROOT" -maxdepth 4 -name node_modules | sort; } || :; }
REAL_BEFORE="$(real_snapshot)"

pass=0; fail=0; defer=0
declare -a FAILED=() DEFERRED=()

defer() { DEFER_REASON="$1"; return 90; }

run_case() {
  local file="$1" name
  name="$(basename "$file" .sh)"

  # Per-case sandbox.
  local tmp; tmp="$(mktemp -d "${TMPDIR:-/tmp}/wtreap-gauntlet.XXXXXX")"
  WTROOT="$tmp/worktrees"
  FAKE_HOME="$tmp/home"
  CWD_CANARY="$tmp/cwd-canary"
  PR_TABLE="$tmp/pr-table.tsv"
  GH_LOG="$tmp/gh.log"
  SANDBOX="$tmp"
  mkdir -p "$WTROOT" "$FAKE_HOME" "$CWD_CANARY"
  : >"$PR_TABLE"; : >"$GH_LOG"

  WHAT_BREAKS=""; DEFER_REASON=""; fail_reason=""
  unset -f setup assert 2>/dev/null || :
  # shellcheck disable=SC1090
  source "$HERE/lib.sh"
  # shellcheck disable=SC1090
  source "$file"

  assert_isolated "$WTROOT"

  local rc=0
  setup || rc=$?
  if [ "$rc" = 90 ]; then
    defer=$((defer+1)); DEFERRED+=("$name → ${WHAT_BREAKS}  [DEFERRED: ${DEFER_REASON}]")
    printf 'DEFER %-34s %s\n' "$name" "$DEFER_REASON"
    [ -n "${GAUNTLET_KEEP:-}" ] || rm -rf "$tmp"
    return 0
  elif [ "$rc" != 0 ]; then
    fail=$((fail+1)); FAILED+=("$name → ${WHAT_BREAKS}  [setup failed rc=$rc]")
    printf 'FAIL  %-34s setup failed (rc=%s)\n' "$name" "$rc"
    [ -n "${GAUNTLET_KEEP:-}" ] || rm -rf "$tmp"
    return 0
  fi

  assert_isolated "$WTROOT"
  rc=0
  assert || rc=$?

  # Sabotage hook: invert this case's verdict to prove the runner can go red.
  if [ "${GAUNTLET_SABOTAGE:-}" = "$name" ]; then
    if [ "$rc" = 0 ]; then rc=1; fail_reason="SABOTAGED: assertion forcibly inverted"; else rc=0; fi
  fi

  if [ "$rc" = 90 ]; then
    defer=$((defer+1)); DEFERRED+=("$name → ${WHAT_BREAKS}  [DEFERRED: ${DEFER_REASON}]")
    printf 'DEFER %-34s %s\n' "$name" "$DEFER_REASON"
  elif [ "$rc" = 0 ]; then
    pass=$((pass+1)); printf 'PASS  %-34s %s\n' "$name" "$WHAT_BREAKS"
  else
    fail=$((fail+1)); FAILED+=("$name → ${WHAT_BREAKS}  [${fail_reason:-assertion failed}]")
    printf 'FAIL  %-34s %s\n' "$name" "${fail_reason:-assertion failed}"
    printf '      what breaks: %s\n' "$WHAT_BREAKS"
    if [ -n "${GAUNTLET_VERBOSE:-}" ]; then printf '      --- script output ---\n%s\n' "$REAP_OUT" | sed 's/^/      /'; fi
  fi

  [ -n "${GAUNTLET_KEEP:-}" ] || rm -rf "$tmp"
}

mapfile -t files < <(find "$CORPUS" -maxdepth 1 -name '*.sh' | sort)
[ "${#files[@]}" -gt 0 ] || { echo "no corpus files in $CORPUS" >&2; exit 2; }

for f in "${files[@]}"; do
  if [ $# -gt 0 ]; then
    match=0
    for pat in "$@"; do case "$(basename "$f" .sh)" in *"$pat"*) match=1 ;; esac; done
    [ "$match" = 1 ] || continue
  fi
  run_case "$f"
done

echo
if [ "$REAL_BEFORE" != "$(real_snapshot)" ]; then
  echo "FATAL: the real worktree root at $REAL_ROOT CHANGED during this run." >&2
  exit 3
fi
echo "isolation: real worktree root $REAL_ROOT unchanged (top-level entries + node_modules to depth 4)"

if [ "${#DEFERRED[@]}" -gt 0 ]; then
  echo
  echo "DEFERRED (not counted as passing):"
  printf '  - %s\n' "${DEFERRED[@]}"
fi
if [ "${#FAILED[@]}" -gt 0 ]; then
  echo
  echo "FAILURES:"
  printf '  - %s\n' "${FAILED[@]}"
fi

echo
printf 'pass: %d   fail: %d   deferred: %d\n' "$pass" "$fail" "$defer"
[ "$fail" -eq 0 ] || exit 1
