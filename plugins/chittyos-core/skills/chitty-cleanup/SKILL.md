---
name: chitty-cleanup
description: Free disk space on macOS or Linux by clearing the current user's regenerable caches (browser, npm, pnpm, pip, uv, Homebrew, logs, trash). Use when a host is low on disk or above 90% full. Never touches Docker, other users' homes, or anything needing sudo.
canon_uri: chittycanon://core/services/chittymarket#skills/chitty-cleanup
---

# ChittyOS Cleanup Skill

## Overview
Free disk space by clearing the **current user's** regenerable caches. Safe to run anytime: it only removes data the owning tool rebuilds on next use.

## Usage
```
/cleanup [--dry-run]
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| --dry-run | false | Report sizes and the commands that would run; delete nothing |

## Step 1: detect the host, then measure

```bash
uname -s          # Darwin -> macOS targets, Linux -> Linux targets
df -h /           # record before
```

Use only the target table for the detected OS. On Linux, never substitute macOS `~/Library/...` paths.

## Step 2: clear, preferring each tool's own clean command

A tool's own command knows its cache layout and lock files. Fall back to deleting the
directory only when the tool isn't installed.

| Cache | Command (preferred) | Fallback path: macOS | Fallback path: Linux |
|---|---|---|---|
| npm | `npm cache clean --force` | `~/.npm/_cacache` | `~/.npm/_cacache` |
| pnpm | `pnpm store prune` | `~/Library/Caches/pnpm` | `~/.local/share/pnpm/store` |
| yarn | `yarn cache clean` | `~/Library/Caches/yarn` | `~/.cache/yarn` |
| pip | `pip cache purge` | `~/Library/Caches/pip` | `~/.cache/pip` |
| uv | `uv cache clean` | `~/Library/Caches/uv` | `~/.cache/uv` |
| Homebrew | `brew cleanup -s --prune=all` | `~/Library/Caches/Homebrew` | `~/.cache/Homebrew` |
| node-gyp | n/a | `~/Library/Caches/node-gyp` | `~/.cache/node-gyp` |
| TypeScript | n/a | `~/Library/Caches/typescript` | `~/.cache/typescript` |
| Browsers | n/a | `~/Library/Caches/{Google,com.google.Chrome,com.brave.Browser,Firefox,com.apple.Safari}` | `~/.cache/{google-chrome,chromium,BraveSoftware,mozilla}` |
| Apps (macOS) | n/a | `~/Library/Caches/{com.openai.atlas,SiriTTS,com.spotify.client,com.microsoft.VSCode}` | n/a |
| User logs | n/a | `~/Library/Logs` | n/a: `journalctl` is system-owned, so skip it |
| Trash | n/a | `~/.Trash` | `~/.local/share/Trash` |

Dry run (either OS) sizes only the paths that exist:

```bash
du -sh <paths for this OS> 2>/dev/null | sort -hr
```

Delete with an exact path, never a glob outside the user's home: `rm -rf -- "$HOME/.cache/uv"`.

## Step 3: report

`df -h /` again. Report the freed MB per target, before and after use%, and **where the remaining
usage lives if it is outside this user's home**, as a pointer for the owner, not an action.

## Safety

### Never touched
- Anything outside `$HOME` of the user running the skill, including other users' homes on a shared host
- Anything that needs `sudo`
- Docker images, volumes and build cache (`docker system prune` is a destructive action with its own approval gate)
- Agent and editor state: `~/.claude/` (plugins, file-history, projects), `~/.cache/claude*`, `~/.config/`
- iCloud / CloudKit data, macOS Application Support
- Downloads, documents, ISO images, any repo or worktree

### Always safe to clear
Every target in the Step 2 table is a cache its owning tool regenerates. There is no data loss and no re-authentication.

## Typical results
- macOS workstation: 2–5 GB per run. macOS may also release purgeable space afterwards.
- Linux server account: usually under 1–2 GB. On a shared host, most usage is typically
  system or other users' data, which this skill reports but never clears.
- Run weekly, or when disk use exceeds 90%.
