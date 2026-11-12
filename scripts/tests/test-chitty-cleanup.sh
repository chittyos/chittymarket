#!/usr/bin/env bash
# test-chitty-cleanup.sh: pins every safety rule in chitty-cleanup/scripts/cleanup.sh.
# One case per finding from the three separated reviews of chittymarket#254.
# Tools are stubbed on PATH, so nothing real is cleaned. Each case uses a fresh sandbox $HOME.
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd -P)
SCRIPT=${CLEANUP_SCRIPT:-$ROOT/plugins/chittyos-core/skills/chitty-cleanup/scripts/cleanup.sh}
TMP=$(mktemp -d "${TMPDIR:-/tmp}/chitty-cleanup-test.XXXXXX")
trap 'rm -rf -- "$TMP"' EXIT
pass=0; fail=0

mkstubs() {  # $1 = stub dir. Each stub answers its resolver query from env and logs all calls.
  local s=$1; mkdir -p "$s"
  for t in npm pnpm yarn pip uv brew; do
    cat > "$s/$t" <<EOF
#!/usr/bin/env bash
echo "$t \$*" >> "\$STUB_LOG"
case "$t \$*" in
  "npm config get cache") printf '%s\n' "\${STUB_NPM:-}" ;;
  "pnpm store path") printf '%s\n' "\${STUB_PNPM:-}" ;;
  "yarn --version") printf '%s\n' "\${STUB_YARN_VER:-}" ;;
  "yarn cache dir") printf '%s\n' "\${STUB_YARN:-}" ;;
  "pip cache dir") printf '%s\n' "\${STUB_PIP:-}" ;;
  "uv cache dir") printf '%s\n' "\${STUB_UV:-}" ;;
  "brew --cache") printf '%s\n' "\${STUB_BREW:-}" ;;
  "brew cleanup"*) echo "FORBIDDEN brew cleanup" >> "\$STUB_LOG"; exit 9 ;;
esac
exit 0
EOF
    chmod +x "$s/$t"
  done
}

new_case() {  # fresh sandbox; sets H, LOG, OUT
  C="$TMP/case$((pass+fail))"; rm -rf -- "$C"; mkdir -p "$C/home" "$C/stubs" "$C/outside"
  H=$(cd "$C/home" && pwd -P); LOG="$C/stub.log"; : > "$LOG"; mkstubs "$C/stubs"
}
run() {  # run cleanup.sh in the sandbox with the given args
  OUT=$(env -i HOME="$H" PATH="$C/stubs:/usr/bin:/bin" STUB_LOG="$LOG" TMPDIR="$TMP" \
    STUB_NPM="${STUB_NPM:-}" STUB_PNPM="${STUB_PNPM:-}" STUB_YARN="${STUB_YARN:-}" STUB_YARN_VER="${STUB_YARN_VER:-}" \
    STUB_PIP="${STUB_PIP:-}" STUB_UV="${STUB_UV:-}" STUB_BREW="${STUB_BREW:-}" \
    ${EXTRA_ENV:-} bash "$SCRIPT" "$@" 2>&1); RC=$?
}
ok()  { pass=$((pass+1)); echo "ok   $1"; }
bad() { fail=$((fail+1)); echo "FAIL $1"; printf '%s\n' "$OUT" | sed 's/^/     | /' | head -20; }
reset_stubs() { STUB_NPM=; STUB_PNPM=; STUB_YARN=; STUB_YARN_VER=; STUB_PIP=; STUB_UV=; STUB_BREW=; EXTRA_ENV=; }

# 1. HOME unset or "/" refuses everything (r3 C1, r2 M5)
reset_stubs; new_case
OUT=$(env -i PATH="$C/stubs:/usr/bin:/bin" STUB_LOG="$LOG" HOME=/ bash "$SCRIPT" --apply 2>&1); RC=$?
[ "$RC" -eq 3 ] && grep -q REFUSE <<<"$OUT" && ! grep -q 'cache clean' "$LOG" && ok "HOME=/ refuses" || bad "HOME=/ refuses"
OUT=$(env -i PATH="$C/stubs:/usr/bin:/bin" STUB_LOG="$LOG" bash "$SCRIPT" --apply 2>&1); RC=$?
[ "$RC" -eq 3 ] && ok "HOME unset refuses" || bad "HOME unset refuses"

# 2. Dry run is the default: no clean command, no deletion (r1 M2, r2 M7)
reset_stubs; new_case; mkdir -p "$H/.cache/Homebrew/x"; STUB_BREW="$H/.cache/Homebrew"; STUB_UV="$H/.cache/uv"; mkdir -p "$H/.cache/uv"
run
grep -q '^PLAN homebrew' <<<"$OUT" && [ -d "$H/.cache/Homebrew/x" ] && ! grep -q 'uv cache clean' "$LOG" && ok "dry-run deletes nothing" || bad "dry-run deletes nothing"

# 3. --apply cleans an allowlisted cache, and passes the guarded dir explicitly to the tool (r3 H4)
reset_stubs; new_case; mkdir -p "$H/.cache/uv" "$H/.cache/pip" "$H/.npm/_cacache" "$H/.local/share/pnpm/store"
STUB_UV="$H/.cache/uv"; STUB_PIP="$H/.cache/pip"; STUB_NPM="$H/.npm"; STUB_PNPM="$H/.local/share/pnpm/store"
run --apply
grep -q "uv cache clean --cache-dir $H/.cache/uv" "$LOG" \
 && grep -q "pip --cache-dir $H/.cache/pip cache purge" "$LOG" \
 && grep -q "npm cache clean --force --cache $H/.npm" "$LOG" \
 && grep -q "pnpm store prune --store-dir $H/.local/share/pnpm/store" "$LOG" \
 && ok "tools get explicit guarded cache dir" || bad "tools get explicit guarded cache dir"

# 4. Symlinked cache pointing at real data is refused, and the data survives (r2 H2)
reset_stubs; new_case; mkdir -p "$H/Documents/precious" "$H/.cache"; echo keep > "$H/Documents/precious/f"
ln -s "$H/Documents/precious" "$H/.cache/mozilla"
run --apply
grep -q 'SKIP firefox: .* is a symlink' <<<"$OUT" && [ -f "$H/Documents/precious/f" ] && ok "symlinked cache refused" || bad "symlinked cache refused"

# 5. Tool cache pointed into user data via env (HOMEBREW_CACHE=~/Downloads) is refused (r2 H3)
reset_stubs; new_case; mkdir -p "$H/Downloads"; echo keep > "$H/Downloads/f"; STUB_BREW="$H/Downloads"
run --apply
grep -q 'SKIP homebrew: .*not under an allowlisted cache root' <<<"$OUT" && [ -f "$H/Downloads/f" ] && ok "brew cache in ~/Downloads refused" || bad "brew cache in ~/Downloads refused"

# 6. Cache outside $HOME (UV_CACHE_DIR=/shared) is refused (r1 H3)
reset_stubs; new_case; mkdir -p "$C/outside/uv"; STUB_UV="$C/outside/uv"
run --apply
grep -q 'SKIP uv: .*not under an allowlisted' <<<"$OUT" && ! grep -q 'uv cache clean' "$LOG" && ok "cache outside home refused" || bad "cache outside home refused"

# 7. A ".." escape is refused (r1/r2)
reset_stubs; new_case; mkdir -p "$C/outside/pip" "$H/.cache"; STUB_PIP="$H/.cache/../../outside/pip"
run --apply
! grep -q 'pip --cache-dir' "$LOG" && ok ".. escape refused" || bad ".. escape refused"

# 8. A parent symlink escaping home is refused: ~/.cache -> outside (r2 finding 4 / review comment)
reset_stubs; new_case; mkdir -p "$C/outside/realcache/uv"; ln -s "$C/outside/realcache" "$H/.cache"; STUB_UV="$H/.cache/uv"
run --apply
! grep -q 'uv cache clean' "$LOG" && [ -d "$C/outside/realcache/uv" ] && ok "parent-symlink escape refused" || bad "parent-symlink escape refused"

# 9. A cache root itself (~/.cache) is not a target (allowlist requires strictly below a root)
reset_stubs; new_case; mkdir -p "$H/.cache/keep"; STUB_BREW="$H/.cache"
run --apply
grep -q 'SKIP homebrew: .*not under an allowlisted' <<<"$OUT" && [ -d "$H/.cache/keep" ] && ok "cache root itself refused" || bad "cache root itself refused"

# 10. A directory containing a repo is refused (r3 H2)
reset_stubs; new_case; mkdir -p "$H/.cache/Homebrew/proj/.git"; STUB_BREW="$H/.cache/Homebrew"
run --apply
grep -q 'SKIP homebrew: .*git repo' <<<"$OUT" && [ -d "$H/.cache/Homebrew/proj/.git" ] && ok "dir containing a repo refused" || bad "dir containing a repo refused"

# 11. Inside a repo is refused even with GIT_DIR pointing somewhere bogus (r3 H3)
reset_stubs; new_case; mkdir -p "$H/.cache/.git" "$H/.cache/uv"; STUB_UV="$H/.cache/uv"; EXTRA_ENV="GIT_DIR=/nonexistent"
run --apply
grep -q 'SKIP uv: .*git repo' <<<"$OUT" && ! grep -q 'uv cache clean' "$LOG" && ok "inside repo refused despite GIT_DIR" || bad "inside repo refused despite GIT_DIR"

# 12. uv with symlink link-mode is skipped pending approval (review comment, uv)
reset_stubs; new_case; mkdir -p "$H/.cache/uv"; STUB_UV="$H/.cache/uv"; EXTRA_ENV="UV_LINK_MODE=symlink"
run --apply
grep -q 'SKIP uv: link-mode' <<<"$OUT" && ! grep -q 'uv cache clean' "$LOG" && ok "uv symlink link-mode skipped" || bad "uv symlink link-mode skipped"

# 13. brew cleanup is never invoked (r1 H1, review comment)
reset_stubs; new_case; mkdir -p "$H/.cache/Homebrew"; STUB_BREW="$H/.cache/Homebrew"
run --apply
! grep -q 'FORBIDDEN' "$LOG" && ! grep -q 'brew cleanup' "$LOG" && ok "brew cleanup never run" || bad "brew cleanup never run"

# 14. Yarn Berry is not automated (r1 H2, r2 M4)
reset_stubs; new_case; mkdir -p "$H/.yarn/berry/cache"; STUB_YARN_VER=4.1.0; STUB_YARN="$H/.yarn/berry/cache"
run --apply
grep -q 'SKIP yarn: Berry' <<<"$OUT" && ! grep -q 'yarn cache clean' "$LOG" && ok "yarn berry not automated" || bad "yarn berry not automated"

# 15. Trash is kept without --trash, and emptied (files/info only) with --apply --trash (r1 M1, r2 L8)
reset_stubs; new_case; mkdir -p "$H/.local/share/Trash/files" "$H/.local/share/Trash/info"; echo x > "$H/.local/share/Trash/files/a"
run --apply
[ -f "$H/.local/share/Trash/files/a" ] && grep -q 'kept; pass --apply --trash' <<<"$OUT" && ok "trash kept by default" || bad "trash kept by default"
run --apply --trash
[ ! -e "$H/.local/share/Trash/files" ] && [ -d "$H/.local/share/Trash" ] && ok "trash emptied only with --trash" || bad "trash emptied only with --trash"

# 16. Darwin: allowlist check is case-insensitive, and ~/Library/Logs is report-only
reset_stubs; new_case; mkdir -p "$H/Library/Caches/Homebrew" "$H/Library/Logs"; echo x > "$H/Library/Logs/crash"; STUB_BREW="$H/library/caches/Homebrew"; mkdir -p "$H/library/caches/Homebrew" 2>/dev/null
EXTRA_ENV="CLEANUP_OS_OVERRIDE=Darwin"; run --apply
grep -q '^DONE homebrew\|^FAIL homebrew\|^PLAN homebrew' <<<"$OUT" && [ -f "$H/Library/Logs/crash" ] && grep -q '^LOGS ' <<<"$OUT" && ok "darwin case-insensitive allowlist + logs report-only" || bad "darwin case-insensitive allowlist + logs report-only"

echo "--- $pass passed, $fail failed"
[ "$fail" -eq 0 ]
