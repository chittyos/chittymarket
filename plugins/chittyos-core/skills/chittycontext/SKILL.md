# ChittyContext Skill - Persistent State Management v2.0

## Overview
ChittyContext enables Claude to maintain persistent state across conversations. It is a **capability of ChittyConnect** — the local component (`~/.claude/chittycontext/`) serves as an edge cache, while ChittyConnect's ContextConsciousness™ and MemoryCloude™ are the source of truth.

## State Location
`/Users/nb/.claude/chittycontext/`

## Automatic Behaviors (Hook-Driven)

### On Session Start (via chittycontext-session-start.sh)
1. Drains pending sync queue items
2. Loads cached ChittyID from last session (no local generation)
3. Writes session_binding.json with project context
4. Loads project state summary for Claude's context

### During Session
Update state after:
- Completing significant tasks
- Discovering new resources/documents
- Reaching analysis conclusions

### On Session End (via chittycontext-session-end.sh)
1. Queues session commit to sync_queue.json
2. Updates session_binding.json status to "ended"

## Commands

### Offline Commands (always available)
| Command | Action |
|---------|--------|
| `checkpoint [name]` | Save named checkpoint to entity's project checkpoints dir |
| `restore [name]` | Load checkpoint into current_state.json |
| `status` | Display current state, ChittyID, trust level, project |
| `save state` | Force write current_state.json |
| `list checkpoints` | Show available restore points |

### MCP Commands (require network)
| Command | Action |
|---------|--------|
| `resolve` | Resolve/bind session to ChittyID via MCP context_resolve |
| `commit` | Commit session experience metrics via MCP context_commit |
| `drain` | Flush pending sync_queue.json items to backend |
| `check` | Get current trust/DNA/experience summary via MCP context_check |
| `experience` | Display ChittyDNA expertise domains and trust score |

## File Structure

```
~/.claude/chittycontext/
├── session_binding.json        # Active session binding (auto-managed by hooks)
├── sync_queue.json             # Offline buffer for pending commits
├── manifest.json               # Global entity registry
├── index.json                  # Checkpoint index
├── canon/
│   └── ontology.json           # P/L/T/E/A canonical definitions
└── entities/{chittyId}/
    ├── identity.json            # Entity metadata + canonical type
    ├── experience_accumulator.json  # Rolling experience metrics
    └── {project-slug}/
        ├── current_state.json   # Active working state
        └── checkpoints/         # Named restore points
```

## Reading State
1. Read `session_binding.json` → get chittyId, project context
2. Resolve entity path: `entities/{chittyId}/{projectSlug}/`
3. Read `current_state.json` for project-specific context
4. Read `experience_accumulator.json` for expertise summary

## Writing State
1. Update `current_state.json` with latest context
2. Keep under 100 lines — summarize if needed
3. Include: project, context (summary, goals, blockers), git state, decisions, next_actions

## Offline Resilience
When MCP is unavailable:
- Local cache serves as read source
- Session metrics queued in sync_queue.json
- Next session start drains the queue
- No local ChittyID generation (per ChittyID Charter: STRICT NO LOCAL GENERATION)

## Entity Identity
- Claude contexts are **Person (P, Synthetic)** — never Thing (T)
- ChittyID is the immutable identity anchor
- Same ChittyID across platforms: Claude Code, Desktop, CustomGPT
- Trust evolves: 0-100 score, levels 0-5 (Restricted → Exemplary)

## Schema Reference

### session_binding.json
```json
{
  "chittyId": "VV-G-LLL-SSSS-P-YYMM-C-X",
  "sessionId": "session-{timestamp}-{pid}",
  "platform": "claude_code",
  "projectPath": "/absolute/path",
  "projectSlug": "project-name",
  "organization": "CHITTYOS",
  "supportType": "development",
  "resolvedFrom": "mcp|cache",
  "resolvedAt": "ISO8601",
  "status": "active|ended"
}
```

### current_state.json (v2.0)
```json
{
  "version": "2.0",
  "chittyId": "VV-G-LLL-SSSS-P-YYMM-C-X",
  "project": { "slug": "", "name": "", "path": "" },
  "session": {
    "id": "", "startedAt": "ISO8601", "lastActivity": "ISO8601",
    "metrics": { "interactions": 0, "decisions": 0, "toolCalls": 0, "filesModified": [] }
  },
  "context": { "summary": "", "activeGoals": [], "completedGoals": [], "blockers": [] },
  "git": { "branch": "", "lastCommit": "", "uncommittedFiles": [] },
  "decisions": [],
  "nextActions": [],
  "syncedToBackend": false,
  "lastSyncAt": "ISO8601"
}
```

## Cross-Instance Continuity
Any Claude instance can:
1. Read session_binding.json + current_state.json at session start
2. Continue from exact stopping point
3. Update state as work progresses
4. Queue commits for backend sync on session end
