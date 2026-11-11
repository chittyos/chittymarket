---
name: development-work-continuity
description: Reconcile and persist GitHub issues, branches, PRs, commits, reviews, checks, blockers and resumable engineering state. Use for handoffs, resuming work, duplicate PRs, project trackers, cross-agent development, or requests to continue prior implementation.
---

# Canonical Development Work Continuity

1. Find the existing GitHub issue and inspect default branch, open PRs, reviews, CI results and deployment references before opening work.
2. Reuse existing branches and PRs where possible. Resolve duplicate or conflicting proposals explicitly; never open a new PR solely to show progress.
3. Maintain one canonical issue containing acceptance criteria, source-of-truth links, exact commit SHA, validation command and observed result, current branch/PR state, outstanding review/security gates, blockers, next safe action.
4. Treat Linear and agent queues as linked projections, not parallel specifications. When delegating, dispatch the canonical issue link and scope/authorization limits.
5. Distinguish planned, committed, tested, reviewed, merged, deployed, and runtime-verified. Never infer later states from earlier ones.
6. At a real blocker or execution-window boundary, checkpoint enough information for another session/agent to resume without re-creating work. Do not imply an unattended agent is running.
