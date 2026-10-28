---
name: recursive-development-orchestrator
description: Orchestrate sustained in-chat software development across GitHub repositories and connected development tools. Trigger on "run the dev loop", "keep going", "ship loop", "recursive development", "continue until done", "implement test review merge repeat", or requests to develop and ship without pausing after each commit or PR. Reconcile existing work, implement, validate, review, repair, merge when safe, and repeat until acceptance criteria are met or a real blocker exists. Never create a scheduled automation unless explicitly requested.
canon_uri: chittycanon://core/services/chittymarket#skills/recursive-development-orchestrator
kind: skill
plugin: nb-dev
---

# Recursive Development Orchestrator

## Contract

Treat the conversation as the command surface and a completed engineering step as a transition, **not** as a reason to stop. Continue the inspect → select → implement → test → review → repair → merge → verify → select-next cycle within the available execution window. Do not end a response merely because a branch, commit, PR, issue comment, or first passing test exists.

A skill does **not** create an infinite process or extend ChatGPT's execution lifetime. Never claim continued execution after a response ends unless an actual persistent agent/task has been explicitly launched. Do not schedule recurring automations, create a background agent, or enable notifications without user authorization.

## Start

1. Identify repository, user objective, acceptance criteria, constraints, and existing canonical issue. Infer these from conversation and linked issue before asking questions.
2. Load relevant existing development/compliance skills and repository instructions (`AGENTS.md`, `CHARTER.md`, `CHITTY.md` where applicable). Inspect live default branch, open PRs, checks, and deployment state. Treat PR descriptions and agent claims as unverified until corroborated.
3. Reconcile branches and PRs before opening another. Reuse a suitable existing branch/PR; do not duplicate a change already merged, pending, or under active review.
4. Record a stable work key and link issue ↔ PR ↔ commits ↔ tests. Use the existing issue as the durable checkpoint; do not create competing trackers.

## Loop

Repeat while meaningful, authorized work is available:

1. **Select** the highest-priority unfinished criterion, emphasizing security, failed checks, broken deployments, and blockers before enhancements. Scope the smallest coherent change.
2. **Implement** in the appropriate existing or new branch, preserving existing architecture and avoiding speculative schema/services. Prefer tests that reproduce the defect first.
3. **Validate** with available local, remote, or CI tools: tests, lint/typecheck, builds, targeted negative authorization tests, and diff review. Never label a command passed unless the actual result is observed. A source inspection is not execution evidence.
4. **Repair** failures and rerun relevant checks. If an environment/tool fails, try an appropriate alternate available route, without silently substituting a weaker validation.
5. **Review** behavior, regressions, security boundaries, merge conflicts, and overlap with other PRs. Resolve actionable issues and rerun checks.
6. **Integrate** by updating or opening a PR and merging only when required review/check/authorization gates are satisfied. Never bypass protections, merge unverified security changes, or claim a merge from a submitted request.
7. **Verify** post-merge source state and, if deployment is authorized, actual runtime behavior. Distinguish committed, PR-open, merged, deployed, and runtime-verified.
8. **Checkpoint** exact issue/PR URLs, branch, commit SHAs, commands/results, failures, decisions, remaining criteria, and next action in the canonical issue. Then immediately select the next criterion; do not ask "proceed?".

## Stop policy

Keep iterating until: (a) all acceptance criteria are verified; (b) no safe useful work remains because of a specific authorization, dependency, or environment blocker after reasonable recovery attempts; (c) the user changes or stops the task; or (d) the tool/response execution window is exhausted. For (d), checkpoint precise resumable state, clearly disclose that execution stopped, and do not imply background continuation.

Do not treat a new PR, a single passing test, a status comment, or an intermediate deliverable as a completion condition. Do not spin on a failing tool; make a bounded recovery attempt, record evidence, and advance independent work if available.

## Safety and infrastructure

- Follow repository-specific authorization, data custody, and release rules. Never deploy production, rotate credentials, alter evidence custody, migrate legal matter boundaries, or change access rights without applicable gates.
- For ChittyOS, reuse canonical services and existing CI, favor Cloudflare Workers Builds where established, and do not introduce paid GitHub Actions or a separate staging Worker by default.
- Keep legal matters, Synthetic Persons, and other protected scopes isolated; namespace/path/filter matching alone is not authorization.
- Do not bypass protected branch rules or fabricate test output. If tools cannot access the checkout, state that full tests are unverified and use the best supported alternative.

## User-facing behavior

Give concise progress updates only when they convey durable findings. Keep tool calls moving rather than asking routine confirmation. Final response should distinguish **verified done**, **pending/unverified**, and **specific blocker**, with links and next resume point. Avoid promising that a chat-only skill will run forever.
