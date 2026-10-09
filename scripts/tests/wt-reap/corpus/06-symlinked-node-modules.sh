WHAT_BREAKS="git wt symlinks node_modules from the root checkout; rm -rf through that link destroys the ROOT CHECKOUT's dependency tree, breaking every other worktree and the main repo at once"
setup() {
  mk_main chittyos/chittymarket "$SANDBOX/main-cm" >/dev/null
  SHARED="$(mk_nm "$SANDBOX/main-cm")"
  mk_wt "$SANDBOX/main-cm" "$WTROOT/cm-reap" chore/cm-reap
  ln -s "$SHARED" "$WTROOT/cm-reap/node_modules"
  pr chittyos/chittymarket chore/cm-reap MERGED
  run_reap --apply
}
assert() {
  expect_exists "$SHARED/.gauntlet-marker" &&
  expect_exists "$WTROOT/cm-reap/node_modules" &&
  expect_rc 0
}
