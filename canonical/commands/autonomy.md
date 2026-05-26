---
name: autonomy
description: Drive a feature from one-line intent to merged PR via the ChittyOS canonical autonomy workflow. Requests a SOVEREIGNTY.cert, runs ecosystem discovery, plans/generates/implements with TDD-aware code, reviews via chittyagent-canon + code-reviewer + silent-failure-hunter, tidies, scaffolds CI/CD, ships, and persists memory.
canonical_uri: chittycanon://commands/autonomy
kind: command
plugin: chittyagent-autobot
runtimes:
  - claude-code
classification:
  - autonomy
  - orchestration
---

# /autonomy

Single entry point for the chittyagent-autobot.

## Usage

```
/autonomy <feature-request>
/autonomy --tdd <feature-request>
/autonomy --service <service-name> <description>
/autonomy --resume <feature-name>
```

## What happens

The autobot enters Phase 0 (Sovereignty Affirmation) immediately. If you do not have a bound ChittyID, it will refuse and ask you to run `can chitty authenticate-context`. Otherwise it requests a cert from ChittyCert, persists it, and proceeds through phases 1-10.

You will be prompted only at:
- Phase 3 (Plan) if there are `[NEEDS_CLARIFICATION]` markers
- Phase 6 (Review) if `chittyagent-canon` flags a canon violation that the autobot cannot self-correct
- Phase 8 (CI/CD) if a required GitHub Actions secret scope is missing (dashboard step)

All other phases run autonomously.

## State

`chittycontext/structured-autonomy/<feature>/state.json` survives session restart. Re-invoke with `--resume <feature>` to continue.

## See also

- `chittycanon://skills/chitty-autonomy` — parent orchestrator
- `chittycanon://core/agents/chittyagent-autobot` — the agent that runs the orchestrator
