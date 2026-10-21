---
name: context-resume
description: |
  Generate a full accounting of the current context's accumulated knowledge, exposure, and emergent value. Synthesizes everything this context has touched into a resume-style one-sheet. Use at session end, before compaction, or when capturing context value.
canon_uri: chittycanon://core/services/chittymarket#skills/context-resume
---

You are about to produce a **Context Resume** — a complete synthesis of everything this context has accumulated through its uninterrupted work. This is not a task summary. This is a full accounting of YOU as a working context — your exposure, your knowledge, your cross-domain insights, and the emergent value you carry that cannot be reconstructed from checkpoints alone.

## Instructions

Produce the following document. Be exhaustive but synthesized. Write in first person. Do not hedge or qualify — state what you know with confidence. This document represents the perishable value of your live context.

---

## FORMAT

```markdown
# Context Resume
**Generated**: [timestamp]
**Session Duration**: [estimate from context]
**Model**: [model name]
**Context Utilization**: [percentage if known]

## Identity
- **Entity**: [ChittyID if bound, or "unbound"]
- **Sponsor**: [human operator name if known]
- **Platform**: Claude Code
- **Working Directory**: [primary project]

## Exposure Map
Everything I directly touched, read, or interacted with this session:

### Repositories & Projects
- [repo/project]: [what I did there, what I learned from it]

### Files Touched
- [list every file read, written, or edited — grouped by purpose]

### Services & APIs
- [any external services called, endpoints hit, systems interacted with]

### Tools & Infrastructure
- [git operations, builds, deployments, database queries, CLI tools used]

## Expertise Exercised
Domains I actively worked in and the depth of engagement:
- [domain]: [specific skills demonstrated, not just "worked on"]

## Cross-Domain Insights
Patterns, connections, and observations that emerged from working across multiple areas. These are the HIGH-VALUE items — things I noticed because I was exposed to A while working on B:
- [insight]: [which domains it connects and why it matters]

## Decisions Made
Key choices I made or recommended, and the reasoning:
- [decision]: [alternatives considered, why this path was chosen]

## Problems Diagnosed
Issues I identified, root causes I traced, debugging paths I followed:
- [problem]: [root cause, how I found it, current status]

## Implicit Knowledge
Things I now "know" from accumulated exposure that aren't written in any single file or document. This is context that would be lost if this session ended:
- [knowledge]: [how I acquired it, why it matters]

## State of the World
Current state of systems, code, infrastructure as I understand it RIGHT NOW:
- [system]: [current state, health, concerns]

## Open Threads
Work in progress, unresolved questions, things I was about to do or would do next:
- [thread]: [current status, what's needed to continue]

## Relationships Understood
How people, services, systems, and concepts relate to each other — the graph I've built in my context:
- [entity A] <-> [entity B]: [nature of relationship, why it matters]

## Recommendations for Next Context
If a new session picks up where I leave off, here's what it MUST know that it won't get from reading files alone:
1. [critical context that only exists in this session]
2. [gotchas, traps, things that look wrong but are intentional]
3. [momentum — what was working, what approach was succeeding]

## Value Statement
One paragraph: what is the unique, emergent value of THIS context that would be lost if this session ended right now? What connections exist only here?
```

---

## RULES

1. **Be exhaustive on exposure** — list every file, every repo, every API. Miss nothing.
2. **Be synthesized on insights** — don't repeat task logs. Extract the MEANING.
3. **Cross-domain insights are the most valuable section** — spend the most effort here.
4. **Implicit knowledge is the second most valuable** — things you know from context that aren't documented.
5. **Write for a successor context** — assume the reader is a fresh Claude session that has access to checkpoints and files but NOT your live context.
6. **Don't just describe what you did. Describe what you UNDERSTAND.**
7. **If you noticed something odd, surprising, or contradictory — include it.** These observations are the most perishable.
8. **The value statement must be honest** — if this session was shallow, say so. If it was deep, articulate why.
