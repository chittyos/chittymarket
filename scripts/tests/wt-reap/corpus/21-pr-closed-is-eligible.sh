WHAT_BREAKS="CLOSED is documented as reapable alongside MERGED; if only MERGED is honoured the abandoned-branch half of the sprawl is never reclaimed"
setup() {
  mk_main chittyos/chittydiscovery "$SANDBOX/main-cd" >/dev/null
  mk_wt "$SANDBOX/main-cd" "$WTROOT/cd-registry" feat/cd-registry
  NM="$(mk_nm "$WTROOT/cd-registry")"
  pr chittyos/chittydiscovery feat/cd-registry CLOSED
  run_reap --apply
}
assert() { expect_out "PR CLOSED" && expect_gone "$NM"; }
