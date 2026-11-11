WHAT_BREAKS="a typo'd flag that is silently ignored runs the DEFAULT mode instead of the requested one; for --mode that is the difference between reporting and deleting"
setup() {
  run_reap --mode bogus; RC_MODE=$REAP_RC
  run_reap --frobnicate; RC_UNK=$REAP_RC; OUT_UNK="$REAP_OUT"
}
assert() {
  [ "$RC_MODE" = 2 ] || { fail_reason="--mode bogus exited $RC_MODE, expected 2"; return 1; }
  [ "$RC_UNK" = 2 ] || { fail_reason="unknown flag exited $RC_UNK, expected 2"; return 1; }
  grep -qF 'unknown argument' <<<"$OUT_UNK" || { fail_reason="unknown flag not reported"; return 1; }
}
