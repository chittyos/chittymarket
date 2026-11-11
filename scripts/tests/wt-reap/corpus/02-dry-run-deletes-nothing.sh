WHAT_BREAKS="if the default (no --apply) deletes anything, every operator who ran it to look costs themselves the rebuild"
setup() {
  mk_main chittyos/chittyevidence-db "$SANDBOX/main-ced" >/dev/null
  mk_wt "$SANDBOX/main-ced" "$WTROOT/ced-failclosed" fix/ced-fail-closed
  NM="$(mk_nm "$WTROOT/ced-failclosed")"
  pr chittyos/chittyevidence-db fix/ced-fail-closed MERGED
  run_reap
}
assert() {
  expect_out "DRY RUN" && expect_exists "$NM/.gauntlet-marker" &&
  expect_rc 0
}
