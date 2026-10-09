WHAT_BREAKS="gh exiting 0 with no output means 'no PR found'; if an empty string is coerced to a landed state the gate is bypassed entirely and unlanded branches are reaped"
setup() {
  mk_main chittyos/chittymonitor "$SANDBOX/main-cmo" >/dev/null
  mk_wt "$SANDBOX/main-cmo" "$WTROOT/cmo-probe" feat/cmo-probe
  NM="$(mk_nm "$WTROOT/cmo-probe")"
  pr chittyos/chittymonitor feat/cmo-probe __EMPTY__
  run_reap --apply
}
assert() { expect_out "no PR for" && expect_exists "$NM/.gauntlet-marker" && expect_rc 0; }
