---
name: chitty-cleanup
description: Free disk space on macOS or Linux by clearing the current user's regenerable tool caches (npm, pnpm, yarn v1, pip, uv, Homebrew downloads, browser caches) via a guarded script. Dry run by default. Use when a host is low on disk or above 90% full. Never sudo, Docker, other users' data, repos, or Trash without --trash.
canon_uri: chittycanon://core/services/chittymarket#skills/chitty-cleanup
---

# ChittyOS Cleanup Skill

Free disk space by clearing the **current user's** regenerable caches. Every safety rule lives
in `scripts/cleanup.sh` (in this skill's directory), and each rule is pinned by
`scripts/tests/test-chitty-cleanup.sh` in chittymarket. **Run the script. Don't reimplement it with
ad-hoc `rm` or tool commands.** Three reviews of a prose-only version each found new ways
an improvised guard fails open.

## Usage

| Command | Effect |
|---|---|
| `bash scripts/cleanup.sh` | **Dry run (default).** Resolves, guards and sizes every target, prints `PLAN`/`SKIP` lines, deletes nothing |
| `bash scripts/cleanup.sh --apply` | Cleans every target that passed the guards |
| `bash scripts/cleanup.sh --apply --trash` | Also empties the user's Trash. **Permanent. Only on the user's explicit request** |

Always run the dry run first and show its `PLAN` and `SKIP` lines before `--apply`.

## What the script guarantees
- **Home** is computed inside the script (`pwd -P`). If it's empty or `/`, the script refuses and exits 3.
- **Allowlist, not "inside `$HOME`".** A target's resolved path must be strictly below `~/.cache`, `~/Library/Caches`, `~/.local/share/pnpm`, `~/Library/pnpm`, or be `~/.npm/_cacache`. So `HOMEBREW_CACHE=~/Downloads` is refused. The comparison is case-insensitive on macOS.
- **Symlinks:** a symlinked target is refused, and parent symlinks are resolved before the allowlist check.
- **Repos:** anything inside or containing a `.git` is refused. The script finds it by walking the path, without relying on `git`, so `GIT_DIR` can't fool it.
- **Tools are cleaned with the guarded directory passed explicitly:** `npm --cache`, `pnpm --store-dir`, `yarn --cache-folder` (v1), `pip --cache-dir`, `uv --cache-dir`.
- **Never automated:** `brew cleanup` (only Homebrew's download cache is removed), Yarn Berry, uv when `link-mode` may be `symlink` (needs approval), running browsers, `~/Library/Logs` (report only), Trash without `--trash`.
- **Never touched:** anything needing `sudo`, Docker, other users' homes, `~/.claude`, `~/.config`, documents.

## Reporting
Relay the script's `SKIP`, `DONE`/`PLAN` and `SUMMARY` lines and the before/after `df`. If the disk is
still full, say the rest lies outside this user's caches. Don't scan other users' homes or `/`.

## Codex / other runtimes
This skill's script ships in the Claude Code projection (`plugins/chittyos-core/skills/chitty-cleanup/scripts/cleanup.sh`).
Other runtimes run that file directly, or report that it's unavailable. They must not improvise a replacement.
