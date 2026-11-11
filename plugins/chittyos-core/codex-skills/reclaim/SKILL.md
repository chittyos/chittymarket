---
name: reclaim
description: |
  Claim orphaned in-progress tasks left behind by dead Claude Code sessions. Lists unclaimed tasks from the orphan sweeper, lets you claim one, loads its context, and resumes. Triggers on "reclaim", "orphaned tasks", "dead session tasks", "/reclaim".
canon_uri: chittycanon://core/services/chittymarket#skills/reclaim
---

# /reclaim — Claim orphaned tasks from dead sessions

View and claim in-progress work left behind by sessions that died.
Triggers on: "reclaim", "orphaned tasks", "dead session tasks".

## How it works

Dead Claude Code sessions leave behind in-progress tasks (TodoWrite/TaskCreate items)
and uncommitted git changes. The orphan sweeper extracts these into
`~/.claude/orphaned-tasks/{session-id}.json` files. This skill lets you browse
and claim them so work isn't lost.

## Workflow

### Step 1: List unclaimed tasks

```bash
TASK_STORE="$HOME/projects/github.com/CHITTYOS/chittyagent-task/lib/task-store.sh"
CWD="$(pwd)"

# Count unclaimed tasks for current cwd
count=$(bash "$TASK_STORE" count "$CWD")

if [ "$count" -eq 0 ]; then
  # Also check all cwds
  count_all=$(bash "$TASK_STORE" count "/")
fi

# List them
bash "$TASK_STORE" list "$CWD"
```

Present the list to the user. Each entry shows:
- Session ID (truncated)
- Topic (first user message)
- Task count + uncommitted file count

### Step 2: User picks a task

Ask which orphaned session's tasks to claim. If only one, auto-select.

### Step 3: Claim it

```bash
SESSION_ID="<selected>"
MY_PID="$$"
MY_SESSION="<current session id>"
bash "$TASK_STORE" claim "$SESSION_ID" "$MY_PID" "$MY_SESSION"
```

### Step 4: Load context

Read the orphaned task file:
```bash
cat ~/.claude/orphaned-tasks/${SESSION_ID}.json
```

Present to the user:
- **Tasks**: each pending/in_progress task with its description
- **Git state**: branch, uncommitted files, unpushed commits
- **Topic**: what the dead session was working on

Create TaskCreate entries for each orphaned task so progress is tracked in the current session.

### Step 5: Resume

If there are uncommitted git changes, ask the user whether to:
- Continue working on them
- Stash them
- Discard them

Then proceed with the first in_progress task.

## Cleanup

Claimed tasks are automatically ignored by the ParallelSession hook.
Tasks older than 7 days are GC'd by:
```bash
bash "$TASK_STORE" gc 7
```
