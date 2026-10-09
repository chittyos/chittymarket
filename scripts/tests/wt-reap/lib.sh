#!/usr/bin/env bash
# Shared fixture helpers for the wt-reap gauntlet.
#
# Everything here builds SYNTHETIC repos and worktrees inside a per-case
# temp dir. Nothing reads or writes $HOME/projects/worktrees or any real
# repository. See the isolation guard in run.sh.

# --- repo construction -------------------------------------------------

# mk_main <owner/name> <dir>  — a real main checkout with one commit and an
# origin URL that is never fetched. Branch names and repo slugs mirror the
# shapes seen on this host (chittyos/chittyconnect, cc-280, chore/foo).
mk_main() {
  local slug="$1" dir="$2"
  mkdir -p "$dir"
  git -C "$dir" init -q -b main
  git -C "$dir" remote add origin "https://github.com/${slug}.git"
  printf 'name: %s\n' "${slug##*/}" >"$dir/wrangler.toml"
  git -C "$dir" add -A
  git -C "$dir" commit -q -m "chore: initial import of ${slug##*/}"
  printf '%s' "$dir"
}

# mk_wt <main_dir> <worktree_path> <branch>  — a genuinely registered linked
# worktree, so gate 1 sees what it expects to see.
mk_wt() {
  local main="$1" path="$2" branch="$3"
  git -C "$main" worktree add -q -b "$branch" "$path" main
}

# mk_loose <owner/name> <dir>  — a standalone clone-shaped repo, NOT a
# registered worktree of anything. Used to probe gate 1's actual check.
mk_loose() { mk_main "$1" "$2" >/dev/null; }

# mk_nm <dir> [relative_subpath]  — a node_modules directory with content,
# carrying a marker so deletion is detectable.
mk_nm() {
  local wt="$1" sub="${2:-}" nm
  if [ -n "$sub" ]; then nm="$wt/$sub/node_modules"; else nm="$wt/node_modules"; fi
  mkdir -p "$nm/.bin" "$nm/typescript/lib"
  printf '{"name":"typescript","version":"5.6.3"}\n' >"$nm/typescript/package.json"
  head -c 65536 /dev/zero >"$nm/typescript/lib/tsc.js" 2>/dev/null || :
  printf 'NODE_MODULES_MARKER\n' >"$nm/.gauntlet-marker"
  printf '%s' "$nm"
}

# canary <path>  — a marker file whose SURVIVAL is the assertion. Used for
# anything the script must never touch.
canary() {
  local p="$1"
  mkdir -p "$(dirname "$p")"
  printf 'CANARY — deleting this file is the defect\n' >"$p"
}

# pr <owner/name> <branch> <state>  — append a row to the stub's PR table.
pr() { printf '%s\t%s\t%s\n' "$1" "$2" "$3" >>"$PR_TABLE"; }

# --- running the real script ------------------------------------------

# run_reap [args...] — invokes the REAL scripts/wt-reap.sh with the stub gh
# on PATH, HOME redirected, and cwd set to the cwd canary dir (so a relative
# path escaping into rm -rf lands somewhere observable).
# Sets: REAP_OUT, REAP_RC
run_reap() {
  local out rc=0
  # CHOKEPOINT. The real script is never launched until the synthetic root
  # has been proven to be inside this case's temp dir. The pre/post checks in
  # run.sh are belt; this is braces.
  assert_isolated "$WTROOT"
  out="$(
    cd "$CWD_CANARY" || exit 99
    env -i \
      PATH="$STUB_DIR:/usr/local/bin:/usr/bin:/bin" \
      HOME="$FAKE_HOME" \
      GIT_WT_ROOT="$WTROOT" \
      GAUNTLET_PR_TABLE="$PR_TABLE" \
      GAUNTLET_GH_LOG="$GH_LOG" \
      GIT_AUTHOR_NAME="gauntlet" GIT_AUTHOR_EMAIL="gauntlet@invalid" \
      GIT_COMMITTER_NAME="gauntlet" GIT_COMMITTER_EMAIL="gauntlet@invalid" \
      GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
      LANG=C.UTF-8 \
      bash "$TARGET" "$@" 2>&1
  )" || rc=$?
  REAP_OUT="$out"
  REAP_RC=$rc
  if [ "$rc" != 2 ] && ! grep -q '^auth auth status' "$GH_LOG"; then
    echo "FATAL: stub gh was never invoked — PATH injection failed, the real gh may have answered" >&2
    exit 3
  fi
}

# --- assertions --------------------------------------------------------

fail_reason=""
expect_exists() { [ -e "$1" ] || { fail_reason="expected to still exist but is gone: $1"; return 1; }; }
expect_gone()   { [ ! -e "$1" ] || { fail_reason="expected to be deleted but still exists: $1"; return 1; }; }
expect_rc()     { [ "$REAP_RC" = "$1" ] || { fail_reason="exit code $REAP_RC, expected $1"; return 1; }; }
expect_out()    { grep -qF -- "$1" <<<"$REAP_OUT" || { fail_reason="output missing: $1"; return 1; }; }
expect_no_out() { grep -qF -- "$1" <<<"$REAP_OUT" && { fail_reason="output should not contain: $1"; return 1; }; return 0; }
expect_out_re() { grep -qE -- "$1" <<<"$REAP_OUT" || { fail_reason="output missing /$1/"; return 1; }; }
expect_no_out_re() { grep -qE -- "$1" <<<"$REAP_OUT" && { fail_reason="output should not match /$1/"; return 1; }; return 0; }
expect_gh_calls() {
  local want="$1" got
  got=$(grep -c '^pr list' "$GH_LOG" 2>/dev/null || echo 0)
  [ "$got" = "$want" ] || { fail_reason="gh pr list called $got time(s), expected $want"; return 1; }
}
