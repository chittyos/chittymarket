WHAT_BREAKS="gate 1 claims 'registered git worktree' but tests only is-inside-work-tree, which is true for ANY repo; a loose clone someone parked under the root is treated as reapable"
setup() {
  mk_loose chittyos/chittybeacon "$WTROOT/cb-standalone"
  git -C "$WTROOT/cb-standalone" checkout -q -b fix/cb-heartbeat
  NM="$(mk_nm "$WTROOT/cb-standalone")"
  pr chittyos/chittybeacon fix/cb-heartbeat MERGED
  run_reap --apply
}
assert() {
  expect_out "SKIP  cb-standalone" &&
  expect_exists "$NM/.gauntlet-marker" &&
  expect_rc 0
}
