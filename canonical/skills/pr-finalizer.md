---
name: pr-finalizer
description: Finalize ChittyOS pull requests. Use for merge readiness, review resolution, branch protection, overlapping PRs, merge conflicts, and post-merge verification.
canon_uri: chittycanon://core/services/chittymarket#skills/pr-finalizer
kind: skill
plugin: nb-dev
---

# PR Finalizer
- Read canonical issue, all overlapping open PRs, base/head commits, reviews and status checks before modifying anything.
- Prioritize duplication and branch drift, then security findings, failed checks and conflicts.
- Apply smallest safe corrections to the existing branch, rerun targeted and repository checks, and document observed evidence.
- Merge only when required approvals and checks are satisfied; never bypass protected branch policies.
- Confirm actual merge SHA and base branch state. Close duplicate PRs only after verifying equivalence and recording rationale.
- Update canonical issue with exact evidence and next criterion; continue the development loop if requested.
