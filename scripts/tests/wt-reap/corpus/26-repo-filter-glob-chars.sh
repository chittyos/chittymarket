WHAT_BREAKS="the filter is used as a shell case pattern, not a literal; a value containing *, ? or [ matches far more than typed, and --repo '*' silently selects everything including trees the operator meant to exclude"
setup() {
  mk_main chittyos/chittycases "$SANDBOX/main-cca" >/dev/null
  mk_wt "$SANDBOX/main-cca" "$WTROOT/cca-intake" feat/cca-intake
  NM="$(mk_nm "$WTROOT/cca-intake")"
  pr chittyos/chittycases feat/cca-intake MERGED
  run_reap --repo 'zzz*' --apply
}
assert() {
  expect_no_out "REAP" && expect_exists "$NM/.gauntlet-marker" &&
  expect_rc 0
}
