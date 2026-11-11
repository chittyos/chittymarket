WHAT_BREAKS="if a cleanly-landed worktree is NOT reaped the script does nothing and the 14G stays; if it reaps something other than node_modules it destroyed tracked work"
setup() {
  mk_main chittyos/chittyconnect "$SANDBOX/main-chittyconnect" >/dev/null
  mk_wt "$SANDBOX/main-chittyconnect" "$WTROOT/cc-280" chore/cc-280-env-normalize
  NM="$(mk_nm "$WTROOT/cc-280")"
  canary "$WTROOT/cc-280/wrangler.toml.keep"
  pr chittyos/chittyconnect chore/cc-280-env-normalize MERGED
  run_reap --apply
}
assert() {
  expect_out "REAP  cc-280" &&
  expect_gone "$NM" &&
  expect_exists "$WTROOT/cc-280/wrangler.toml" &&
  expect_exists "$WTROOT/cc-280/wrangler.toml.keep"
}
