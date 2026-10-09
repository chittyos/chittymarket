WHAT_BREAKS="three real worktrees on this host are on detached HEAD; with no branch there is no PR to resolve, so reaping them is reaping on unverified state"
setup() {
  mk_main chittyos/chittyschema "$SANDBOX/main-cs" >/dev/null
  mk_wt "$SANDBOX/main-cs" "$WTROOT/cs-migr" wip/cs-migr
  git -C "$WTROOT/cs-migr" checkout -q --detach HEAD
  NM="$(mk_nm "$WTROOT/cs-migr")"
  pr chittyos/chittyschema wip/cs-migr MERGED
  run_reap --apply
}
assert() {
  expect_out "detached HEAD" && expect_exists "$NM/.gauntlet-marker" &&
  expect_rc 0
}
