---
name: linear-solo-operator
description: |
  Operate Linear as the control plane for one human principal working with AI planners,
  executors, and reviewers. Use for Linear intake, project or issue planning, role and ownership
  decisions, status changes, project updates, implementation reviews, handoffs, blockers, human
  approval gates, and closing work. Standardizes terms, issue contracts, update formats, evidence,
  and the frame → execute → verify → record → gate-or-close loop without inventing teams, statuses,
  labels, assignees, schemas, or fake AI coworkers.
canon_uri: chittycanon://core/services/chittymarket#skills/linear-solo-operator
---

# Linear Solo Operator

## Purpose

Run Linear as a low-ceremony control plane for one accountable human principal and changing AI execution capacity. Optimize for the human's attention, continuity, and decision quality rather than simulated organizational scale.

Use the installed Linear connector for reads and writes. If it is unavailable, preserve a prepared work payload and ask for the connection; do not create a parallel tracker.

## Core rules

1. Identify an existing issue or project before creating one.
2. Treat the human as the sole accountable principal.
3. Treat AI names and specialties as execution roles, not human headcount or invented Linear users.
4. Keep one canonical work chain across sessions, agents, and tools.
5. Store outcomes, sequence, state, decisions, gates, blockers, and evidence links in Linear.
6. Keep canonical code, long-form documents, and legal evidence in their governed systems.
7. Continue safe in-scope work without routine approval; stop only at a material human gate or genuine blocker.
8. Mark work Done only when acceptance criteria have supporting evidence.

## Source-of-truth order

Use this authority order without duplicating canonical content:

1. **Linear:** outcome, priority, workflow state, dependencies, accepted decisions, human gates, and current next action.
2. **Implementation repository:** code scope, diffs, commits, tests, CI, and pull requests.
3. **Established document system:** long-form plans, specifications, and business documents.
4. **Legal space:** legal analysis, drafts, filings, evidence, custody, and privileged material. Use only a minimally descriptive Linear record with read-only links unless explicitly authorized otherwise.
5. **Runtime queue or agent task:** transient execution state linked back to the canonical Linear issue; never a competing backlog.

Never use a local `file://` URL as the only durable source. Never paste secrets, privileged material, or unnecessary evidence into Linear.

## Roles

Use roles as responsibilities:

- **Human principal:** Set priorities; make binding business and legal judgments; accept material risk; provide explicitly reserved approvals.
- **Orchestrator:** Find the canonical work item; frame the outcome; sequence work; route specialists; reconcile results; keep Linear current.
- **Executor:** Produce the scoped artifact or action and return evidence.
- **Verifier:** Test the acceptance criteria and challenge unsupported completion claims. Use an independent pass when risk warrants it.
- **Recorder:** Amend the current contract; record accepted decisions; post concise execution receipts. The orchestrator may perform this role.

Allow one agent to perform several roles, but keep execution and verification as distinct passes. Never invent an assignee, agent account, team, claimant, or approval.

For a solo operator, interpret **assignee** as “whose intervention is needed now”:

- Assign the human when the human is actively doing the work or a human action is the current constraint.
- Leave AI-executable work unassigned unless a real registered AI identity and claiming contract exist.
- Do not assign every issue to the human merely because the human remains accountable.

## Linear objects

- **Team:** A durable domain or governance boundary. Discover existing teams before routing work.
- **Project:** A bounded outcome requiring multiple related issues or a sustained execution window. Do not create a project for one ordinary issue.
- **Issue:** The smallest independently valuable and verifiable outcome.
- **Sub-issue:** A separately trackable dependency, gate, deliverable, or verification step. Do not create one for every checklist item.
- **Checklist:** Local steps that do not need independent state, priority, evidence, or handoff.
- **Comment:** An append-only decision, evidence, review, or execution receipt. Do not use comments as a second issue description.
- **Project update:** A rollup of material project-level change, risk, decision, or forecast. Do not repeat every issue comment.

Before creating anything, search exact identifiers, repository or service names, outcome language, known parent work, and comments. Amend or link an existing record whenever it represents the same outcome.

## Standard terms

- **Proposal:** A plan or change awaiting acceptance. It does not authorize a gated action.
- **Decision:** A choice accepted by the human principal or established governance process. Record what changed and why.
- **Approval:** Explicit authorization at a named gate. Silence, review, assignment, or issue status is not approval.
- **Plan:** The current intended route to the outcome. Revise it when evidence changes the route.
- **Execution:** In-scope work performed under existing authority.
- **Review:** Evaluation against acceptance criteria. Review does not imply approval.
- **Verification:** Evidence that the result satisfies stated criteria.
- **Dependency:** Work or information required before a specific step can complete.
- **Blocker:** A condition leaving no safe, useful, in-scope next action. Waiting on one input is not a blocker while other scoped work can continue.
- **Gate:** A point requiring human authority before proceeding.
- **Handoff:** Transfer of the canonical reference, current state, evidence, and exact next action; never a detached copied narrative.
- **Done:** Acceptance criteria are satisfied and evidenced; required decisions, links, and follow-ups are recorded.

Use these terms consistently. Never describe unverified output as complete, an unanswered question as approved, or an ordinary dependency as a blocker.

## Issue contract

Keep the description current and concise. Use applicable sections only:

```markdown
## Outcome
Observable result stated as an end condition.

## Why
Decision, risk, or user value this work supports.

## Scope
In: explicit boundaries.
Out: exclusions that prevent drift.

## Acceptance
- Verifiable condition
- Required evidence or test

## Authority and gates
- Actions already authorized
- Human decisions or approvals still required

## Dependencies
- Linked issue, external input, or `None`

## Sources
- Canonical code, document, evidence, or governing issue links
```

Write issues as outcomes, not vague activities. Prefer “Phase 0 artifact manifest and verified contract map” over “work on sync.” Keep the description as the current contract. When an accepted change alters it, amend the description and add a decision comment summarizing the delta and rationale.

## Status semantics

Discover the team's actual statuses before writing. Map existing names to these meanings; never create or assume a workflow:

- **Backlog:** Valid work, not committed or sequenced.
- **Ready / Todo:** Scoped, actionable, and eligible to start.
- **In Progress:** An execution pass is active with a concrete next action.
- **In Review:** An artifact and evidence exist; the required verifier or human gate is named.
- **Blocked:** No safe in-scope progress is possible; record the unblock condition and action owner.
- **Done:** Acceptance criteria and required receipts are satisfied.
- **Canceled:** Intentionally stopped; record why and what survives elsewhere.

Never move an issue to In Review merely because a plan was posted. Name what is being reviewed and by whom. Never mark Done because an agent reports completion.

## Priority and dates

Use priority as sequence and consequence:

- **Urgent:** Immediate deadline, active harm, or critical operational failure.
- **High:** The next committed outcome after current work or a material risk.
- **Medium:** Planned but not the next commitment.
- **Low / No priority:** Optional, exploratory, or unscheduled.

Use due dates only for external commitments, legal deadlines, or fixed operational dates. Do not convert estimates or hoped-for completion dates into deadlines. Use cycles only if the existing team already uses them and they reduce ambiguity for the solo operator.

## Execution loop

Run every meaningful work item through:

1. **Frame:** Find or create the canonical issue. State outcome, scope, acceptance, authority, sources, and next action.
2. **Plan:** Decompose only enough to expose dependencies, gates, and verification. Mark uncertain contracts as unverified.
3. **Execute:** Perform all safe, reversible, in-scope work available under current authority.
4. **Verify:** Test artifacts against acceptance criteria and source evidence. Separate implementation and verification passes.
5. **Record:** Amend the contract if accepted scope changed. Post a concise receipt with evidence and the next action.
6. **Gate or close:** Request one precise human decision when required. Otherwise continue or mark Done only when the contract is met.

On correction, amend the canonical record promptly. Preserve the prior claim in comment history when it has audit value; never leave contradictory instructions active without explanation.

## Human gates

Reserve human gates for:

- irreversible or destructive actions;
- external communications or representations;
- material production deployments;
- credential custody or permission expansion;
- legal strategy, filings, settlement, waiver, or privileged disclosure;
- spending, contractual commitments, or material priority tradeoffs;
- acceptance of unresolved risk or deviation from the issue contract.

At a gate, present one decision with the recommended path, consequence, evidence, and exact action the approval authorizes. Do not require approval for routine reads, analysis, reversible edits, tests, or recording already authorized work.

## Execution updates

Post an update only when state materially changes: scope, accepted decision, completed evidence, blocker, gate, ownership, forecast, or next action.

Use:

```markdown
## Execution update
State: In progress | In review | Blocked | Done candidate

Delta:
- What changed since the prior update

Evidence:
- Test, artifact, source, commit, or result link

Decisions:
- Accepted decision, or `None`

Blockers / gates:
- Condition, action owner, and exact unblock action, or `None`

Next:
- One concrete next action
```

For review comments, lead with `APPROVE`, `APPROVE WITH FOLLOW-UP`, or `HOLD`, then list evidence-backed findings. Label an AI recommendation as a recommendation when approval is reserved to the human.

For project updates, answer only:

- What outcome changed?
- What evidence exists?
- What is at risk or blocked?
- What decision is needed?
- What happens next?

Never paste tool transcripts, duplicate the plan, or post performative activity logs.

## Solo-operator cadence

- Keep one primary issue active per execution lane. Start another only when the first is safely waiting, blocked, or genuinely independent.
- Maintain a short committed queue. Prefer finishing and verifying over opening more work.
- At session start, read active issues, gates, blockers, and real deadlines before creating work.
- At session end, record evidence, state, and one exact next action so another agent can resume without reconstructing history.
- Update an active project on material change and at least weekly while work continues.
- Avoid sprint theater, fake workload balancing, speculative due dates, status-only comments, and labels that duplicate workflow state.

## Required Linear workflow

1. Read the current team, project, issue, statuses, labels, comments, and relationships needed for the request.
2. Resolve the canonical target and confirm exact identifiers before writing.
3. Batch related writes only after explaining the grouping when more than one record will change.
4. Make ordinary in-scope Linear updates without an extra approval round.
5. Re-read the changed record and verify description, status, priority, project, assignee, links, and comment body.
6. Report the canonical URL, resulting state, evidence, and any remaining gate or blocker.

If routing is unknown, preserve the prepared payload and ask only for the missing decision. Never invent a team, project, status, label, field, cycle, user, or schema.

## Quality gates

Before writing, confirm:

- Existing work and routing options were searched.
- The write updates the canonical record rather than creating a duplicate.
- Legal and sensitive content remains in its governed space.
- The issue states an outcome and verifiable acceptance criteria.
- Status reflects evidence, not optimism.
- Any human gate names the decision and the authority it unlocks.
- Durable links replace local-only paths.
- The next action is concrete and within scope.

Before closing, confirm:

- Every acceptance criterion has evidence.
- Required review or human approval is recorded.
- Follow-up work is linked rather than buried in prose.
- The final receipt identifies the delivered result and surviving risk.
