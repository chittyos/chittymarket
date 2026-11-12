#!/usr/bin/env bash
# cleanup.sh: clear the CURRENT user's regenerable tool caches, macOS or Linux.
#
#   cleanup.sh            dry run (the default): resolve, guard, size, and print the plan
#   cleanup.sh --apply    actually clean the targets that pass every guard
#   cleanup.sh --apply --trash   also empty the user's Trash (explicit opt-in)
#
# The safety rules live here, in code, because three separated reviews of a prose-only
# version (chittymarket#254) each found new fail-open holes. Each rule is pinned by
# scripts/tests/test-chitty-cleanup.sh.
#
#   - Canonical home is computed here, never inherited. Empty or "/" refuses everything.
#   - A target must be ALLOWLISTED by its resolved path: strictly below a known cache root.
#     "Inside $HOME" is not enough (HOMEBREW_CACHE=~/Downloads must not be deleted).
#   - Symlinked targets are refused. Parent symlinks are resolved before the allowlist check.
#   - Anything inside, or containing, a git repo is refused. This is found by walking for
#     .git, not by trusting `git`.
#   - Tool clean commands get the guarded directory passed explicitly, so a project config
#     or env var can't redirect them.
#   - `brew cleanup` is never run. Yarn Berry, Trash and logs are never automatic.
# Bash 3.2-compatible (macOS): no mapfile, no ${x,,}, no realpath.
set -u
umask 077

APPLY=0; TRASH=0
for a in "$@"; do
  case "$a" in
    --apply) APPLY=1 ;;
    --trash) TRASH=1 ;;
    -h|--help) sed -n '2,7p' "$0"; exit 0 ;;
    *) echo "unknown argument: $a" >&2; exit 2 ;;
  esac
done

OS=${CLEANUP_OS_OVERRIDE:-$(uname -s)}   # override for tests only
unset GIT_DIR GIT_WORK_TREE GIT_CEILING_DIRECTORIES GIT_DISCOVERY_ACROSS_FILESYSTEM

H=$(cd "${HOME:-/nonexistent}" 2>/dev/null && pwd -P) || H=""
if [ -z "$H" ] || [ "$H" = "/" ]; then echo "REFUSE: home resolves to '${H}'"; exit 3; fi
cd "$H" || exit 3

lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }
say() { printf '%s\n' "$*"; }

# Resolve $1 to a physical path with parent symlinks resolved. A symlinked final
# component is refused. Prints the resolved path, or nothing on refusal.
resolve() {
  local p=${1%/} parent base
  [ -n "$p" ] || return 1
  case "$p" in */.|*/..|.|..) return 1 ;; esac
  [ -e "$p" ] || [ -L "$p" ] || return 1
  [ -L "$p" ] && return 1
  parent=${p%/*}; base=${p##*/}
  [ -n "$parent" ] || parent=/
  parent=$(cd "$parent" 2>/dev/null && pwd -P) || return 1
  printf '%s/%s' "${parent%/}" "$base"
}

# Allowlist: the resolved path must be STRICTLY below one of these roots.
# Comparison is case-insensitive on Darwin, whose default filesystem is.
allowlisted() {
  local d=$1 r cmp root
  for r in "$H/.cache" "$H/Library/Caches" "$H/.npm" "$H/.local/share/pnpm" "$H/Library/pnpm"; do
    cmp=$d; root=$r
    if [ "$OS" = Darwin ]; then cmp=$(lower "$d"); root=$(lower "$r"); fi
    case "$cmp" in "$root"/?*) return 0 ;; esac
  done
  # npm's cache dir is the root itself (~/.npm); only its _cacache is allowed.
  cmp=$d; root="$H/.npm/_cacache"
  [ "$OS" = Darwin ] && { cmp=$(lower "$d"); root=$(lower "$root"); }
  [ "$cmp" = "$root" ] && return 0
  return 1
}

in_or_contains_repo() {
  local d=$1 up=$1
  while [ -n "$up" ] && [ "$up" != "/" ]; do
    [ -e "$up/.git" ] && return 0
    [ "$up" = "$H" ] && break
    up=${up%/*}
  done
  [ -n "$(find "$d" -maxdepth 4 -name .git -print 2>/dev/null | head -n 1)" ] && return 0
  return 1
}

# guard <label> <path>: sets GUARDED to the safe path, or prints SKIP and returns 1.
guard() {
  local label=$1 raw=${2:-} d
  GUARDED=""
  [ -n "$raw" ] || { say "SKIP $label: no path resolved"; return 1; }
  if [ -L "${raw%/}" ]; then say "SKIP $label: $raw is a symlink"; return 1; fi
  [ -e "$raw" ] || { say "SKIP $label: $raw absent"; return 1; }
  d=$(resolve "$raw") || { say "SKIP $label: $raw unresolvable"; return 1; }
  allowlisted "$d" || { say "SKIP $label: $d is not under an allowlisted cache root"; return 1; }
  in_or_contains_repo "$d" && { say "SKIP $label: $d is in or contains a git repo"; return 1; }
  GUARDED=$d
  return 0
}

size_of() { du -sk -- "$1" 2>/dev/null | awk '{print $1}'; }
FREED_KB=0

# run_clean <label> <dir> <command...>: dry-run prints the plan; --apply runs it.
run_clean() {
  local label=$1 d=$2; shift 2
  local before; before=$(size_of "$d"); before=${before:-0}
  if [ "$APPLY" -ne 1 ]; then say "PLAN $label: $d (${before} KB): $*"; return 0; fi
  if (cd "$H" && "$@") >/dev/null 2>&1; then
    local after; after=$(size_of "$d"); after=${after:-0}
    FREED_KB=$((FREED_KB + before - after))
    say "DONE $label: $d freed $((before - after)) KB"
  else
    say "FAIL $label: $* exited non-zero"
  fi
}

have() { command -v "$1" >/dev/null 2>&1; }

say "OS=$OS HOME=$H mode=$([ "$APPLY" -eq 1 ] && echo apply || echo dry-run)"
df -h / "$H" 2>/dev/null | awk 'NR==1 || !seen[$0]++'

# --- tools: resolve through the tool, guard, then clean with the guarded dir explicit ---
if have npm; then
  c=$(cd "$H" && npm config get cache 2>/dev/null)
  if guard npm "${c%/}/_cacache"; then run_clean npm "$GUARDED" npm cache clean --force --cache "${GUARDED%/_cacache}"; fi
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
    *) say "SKIP yarn: Berry ($v) is not automated (see task 9da85cc4)" ;;
  esac
fi
if have pip; then
  c=$(cd "$H" && pip cache dir 2>/dev/null)
  if guard pip "$c"; then run_clean pip "$GUARDED" pip --cache-dir "$GUARDED" cache purge; fi
fi
if have uv; then
  if [ "$(lower "${UV_LINK_MODE:-}")" = symlink ] || grep -qs 'link-mode' "$H/.config/uv/uv.toml"; then
    say "SKIP uv: link-mode may be symlink (environments link into the cache); needs explicit approval"
  else
    c=$(cd "$H" && uv cache dir 2>/dev/null)
    if guard uv "$c"; then run_clean uv "$GUARDED" uv cache clean --cache-dir "$GUARDED"; fi
  fi
fi
if have brew; then   # download cache only; never `brew cleanup`
  c=$(cd "$H" && brew --cache 2>/dev/null)
  if guard homebrew "$c"; then run_clean homebrew "$GUARDED" rm -rf -- "$GUARDED"; fi
fi

# --- fixed-path caches (no resolver); same guard ---
if [ "$OS" = Darwin ]; then
  FIXED="node-gyp:$H/Library/Caches/node-gyp typescript:$H/Library/Caches/typescript chrome:$H/Library/Caches/Google/Chrome brave:$H/Library/Caches/BraveSoftware firefox:$H/Library/Caches/Firefox"
else
  FIXED="node-gyp:$H/.cache/node-gyp typescript:$H/.cache/typescript chrome:$H/.cache/google-chrome chromium:$H/.cache/chromium brave:$H/.cache/BraveSoftware firefox:$H/.cache/mozilla"
fi
me=$(id -un)
for entry in $FIXED; do
  label=${entry%%:*}; p=${entry#*:}
  [ -e "$p" ] || [ -L "$p" ] || continue
  case "$label" in
    chrome)   procs="chrome Google Chrome" ;;
    chromium) procs="chromium chromium-browser" ;;
    brave)    procs="brave Brave Browser" ;;
    firefox)  procs="firefox firefox-bin" ;;
    *)        procs="" ;;
  esac
  running=0
  for pr in $procs; do pgrep -u "$me" -x "$pr" >/dev/null 2>&1 && running=1; done
  [ "$running" -eq 1 ] && { say "SKIP $label: browser is running"; continue; }
  if guard "$label" "$p"; then run_clean "$label" "$GUARDED" rm -rf -- "$GUARDED"; fi
done

# --- Trash: reported always, emptied only with --apply --trash ---
if [ "$OS" = Darwin ]; then t="$H/.Trash"; else t="$H/.local/share/Trash"; fi
if [ -d "$t" ] && [ ! -L "$t" ]; then
  tk=$(size_of "$t"); say "TRASH $t: ${tk:-0} KB ($([ "$TRASH" -eq 1 ] && [ "$APPLY" -eq 1 ] && echo emptying || echo 'kept; pass --apply --trash to empty, this is permanent'))"
  if [ "$TRASH" -eq 1 ] && [ "$APPLY" -eq 1 ]; then
    if [ "$OS" = Darwin ]; then
      find "$t" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} + 2>/dev/null || say "FAIL trash: needs Full Disk Access; not retrying"
    else
      rm -rf -- "$t/files" "$t/info" "$t/expunged"
    fi
  fi
fi
[ "$OS" = Darwin ] && [ -d "$H/Library/Logs" ] && say "LOGS $H/Library/Logs: $(size_of "$H/Library/Logs") KB (report only; crash reports aren't regenerable)"

say "SUMMARY freed=${FREED_KB} KB mode=$([ "$APPLY" -eq 1 ] && echo apply || echo dry-run)"
df -h / "$H" 2>/dev/null | awk 'NR==1 || !seen[$0]++'
