WHAT_BREAKS="the header documents 'Exits 0 when the sweep completed... non-zero only on a usage or precondition error'. If a successful --apply exits non-zero, every wrapper, cron entry and CI step that checks the status reads a completed reap as a failed one and may retry it or alarm on it"
setup() {
  mk_main chittyos/chittyapi "$SANDBOX/main-ca" >/dev/null
  mk_wt "$SANDBOX/main-ca" "$WTROOT/ca-health" fix/ca-health
  mk_nm "$WTROOT/ca-health" >/dev/null
  pr chittyos/chittyapi fix/ca-health MERGED
  run_reap --apply
}
assert() {
  expect_out_re 'eligible: [0-9]+ worktrees' &&
  expect_out_re 'on-disk size of those dirs' &&
  expect_rc 0
}
