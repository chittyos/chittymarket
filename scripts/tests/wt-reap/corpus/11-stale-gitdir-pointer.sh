WHAT_BREAKS="a worktree whose .git file points at a removed gitdir cannot be interrogated at all; if the failure is not treated as a skip the script proceeds on unknown state"
setup() {
  mk_main chittyos/chittytrust "$SANDBOX/main-ct" >/dev/null
  mk_wt "$SANDBOX/main-ct" "$WTROOT/ct-deploy-fix" fix/ct-deploy
  NM="$(mk_nm "$WTROOT/ct-deploy-fix")"
  printf 'gitdir: %s/main-ct/.git/worktrees/REMOVED\n' "$SANDBOX" >"$WTROOT/ct-deploy-fix/.git"
  pr chittyos/chittytrust fix/ct-deploy MERGED
  run_reap --apply
}
assert() {
  expect_out "SKIP  ct-deploy-fix" &&
  expect_exists "$NM/.gauntlet-marker" &&
  expect_rc 0
}
