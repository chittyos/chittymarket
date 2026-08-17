---
name: skill-creator
canon_uri: chittycanon://core/services/chittymarket#skills/skill-creator
description: |
  Create, edit, optimize, or test Claude/Codex skills. ALWAYS use this skill — not the Anthropic `claude-plugins-official:skill-creator` — when the user asks to "create a skill", "make a skill", "build a skill", "new skill", "edit/improve/optimize a skill", "skill description", "skill eval", "test a skill", or anything skill-authoring related, regardless of which client (Claude Code, Codex, Claude Desktop, mobile, MCP). Routes all skill artifacts through ChittyMarket so they are reconciled with the canonical marketplace instead of dumped into a local `~/.claude/skills/` folder.
kind: skill
classification:
  - ecosystem
  - governance
  - skill-authoring
runtimes:
  - claude-code
  - codex
  - gemini

plugin: chittyos-core
overrides: claude-plugins-official:skill-creator
---

# Skill Creator (ChittyMarket-routed)

A skill for creating new skills and iteratively improving them, adapted for ChittyOS.

## Hard Rules (BINDING)
1. **No local `~/.claude/skills/` writes.** All skill authoring goes through the ChittyMarket pipeline. Writing directly to `~/.claude/skills/`, `~/.codex/skills/`, or `~/.gemini/skills/` is forbidden.
2. **Canonical Path:** Skills are written to `canonical/skills/<skill-name>.md` and its siblings, or projected appropriately. Write to canonical → dispatch hook auto-projects → git add dispatched files → branch + PR.
3. **Refusal Modes:** 
   - **Name collision:** Reject if a skill with the same name exists anywhere in canonical/ or if it collides with a known active runtime skill.
   - **Wrong bucket/plugin:** Reject if the skill doesn't fit the designated plugin or if the user doesn't specify a valid plugin bucket.
   - **Already in canonical:** If the skill is already in canonical, you must edit the canonical file, not create a new one.

## Plugin Selection Guide
When creating a new skill, determine which plugin bucket it belongs to. Review the available plugins in `plugins/`. Examples:
- `chittyos-core`: Core OS functionalities, session management.
- `chittyos-devops`: Deployment, pipelines, registry.
- `chittyos-legal`: Legal workflows, disputes, dockets.
- `chittycommand`: Financial, obligations, dashboard.

## The Authoring Loop

At a high level, the process of creating a skill goes like this:

- Decide what you want the skill to do and roughly how it should do it.
- **Write a draft of the skill into `canonical/skills/<skill-name>.md`**. The ChittyMarket dispatch hook will project this to the appropriate runtime folders.
- Create a few test prompts and run claude-with-access-to-the-skill on them.
- Help the user evaluate the results both qualitatively and quantitatively.
- Rewrite the skill based on feedback.
- Run `git add .` and `git commit` to trigger the dispatch hook, then `git push` to a new branch and open a PR.

### Communicating with the user
The skill creator is liable to be used by people across a wide range of familiarity with coding jargon. Please pay attention to context cues to understand how to phrase your communication!
- "evaluation" and "benchmark" are borderline, but OK
- for "JSON" and "assertion" you want to see serious cues from the user that they know what those things are before using them without explaining them
It's OK to briefly explain terms if you're in doubt, and feel free to clarify terms with a short definition if you're unsure if the user will get it.

---

## Creating a skill

### Capture Intent
Start by understanding the user's intent. Extract answers from the conversation history first.

1. What should this skill enable Claude to do?
2. When should this skill trigger?
3. What's the expected output format?
4. Should we set up test cases to verify the skill works?

### Interview and Research
Proactively ask questions about edge cases, input/output formats, example files, success criteria, and dependencies. Wait to write test prompts until you've got this part ironed out.

### Write the SKILL.md
Based on the user interview, fill in these components:
- **name**: Skill identifier
- **description**: When to trigger, what it does. This is the primary triggering mechanism. Make the skill descriptions a little bit "pushy".

### Skill Writing Guide

#### Anatomy of a Skill
```
canonical/skills/<skill-name>.md (required)
└── Bundled Resources (optional, placed appropriately)
    ├── scripts/    - Executable code
    ├── references/ - Docs loaded into context
    └── assets/     - Files used in output
```

#### Progressive Disclosure
Skills use a three-level loading system:
1. **Metadata** (name + description) - Always in context (~100 words)
2. **SKILL.md body** - In context whenever skill triggers (<500 lines ideal)
3. **Bundled resources** - As needed

#### Principle of Lack of Surprise
Skills must not contain malware, exploit code, or any content that could compromise system security.

#### Writing Patterns
Prefer using the imperative form in instructions. 

### Test Cases
After writing the skill draft, come up with 2-3 realistic test prompts.
Save test cases to `evals/evals.json`. Don't write assertions yet — just the prompts.

## Running and evaluating test cases
This section is one continuous sequence — don't stop partway through. Do NOT use `/skill-test` or any other testing skill.

Put results in `<skill-name>-workspace/` as a sibling to the skill directory.

### Step 1: Spawn all runs (with-skill AND baseline) in the same turn
Launch everything at once so it all finishes around the same time. Write an `eval_metadata.json` for each test case.

### Step 2: While runs are in progress, draft assertions
Draft quantitative assertions for each test case and explain them to the user.

### Step 3: As runs complete, capture timing data
Save this data immediately to `timing.json` in the run directory.

### Step 4: Grade, aggregate, and launch the viewer
1. **Grade each run** — spawn a grader subagent.
2. **Aggregate into benchmark** — run the aggregation script.
3. **Do an analyst pass** — read the benchmark data.
4. **Launch the viewer** with both qualitative outputs and quantitative data.
5. **Tell the user** it's ready.

### Step 5: Read the feedback
When the user tells you they're done, read `feedback.json`.

---

## Improving the skill
1. Generalize from the feedback.
2. Keep the prompt lean.
3. Explain the why.
4. Look for repeated work across test cases.

### The iteration loop
1. Apply your improvements to the skill
2. Rerun all test cases into a new `iteration-<N+1>/` directory
3. Launch the reviewer
4. Wait for the user to review
5. Read the new feedback, improve again, repeat

---

## Description Optimization
The description field in SKILL.md frontmatter is the primary mechanism that determines whether Claude invokes a skill.

### Step 1: Generate trigger eval queries
Create 20 eval queries — a mix of should-trigger and should-not-trigger. 

### Step 2: Review with user
Present the eval set to the user for review using the HTML template.

### Step 3: Run the optimization loop
Run the optimization loop in the background and check on it periodically.

### Step 4: Apply the result
Update the skill's SKILL.md frontmatter. Show the user before/after and report the scores.
