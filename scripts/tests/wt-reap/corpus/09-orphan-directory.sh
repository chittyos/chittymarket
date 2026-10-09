WHAT_BREAKS="a plain directory under the root is not a worktree and the script cannot know what it is; reaping inside it deletes someone's untracked scratch space"
setup() {
  mkdir -p "$WTROOT/canon-data-export/node_modules"
  canary "$WTROOT/canon-data-export/node_modules/.gauntlet-marker"
  run_reap --apply
}
assert() {
  expect_out "not a git worktree (orphan directory)" &&
  expect_exists "$WTROOT/canon-data-export/node_modules/.gauntlet-marker" &&
  expect_rc 0
}
