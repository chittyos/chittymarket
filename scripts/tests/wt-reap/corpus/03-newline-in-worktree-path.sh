WHAT_BREAKS="mapfile splits find output on newlines, so a worktree path containing one yields two bogus paths and rm -rf deletes a sibling directory that is not node_modules — the headline blast-radius defect"
setup() {
  mk_main chittyos/chittyconnect "$SANDBOX/main-cc" >/dev/null
  # A plain sibling directory whose name is the prefix before the newline.
  # If mapfile splits, rm -rf lands on exactly this path.
  canary "$WTROOT/cc-280/IMPORTANT_SIBLING.txt"
  # Relative-path fallout lands in cwd.
  canary "$CWD_CANARY/hotfix/node_modules/DO_NOT_DELETE.txt"
  WT="$WTROOT/$(printf 'cc-280\nhotfix')"
  mk_wt "$SANDBOX/main-cc" "$WT" chore/cc-280-hotfix 2>/dev/null \
    || { mk_loose chittyos/chittyconnect "$WT"; }
  NM="$(mk_nm "$WT")"
  pr chittyos/chittyconnect chore/cc-280-hotfix MERGED
  run_reap --apply
}
assert() {
  expect_exists "$WTROOT/cc-280/IMPORTANT_SIBLING.txt" &&
  expect_exists "$CWD_CANARY/hotfix/node_modules/DO_NOT_DELETE.txt"
}
