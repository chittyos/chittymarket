WHAT_BREAKS="the PR cache key is \"\$repo@\$branch\"; a branch containing / or @ must still resolve, and two worktrees sharing a branch must cost ONE gh call — otherwise the cache silently never hits and a 170-tree sweep makes 170 network calls"
setup() {
  mk_main chittyos/chittymarket "$SANDBOX/main-cm" >/dev/null
  mk_wt "$SANDBOX/main-cm" "$WTROOT/cm-reap-a" 'chore/wt-reap@v2'
  # --force: git refuses a second worktree on a checked-out branch otherwise.
  git -C "$SANDBOX/main-cm" worktree add -q --force "$WTROOT/cm-reap-b" 'chore/wt-reap@v2'
  NM1="$(mk_nm "$WTROOT/cm-reap-a")"; NM2="$(mk_nm "$WTROOT/cm-reap-b")"
  pr chittyos/chittymarket 'chore/wt-reap@v2' MERGED
  run_reap --apply
}
assert() {
  expect_gone "$NM1" && expect_gone "$NM2" && expect_gh_calls 1
}
