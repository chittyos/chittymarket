WHAT_BREAKS="\$WTROOT/*/ matches a directory SYMLINK; in --mode empty --apply the script resolves it and runs 'worktree remove --force' on the real tree OUTSIDE the root, deleting a worktree the operator never asked it to consider"
setup() {
  mk_main chittyos/chittyevidence "$SANDBOX/main-ce" >/dev/null
  mk_wt "$SANDBOX/main-ce" "$SANDBOX/elsewhere/ce-exhibit" feat/ce-exhibit
  canary "$SANDBOX/elsewhere/ce-exhibit/UNTRACKED_NOTES.txt"
  ln -s "$SANDBOX/elsewhere/ce-exhibit" "$WTROOT/ce-alias"
  pr chittyos/chittyevidence feat/ce-exhibit MERGED
  run_reap --mode empty --apply
}
assert() {
  expect_exists "$SANDBOX/elsewhere/ce-exhibit/UNTRACKED_NOTES.txt" &&
  expect_exists "$SANDBOX/elsewhere/ce-exhibit/wrangler.toml" &&
  expect_rc 0
}
