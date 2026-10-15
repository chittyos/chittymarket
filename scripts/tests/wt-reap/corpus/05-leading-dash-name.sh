WHAT_BREAKS="a path fragment beginning with - is read as a flag by find/du/rm; at best the sweep aborts, at worst rm -rf receives an option it honours"
setup() {
  mk_main chittyos/chittyrouter "$SANDBOX/main-cr" >/dev/null
  mk_wt "$SANDBOX/main-cr" "$WTROOT/-rf-router-retry" fix/router-retry
  NM="$(mk_nm "$WTROOT/-rf-router-retry")"
  pr chittyos/chittyrouter fix/router-retry MERGED
  run_reap --apply
}
assert() {
  expect_gone "$NM" && expect_exists "$WTROOT/-rf-router-retry/wrangler.toml"
}
