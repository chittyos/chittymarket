#!/usr/bin/env bash
# wt-reap.sh — reclaim disk from worktrees whose work is already landed.
#
# Companion to `git wt` (git-wt), which creates worktrees under
# $GIT_WT_ROOT (default ~/projects/worktrees). Creation is cheap and
# frequent; nothing ever reclaimed. Measured 2026-10-02 on this host:
# 170 worktrees across 32 repos, 17G total — of which 14G was node_modules
# in 43 directories. The tracked content of all 170 trees was under 3G.
#
# The two costs are separable, and only one of them is safe to reclaim:
#
#   * REMOVING A WORKTREE is risky. With many parallel sessions on one host,
#     a worktree may be another session's live tree, and there is no reliable
#     owner recorded anywhere. This script never removes a worktree that
#     holds tracked changes, and by default removes none at all.
#
#   * DELETING node_modules INSIDE a worktree whose PR has already merged or
#     closed is not risky. It is gitignored and regenerable by definition,
#     it touches nothing tracked, and a landed branch has no in-flight test
#     run worth protecting. That is where the 14G sits and where the risk
#     is not.
#
# So the default mode reaps node_modules only, gated on PR state.
#
# Every skip is printed with its reason. A silent cap reads as "covered
# everything", which is how the sprawl went unnoticed in the first place.
#
# Usage:
#   scripts/wt-reap.sh                      # dry run, node_modules mode
#   scripts/wt-reap.sh --apply              # actually delete
#   scripts/wt-reap.sh --mode empty         # also report empty worktrees
#   scripts/wt-reap.sh --repo chittyentity  # restrict to one repo's worktrees
#
# Requires: git, gh (authenticated). Exits 0 when the sweep completed, even
# if nothing was eligible; non-zero only on a usage or precondition error.
set -euo pipefail

WTROOT="${GIT_WT_ROOT:-$HOME/projects/worktrees}"
APPLY=0
MODE=node-modules
REPO_FILTER=""

while [ $# -gt 0 ]; do
  case "$1" in
    --apply) APPLY=1; shift ;;
    --mode) MODE="${2:?--mode needs a value: node-modules|empty}"; shift 2 ;;
    --repo) REPO_FILTER="${2:?--repo needs a repo name}"; shift 2 ;;
    -h|--help) sed -n '1,40p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

case "$MODE" in
  node-modules|empty) ;;
  *) echo "--mode must be node-modules or empty (got: $MODE)" >&2; exit 2 ;;
esac

command -v gh >/dev/null || { echo "gh is required to resolve PR state" >&2; exit 2; }
gh auth status >/dev/null 2>&1 || { echo "gh is not authenticated; cannot resolve PR state" >&2; exit 2; }
[ -d "$WTROOT" ] || { echo "no worktree root at $WTROOT" >&2; exit 2; }

[ "$APPLY" -eq 1 ] || echo "DRY RUN — nothing will be deleted. Re-run with --apply to act."
echo "root: $WTROOT   mode: $MODE"
echo

# PR state for a branch, cached per (repo,branch): gh is by far the slow part
# and many worktrees share a repo. The cache MUST be updated in this shell —
# an earlier revision called this inside $( ), where every cache write was
# discarded with the subshell and every lookup hit the network again.
declare -A PR_CACHE
PR_STATE=""
pr_state() { # $1=repo slug (owner/name)  $2=branch -> sets PR_STATE
  local key="$1@$2" state
  if [ -n "${PR_CACHE[$key]:-}" ]; then PR_STATE="${PR_CACHE[$key]}"; return 0; fi
  # Ask for EVERY PR on this head, not just the newest. A branch with an older
  # OPEN pr and a newer CLOSED one must read as OPEN — "the first PR is landed"
  # would reap a tree whose work is still in flight.
  local all
  all=$(gh pr list --repo "$1" --head "$2" --state all --limit 100 \
          --json state -q '.[].state' 2>/dev/null) || all="__ERR__"
  if [ "$all" = "__ERR__" ]; then
    state=UNKNOWN
  elif [ -z "$all" ]; then
    state=NONE
  elif printf '%s\n' "$all" | grep -qx OPEN; then
    state=OPEN
  elif printf '%s\n' "$all" | grep -qx MERGED; then
    state=MERGED
  elif printf '%s\n' "$all" | grep -qx CLOSED; then
    state=CLOSED
  else
    state=UNKNOWN
  fi
  PR_CACHE[$key]="$state"
  PR_STATE="$state"
}

# owner/name from the worktree's own origin remote, so no `gh repo view` call
# is needed per worktree. Handles both SSH and HTTPS remotes.
repo_slug() { # $1=worktree path -> sets REPO_SLUG ("" if undeterminable)
  local url
  url="$(git -C "$1" remote get-url origin 2>/dev/null || true)"
  REPO_SLUG=""
  [ -n "$url" ] || return 0
  url="${url%.git}"
  case "$url" in
    *github.com*) ;;
    *) return 0 ;;   # non-GitHub remote: no PR state is knowable
  esac
  REPO_SLUG="${url#*github.com}"
  # Strip the separator, then an ssh:// port ("github.com:22/org/repo" left ":22/org/repo").
  REPO_SLUG="${REPO_SLUG#[:/]}"
  case "$REPO_SLUG" in
    [0-9]*/*/*) REPO_SLUG="${REPO_SLUG#*/}" ;;   # drop a leading numeric port segment
  esac
  # Must be exactly owner/name; anything else is not a slug we will query.
  case "$REPO_SLUG" in
    */*/*|*/|/*|'') REPO_SLUG="" ;;
    */*) ;;
    *) REPO_SLUG="" ;;
  esac
}

# The repo's short name, for --repo filtering. Directory names under the
# worktree root are BRANCH slugs (cc-280, ced-failclosed), not repo names, so
# matching on the directory name filtered the wrong set entirely.
repo_name() { REPO_NAME="${1##*/}"; }

# Candidate node_modules paths accumulate here so the total can be measured
# with ONE du invocation at the end. Summing per-directory du double-counts:
# pnpm/npm hardlink shared files between worktrees, and `du` counts a given
# inode once per invocation. Measured 2026-10-02: summing per directory gave
# 28636MB across 23 worktrees, while a single du over the same 668 directories
# gave 9779MB — the per-directory sum exceeded the 17G the entire worktree
# root occupies, which is how the error was caught.
REAP_DIRS=()
eligible=0
skipped=0

# Without nullglob an empty root leaves the literal pattern, and the loop then
# reported `SKIP * — orphan directory` and `skipped: 1` for a root holding
# nothing. A miscounted sweep reads as "covered everything".
shopt -s nullglob
entries=("$WTROOT"/*/)
shopt -u nullglob
for wt in "${entries[@]}"; do
  wt="${wt%/}"
  name="$(basename "$wt")"

  # A symlink under the root is never followed. du measures the LINK (0KB), so
  # --mode empty judged any dir-symlink "empty" regardless of content and then
  # `worktree remove --force` resolved the realpath and removed the real tree.
  if [ -L "$wt" ]; then
    echo "SKIP  $name — symlink; not followed"; skipped=$((skipped+1)); continue
  fi

  # A directory under WTROOT is not necessarily a REGISTERED worktree.
  # --is-inside-work-tree is true for any repo, so a loose clone parked here
  # was reaped instead of reported. A linked worktree is the case where
  # --git-dir and --git-common-dir differ.
  gd="$(git -C "$wt" rev-parse --git-dir 2>/dev/null || true)"
  gcd="$(git -C "$wt" rev-parse --git-common-dir 2>/dev/null || true)"
  if [ -z "$gd" ]; then
    echo "SKIP  $name — not a git worktree (orphan directory)"; skipped=$((skipped+1)); continue
  fi
  if [ "$gd" = "$gcd" ]; then
    echo "SKIP  $name — a standalone clone, not a linked worktree"; skipped=$((skipped+1)); continue
  fi

  branch="$(git -C "$wt" rev-parse --abbrev-ref HEAD 2>/dev/null || echo DETACHED)"
  if [ "$branch" = HEAD ] || [ "$branch" = DETACHED ]; then
    echo "SKIP  $name — detached HEAD, no branch to resolve"; skipped=$((skipped+1)); continue
  fi

  # Uncommitted tracked changes mean someone is mid-edit. Never touch these,
  # in either mode — even node_modules, since a running test may depend on it.
  dirty="$(git -C "$wt" status --porcelain --untracked-files=no 2>/dev/null | wc -l)"
  if [ "$dirty" -gt 0 ]; then
    echo "SKIP  $name — $dirty uncommitted tracked change(s) on $branch"; skipped=$((skipped+1)); continue
  fi

  repo_slug "$wt"
  if [ -z "$REPO_SLUG" ]; then
    echo "SKIP  $name — no github origin remote; cannot resolve PR state"; skipped=$((skipped+1)); continue
  fi
  # --repo filters on the REPO, not the directory name. Exact match on the
  # repo's short name; the old prefix-match on $name selected branch slugs.
  repo_name "$REPO_SLUG"
  if [ -n "$REPO_FILTER" ] && [ "$REPO_NAME" != "$REPO_FILTER" ]; then continue; fi
  pr_state "$REPO_SLUG" "$branch"
  state="$PR_STATE"
  case "$state" in
    MERGED|CLOSED) ;;
    OPEN)    echo "SKIP  $name — PR is OPEN ($branch)"; skipped=$((skipped+1)); continue ;;
    NONE)    echo "SKIP  $name — no PR for $branch; cannot confirm the work landed"; skipped=$((skipped+1)); continue ;;
    *)       echo "SKIP  $name — PR state unresolved ($branch)"; skipped=$((skipped+1)); continue ;;
  esac

  if [ "$MODE" = empty ]; then
    size="$(du -s "$wt" 2>/dev/null | cut -f1)"
    if [ "${size:-9999}" -le 8 ]; then
      eligible=$((eligible+1))
      echo "EMPTY $name — ${size}KB, PR $state ($branch)"
      if [ "$APPLY" -eq 1 ]; then
        ( cd "$wt/.." && git -C "$wt" worktree remove --force "$wt" 2>/dev/null ) \
          && echo "      removed" || echo "      FAILED to remove — left in place"
      fi
    fi
    continue
  fi

  # node-modules mode.
  # -print0 / mapfile -d '' is load-bearing, not style. With `mapfile -t` a
  # worktree path containing a newline split into two fragments and `rm -rf`
  # deleted BOTH: a sibling directory under the root, and the second fragment
  # resolved relative to the INVOKING SHELL'S CWD — outside the root entirely.
  # -type d (not -L) also means a symlinked node_modules is never a candidate,
  # so `git wt`-symlinked trees are excluded from the reclaim figure.
  nm=()
  while IFS= read -r -d '' d; do nm+=("$d"); done \
    < <(find "$wt" -maxdepth 3 -name node_modules -type d -prune -print0 2>/dev/null)
  if [ "${#nm[@]}" -eq 0 ]; then continue; fi
  kb="$(du -s --total "${nm[@]}" 2>/dev/null | tail -1 | cut -f1)"
  eligible=$((eligible+1))
  REAP_DIRS+=("${nm[@]}")
  # "apparent" because content hardlinked to another worktree is counted here
  # but will not free until the last link to it is gone. The footer total is
  # the figure to trust.
  printf 'REAP  %-58s %6sMB apparent  PR %s (%s)\n' "$name" "$(( ${kb:-0} / 1024 ))" "$state" "$branch"
done

# Measure and report BEFORE deleting. An earlier revision measured after, so
# `du` ran on paths rm had just removed, exited 1, and under pipefail+errexit
# killed the script before the footer — every successful --apply exited 1 and
# printed no summary. Dry run never deletes, so the author's own validation
# never reached it.
echo
true_kb=0
if [ "${#REAP_DIRS[@]}" -gt 0 ]; then
  # One invocation, so each inode is counted once no matter how many
  # worktrees link to it.
  true_kb="$(du -s --total "${REAP_DIRS[@]}" 2>/dev/null | tail -1 | cut -f1 || true)"
fi
printf 'eligible: %d worktrees, %d node_modules dirs   skipped: %d\n' \
  "$eligible" "${#REAP_DIRS[@]}" "$skipped"
printf 'on-disk size of those dirs: %sMB (hardlinks counted once)\n' "$(( ${true_kb:-0} / 1024 ))"
echo "that is an upper bound on space freed: content still hardlinked from a"
echo "skipped worktree does not free until its last link is removed."

if [ "$APPLY" -eq 1 ] && [ "${#REAP_DIRS[@]}" -gt 0 ]; then
  echo
  failed=0
  for d in "${REAP_DIRS[@]}"; do
    rm -rf -- "$d" || { echo "FAILED: $d" >&2; failed=$((failed+1)); }
  done
  printf 'deleted %d node_modules dir(s)' "$(( ${#REAP_DIRS[@]} - failed ))"
  if [ "$failed" -eq 0 ]; then
    echo " — regenerate with your package manager"
  else
    printf ' of %d; %d failed\n' "${#REAP_DIRS[@]}" "$failed"
    exit 1
  fi
elif [ "$APPLY" -eq 0 ]; then
  echo "re-run with --apply to delete"
fi
exit 0
