#!/usr/bin/env bash
# cleanup.sh: clear the CURRENT user's regenerable tool caches, macOS or Linux.
#
#   cleanup.sh                  dry run (the default): resolve, guard, size, and print the plan
#   cleanup.sh --apply          clean every target that passes every guard
#   cleanup.sh --apply --uv     also clean uv's cache (opt-in: environments may symlink into it)
#   cleanup.sh --apply --trash  also empty the user's Trash (opt-in; permanent)
#
# Every safety rule lives here, in code, and each is pinned by
# scripts/tests/test-chitty-cleanup.sh. Prose-only versions failed open (chittymarket#254).
#
#   - Canonical home is computed here, never inherited. Empty or "/" refuses everything.
#   - Each target must resolve to that tool's OWN expected cache directory (per-tool exact
#     path, or strictly below a tool-specific store root). Broad roots such as ~/.cache or
#     ~/.npm are never allowlisted, because they also hold data that isn't regenerable.
#   - A symlinked target is refused, and parent symlinks are resolved first. The symlink
#     check is repeated immediately before every rm.
#   - Anything inside, or containing, a git repo (worktree or bare, at any depth) is
#     refused. An unreadable scan also refuses.
#   - Tool clean commands get the guarded directory passed explicitly.
#   - Never `brew cleanup`. Never yarn Berry. uv only with --uv. Running browsers skipped.
#   - Exits 1 if any step failed, 3 on refusal, 2 on usage error, 0 otherwise.
# Bash 3.2-compatible (macOS): no mapfile, no ${x,,}, no realpath, no associative arrays.
set -u
umask 077

APPLY=0; TRASH=0; UVOK=0
for a in "$@"; do
  case "$a" in
    --apply) APPLY=1 ;;
    --trash) TRASH=1 ;;
    --uv)    UVOK=1 ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    *) echo "unknown argument: $a" >&2; exit 2 ;;
  esac
done

OS=${CLEANUP_OS_OVERRIDE:-$(uname -s)}   # override for tests only
unset GIT_DIR GIT_WORK_TREE GIT_CEILING_DIRECTORIES GIT_DISCOVERY_ACROSS_FILESYSTEM

H=$(cd "${HOME:-/nonexistent}" 2>/dev/null && pwd -P) || H=""
if [ -z "$H" ] || [ "$H" = "/" ]; then echo "REFUSE: home resolves to '${H}'"; exit 3; fi
cd "$H" || exit 3

FAILS=0
lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }
say() { printf '%s\n' "$*"; }
fold() { if [ "$OS" = Darwin ]; then lower "$1"; else printf '%s' "$1"; fi; }

# Resolve to a physical path with parent symlinks resolved. A symlinked final component
# is refused. Prints the resolved path, or nothing on refusal.
resolve() {
  local p=${1%/} parent base
  [ -n "$p" ] || return 1
  case "$p" in */.|*/..|.|..) return 1 ;; esac
  [ -L "$p" ] && return 1
  [ -e "$p" ] || return 1
  parent=${p%/*}; base=${p##*/}
  [ -n "$parent" ] || parent=/
  parent=$(cd "$parent" 2>/dev/null && pwd -P) || return 1
  printf '%s/%s' "${parent%/}" "$base"
}

# Per-tool allowlist. "=path" is an exact match; "<path" means strictly below path.
expected() {
  case "$1" in
    npm)        echo "=$H/.npm/_cacache" ;;
    pnpm)       echo "<$H/.local/share/pnpm/store"; echo "<$H/Library/pnpm/store"; echo "=$H/.local/share/pnpm/store"; echo "=$H/Library/pnpm/store" ;;
    yarn)       echo "=$H/.cache/yarn"; echo "<$H/.cache/yarn"; echo "=$H/Library/Caches/Yarn"; echo "<$H/Library/Caches/Yarn" ;;
    pip)        echo "=$H/.cache/pip"; echo "=$H/Library/Caches/pip" ;;
    uv)         echo "=$H/.cache/uv"; echo "=$H/Library/Caches/uv" ;;
    homebrew)   echo "=$H/.cache/Homebrew"; echo "=$H/Library/Caches/Homebrew" ;;
    node-gyp)   echo "=$H/.cache/node-gyp"; echo "=$H/Library/Caches/node-gyp" ;;
    typescript) echo "=$H/.cache/typescript"; echo "=$H/Library/Caches/typescript" ;;
    chrome)     echo "=$H/.cache/google-chrome"; echo "=$H/Library/Caches/Google/Chrome" ;;
    chromium)   echo "=$H/.cache/chromium" ;;
    brave)      echo "=$H/.cache/BraveSoftware"; echo "=$H/Library/Caches/BraveSoftware" ;;
    firefox)    echo "=$H/.cache/mozilla"; echo "=$H/Library/Caches/Firefox" ;;
  esac
}
allowlisted() {  # <label> <resolved path>
  local label=$1 d; d=$(fold "$2")
  local line kind path
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    kind=${line%"${line#?}"}; path=$(fold "${line#?}")
    case "$kind" in
      =) [ "$d" = "$path" ] && return 0 ;;
      "<") case "$d" in "$path"/?*) return 0 ;; esac ;;
    esac
  done <<EOF
$(expected "$label")
EOF
  return 1
}

# 0 = repo found (refuse); 1 = clean; 2 = scan incomplete (refuse)
repo_status() {
  local d=$1 up=$1 hit rc
  while [ -n "$up" ] && [ "$up" != "/" ]; do
    [ -e "$up/.git" ] && return 0
    [ "$up" = "$H" ] && break
    up=${up%/*}
  done
  hit=$(find "$d" \( -name .git -o \( -name HEAD -type f \) \) -print 2>/dev/null; echo "rc=$?")
  rc=${hit##*rc=}; hit=${hit%rc=*}
  [ "$rc" = 0 ] || return 2
  local f
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    case "$f" in */.git) return 0 ;; esac
    [ -d "${f%/HEAD}/objects" ] && [ -d "${f%/HEAD}/refs" ] && return 0   # bare repo
  done <<EOF
$hit
EOF
  return 1
}

# guard <label> <raw path>: sets GUARDED on success, otherwise prints SKIP and returns 1.
guard() {
  local label=$1 raw=${2:-} d rs
  GUARDED=""
  [ -n "$raw" ] || { say "SKIP $label: no path resolved"; return 1; }
  if [ -L "${raw%/}" ]; then say "SKIP $label: $raw is a symlink"; return 1; fi
  [ -e "$raw" ] || { say "SKIP $label: $raw absent"; return 1; }
  d=$(resolve "$raw") || { say "SKIP $label: $raw unresolvable"; return 1; }
  allowlisted "$label" "$d" || { say "SKIP $label: $d is not $label's expected cache directory"; return 1; }
  repo_status "$d"; rs=$?
  [ "$rs" -eq 0 ] && { say "SKIP $label: $d is in or contains a git repo"; return 1; }
  [ "$rs" -eq 2 ] && { say "SKIP $label: $d could not be fully scanned"; return 1; }
  GUARDED=$d
}

# rm with the symlink and resolution re-checked immediately before deletion (TOCTOU)
safe_rm() {
  local d=$1
  [ -L "$d" ] && { say "FAIL safe_rm: $d became a symlink"; return 1; }
  [ "$(resolve "$d")" = "$d" ] || { say "FAIL safe_rm: $d no longer resolves to itself"; return 1; }
  rm -rf -- "$d"
}

size_of() { du -sk -- "$1" 2>/dev/null | awk '{print $1}'; }
FREED_KB=0
run_clean() {  # <label> <dir> <command...>
  local label=$1 d=$2; shift 2
  local before after; before=$(size_of "$d"); before=${before:-0}
  if [ "$APPLY" -ne 1 ]; then say "PLAN $label: $d (${before} KB): $*"; return 0; fi
  if (cd "$H" && "$@") >/dev/null 2>&1; then
    after=$(size_of "$d"); after=${after:-0}
    FREED_KB=$((FREED_KB + before - after))
    say "DONE $label: $d freed $((before - after)) KB"
  else
    say "FAIL $label: $* exited non-zero"; FAILS=$((FAILS + 1))
  fi
}
have() { command -v "$1" >/dev/null 2>&1; }

say "OS=$OS HOME=$H mode=$([ "$APPLY" -eq 1 ] && echo apply || echo dry-run)"
df -h / "$H" 2>/dev/null | awk 'NR==1 || !seen[$0]++'

# --- tools: resolve through the tool, guard, then clean with the guarded dir explicit ---
if have npm; then
  c=$(cd "$H" && npm config get cache 2>/dev/null)
  if [ -n "$c" ] && guard npm "${c%/}/_cacache"; then run_clean npm "$GUARDED" npm cache clean --force --cache "${GUARDED%/_cacache}"; fi
fi
if have pnpm; then
  c=$(cd "$H" && pnpm store path 2>/dev/null)
  if guard pnpm "$c"; then run_clean pnpm "$GUARDED" pnpm store prune --store-dir "$GUARDED"; fi
fi
if have yarn; then
  v=$(cd "$H" && yarn --version 2>/dev/null)
  case "$v" in
    1.*) c=$(cd "$H" && yarn cache dir 2>/dev/null)
         if guard yarn "$c"; then run_clean yarn "$GUARDED" yarn cache clean --cache-folder "$GUARDED"; fi ;;
    "") ;;
    *) say "SKIP yarn: Berry ($v) is not automated" ;;
  esac
fi
if have pip; then
  c=$(cd "$H" && pip cache dir 2>/dev/null)
  if guard pip "$c"; then run_clean pip "$GUARDED" pip --cache-dir "$GUARDED" cache purge; fi
fi
if have uv; then
  if [ "$UVOK" -ne 1 ]; then
    say "SKIP uv: needs --uv (environments installed with link-mode=symlink break if the cache is cleaned)"
  elif [ "$(lower "${UV_LINK_MODE:-}")" = symlink ]; then
    say "SKIP uv: UV_LINK_MODE=symlink"
  else
    c=$(cd "$H" && uv cache dir 2>/dev/null)
    if guard uv "$c"; then run_clean uv "$GUARDED" uv cache clean --cache-dir "$GUARDED"; fi
  fi
fi
if have brew; then   # download cache only; never `brew cleanup`
  c=$(cd "$H" && brew --cache 2>/dev/null)
  if guard homebrew "$c"; then run_clean homebrew "$GUARDED" safe_rm "$GUARDED"; fi
fi

# --- fixed-path caches: newline/tab-delimited (safe for spaces in $H) ---
if [ "$OS" = Darwin ]; then
  FIXED=$(printf '%s\t%s\n' node-gyp "$H/Library/Caches/node-gyp" typescript "$H/Library/Caches/typescript" \
    chrome "$H/Library/Caches/Google/Chrome" brave "$H/Library/Caches/BraveSoftware" firefox "$H/Library/Caches/Firefox")
else
  FIXED=$(printf '%s\t%s\n' node-gyp "$H/.cache/node-gyp" typescript "$H/.cache/typescript" \
    chrome "$H/.cache/google-chrome" chromium "$H/.cache/chromium" brave "$H/.cache/BraveSoftware" firefox "$H/.cache/mozilla")
fi
me=$(id -un)
browser_running() {  # Linux: kernel comm names (<=15 chars, exact). Darwin: app bundle path.
  local names n
  if [ "$OS" = Darwin ]; then
    case "$1" in
      chrome)  names="Google Chrome.app" ;;
      brave)   names="Brave Browser.app" ;;
      firefox) names="Firefox.app" ;;
      *) return 1 ;;
    esac
    pgrep -u "$me" -f "$names" >/dev/null 2>&1 && return 0
    return 1
  fi
  case "$1" in
    chrome)   names=$(printf '%s\n' chrome google-chrome) ;;
    chromium) names=$(printf '%s\n' chromium chromium-browse) ;;
    brave)    names=$(printf '%s\n' brave brave-browser) ;;
    firefox)  names=$(printf '%s\n' firefox firefox-bin) ;;
    *) return 1 ;;
  esac
  while IFS= read -r n; do
    [ -n "$n" ] && pgrep -u "$me" -x "$n" >/dev/null 2>&1 && return 0
  done <<EOF
$names
EOF
  return 1
}
while IFS="$(printf '\t')" read -r label p; do
  [ -n "$label" ] || continue
  [ -e "$p" ] || [ -L "$p" ] || continue
  if browser_running "$label"; then say "SKIP $label: browser is running"; continue; fi
  if guard "$label" "$p"; then run_clean "$label" "$GUARDED" safe_rm "$GUARDED"; fi
done <<EOF
$FIXED
EOF

# --- Trash: reported always, emptied only with --apply --trash ---
if [ "$OS" = Darwin ]; then t="$H/.Trash"; else t="$H/.local/share/Trash"; fi
if [ -d "$t" ] && [ ! -L "$t" ]; then
  tk=$(size_of "$t"); tk=${tk:-0}
  if [ "$TRASH" -eq 1 ] && [ "$APPLY" -eq 1 ]; then
    say "TRASH $t: ${tk} KB, emptying (permanent)"
    if [ "$OS" = Darwin ]; then
      find "$t" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} + 2>/dev/null || { say "FAIL trash: needs Full Disk Access; not retrying"; FAILS=$((FAILS + 1)); }
    else
      rm -rf -- "$t/files" "$t/info" "$t/expunged" || { say "FAIL trash: rm failed"; FAILS=$((FAILS + 1)); }
    fi
    ta=$(size_of "$t"); FREED_KB=$((FREED_KB + tk - ${ta:-0}))
  else
    say "TRASH $t: ${tk} KB kept (pass --apply --trash to empty; permanent)"
  fi
fi
if [ "$OS" = Darwin ] && [ -d "$H/Library/Logs" ]; then
  say "LOGS $H/Library/Logs: $(size_of "$H/Library/Logs") KB (report only; crash reports aren't regenerable)"
fi

say "SUMMARY freed=${FREED_KB} KB failures=${FAILS} mode=$([ "$APPLY" -eq 1 ] && echo apply || echo dry-run)"
df -h / "$H" 2>/dev/null | awk 'NR==1 || !seen[$0]++'
[ "$FAILS" -eq 0 ] || exit 1
exit 0
