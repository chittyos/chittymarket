WHAT_BREAKS="a nonexistent GIT_WT_ROOT must be a precondition failure, not an empty successful sweep that reads as 'nothing to reclaim'"
setup() {
  WTROOT="$SANDBOX/worktrees-absent"
  run_reap
}
assert() {
  [ "$REAP_RC" = 2 ] || { fail_reason="exited $REAP_RC, expected 2"; return 1; }
  expect_out "no worktree root at"
}
