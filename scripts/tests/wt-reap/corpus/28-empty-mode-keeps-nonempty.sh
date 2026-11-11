WHAT_BREAKS="--mode empty removes worktrees with --force; if the size gate is wrong it removes a tree holding untracked-but-unreplaceable files, which --force discards without a word"
setup() {
  mk_main chittyos/chittydashboard "$SANDBOX/main-cdb" >/dev/null
  mk_wt "$SANDBOX/main-cdb" "$WTROOT/cdb-panels" feat/cdb-panels
  head -c 262144 /dev/zero >"$WTROOT/cdb-panels/BIG_UNTRACKED.bin"
  canary "$WTROOT/cdb-panels/UNTRACKED_NOTES.txt"
  pr chittyos/chittydashboard feat/cdb-panels MERGED
  run_reap --mode empty --apply
}
assert() {
  expect_no_out "EMPTY" &&
  expect_exists "$WTROOT/cdb-panels/UNTRACKED_NOTES.txt" &&
  expect_rc 0
}
