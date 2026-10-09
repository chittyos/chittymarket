WHAT_BREAKS="under rate limiting EVERY lookup fails at once; if that reads as landed the script reaps all 20 worktrees in a single sweep"
setup() {
  mk_main chittyos/chittyscore "$SANDBOX/main-csc" >/dev/null
  mk_wt "$SANDBOX/main-csc" "$WTROOT/csc-weights" feat/csc-weights
  mk_wt "$SANDBOX/main-csc" "$WTROOT/csc-decay" feat/csc-decay
  NM1="$(mk_nm "$WTROOT/csc-weights")"; NM2="$(mk_nm "$WTROOT/csc-decay")"
  pr chittyos/chittyscore feat/csc-weights __RATELIMIT__
  pr chittyos/chittyscore feat/csc-decay __RATELIMIT__
  run_reap --apply
}
assert() {
  expect_exists "$NM1/.gauntlet-marker" && expect_exists "$NM2/.gauntlet-marker" &&
  expect_no_out "REAP" &&
  expect_rc 0
}
