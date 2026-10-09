WHAT_BREAKS="a gh failure is an UNKNOWN PR state, not a landed one; conflating the two deletes on no evidence at all"
setup() {
  mk_main chittyos/chittyintel "$SANDBOX/main-ci" >/dev/null
  mk_wt "$SANDBOX/main-ci" "$WTROOT/ci-ingest" feat/ci-ingest
  NM="$(mk_nm "$WTROOT/ci-ingest")"
  pr chittyos/chittyintel feat/ci-ingest __ERR__
  run_reap --apply
}
assert() { expect_out_re 'SKIP +ci-ingest' && expect_exists "$NM/.gauntlet-marker" && expect_rc 0; }
