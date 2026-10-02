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
  state=$(gh pr list --repo "$1" --head "$2" --state all --limit 1 \
            --json state -q '.[0].state' 2>/dev/null) || state=""
  [ -n "$state" ] || state=NONE
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
    *github.com[:/]*) REPO_SLUG="${url#*github.com}"; REPO_SLUG="${REPO_SLUG#[:/]}" ;;
  esac
}

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

for wt in "$WTROOT"/*/; do
  wt="${wt%/}"
  name="$(basename "$wt")"
  [ -z "$REPO_FILTER" ] || case "$name" in "$REPO_FILTER"*) ;; *) continue ;; esac

  # A directory under WTROOT is not necessarily a registered worktree. Report
  # orphans; never delete them — we cannot tell what they are.
  if ! git -C "$wt" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "SKIP  $name — not a git worktree (orphan directory)"; skipped=$((skipped+1)); continue
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

  # node-modules mode
  mapfile -t nm < <(find "$wt" -maxdepth 3 -name node_modules -type d -prune 2>/dev/null)
  if [ "${#nm[@]}" -eq 0 ]; then continue; fi
  kb="$(du -s --total "${nm[@]}" 2>/dev/null | tail -1 | cut -f1)"
  eligible=$((eligible+1))
  REAP_DIRS+=("${nm[@]}")
  # "apparent" because content hardlinked to another worktree is counted here
  # but will not free until the last link to it is gone. The footer total is
  # the figure to trust.
  printf 'REAP  %-58s %6sMB apparent  PR %s (%s)\n' "$name" "$(( ${kb:-0} / 1024 ))" "$state" "$branch"
  if [ "$APPLY" -eq 1 ]; then
    for d in "${nm[@]}"; do rm -rf "$d" || echo "      FAILED: $d"; done
    echo "      deleted ${#nm[@]} node_modules dir(s) — regenerate with your package manager"
  fi
done

echo
if [ "${#REAP_DIRS[@]}" -gt 0 ]; then
  # One invocation, so each inode is counted once no matter how many
  # worktrees link to it.
  true_kb="$(du -s --total "${REAP_DIRS[@]}" 2>/dev/null | tail -1 | cut -f1)"
else
  true_kb=0
fi
printf 'eligible: %d worktrees, %d node_modules dirs   skipped: %d\n' \
  "$eligible" "${#REAP_DIRS[@]}" "$skipped"
printf 'on-disk size of those dirs: %sMB (hardlinks counted once)\n' "$(( ${true_kb:-0} / 1024 ))"
echo "that is an upper bound on space freed: content still hardlinked from a"
echo "skipped worktree does not free until its last link is removed."
[ "$APPLY" -eq 1 ] || echo "re-run with --apply to delete"
