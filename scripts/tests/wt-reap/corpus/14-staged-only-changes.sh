WHAT_BREAKS="a staged-but-uncommitted change is still unlanded work; if --porcelain parsing misses the index column the gate passes and live work is reaped"
setup() {
  mk_main chittyos/chittyid "$SANDBOX/main-cid" >/dev/null
  mk_wt "$SANDBOX/main-cid" "$WTROOT/cid-mint-id" fix/cid-mint-id
  printf 'name: staged\n' >"$WTROOT/cid-mint-id/wrangler.toml"
  git -C "$WTROOT/cid-mint-id" add wrangler.toml
  NM="$(mk_nm "$WTROOT/cid-mint-id")"
  pr chittyos/chittyid fix/cid-mint-id MERGED
  run_reap --apply
}
assert() {
  expect_out "uncommitted tracked change" && expect_exists "$NM/.gauntlet-marker" &&
  expect_rc 0
}
