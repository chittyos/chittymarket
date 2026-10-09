WHAT_BREAKS="ssh://git@github.com:22/org/repo must parse to org/repo; a naive strip yields the slug '22/org/repo', which resolves to no PR and silently skips a tree that was in fact reapable"
setup() {
  mk_main chittyos/chittyapi "$SANDBOX/main-ca" >/dev/null
  git -C "$SANDBOX/main-ca" remote set-url origin ssh://git@github.com:22/chittyos/chittyapi.git
  mk_wt "$SANDBOX/main-ca" "$WTROOT/ca-gateway" feat/ca-gateway
  NM="$(mk_nm "$WTROOT/ca-gateway")"
  pr chittyos/chittyapi feat/ca-gateway MERGED
  run_reap --apply
}
assert() {
  expect_out "REAP  ca-gateway" && expect_gone "$NM" &&
  { grep -qF -- '--repo chittyos/chittyapi' "$GH_LOG" || { fail_reason="gh was asked for the wrong slug: $(grep '^pr list' "$GH_LOG" | head -1)"; return 1; }; }
}
