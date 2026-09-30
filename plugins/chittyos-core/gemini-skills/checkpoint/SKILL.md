---
name: checkpoint
description: Save or resume session state. Use /checkpoint to save progress at session end, or /checkpoint resume to reload prior session state at session start. Triggers on "checkpoint", "save progress", "session state", "where did I leave off", "resume", "pick up where I left off".
canon_uri: chittycanon://core/services/chittymarket#skills/checkpoint
---

# Session Checkpoint

Persist session state so the next session can resume without losing context.

## Usage

- `/checkpoint` or `/checkpoint save` — Save current session state
- `/checkpoint resume` — Load most recent checkpoint and resume work

## Save Mode (default)

When saving, create a checkpoint file at `~/.claude/checkpoints/{project-slug}-{date}.md` and update the latest pointer.

### Step 1: Gather State

Collect the following from the current session:

1. **Working directory**: `pwd`
2. **Git state**: `git branch --show-current`, `git status --short`, `git log --oneline -5`
3. **Task list**: Check TaskList for any open/in-progress tasks
4. **Modified files**: `git diff --name-only` (unstaged) and `git diff --cached --name-only` (staged)
5. **What was discussed**: Summarize the key topics, decisions, and work done this session

### Step 2: Write Checkpoint

Write the checkpoint file:

```markdown
# Session Checkpoint
**Date**: {YYYY-MM-DD HH:MM}
**Project**: {project name from directory}
**Branch**: {current git branch}
**Duration context**: {brief summary of session length/scope}

## Accomplished
- {bullet list of what was completed}

## In Progress
- {bullet list of unfinished work with specific file paths and line numbers}

## Blocked / Issues
- {any blockers, environment issues, or unresolved problems}

## Next Steps
1. {numbered list of what to do next, in priority order}
2. {include specific commands where helpful}

## Modified Files (uncommitted)
{list from git diff}

## Open Tasks
{from TaskList, if any}

## Resume Commands
```bash
# Run these to get back to where you were:
cd {working directory}
git status
{any other setup commands}
```
```

### Step 3: Update Latest Pointer

```bash
# Create symlink or copy to "latest" for easy resume
cp checkpoint-file ~/.claude/checkpoints/{project-slug}-latest.md
```

### Step 4: Confirm

Tell the user: "Checkpoint saved. Next session, run `/checkpoint resume` to pick up where you left off."

---

## Resume Mode

When the user says `/checkpoint resume` or "where did I leave off":

### Step 1: Find Latest Checkpoint

```bash
# Check for project-specific checkpoint first
PROJECT=$(basename "$(pwd)")
ls -t ~/.claude/checkpoints/${PROJECT}*-latest.md 2>/dev/null | head -1

# Fall back to most recent checkpoint
ls -t ~/.claude/checkpoints/*-latest.md 2>/dev/null | head -1
```

### Step 2: Load and Present

Read the checkpoint file and present a concise summary:

```
Resuming from checkpoint ({date}):

**Last session**: {1-line summary}
**Branch**: {branch} | **Uncommitted**: {count} files
**Next steps**:
1. {first priority}
2. {second priority}

Ready to continue?
```

### Step 3: Verify State

Run the resume commands from the checkpoint to verify the environment matches:
- Check we're on the right branch
- Check uncommitted files still exist
- Check for any new changes since the checkpoint
- Flag any discrepancies (e.g., "Note: 3 files have changed since the checkpoint")

### Step 4: Create Tasks

If the checkpoint has "Next Steps", create TaskCreate entries for each one so progress is tracked.

---

## Cleanup

Checkpoints older than 14 days can be cleaned up:

```bash
find ~/.claude/checkpoints -name "*.md" -not -name "*-latest.md" -mtime +14 -delete
```
