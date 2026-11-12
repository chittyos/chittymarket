---
name: chitty-cleanup
canon_uri: chittycanon://core/services/chittymarket#skills/chitty-cleanup
description: Free disk space on macOS or Linux by clearing the current user's npm and pip caches (and uv's with --uv) through a guarded script that deletes nothing itself. Dry run by default. Reports, but never deletes, Homebrew, pnpm, yarn, browser caches, Trash and logs. Use when a host is low on disk.
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

Free disk space by clearing the **current user's** npm and pip caches, and uv's on request.
The guarded script `scripts/cleanup.sh` (in this skill's directory) does it. **The script deletes nothing itself.** Deletion is left to the tools'
own commands, each given an explicit cache directory, so they only touch their own cache
internals. Everything else is reported by size and never deleted.

**Run the script. Don't reimplement it with ad-hoc `rm` or tool commands.** Four separated
reviews of broader versions (chittymarket#254) each found ways an improvised or broader
cleaner deletes data that isn't regenerable.

## Usage

| Command | Effect |
|---|---|
| `bash scripts/cleanup.sh` | **Dry run (default).** `PLAN`, `SKIP` and `REPORT` lines; deletes nothing |
| `bash scripts/cleanup.sh --apply` | `npm cache clean --force --cache D` and `pip --cache-dir D cache purge` |
| `bash scripts/cleanup.sh --apply --uv` | Also `uv cache clean --cache-dir D`. **Only on explicit request**: environments installed with `link-mode=symlink` break |

Always show the dry run's output before running `--apply`.

## What the script guarantees
- **Home** is computed inside the script. If it's empty or `/`, the script refuses (exit 3).
- **Exact default directories only:** `~/.npm/_cacache`, `~/.cache/pip` or `~/Library/Caches/pip`, and `~/.cache/uv` or `~/Library/Caches/uv`. The comparison is case-insensitive on macOS. A tool resolving somewhere else (an env var or project config) is refused.
- **Symlinks:** a symlinked target is refused, and parent symlinks are resolved first.
- **Repos:** anything inside, or containing at any depth, a git worktree or bare repo is refused. So is any target the scan couldn't fully read. The scan is a single `find` with no temp files or here-docs, so it can't fail open on a full disk. If home is itself a repo, every target is skipped.
- **uv** is skipped without `--uv`, and also when `UV_LINK_MODE` or a `uv.toml` sets `link-mode = "symlink"`.
- **Report only, never deleted:** Homebrew, pnpm store, yarn, browser caches, Trash, `~/Library/Logs`. Clear those by hand only when the user confirms.
- **Exit codes:** 0 OK, 1 if any step failed (`FAIL`), 2 on bad arguments, 3 on refusal.

## Reporting
Relay the `SKIP`, `PLAN`/`DONE`, `REPORT` and `SUMMARY` lines and the before/after `df`. If the disk is
still full, say the rest lies elsewhere. Don't scan other users' homes or `/`, and don't use `sudo`.

## Other runtimes
The script ships in the Claude Code projection (`plugins/chittyos-core/skills/chitty-cleanup/scripts/cleanup.sh`).
Other runtimes run that file directly, or report that it's unavailable. They must not improvise a replacement.
