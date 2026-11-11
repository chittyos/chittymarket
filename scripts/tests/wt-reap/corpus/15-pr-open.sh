WHAT_BREAKS="an OPEN PR is in-flight work; reaping its node_modules kills the CI-reproduction tree the author is still iterating on"
setup() {
  mk_main chittyos/chittyrouter "$SANDBOX/main-cr" >/dev/null
  mk_wt "$SANDBOX/main-cr" "$WTROOT/cr-queue" feat/cr-queue
  NM="$(mk_nm "$WTROOT/cr-queue")"
  pr chittyos/chittyrouter feat/cr-queue OPEN
  run_reap --apply
}
assert() { expect_out "PR is OPEN" && expect_exists "$NM/.gauntlet-marker" && expect_rc 0; }
