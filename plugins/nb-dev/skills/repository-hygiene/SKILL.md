---
name: repository-hygiene
description: Reconcile ChittyOS repository branches, worktrees, stale pull requests, duplicate changes and development tracking. Use for git hygiene and cleanup.
---

# Repository Hygiene
- Inventory branches, PRs, issues, worktrees and recent merges from authoritative repository sources.
- Detect duplicate implementations and cross-PR dependencies before creating new work.
- Preserve unmerged changes and user work; never delete branches, worktrees or files without verifying safety and authorization.
- Prefer consolidating into an existing PR. Document obsolete work with exact replacement commits.
- Keep canonical issue as durable checkpoint and separate planned from verified completion.
