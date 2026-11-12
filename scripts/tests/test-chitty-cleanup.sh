#!/usr/bin/env bash
# test-chitty-cleanup.sh: pins every safety rule in chitty-cleanup/scripts/cleanup.sh
# (npm/pip/uv only). Each refusal asserts the SKIP reason AND that the data survives.
# Tools are stubbed on PATH. Every case uses a fresh sandbox $HOME.
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd -P)
SCRIPT=${CLEANUP_SCRIPT:-$ROOT/plugins/chittyos-core/skills/chitty-cleanup/scripts/cleanup.sh}
TMP=$(mktemp -d "${TMPDIR:-/tmp}/chitty-cleanup-test.XXXXXX")
trap 'chmod -R u+rwx "$TMP" 2>/dev/null; rm -rf -- "$TMP"' EXIT
pass=0; fail=0; n=0

mkstubs() {
  local s=$1; mkdir -p "$s"
  for t in npm pip uv brew pnpm yarn; do
    cat > "$s/$t" <<EOF
#!/usr/bin/env bash
echo "$t \$*" >> "\$STUB_LOG"
case "$t \$*" in
  "npm config get cache") printf '%s\n' "\${STUB_NPM:-}" ;;
  "pip cache dir") printf '%s\n' "\${STUB_PIP:-}" ;;
  "uv cache dir") printf '%s\n' "\${STUB_UV:-}" ;;
  *clean*|*purge*|*prune*) [ "\${STUB_FAIL:-}" = "$t" ] && exit 1 ;;
esac
exit 0
EOF
    chmod +x "$s/$t"
  done
}
new_case() {
  n=$((n+1)); C="$TMP/case$n"; mkdir -p "$C/${1:-home}" "$C/outside" "$C/stubs"
  H=$(cd "$C/${1:-home}" && pwd -P); LOG="$C/stub.log"; : > "$LOG"; mkstubs "$C/stubs"
  STUB_NPM=; STUB_PIP=; STUB_UV=; STUB_FAIL=; XENV=
}
run() {
  OUT=$(env -i HOME="$H" PATH="$C/stubs:/usr/bin:/bin" STUB_LOG="$LOG" TMPDIR="$TMP" \
    STUB_NPM="$STUB_NPM" STUB_PIP="$STUB_PIP" STUB_UV="$STUB_UV" STUB_FAIL="$STUB_FAIL" \
    $XENV bash "$SCRIPT" "$@" 2>&1); RC=$?
}
check() { if eval "$2"; then pass=$((pass+1)); echo "ok   $1"; else fail=$((fail+1)); echo "FAIL $1"; printf '%s\n' "$OUT" | sed 's/^/     | /' | head -12; fi; }
has()  { grep -qF -- "$1" <<<"$OUT"; }
logs() { grep -qF -- "$1" "$LOG"; }

# Structural: the script deletes nothing itself and uses no here-docs (fail-open on ENOSPC)
OUT=""; check "script contains no rm/rmdir/unlink/shred/-delete" '! grep -vE "^[[:space:]]*#" "$SCRIPT" | grep -nE "(^|[^[:alnum:]_])(rm|rmdir|unlink|shred)([^[:alnum:]_]|$)|-delete"'
check "script contains no here-docs" "! grep -nE '<<-?[[:space:]]*[\\\"'\''A-Za-z_]' \"\$SCRIPT\""

# HOME "/" or unset refuses (exit 3)
new_case; OUT=$(env -i PATH="$C/stubs:/usr/bin:/bin" STUB_LOG="$LOG" HOME=/ bash "$SCRIPT" --apply 2>&1); RC=$?
check "HOME=/ refuses" '[ $RC -eq 3 ] && has REFUSE && ! logs "cache clean"'
new_case; OUT=$(env -i PATH="$C/stubs:/usr/bin:/bin" STUB_LOG="$LOG" bash "$SCRIPT" --apply 2>&1); RC=$?
check "HOME unset refuses" '[ $RC -eq 3 ] && ! logs "cache"'

# Dry run is the default
new_case; mkdir -p "$H/.cache/pip/x"; STUB_PIP="$H/.cache/pip"; run
check "dry-run plans, runs no clean" 'has "PLAN pip" && ! logs "cache purge" && [ -d "$H/.cache/pip/x" ]'

# Tools get the guarded dir explicitly
new_case; mkdir -p "$H/.npm/_cacache" "$H/.cache/pip" "$H/.cache/uv"; STUB_NPM="$H/.npm"; STUB_PIP="$H/.cache/pip"; STUB_UV="$H/.cache/uv"; run --apply --uv
check "explicit cache dirs" 'logs "npm cache clean --force --cache $H/.npm" && logs "pip --cache-dir $H/.cache/pip cache purge" && logs "uv cache clean --cache-dir $H/.cache/uv" && [ $RC -eq 0 ]'

# Only each tool's exact default dir is allowed
new_case; mkdir -p "$H/.npm/global/_cacache"; echo k > "$H/.npm/global/_cacache/f"; STUB_NPM="$H/.npm/global"; run --apply
check "npm pointed at ~/.npm/global refused" 'has "SKIP npm:" && has "default cache directory" && ! logs "npm cache clean"'
new_case; mkdir -p "$H/Downloads"; echo k > "$H/Downloads/f"; STUB_PIP="$H/Downloads"; run --apply
check "pip pointed at ~/Downloads refused" 'has "SKIP pip:" && has "default cache directory" && [ -f "$H/Downloads/f" ] && ! logs "cache purge"'
new_case; mkdir -p "$H/.cache/pypoetry/virtualenvs"; STUB_UV="$H/.cache/pypoetry/virtualenvs"; run --apply --uv
check "uv pointed at poetry venvs refused" 'has "SKIP uv:" && has "default cache directory" && ! logs "uv cache clean"'
new_case; mkdir -p "$H/.cache/keep"; STUB_PIP="$H/.cache"; run --apply
check "~/.cache root refused" 'has "SKIP pip:" && has "default cache directory" && ! logs "cache purge"'
new_case; mkdir -p "$C/outside/uv"; STUB_UV="$C/outside/uv"; run --apply --uv
check "outside home refused" 'has "SKIP uv:" && has "default cache directory" && ! logs "uv cache clean"'
new_case; mkdir -p "$C/outside/pip" "$H/.cache"; STUB_PIP="$H/.cache/../../outside/pip"; run --apply
check ".. escape refused" 'has "SKIP pip:" && has "default cache directory" && ! logs "cache purge"'

# Symlinks
new_case; mkdir -p "$H/Documents/p" "$H/.cache"; ln -s "$H/Documents/p" "$H/.cache/pip"; STUB_PIP="$H/.cache/pip"; run --apply
check "symlinked cache refused" 'has "SKIP pip:" && has "is a symlink" && ! logs "cache purge"'
new_case; mkdir -p "$C/outside/real/uv"; ln -s "$C/outside/real" "$H/.cache"; STUB_UV="$H/.cache/uv"; run --apply --uv
check "parent-symlink escape refused" 'has "SKIP uv:" && has "default cache directory" && ! logs "uv cache clean"'

# Repos at any depth, bare (including a symlinked HEAD), odd names, inside, and with GIT_DIR set
new_case; mkdir -p "$H/.cache/pip/a/b/c/d/e/.git"; STUB_PIP="$H/.cache/pip"; run --apply
check "deep nested repo refused" 'has "git repo" && ! logs "cache purge"'
new_case; mkdir -p "$H/.cache/pip/x.git/objects" "$H/.cache/pip/x.git/refs/heads"; ln -s refs/heads/main "$H/.cache/pip/x.git/HEAD"; STUB_PIP="$H/.cache/pip"; run --apply
check "bare repo with symlinked HEAD refused" 'has "git repo" && ! logs "cache purge"'
new_case; d="$H/.cache/pip/a"$'\n'"b/x.git"; mkdir -p "$d/objects" "$d/refs"; echo ref > "$d/HEAD"; STUB_PIP="$H/.cache/pip"; run --apply
check "bare repo under newline name refused" 'has "git repo" && ! logs "cache purge"'
new_case; mkdir -p "$H/.cache/.git" "$H/.cache/pip"; STUB_PIP="$H/.cache/pip"; XENV="GIT_DIR=/nonexistent"; run --apply
check "inside repo refused despite GIT_DIR" 'has "SKIP pip:" && has "git repo" && ! logs "cache purge"'
new_case; mkdir -p "$H/.cache/pip/x"; echo h > "$H/.cache/pip/x/HEAD"; STUB_PIP="$H/.cache/pip"; run --apply
check "plain HEAD file (not a repo) allowed" 'has "DONE pip" && logs "cache purge"'
if [ "$(id -u)" -ne 0 ]; then
  new_case; mkdir -p "$H/.cache/pip/locked/in"; chmod 000 "$H/.cache/pip/locked"; STUB_PIP="$H/.cache/pip"; run --apply; chmod 700 "$H/.cache/pip/locked"
  check "unreadable scan refused" 'has "could not be fully scanned" && ! logs "cache purge"'
fi

# Full disk: a write limit must not turn the repo check into "no repo" (r5 critical)
new_case; mkdir -p "$H/.cache/pip/zz/repo/.git"; for i in $(seq 1 300); do mkdir -p "$H/.cache/pip/h$i"; echo r > "$H/.cache/pip/h$i/HEAD"; done
STUB_PIP="$H/.cache/pip"
OUT=$(env -i HOME="$H" PATH="$C/stubs:/usr/bin:/bin" STUB_LOG="$LOG" TMPDIR="$TMP" STUB_PIP="$STUB_PIP" bash -c 'trap "" XFSZ; ulimit -f 1; exec bash "$0" --apply' "$SCRIPT" 2>&1); RC=$?
check "write-limited run still refuses repo (structural no-here-doc test is the real guard)" 'has "git repo" && ! logs "cache purge"'

# pip: a symlinked subdirectory inside the cache is refused, so pip can't follow it out (r6 H1)
new_case; mkdir -p "$H/.cache/pip" "$C/outside/victim"; echo k > "$C/outside/victim/a"; ln -s "$C/outside/victim" "$H/.cache/pip/http"; STUB_PIP="$H/.cache/pip"; run --apply
check "pip cache with symlinked http refused" 'has "SKIP pip:" && has "contains a symlink" && ! logs "cache purge" && [ -f "$C/outside/victim/a" ]'

# Darwin: a .GIT directory (case-insensitive filesystem) counts as a repo (r6 L6)
new_case; mkdir -p "$H/Library/Caches/pip/x/.GIT"; STUB_PIP="$H/Library/Caches/pip"; XENV="CLEANUP_OS_OVERRIDE=Darwin"; run --apply
check "darwin .GIT refused" 'has "git repo" && ! logs "cache purge"'

# uv is opt-in; symlink link-mode from env or config is skipped
new_case; mkdir -p "$H/.cache/uv"; STUB_UV="$H/.cache/uv"; run --apply
check "uv needs --uv" 'has "SKIP uv: needs --uv" && ! logs "uv cache clean"'
XENV="UV_LINK_MODE=symlink"; run --apply --uv
check "uv env symlink skipped" 'has "link-mode=symlink" && ! logs "uv cache clean"'
XENV=; mkdir -p "$H/.config/uv"; printf 'link-mode = "symlink"\n' > "$H/.config/uv/uv.toml"; run --apply --uv
check "uv config symlink skipped" 'has "link-mode=symlink" && ! logs "uv cache clean"'
printf "link-mode = 'symlink'\n" > "$H/.config/uv/uv.toml"; run --apply --uv
check "uv config single-quoted symlink skipped" 'has "link-mode=symlink" && ! logs "uv cache clean"'

# No other tool is ever invoked to clean; everything else is report-only
new_case; mkdir -p "$H/.cache/Homebrew/dl" "$H/.local/share/Trash/files"; echo x > "$H/.local/share/Trash/files/a"; run --apply
check "others report-only" 'has "REPORT $H/.cache/Homebrew" && [ -d "$H/.cache/Homebrew/dl" ] && [ -f "$H/.local/share/Trash/files/a" ] && ! logs "brew " && ! logs "pnpm " && ! logs "yarn "'

# Home with spaces works; failure exits 1; Darwin case-insensitive match
new_case "home with space"; mkdir -p "$H/.cache/pip"; STUB_PIP="$H/.cache/pip"; run --apply
check "home with spaces works" 'has "DONE pip"'
new_case; mkdir -p "$H/.cache/pip"; STUB_PIP="$H/.cache/pip"; STUB_FAIL=pip; run --apply
check "failure exits 1" '[ $RC -eq 1 ] && has "FAIL pip" && has "failures=1"'
new_case; mkdir -p "$H/Library/Caches/pip"; STUB_PIP="$H/Library/caches/PIP"; mkdir -p "$H/Library/caches/PIP"; XENV="CLEANUP_OS_OVERRIDE=Darwin"; run --apply
check "darwin case-insensitive match" 'has "DONE pip"'

echo "--- $pass passed, $fail failed"
[ "$fail" -eq 0 ]
