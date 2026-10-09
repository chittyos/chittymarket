WHAT_BREAKS="uncommitted tracked work means a live session; deleting its node_modules kills a running test run mid-flight"
setup() {
  mk_main chittyos/chittyconnect "$SANDBOX/main-cc" >/dev/null
  mk_wt "$SANDBOX/main-cc" "$WTROOT/cc-subdomain" feat/cc-subdomain
  printf 'name: edited-in-place\n' >"$WTROOT/cc-subdomain/wrangler.toml"
  NM="$(mk_nm "$WTROOT/cc-subdomain")"
  pr chittyos/chittyconnect feat/cc-subdomain MERGED
  run_reap --apply
}
assert() {
  expect_out "uncommitted tracked change" && expect_exists "$NM/.gauntlet-marker" &&
  expect_rc 0
}
