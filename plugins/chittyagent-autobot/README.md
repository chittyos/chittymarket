# chittyagent-autobot

ChittyOS-canonical autonomous PR-driver. Successor to `structured-autonomy-{plan,generate,implement}`.

## Quick start

```
/autonomy "build a Drive→pipeline watcher for case evidence"
```

The autobot will:
1. Request a `SOVEREIGNTY.cert` from ChittyCert (refuses to act without it).
2. Run ecosystem discovery — registry + Pentad reads of relevant services.
3. Brainstorm with you to refine intent.
4. Plan into commits with `[NEEDS_CLARIFICATION]` markers that pause for your input.
5. Generate copy-paste-ready implementation with canonical-URI citations.
6. Implement commit-by-commit, with TDD if `--tdd` was set.
7. Run `chittyagent-canon` + `code-reviewer` + `silent-failure-hunter` review.
8. Tidy: format, lint, branch cleanup, wrangler-audit if applicable.
9. Scaffold CI/CD if missing; audit your GitHub-Actions CF token scopes.
10. Ship: push, PR, ChittyRegistry update for new services, Notion sync, auto-merge if allowed.
11. Persist memory + finalize ChittyChronicle audit chain.

## Why successor not extension

The original `structured-autonomy` trio had:
- Tool-syntax debt (`#tool:`, `#context7`)
- Hardcoded Windows / `ResizeMe` references
- No ChittyOS ecosystem awareness
- No state machine (three skills that don't compose)
- No product-level enforcement (only Claude Code hookify, which doesn't fire from systemd / non-CC contexts)

Autobot replaces those with Pentad-aware product gates, ChittyCert-issued sovereignty affirmation, ChittyChronicle audit, and a resumable state machine.

## Pentad

For services scaffolded by Autobot, all five docs are required before Ship:

| Doc | Purpose |
|---|---|
| `CHARTER.md` | API contract, scope, dependencies |
| `CHITTY.md` | Architecture + ecosystem position |
| `CLAUDE.md` | Dev patterns, commands |
| `SECURITY.md` | Threat model, secrets, disclosure flow |
| `AGENTS.md` | Capabilities, invocation patterns |

## Sovereignty Ontology

See `templates/sovereignty-ontology.md` (`chittycanon://docs/sovereignty-ontology-v1`).

Two-axis model:
- **Type**: `earned` (track record) and/or `declared` (user-affirmed scope)
- **Level**: sliding scale `operational → partial → provisional → process_governed → full` with numeric 0-100

At `full` level, conflict resolution is contract-governed; user overrides require invoking the agreed conflict-resolution process, not unilateral intervention.

## Layout

```
chittyagent-autobot/
├── plugin.json
├── manifest.json
├── README.md
├── agents/
│   └── chittyagent-autobot.md
├── commands/
│   └── autonomy.md
├── skills/
│   ├── chitty-autonomy/SKILL.md          (parent)
│   ├── chitty-autonomy-affirm/SKILL.md   (P0)
│   ├── chitty-autonomy-discover/SKILL.md (P1)
│   ├── chitty-autonomy-plan/SKILL.md     (P3)
│   ├── chitty-autonomy-generate/SKILL.md (P4)
│   ├── chitty-autonomy-implement/SKILL.md(P5)
│   ├── chitty-autonomy-tidy/SKILL.md     (P7)
│   ├── chitty-autonomy-cicd/SKILL.md     (P8)
│   └── chitty-autonomy-ship/SKILL.md     (P9)
└── templates/
    └── sovereignty-ontology.md
```
