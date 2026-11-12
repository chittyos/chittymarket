#!/usr/bin/env bash
# cleanup.sh: clear the CURRENT user's npm, pip and (opt-in) uv caches, macOS or Linux.
#
#   cleanup.sh                dry run (the default): resolve, guard, size, print the plan
#   cleanup.sh --apply        clean npm's and pip's caches with their own commands
#   cleanup.sh --apply --uv   also clean uv's cache (opt-in: envs may symlink into it)
#
# Deliberately minimal: after four separated reviews of broader versions (chittymarket#254),
# this script deletes NOTHING itself. There's no rm. Deletion is done only by tools that
# take an explicit cache-dir flag and touch only their own cache internals:
#   npm cache clean --force --cache D   (removes D/_cacache)
#   pip --cache-dir D cache purge        (removes pip's own subdirs of D)
#   uv cache clean --cache-dir D         (removes D)
# Everything else (Homebrew, pnpm, yarn, browsers, Trash, logs) is REPORTED by size, never deleted.
#
# Guards, each pinned by scripts/tests/test-chitty-cleanup.sh:
#   - Home is computed here (pwd -P). Empty or "/" refuses (exit 3).
#   - Each cache must resolve to its tool's exact default dir. Symlinked targets refused;
#     parent symlinks resolved first.
#   - A target in, or containing at any depth, a git worktree or bare repo is refused. The
#     check is a single find whose ANY non-zero status refuses: no here-docs or temp files,
#     so it can't fail open on a full disk.
#   - Exits 1 if any step failed, 3 on refusal, 2 on usage error.
# Bash 3.2-compatible (macOS).
set -u
umask 077

APPLY=0; UVOK=0
for a in "$@"; do
  case "$a" in
    --apply) APPLY=1 ;;
    --uv)    UVOK=1 ;;
    -h|--help) sed -n '2,6p' "$0"; exit 0 ;;
    *) echo "unknown argument: $a" >&2; exit 2 ;;
  esac
done

OS=${CLEANUP_OS_OVERRIDE:-$(uname -s)}   # override for tests only
unset GIT_DIR GIT_WORK_TREE GIT_CEILING_DIRECTORIES GIT_DISCOVERY_ACROSS_FILESYSTEM

H=$(cd "${HOME:-/nonexistent}" 2>/dev/null && pwd -P) || H=""
if [ -z "$H" ] || [ "$H" = "/" ]; then echo "REFUSE: home resolves to '${H}'"; exit 3; fi
cd "$H" || exit 3

FAILS=0
say() { printf '%s\n' "$*"; }
fold() { if [ "$OS" = Darwin ]; then printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; else printf '%s' "$1"; fi; }

resolve() {  # physical path, parent symlinks resolved; a symlinked final component is refused
  local p=${1%/} parent base
  [ -n "$p" ] || return 1
  case "$p" in */.|*/..|.|..) return 1 ;; esac
  [ -L "$p" ] && return 1
  [ -e "$p" ] || return 1
  parent=${p%/*}; base=${p##*/}; [ -n "$parent" ] || parent=/
  parent=$(cd "$parent" 2>/dev/null && pwd -P) || return 1
  printf '%s/%s' "${parent%/}" "$base"
}

# 0 = clean; anything else = refuse (repo found, unreadable, or find itself failed)
no_repo() {
  local d=$1 up=$1
  while [ -n "$up" ] && [ "$up" != "/" ]; do      # is d inside a repo?
    [ -e "$up/.git" ] && return 1
    [ "$up" = "$H" ] && break
    up=${up%/*}
  done
  # Does d contain a repo, at any depth? -exec gets argv, so odd names are safe. A worktree
  # (.git) or a bare repo (dir with HEAD + objects + refs, any HEAD type) makes sh exit 3,
  # and find then exits non-zero. Unreadable directories also make find exit non-zero.
  local nm=-name; [ "$OS" = Darwin ] && nm=-iname   # APFS is case-insensitive: .GIT is a repo
  find "$d" \( $nm .git -o $nm HEAD \) -exec sh -c '
    for f; do
      case ${f##*/} in
        [Hh][Ee][Aa][Dd]) p=${f%/*}; [ -d "$p/objects" ] && [ -d "$p/refs" ] && exit 3 ;;
        *) exit 3 ;;
      esac
    done; exit 0' sh {} + >/dev/null 2>&1
}

# 0 = D contains no symlink anywhere. Anything else (a symlink found, or find failed) refuses.
# Needed for pip: `pip cache purge` walks D/http and D/wheels with os.walk, which FOLLOWS a
# symlinked top directory and deletes the files it points at (reproduced, pip 25.1.1).
no_symlinks_inside() {
  find "$1" -mindepth 1 -type l -exec sh -c 'exit 3' sh {} + >/dev/null 2>&1
}

guard() {  # guard <label> <raw> <exact expected path...>; sets GUARDED
  local label=$1 raw=${2:-} d e ok=1; shift 2
  GUARDED=""
  [ -n "$raw" ] || { say "SKIP $label: no path resolved"; return 1; }
  [ -L "${raw%/}" ] && { say "SKIP $label: $raw is a symlink"; return 1; }
  [ -e "$raw" ] || { say "SKIP $label: $raw absent"; return 1; }
  d=$(resolve "$raw") || { say "SKIP $label: $raw unresolvable"; return 1; }
  for e in "$@"; do [ "$(fold "$d")" = "$(fold "$e")" ] && ok=0; done
  [ "$ok" -eq 0 ] || { say "SKIP $label: $d is not $label's default cache directory"; return 1; }
  no_repo "$d" || { say "SKIP $label: $d is in or contains a git repo, or could not be fully scanned"; return 1; }
  GUARDED=$d
}

size_of() { du -sk -- "$1" 2>/dev/null | awk '{print $1}'; }
FREED_KB=0
run_clean() {  # <label> <measured dir> <command...>
  local label=$1 d=$2 before after; shift 2
  before=$(size_of "$d"); before=${before:-0}
  if [ "$APPLY" -ne 1 ]; then say "PLAN $label: $d (${before} KB): $*"; return 0; fi
  if (cd "$H" && "$@") >/dev/null 2>&1; then
    after=$(size_of "$d"); after=${after:-0}
    FREED_KB=$((FREED_KB + before - after)); say "DONE $label: $d freed $((before - after)) KB"
  else
    say "FAIL $label: $* exited non-zero"; FAILS=$((FAILS + 1))
  fi
}
have() { command -v "$1" >/dev/null 2>&1; }
if [ "$OS" = Darwin ]; then CACHES="$H/Library/Caches"; else CACHES="$H/.cache"; fi

say "OS=$OS HOME=$H mode=$([ "$APPLY" -eq 1 ] && echo apply || echo dry-run)"
df -h / "$H" 2>/dev/null | awk 'NR==1 || !seen[$0]++'

if have npm; then
  c=$(cd "$H" && npm config get cache 2>/dev/null)
  if [ -n "$c" ] && guard npm "${c%/}/_cacache" "$H/.npm/_cacache"; then
    run_clean npm "$GUARDED" npm cache clean --force --cache "${GUARDED%/_cacache}"
  fi
fi
if have pip; then
  c=$(cd "$H" && pip cache dir 2>/dev/null)
  if guard pip "$c" "$H/.cache/pip" "$H/Library/Caches/pip"; then
    if ! no_symlinks_inside "$GUARDED"; then
      say "SKIP pip: $GUARDED contains a symlink (pip cache purge follows it), or could not be scanned"
    else
      run_clean pip "$GUARDED" pip --cache-dir "$GUARDED" cache purge
    fi
  fi
fi
if have uv; then
  uvsym=0
  [ "$(printf '%s' "${UV_LINK_MODE:-}" | tr '[:upper:]' '[:lower:]')" = symlink ] && uvsym=1
  _uvcfgs="${XDG_CONFIG_HOME:-$H/.config}/uv/uv.toml:$H/.config/uv/uv.toml:/etc/uv/uv.toml"
  _old_ifs=$IFS; IFS=:
  for f in $_uvcfgs ${XDG_CONFIG_DIRS:-}; do
    case "$f" in */uv.toml) ;; *) f="$f/uv/uv.toml" ;; esac
    grep -qsiE "^[[:space:]]*link-mode[[:space:]]*=[[:space:]]*[\"']?symlink" "$f" && uvsym=1
  done
  IFS=$_old_ifs
  if [ "$UVOK" -ne 1 ]; then
    say "SKIP uv: needs --uv (environments installed with link-mode=symlink break if the cache is cleaned)"
  elif [ "$uvsym" -eq 1 ]; then
    say "SKIP uv: link-mode=symlink is configured"
  else
    c=$(cd "$H" && uv cache dir 2>/dev/null)
    if guard uv "$c" "$H/.cache/uv" "$H/Library/Caches/uv"; then
      run_clean uv "$GUARDED" uv cache clean --cache-dir "$GUARDED"
    fi
  fi
fi

# Report only. These are never deleted by this script.
for p in "$CACHES/Homebrew" "$H/.local/share/pnpm/store" "$H/Library/pnpm/store" "$CACHES/yarn" "$CACHES/Yarn" \
         "$CACHES/google-chrome" "$CACHES/Google/Chrome" "$CACHES/chromium" "$CACHES/BraveSoftware" \
         "$CACHES/mozilla" "$CACHES/Firefox" "$H/.local/share/Trash" "$H/.Trash" "$H/Library/Logs"; do
  [ -d "$p" ] && [ ! -L "$p" ] && say "REPORT $p: $(size_of "$p") KB (not cleaned by this script; clear by hand if you're sure)"
done

say "SUMMARY freed=${FREED_KB} KB failures=${FAILS} mode=$([ "$APPLY" -eq 1 ] && echo apply || echo dry-run)"
df -h / "$H" 2>/dev/null | awk 'NR==1 || !seen[$0]++'
[ "$FAILS" -eq 0 ] || exit 1
exit 0
