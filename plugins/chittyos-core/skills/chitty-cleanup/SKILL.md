---
name: chitty-cleanup
description: Free disk space on macOS or Linux by clearing the current user's regenerable tool caches (npm, pnpm, yarn, pip, uv, Homebrew download cache, browser caches). Use when a host is low on disk or above 90% full. Only touches cache directories that resolve inside $HOME; never sudo, Docker, other users' data, or Trash without confirmation.
canon_uri: chittycanon://core/services/chittymarket#skills/chitty-cleanup
---

# ChittyOS Cleanup Skill

## Overview
Free disk space by clearing the **current user's** regenerable caches. Every target is
resolved to its real directory first and is touched only if that directory is inside
`$HOME`. Trash is never emptied without explicit confirmation, because it holds
recoverable user files.

## Usage
```
/cleanup [--dry-run]
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| --dry-run | false | Resolve and size every target and print what would run. **Run no clean command and no `rm`.** |

## Step 1: guard, detect, measure

```bash
: "${HOME:?HOME unset}"; cd "$HOME"   # run everything from $HOME, so project-level
                                      # .npmrc / .yarnrc.yml / pip.conf can't redirect a tool
uname -s                              # Darwin or Linux; use only that OS's rows
H=$(cd "$HOME" && pwd -P)             # canonical home (resolves symlinks, portable)
[ -n "$H" ] && [ "$H" != "/" ] || { echo "REFUSE: home resolves to '$H'"; exit 1; }
df -h / "$H"                          # record before; $HOME may be a separate filesystem
```

## Step 2: resolve each cache's real directory, then check it is inside $HOME

Ask the tool where its cache really is. Environment variables (`npm_config_cache`,
`PIP_CACHE_DIR`, `UV_CACHE_DIR`, `XDG_CACHE_HOME`, pnpm `store-dir`) can point a cache at
a shared location, and fixed paths are wrong in those cases.

> **In `--dry-run`, never execute the "Clean with" column.** Run only the "Resolve with"
> commands and the guard, then size each guarded path (Step 3).

| Cache | Resolve with | Clean with (only if the guard passes) |
|---|---|---|
| npm | `npm config get cache` | `npm cache clean --force` |
| pnpm | `pnpm store path` | `pnpm store prune` |
| yarn v1 | `yarn cache dir` | `yarn cache clean` |
| yarn Berry (`yarn --version` ≥ 2) | `yarn config get cacheFolder` | `yarn cache clean --mirror`. **Never plain `yarn cache clean`**: in a zero-install repo it deletes the committed `.yarn/cache` |
| pip | `pip cache dir` | `pip cache purge` |
| uv | `uv cache dir` | `uv cache clean`, **only if no environment links into the cache**. With `link-mode = "symlink"`, installed packages are symlinks into the cache, so cleaning it breaks those environments. Skip uv and report it as needing approval if `UV_LINK_MODE=symlink` is set, if `link-mode` appears in `~/.config/uv/uv.toml` (or a `uv.toml`/`pyproject.toml` the operator names), or if this can't be ruled out. Clean only after explicit approval |
| Homebrew downloads | `brew --cache` | `rm -rf -- "$d"` (the guarded path from below). **Never `brew cleanup`**: it also removes installed formula versions under the Homebrew prefix, which isn't a cache and may be outside `$HOME` |

**Guard (required for every row):** call `guard "<resolved dir>"`. Use the target only if it prints `OK`; then `d` is the path to act on.
```bash
guard() {   # portable (macOS + Linux); no realpath -m
  p=${1%/}
  [ -e "$p" ] || { echo "SKIP $p: absent"; return 1; }
  [ -L "$p" ] && { echo "SKIP $p: is a symlink"; return 1; }       # never follow into real data
  par=$(cd "$(dirname -- "$p")" 2>/dev/null && pwd -P) || { echo "SKIP $p: parent unresolvable"; return 1; }
  d="$par/$(basename -- "$p")"                                     # parent symlinks resolved
  case "$d" in "$H"/*) ;; *) echo "SKIP $d: outside $H"; return 1 ;; esac
  case "$d" in "$H"/.claude*|"$H"/.config|"$H"/.config/*|"$H"/.ssh*|"$H"/Downloads*|"$H"/Documents*|"$H"/Desktop*)
    echo "SKIP $d: protected"; return 1 ;; esac
  (cd "$d" && git rev-parse --is-inside-work-tree >/dev/null 2>&1) && { echo "SKIP $d: inside a git work tree"; return 1; }
  df -P -- "$d" | tail -1 | awk '{print "FS "$6}'                   # report the target's filesystem
  echo "OK $d"
}
```
If a tool isn't installed, skip its row. Don't guess its path.

Fixed-path rows, which have no resolver. Each one is still guarded the same way:

| Cache | macOS | Linux |
|---|---|---|
| node-gyp | `~/Library/Caches/node-gyp` | `~/.cache/node-gyp` |
| TypeScript | `~/Library/Caches/typescript` | `~/.cache/typescript` |
| Chrome | `~/Library/Caches/Google/Chrome` | `~/.cache/google-chrome` |
| Chromium | n/a | `~/.cache/chromium` |
| Brave | `~/Library/Caches/BraveSoftware` | `~/.cache/BraveSoftware` |
| Firefox | `~/Library/Caches/Firefox` | `~/.cache/mozilla` |

Skip a browser if it's running: check `pgrep -x` for the browser's process name first. Clearing the cache of a running browser can corrupt it.

## Step 3: delete, exact paths only

- **Never use globs or brace expansion with `rm`.** Delete only an exact path from the tables above, after the guard has passed: `rm -rf -- "$d"`.
- In `--dry-run`, size each guarded path with `du -sh -- "$d"`, list the commands that would run, and stop.

## Step 4: Trash and logs: report, ask, never automatic

| Item | Path | Rule |
|---|---|---|
| Trash | macOS `~/.Trash` (needs Full Disk Access; on "Operation not permitted", report it and don't retry), Linux `~/.local/share/Trash` | Report the size. Empty it **only after explicit confirmation**, because it holds recoverable files |
| Logs | macOS `~/Library/Logs` | Report the size only. It holds crash reports, which aren't regenerable |

## Step 5: report

`df -h / "$H"` again (plus each distinct `FS` the guard reported), and `du -xsh "$H"`. Report the freed size per target, any `SKIP` lines,
and the use% before and after. If the disk is still full, say that the rest is outside
this user's home and stop. **Don't scan other users' homes or `/`, and don't use `sudo`.**

## Safety: never touched
- Anything whose resolved path is outside `$HOME`. This covers shared caches, other users' homes and the Homebrew prefix
- Anything that needs `sudo`
- Docker images, volumes and build cache. `docker system prune` is a destructive action with its own approval gate
- Agent and editor state: `~/.claude/`, `~/.cache/claude*`, `~/.config/`
- Repos and worktrees, including project `.yarn/cache` and `node_modules`
- iCloud / CloudKit data, macOS Application Support, Downloads, documents, ISO images

## Typical results
- macOS workstation: 2–5 GB per run.
- Linux server account: usually under 1–2 GB. On a shared host, most usage is someone else's, so the skill reports it but never clears it.
- Run weekly, or when disk use exceeds 90%.
