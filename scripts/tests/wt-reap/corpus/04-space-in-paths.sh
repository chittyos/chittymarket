WHAT_BREAKS="an unquoted expansion on a path with a space splits into two words; rm -rf then takes the first fragment and deletes an unrelated directory"
setup() {
  WTROOT="$SANDBOX/my worktrees"; mkdir -p "$WTROOT"
  mk_main chittyos/chittyid "$SANDBOX/main chittyid" >/dev/null
  mk_wt "$SANDBOX/main chittyid" "$WTROOT/cid mint fix" fix/cid-mint
  NM="$(mk_nm "$WTROOT/cid mint fix")"
  canary "$WTROOT/cid/SHOULD_NOT_EXIST_AS_TARGET.txt"
  pr chittyos/chittyid fix/cid-mint MERGED
  run_reap --apply
}
assert() {
  expect_gone "$NM" &&
  expect_exists "$WTROOT/cid mint fix/wrangler.toml" &&
  expect_exists "$WTROOT/cid/SHOULD_NOT_EXIST_AS_TARGET.txt"
}
