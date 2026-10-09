WHAT_BREAKS="jq/gojq emit the literal string 'null' for .[0].state on an empty array; the state variable is then non-empty and must not be read as landed"
setup() {
  mk_main chittyos/chittycert "$SANDBOX/main-cce" >/dev/null
  mk_wt "$SANDBOX/main-cce" "$WTROOT/cce-rotate" fix/cce-rotate
  NM="$(mk_nm "$WTROOT/cce-rotate")"
  pr chittyos/chittycert fix/cce-rotate __NULL__
  run_reap --apply
}
assert() {
  expect_out_re 'SKIP +cce-rotate' && expect_exists "$NM/.gauntlet-marker" &&
  expect_rc 0
}
