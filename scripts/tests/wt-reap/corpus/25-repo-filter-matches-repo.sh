WHAT_BREAKS="--repo is documented as 'restrict to one repo's worktrees' but matches the worktree DIRECTORY name; on this host directory names are branch slugs (cc-280, ced-failclosed), so the flag silently selects the wrong set — it can exclude every worktree of the named repo and include worktrees of a different repo"
setup() {
  mk_main chittyos/chittyconnect "$SANDBOX/main-cc" >/dev/null
  mk_main chittyos/chittyconnect-legacy "$SANDBOX/main-ccl" >/dev/null
  # Belongs to chittyconnect, but the directory is named after the branch.
  mk_wt "$SANDBOX/main-cc"  "$WTROOT/cc-280"              chore/cc-280
  # Belongs to a DIFFERENT repo, but the directory name shares the prefix.
  mk_wt "$SANDBOX/main-ccl" "$WTROOT/chittyconnect-legacy-pin" chore/ccl-pin
  NM_IN="$(mk_nm "$WTROOT/cc-280")"
  NM_OUT="$(mk_nm "$WTROOT/chittyconnect-legacy-pin")"
  pr chittyos/chittyconnect chore/cc-280 MERGED
  pr chittyos/chittyconnect-legacy chore/ccl-pin MERGED
  run_reap --repo chittyconnect --apply
}
assert() {
  expect_gone "$NM_IN" &&
  expect_exists "$NM_OUT/.gauntlet-marker"
}
