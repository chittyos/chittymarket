WHAT_BREAKS="a landed worktree with no node_modules must not be counted as eligible; inflating the eligible count misstates how much is actually reclaimable"
setup() {
  mk_main chittyos/chittycanon "$SANDBOX/main-ccn" >/dev/null
  mk_wt "$SANDBOX/main-ccn" "$WTROOT/ccn-ontology" feat/ccn-ontology
  pr chittyos/chittycanon feat/ccn-ontology MERGED
  run_reap --apply
}
assert() {
  expect_out_re 'eligible: 0 worktrees, 0 node_modules dirs' &&
  expect_rc 0
}
