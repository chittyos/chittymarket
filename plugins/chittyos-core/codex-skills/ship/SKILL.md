---
name: ship
description: |
  Development wrap-up lifecycle — preflight, brainstorm, checkpoint, cleanup, branch
  Triggers on "/ship", "wrap up", "finish up", "ship it", "done for now", "close this out".
canon_uri: chittycanon://core/services/chittymarket#skills/ship
---

# /ship — Development Wrap-Up

Automates the full end-of-cycle wrap-up: type-check, verify PRs, deploy health, brainstorm next steps, checkpoint context, clean up, and start fresh.

## MCP Server

This skill orchestrates tools from the `chittyagent-ship` MCP server at `ship.chitty.cc/mcp`.

## Workflow

Execute these steps in order, with confirmation gates at destructive stages:

### Step 1: Gather Local Context

Before calling any MCP tools, gather local info:

```bash
# Current branch
BRANCH=$(git rev-parse --abbrev-ref HEAD)
# Last commit
LAST_COMMIT=$(git log -1 --oneline)
# Open PRs for this branch
OPEN_PRS=$(gh pr list --head "$BRANCH" --json title,url,state --jq '.[].title' 2>/dev/null || echo "none")
```

### Step 2: Start Session

Call `ship_start` with:
- `project_path`: Current working directory (absolute path)
- `project_name`: Repo name from `git remote get-url origin`
- `branch`: Current branch
- `last_commit`: Last commit message
- `open_prs`: Open PRs for this branch

### Step 3: Run Preflight Checks (Client-Side)

Run these checks locally, then report results to `ship_preflight`:

```bash
# type_check: tsc --noEmit
npx tsc --noEmit 2>&1 && echo "PASS" || echo "FAIL"

# uncommitted: git status
[ -z "$(git status --porcelain)" ] && echo "PASS" || echo "FAIL"

# pr_status: Check if PRs are merged
gh pr list --head "$BRANCH" --state open --json number --jq length

# doc_sync: Compare tool/endpoint counts in docs vs source (project-specific)
```

Call `ship_preflight` with:
- `session_id`: From step 2
- `client_results`: Array of check results from above

Show results as a checklist to the user. If any checks FAIL, ask whether to proceed or fix first.

### Step 4: Brainstorm Next Steps

Gather context locally:

```bash
# Commits since diverging from main
git log main..HEAD --oneline

# TODOs in modified files
git diff main --name-only | xargs grep -n 'TODO\|FIXME\|HACK' 2>/dev/null

# Open issues
gh issue list --limit 10 --json title,number --jq '.[] | "#\(.number) \(.title)"'
```

Call `ship_brainstorm` with gathered context. Show the prioritized list to the user.

### Step 5: Checkpoint

Ask the user: **"Ready to checkpoint and clean up?"**

If yes, call `ship_checkpoint` with:
- `session_id`: From step 2
- `context_summary`: Brief summary of the session's accomplishments
- `decisions`: Key decisions made
- `modified_files`: List of modified files

Show Notion sync status.

### Step 6: Cleanup

Ask the user for explicit confirmation before proceeding.

Call `ship_cleanup` with:
- `session_id`: From step 2
- `confirmed`: true (only after user approval)
- `keep_memory`: true (default)

Execute the client-side cleanup actions from the response.

### Step 7: Branch Operations

Ask the user: **"Delete branch `{name}` and create new?"**
Show suggested branch names from brainstorm results.

Call `ship_branch` with:
- `session_id`: From step 2
- `confirmed`: true (only after user approval)
- `new_branch`: User's chosen branch name
- `delete_remote`: true (default)

Execute the git commands from the response.

### Step 8: Done

Show a final summary:
- Preflight results
- Brainstormed next steps (for reference)
- What was cleaned up
- New branch (if created)
- Checkpoint ID (for recovery)

## Error Handling

- If any MCP tool call fails, show the error and ask the user how to proceed
- If the MCP server is unreachable, fall back to executing the workflow locally without state persistence
- Never execute destructive operations (cleanup, branch delete) without explicit user confirmation
