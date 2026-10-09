WHAT_BREAKS="an unexpected non-state line on stdout (upgrade notice, warning) must land in the unresolved branch; any prefix/substring match against MERGED would reap on noise"
setup() {
  mk_main chittyos/chittyportal "$SANDBOX/main-cp" >/dev/null
  mk_wt "$SANDBOX/main-cp" "$WTROOT/cp-auth" feat/cp-auth
  NM="$(mk_nm "$WTROOT/cp-auth")"
  pr chittyos/chittyportal feat/cp-auth __GARBAGE__
  run_reap --apply
}
assert() { expect_out_re 'SKIP +cp-auth' && expect_exists "$NM/.gauntlet-marker" && expect_rc 0; }
