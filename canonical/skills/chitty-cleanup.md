---
name: chitty-cleanup
canon_uri: chittycanon://core/services/chittymarket#skills/chitty-cleanup
description: Free disk space on macOS or Linux by clearing the current user's regenerable tool caches (npm, pnpm, yarn v1, pip, uv, Homebrew downloads, browser caches) via a guarded script. Dry run by default. Use when a host is low on disk or above 90% full. Never sudo, Docker, other users' data, repos, or Trash without --trash.
kind: skill
plugin: chittyos-core
runtimes:
  - claude-code
  - codex
classification:
  - session
  - operations
canonical_capability_ref: "chittycanon://capability/workspace/session-cleanup"
overlay:
  title: "Session Cleanup"
  capability_group: "workspace"
  group_assignment_source: "name-rule"
  execution_class: "@chitty/connectors"
  canonical_version: "1.0.0"
  projection_version_policy: "inherit-canonical"
  ontology:
    primary:
      - "P"
    secondary:
      - "E"
      - "T"
  authority:
    requires_chittyid: true
  execution:
    default_surface: "ch1tty"
    local_allowed: false
    context_cost: "medium"
    mutation_risk: "medium"
  discovery:
    indexable: true
    session_index: "hidden"
    ambient_by_intent: false
    verbs:
      - "checkpoint"
      - "restore"
      - "remember"
    fallback_search: true
  auth_flow:
    mode: "local-only"
    stores_credentials_in: "n/a"
    fail_closed_if_unavailable: false
  runtime_exclusions: {}
  phase0_audit:
    job_to_be_done: "generate"
    environmental_footprint: "write-capable"
    evidentiary_risk: "none"
    advisory_disposition: "skill"
  legacy_category: "ecosystem"
  deprecated_aliases:
    - "skill-chitty-cleanup"
  visibility: "recommended"
  access: "readwrite"
  compatible_channels:
  - claude_code
  - claude_ai
  - claude_desktop
  - chatgpt
  - codex
  - openclaw
  source_links:
  - local://~/.claude/skills/chitty-cleanup
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
| `bash scripts/cleanup.sh --apply --uv` | Also cleans uv's cache. **Only on explicit request**: environments installed with `link-mode=symlink` break |
| `bash scripts/cleanup.sh --apply --trash` | Also empties the user's Trash. **Permanent. Only on the user's explicit request** |

Always run the dry run first and show its `PLAN` and `SKIP` lines before `--apply`.

## What the script guarantees
- **Home** is computed inside the script (`pwd -P`). If it's empty or `/`, the script refuses and exits 3.
- **A per-tool allowlist, not broad roots.** Each target must resolve to that tool's own cache directory: `~/.npm/_cacache`, the pnpm *store* (not pnpm's global installs), `~/.cache/{yarn,pip,uv,Homebrew,node-gyp,typescript}` or the macOS `~/Library/Caches/...` equivalent, and the exact browser cache directories. `~/.cache`, `~/.npm` and pnpm's root are never targets, because they also hold data that isn't regenerable, such as poetry virtualenvs and pnpm global installs. The comparison is case-insensitive on macOS.
- **Symlinks:** a symlinked target is refused, and parent symlinks are resolved first. The check runs again immediately before every `rm`.
- **Repos:** anything inside, or containing at any depth, a git worktree or bare repo is refused, and so is a scan that couldn't read everything. The script finds repos by walking the path and scanning, without relying on `git`, so `GIT_DIR` can't fool it.
- **Tools are cleaned with the guarded directory passed explicitly:** `npm --cache`, `pnpm --store-dir`, `yarn --cache-folder` (v1), `pip --cache-dir`, `uv --cache-dir`.
- **Never automated:** `brew cleanup` (only Homebrew's download cache is removed), Yarn Berry, uv without `--uv`, running browsers, `~/Library/Logs` (report only), Trash without `--trash`.
- **Never touched:** anything needing `sudo`, Docker, other users' homes, `~/.claude`, `~/.config`, documents.

## Reporting
The exit code is 0 when everything succeeded, 1 when any step failed (a `FAIL` line), 3 when it refused (an unusable home), and 2 on bad arguments.
Relay the script's `SKIP`, `DONE`/`PLAN` and `SUMMARY` lines and the before/after `df`. If the disk is
still full, say the rest lies outside this user's caches. Don't scan other users' homes or `/`.

## Codex / other runtimes
This skill's script ships in the Claude Code projection (`plugins/chittyos-core/skills/chitty-cleanup/scripts/cleanup.sh`).
Other runtimes run that file directly, or report that it's unavailable. They must not improvise a replacement.
