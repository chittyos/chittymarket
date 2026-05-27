---
name: goal-creator
description: Drive ANY stated goal, plan, project, build, or "let's design X" intent through the ChittyOS discover→elicit→architect→adversarial→SoT→build→persist→handoff pipeline using the three-block format `[what to achieve], keep {conditions}, not met until [completion criteria]`. Use aggressively — trigger whenever the user types `/goal-creator`, says "let's goal this", "run a goal pass on", "take this through the pipeline", "design X for me", "plan out X", "scope out X", "architect X", "stand up X", "spec out X", or otherwise expresses planning/architecture/build intent against ChittyOS substrate. Pairs WITH the Claude Code built-in `/goal` (the built-in enforces the stop-hook; this skill runs the pipeline).
canon_uri: chittycanon://core/services/chittymarket#skills/goal-creator
aliases:
- goal-pipeline
---

# Goal Creator — Three-Block Pipeline

Canonical entry. Full projection at `plugins/chittyos-core/skills/goal-creator/SKILL.md`.

## Three blocks

- **goal:** `$ARGUMENTS` — what to achieve. Drives the 9-phase pipeline.
- **conditions:** style + schema discipline + SOT hierarchy + two-space discipline + interaction limits + sequencing + output discipline + anti-patterns.
- **not met until:** explicit checkable gates the model is allowed to stop on; build-only gates if operator typed `go`; blockers that prevent stopping.

## Pipeline phases

1. Restate (+analogy) — ≤3 questions if vague
2. Discover (registry, chittyops, Notion, Neon) — composition vs greenfield
3. Elicit (ask_user_input — locked decisions registry)
4. Architect v0.1 (wire diagram, Pentad, components, data model, policy, cost, surfaces)
5. Adversarial review (Privacy/Legal · Ops/UX · Reliability/Security) — loop until 0 critical, 0 high
6. SoT v0.5 (15-section consolidated doc at `/mnt/user-data/outputs/<slug>-v0.5.md`)
7. Build (only on operator typing `go`)
8. Persist (chittyops.goal_artifacts row or schema proposal; Notion mirror)
9. Handoff (single summary, stop)

## Relationship to Claude Code's built-in `/goal`

`/goal <condition>` (Claude Code built-in, since v2.1.139) installs a
session-scoped Stop hook that blocks completion until the condition holds.
This `goal-creator` skill is the **pipeline runner** that the model executes
to satisfy the hook condition. They compose:
- Built-in `/goal` = enforces the stop-gate
- `goal-creator` = runs the structured work toward the gate

Do NOT trigger this skill on a bare `/goal <text>` invocation — that is the
built-in's job. Trigger on planning intent.
