WHAT_BREAKS="if the inner node_modules is enumerated separately, the second rm -rf runs against a path whose parent is already gone — a silent FAILED line that hides whether anything was reaped"
setup() {
  mk_main chittyos/chittyschema "$SANDBOX/main-cs" >/dev/null
  mk_wt "$SANDBOX/main-cs" "$WTROOT/cs-types" feat/cs-types
  OUTER="$(mk_nm "$WTROOT/cs-types")"
  mkdir -p "$OUTER/@chittyos/schema/node_modules"
  printf 'INNER\n' >"$OUTER/@chittyos/schema/node_modules/.gauntlet-marker"
  pr chittyos/chittyschema feat/cs-types MERGED
  run_reap --apply
}
assert() {
  expect_out "deleted 1 node_modules dir(s)" &&
  expect_no_out "FAILED" &&
  expect_gone "$OUTER"
}
