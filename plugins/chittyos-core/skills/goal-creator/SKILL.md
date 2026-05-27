---
name: goal-creator
description: Drive ANY stated goal, plan, project, build, or "let's design X" intent through the ChittyOS discover→elicit→architect→adversarial→SoT→build→persist→handoff pipeline using the three-block format `[what to achieve], keep {conditions}, not met until [completion criteria]`. Use aggressively — trigger whenever the user types `/goal-creator`, says "let's goal this", "run a goal pass on", "take this through the pipeline", "design X for me", "plan out X", "let's build X end to end", "scope out X", "architect X", "stand up X", "spec out X", "what would it take to ship X", or otherwise expresses planning/architecture/build intent against ChittyOS substrate — even when they don't say "goal" explicitly. Preferred over ad-hoc planning chat for anything multi-component, multi-decision, or that touches ChittyOps/Notion/Neon/Cloudflare. NOTE: `/goal` itself is a Claude Code built-in (sets a session-scoped Stop hook) — do NOT trigger this skill on bare `/goal <condition>`; that is the built-in's job. This skill pairs WITH `/goal` (the built-in enforces the stop-gate, this skill runs the pipeline).
canon_uri: chittycanon://core/services/chittymarket#skills/goal-creator
aliases: [goal-pipeline]
---

# /goal — three-block format

Maps to: `/goal [what to achieve], keep {conditions}, not met until [completion criteria]`

---

## goal: ($ARGUMENTS plus the workflow)

Drive `$ARGUMENTS` through the ChittyOS discovery → design → converge → build pipeline.

1. **Restate** — one paragraph + mental-model analogy. Vague? Ask ≤3 questions, stop.
2. **Discover** — search `registry.chitty.cc`, `~/.claude/skills/`, `chittyops/routines/`, Neon `chittyops` schema, Notion trackers (memory). Output discovery table; state composition (>70% built) vs greenfield.
3. **Elicit** — lock decisions via `ask_user_input_v0` (1–3/turn): scope · surfaces · accounts · authority · cost cap · pilot vs launch · sequencing. Build a Locked Decisions Registry.
4. **Architect v0.1** — wire diagram (ASCII) · Pentad mapping (P+ E N T A) if pipeline · components (existing vs new + hours) · data model (JSON) · policy registry · cost/tier model if AI · surfaces (MCP·Notion·CLI·UI).
5. **Adversarial review** — three personas (Privacy/Legal · Ops/UX · Reliability/Security). Severities crit/high/med/low; fixes tagged `F-L#`/`F-O#`/`F-R#`. Fold crit+high into next version. **Loop until 0 critical, 0 high.**
6. **SoT v0.5** — consolidate to `<slug>-v0.5.md`: goal+analogy · locked decisions · architecture · components · data model · policy registry · cost model · sibling services · surfaces · pilot plan w/ measurable exit · week-by-week build plan · ops cadence · convergence record · open items · build artifact list.
7. **Build (on `go`)** — generate artifacts at chittyops paths (routines/services/studio-flows/mcp-tools/notion-views/seeds/migrations/cli/agent-ui/docs). Bundle to `/mnt/user-data/outputs/<slug>-build/` + `INDEX.md` + tarball + claude-code bootstrap prompt.
8. **Persist** — propose row in `chittyops.goal_artifacts` (slug · statement · sot_path · version · status). Propose schema if table absent; never auto-create. Mirror to Notion Projects `83e8d8f7…` (Business) or Legalink tracker (Legal); set Parent Project if nested.
9. **Handoff** — emit final summary: paths · locked-decisions count · adversarial-passes count (converged at M) · hours · Notion mirror link · next step. Stop.

---

## conditions: (keep these throughout)

**Style** — clinical · brief · artifact-first · chat <150 words · label claims Given/Derived/Unknown · dates "MMM DD, YYYY" · times "h:mm a" · no LaTeX.

**Schema discipline** — no new Neon tables or Notion databases without operator approval. Propose schemas; never auto-create.

**SOT hierarchy** — Cloudflare > state registries > executed docs > ChittyDNA > Notion (mirror only) > AI (downstream). No cross-pollination of AI summaries between systems without upstream verification.

**Two-Space discipline** — Business and Legalink work product never mixed. Privileged content stays in Legalink. Cross-space relations read-only (Legal → Business).

**Interaction** — prefer `ask_user_input_v0` (tappable) over freetext. Max 3 questions/turn. Stop after asking; wait for response.

**Sequencing** — Restate → Discover → Elicit → Architect → Review → SoT → Build → Persist → Handoff. Never skip backward.

**Output discipline** — produce artifacts, don't describe them. Update existing version files; don't sprawl.

**Anti-patterns** — greenfield before substrate check · locking decisions in your head · single-pass adversarial review · prose when deliverable is artifact · finished code before SoT · auto-creating schemas · mixing Business/Legalink.

---

## not met until: (completion criteria — Claude is allowed to stop ONLY when all true)

**Always required:**

- [ ] Goal restated in operator-confirmed form (Phase 1 acknowledged)
- [ ] Discovery table produced, composition vs greenfield stated
- [ ] Locked Decisions Registry contains ≥1 decision and operator confirmed no further decisions block architecture
- [ ] File `<slug>-v0.5.md` exists at `/mnt/user-data/outputs/`
- [ ] v0.5 contains all 15 required sections (Goal · Decisions · Architecture · Components · Data Model · Policy · Cost · Siblings · Surfaces · Pilot · Build Plan · Ops · Convergence Record · Open Items · Build Artifact List)
- [ ] Convergence Record shows ≥2 adversarial passes with the final pass at **0 critical, 0 high**
- [ ] Open Items section enumerates every unconfirmed dependency or deferred decision
- [ ] Pilot plan contains measurable exit criteria (each one numeric or boolean-checkable)
- [ ] Persistence proposed: `chittyops.goal_artifacts` row written OR schema proposed-and-pending if table absent
- [ ] Notion Projects mirror row created (Business or Legalink per scope) with Parent Project set if nested
- [ ] Handoff summary emitted in final chat with paths · decisions count · passes count · hours · mirror link

**Required only if operator typed `go` for build:**

- [ ] Bundle directory `/mnt/user-data/outputs/<slug>-build/` exists with ≥1 artifact per build-artifact-list row
- [ ] `INDEX.md` lists every artifact with path · deploy week · adversarial-fix traceability (F-L# / F-O# / F-R#)
- [ ] Tarball `<slug>-build.tar.gz` written and presented
- [ ] Claude-code bootstrap prompt written and presented alongside tarball

**Blocking — never stop while any are true:**

- ⛔ Adversarial review last pass had ≥1 critical or ≥1 high finding
- ⛔ Any privileged content has been written to a Business-scope artifact
- ⛔ Any new Neon table or Notion database was created without operator approval
- ⛔ Decisions remain unlocked that affect architecture
- ⛔ Operator has asked a clarifying question that hasn't been answered

If any blocker is true: loop the relevant phase, do not advance, do not summarize as complete.
