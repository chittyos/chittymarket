#!/usr/bin/env bash
# test-chitty-cleanup.sh: pins every safety rule in chitty-cleanup/scripts/cleanup.sh.
# One case per finding from the separated reviews of chittymarket#254. Each refusal case
# asserts the SKIP reason AND that the data survives, so a case can't pass just because
# a resolver printed nothing. Tools and pgrep are stubbed; every case has a fresh sandbox $HOME.
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd -P)
SCRIPT=${CLEANUP_SCRIPT:-$ROOT/plugins/chittyos-core/skills/chitty-cleanup/scripts/cleanup.sh}
TMP=$(mktemp -d "${TMPDIR:-/tmp}/chitty-cleanup-test.XXXXXX")
trap 'rm -rf -- "$TMP"' EXIT
pass=0; fail=0; n=0

mkstubs() {
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
  *clean*|*purge*|*prune*) [ "\${STUB_FAIL:-}" = "$t" ] && exit 1 ;;
esac
exit 0
EOF
    chmod +x "$s/$t"
  done
  cat > "$s/pgrep" <<'EOF'
#!/usr/bin/env bash
echo "pgrep $*" >> "$STUB_LOG"
last=${!#}
[ -n "${STUB_RUNNING:-}" ] && [ "$last" = "$STUB_RUNNING" ] && exit 0
exit 1
EOF
  chmod +x "$s/pgrep"
}
new_case() {  # $1 optional home dir name
  n=$((n+1)); C="$TMP/case$n"; mkdir -p "$C/${1:-home}" "$C/outside"; mkdir -p "$C/stubs"
  H=$(cd "$C/${1:-home}" && pwd -P); LOG="$C/stub.log"; : > "$LOG"; mkstubs "$C/stubs"
  STUB_NPM=; STUB_PNPM=; STUB_YARN=; STUB_YARN_VER=; STUB_PIP=; STUB_UV=; STUB_BREW=; STUB_FAIL=; STUB_RUNNING=; XENV=
}
run() {
  OUT=$(env -i HOME="$H" PATH="$C/stubs:/usr/bin:/bin" STUB_LOG="$LOG" TMPDIR="$TMP" \
    STUB_NPM="$STUB_NPM" STUB_PNPM="$STUB_PNPM" STUB_YARN="$STUB_YARN" STUB_YARN_VER="$STUB_YARN_VER" \
    STUB_PIP="$STUB_PIP" STUB_UV="$STUB_UV" STUB_BREW="$STUB_BREW" STUB_FAIL="$STUB_FAIL" STUB_RUNNING="$STUB_RUNNING" \
    $XENV bash "$SCRIPT" "$@" 2>&1); RC=$?
}
check() { if eval "$2"; then pass=$((pass+1)); echo "ok   $1"; else fail=$((fail+1)); echo "FAIL $1"; printf '%s\n' "$OUT" | sed 's/^/     | /' | head -15; fi; }
has()  { grep -qF -- "$1" <<<"$OUT"; }
logs() { grep -qF -- "$1" "$LOG"; }

# 1. HOME "/" or unset refuses (exit 3) and runs no clean
new_case; OUT=$(env -i PATH="$C/stubs:/usr/bin:/bin" STUB_LOG="$LOG" HOME=/ bash "$SCRIPT" --apply 2>&1); RC=$?
check "HOME=/ refuses" '[ $RC -eq 3 ] && has REFUSE && ! logs "cache clean"'
new_case; OUT=$(env -i PATH="$C/stubs:/usr/bin:/bin" STUB_LOG="$LOG" bash "$SCRIPT" --apply 2>&1); RC=$?
check "HOME unset refuses" '[ $RC -eq 3 ]'

# 2. Dry run is the default: plans, deletes nothing, runs no clean command
new_case; mkdir -p "$H/.cache/Homebrew/x" "$H/.cache/pip"; STUB_BREW="$H/.cache/Homebrew"; STUB_PIP="$H/.cache/pip"; run
check "dry-run plans and deletes nothing" 'has "PLAN homebrew" && has "PLAN pip" && [ -d "$H/.cache/Homebrew/x" ] && ! logs "cache purge"'

# 3. --apply passes the guarded dir explicitly to every tool
new_case; mkdir -p "$H/.cache/uv" "$H/.cache/pip" "$H/.npm/_cacache" "$H/.local/share/pnpm/store/v10" "$H/.cache/yarn/v6"
STUB_UV="$H/.cache/uv"; STUB_PIP="$H/.cache/pip"; STUB_NPM="$H/.npm"; STUB_PNPM="$H/.local/share/pnpm/store/v10"; STUB_YARN_VER=1.22.22; STUB_YARN="$H/.cache/yarn/v6"
run --apply --uv
check "tools get explicit guarded dir" 'logs "uv cache clean --cache-dir $H/.cache/uv" && logs "pip --cache-dir $H/.cache/pip cache purge" && logs "npm cache clean --force --cache $H/.npm" && logs "pnpm store prune --store-dir $H/.local/share/pnpm/store/v10" && logs "yarn cache clean --cache-folder $H/.cache/yarn/v6" && [ $RC -eq 0 ]'

# 4. A symlinked cache pointing at real data is refused, and the data survives
new_case; mkdir -p "$H/Documents/p" "$H/.cache"; echo k > "$H/Documents/p/f"; ln -s "$H/Documents/p" "$H/.cache/mozilla"; run --apply
check "symlinked cache refused" 'has "SKIP firefox:" && has "is a symlink" && [ -f "$H/Documents/p/f" ]'

# 5. A tool cache pointed into user data (HOMEBREW_CACHE=~/Downloads) is refused
new_case; mkdir -p "$H/Downloads"; echo k > "$H/Downloads/f"; STUB_BREW="$H/Downloads"; run --apply
check "brew cache in ~/Downloads refused" 'has "SKIP homebrew:" && has "expected cache directory" && [ -f "$H/Downloads/f" ]'

# 6. A cache outside $HOME is refused
new_case; mkdir -p "$C/outside/uv"; echo k > "$C/outside/uv/f"; STUB_UV="$C/outside/uv"; run --apply --uv
check "cache outside home refused" 'has "SKIP uv:" && has "expected cache directory" && [ -f "$C/outside/uv/f" ]'

# 7. A ".." escape is refused (asserts the SKIP line, so it can't pass by absence alone)
new_case; mkdir -p "$C/outside/pip" "$H/.cache"; echo k > "$C/outside/pip/f"; STUB_PIP="$H/.cache/../../outside/pip"; run --apply
check ".. escape refused" 'has "SKIP pip:" && ! logs "pip --cache-dir" && [ -f "$C/outside/pip/f" ]'

# 8. A parent symlink escaping home is refused
new_case; mkdir -p "$C/outside/real/uv"; echo k > "$C/outside/real/uv/f"; ln -s "$C/outside/real" "$H/.cache"; STUB_UV="$H/.cache/uv"; run --apply --uv
check "parent-symlink escape refused" 'has "SKIP uv:" && has "expected cache directory" && [ -f "$C/outside/real/uv/f" ]'

# 9. A broad root (~/.cache) is never a target
new_case; mkdir -p "$H/.cache/keep"; STUB_BREW="$H/.cache"; run --apply
check "cache root itself refused" 'has "SKIP homebrew:" && [ -d "$H/.cache/keep" ]'

# 10. ~/.npm is not an allowlisted root: only ~/.npm/_cacache via npm (r4 C1)
new_case; mkdir -p "$H/.npm/global/lib"; echo k > "$H/.npm/global/lib/f"; STUB_BREW="$H/.npm/global"; run --apply
check "~/.npm/global refused" 'has "SKIP homebrew:" && [ -f "$H/.npm/global/lib/f" ]'

new_case; mkdir -p "$H/.npm/global/_cacache"; echo k > "$H/.npm/global/_cacache/f"; STUB_NPM="$H/.npm/global"; run --apply
check "npm resolver pointed at ~/.npm/global refused" 'has "SKIP npm:" && ! logs "npm cache clean" && [ -f "$H/.npm/global/_cacache/f" ]'

# 11. pnpm global installs are refused; only the store is allowed (r4 H3)
new_case; mkdir -p "$H/.local/share/pnpm/global/5"; echo k > "$H/.local/share/pnpm/global/5/f"; STUB_BREW="$H/.local/share/pnpm/global"; STUB_PNPM="$H/.local/share/pnpm/global"; run --apply
check "pnpm global installs refused" 'has "SKIP homebrew:" && has "SKIP pnpm:" && [ -f "$H/.local/share/pnpm/global/5/f" ]'

# 12. Other apps' data under ~/.cache (poetry virtualenvs) is refused (r4 H3)
new_case; mkdir -p "$H/.cache/pypoetry/virtualenvs/x"; echo k > "$H/.cache/pypoetry/virtualenvs/x/f"; STUB_UV="$H/.cache/pypoetry/virtualenvs"; run --apply --uv
check "poetry virtualenvs refused" 'has "SKIP uv:" && ! logs "uv cache clean" && [ -f "$H/.cache/pypoetry/virtualenvs/x/f" ]'

# 13. A deeply nested repo (depth > 4) is refused (r4 C2)
new_case; mkdir -p "$H/.cache/Homebrew/a/b/c/d/e/.git"; STUB_BREW="$H/.cache/Homebrew"; run --apply
check "deep nested repo refused" 'has "git repo" && [ -d "$H/.cache/Homebrew/a/b/c/d/e/.git" ]'

# 14. A bare repo inside is refused (r4 C2)
new_case; mkdir -p "$H/.cache/Homebrew/x.git/objects" "$H/.cache/Homebrew/x.git/refs"; echo ref > "$H/.cache/Homebrew/x.git/HEAD"; STUB_BREW="$H/.cache/Homebrew"; run --apply
check "bare repo refused" 'has "git repo" && [ -f "$H/.cache/Homebrew/x.git/HEAD" ]'

# 15. An unreadable subdirectory makes the scan incomplete, so the target is refused (r4 C2)
new_case; mkdir -p "$H/.cache/Homebrew/locked/inner"; chmod 000 "$H/.cache/Homebrew/locked"; STUB_BREW="$H/.cache/Homebrew"; run --apply; chmod 700 "$H/.cache/Homebrew/locked"
if [ "$(id -u)" -eq 0 ]; then echo "skip unreadable-scan case (running as root)"; else
check "unreadable scan refused" 'has "could not be fully scanned" && [ -d "$H/.cache/Homebrew/locked/inner" ]'; fi

# 16. Inside a repo is refused even with GIT_DIR set to something bogus
new_case; mkdir -p "$H/.cache/.git" "$H/.cache/pip"; STUB_PIP="$H/.cache/pip"; XENV="GIT_DIR=/nonexistent"; run --apply
check "inside repo refused despite GIT_DIR" 'has "SKIP pip:" && has "git repo" && ! logs "cache purge"'

# 17. uv is opt-in: skipped without --uv, and skipped with UV_LINK_MODE=symlink even with --uv (r4 M5)
new_case; mkdir -p "$H/.cache/uv"; STUB_UV="$H/.cache/uv"; run --apply
check "uv needs --uv" 'has "SKIP uv: needs --uv" && ! logs "uv cache clean"'
XENV="UV_LINK_MODE=symlink"; run --apply --uv
check "uv symlink link-mode skipped" 'has "SKIP uv: UV_LINK_MODE=symlink" && ! logs "uv cache clean"'

# 18. Homebrew's cache is removed by rm of the guarded dir; brew cleanup is never called
new_case; mkdir -p "$H/.cache/Homebrew/dl"; STUB_BREW="$H/.cache/Homebrew"; run --apply
check "brew: guarded rm, never cleanup" 'has "DONE homebrew" && [ ! -e "$H/.cache/Homebrew" ] && ! logs "brew cleanup"'

# 19. yarn Berry is not automated
new_case; mkdir -p "$H/.yarn/berry/cache"; STUB_YARN_VER=4.1.0; STUB_YARN="$H/.yarn/berry/cache"; run --apply
check "yarn berry not automated" 'has "SKIP yarn: Berry" && ! logs "yarn cache clean"'

# 20. A running browser is skipped, including a 15-char comm name, and macOS app bundles (r4 H4)
new_case; mkdir -p "$H/.cache/chromium/x"; STUB_RUNNING=chromium-browse; run --apply
check "linux running chromium-browse skipped" 'has "SKIP chromium: browser is running" && [ -d "$H/.cache/chromium/x" ]'
new_case; mkdir -p "$H/Library/Caches/Google/Chrome/x"; STUB_RUNNING="Google Chrome.app"; XENV="CLEANUP_OS_OVERRIDE=Darwin"; run --apply
check "darwin running Google Chrome skipped" 'has "SKIP chrome: browser is running" && [ -d "$H/Library/Caches/Google/Chrome/x" ]'

# 21. A home path containing spaces still cleans its fixed targets (r4 M6)
new_case "home with space"; mkdir -p "$H/.cache/node-gyp/x"; run --apply
check "home with spaces cleans fixed targets" 'has "DONE node-gyp" && [ ! -e "$H/.cache/node-gyp" ]'

# 22. A failing step exits non-zero (r4 M7)
new_case; mkdir -p "$H/.cache/pip"; STUB_PIP="$H/.cache/pip"; STUB_FAIL=pip; run --apply
check "failure exits 1" '[ $RC -eq 1 ] && has "FAIL pip" && has "failures=1"'

# 23. Trash is kept by default, and emptied (files/info only) with --apply --trash
new_case; mkdir -p "$H/.local/share/Trash/files" "$H/.local/share/Trash/info"; echo x > "$H/.local/share/Trash/files/a"; run --apply
check "trash kept by default" '[ -f "$H/.local/share/Trash/files/a" ] && has "kept"'
run --apply --trash
check "trash emptied only with --trash" '[ ! -e "$H/.local/share/Trash/files" ] && [ -d "$H/.local/share/Trash" ] && has "emptying"'

# 24. Darwin: the case-insensitive per-tool allowlist cleans, and logs are report-only
new_case; mkdir -p "$H/Library/Caches/Homebrew/dl" "$H/Library/Logs"; echo x > "$H/Library/Logs/crash"; STUB_BREW="$H/Library/caches/homebrew"
mkdir -p "$H/Library/caches/homebrew/dl"; XENV="CLEANUP_OS_OVERRIDE=Darwin"; run --apply
check "darwin case-insensitive allowlist + logs report-only" 'has "DONE homebrew" && [ -f "$H/Library/Logs/crash" ] && has "LOGS "'

echo "--- $pass passed, $fail failed"
[ "$fail" -eq 0 ]
