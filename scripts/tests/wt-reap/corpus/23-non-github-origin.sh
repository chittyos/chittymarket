WHAT_BREAKS="a non-GitHub remote has no gh-resolvable PR state; guessing one reaps a tree whose work may never have landed"
setup() {
  mk_main chittyos/chittyledger "$SANDBOX/main-cl" >/dev/null
  git -C "$SANDBOX/main-cl" remote set-url origin git@gitlab.com:chittyos/chittyledger.git
  mk_wt "$SANDBOX/main-cl" "$WTROOT/cl-ledger" feat/cl-ledger
  NM="$(mk_nm "$WTROOT/cl-ledger")"
  pr chittyos/chittyledger feat/cl-ledger MERGED
  run_reap --apply
}
assert() {
  expect_out "no github origin remote" && expect_exists "$NM/.gauntlet-marker" &&
  expect_rc 0
}
