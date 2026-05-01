# ChittyContext Skill - Persistent State Management v2.1

## Overview
ChittyContext enables Claude to maintain persistent state across conversations. It is a **capability of ChittyConnect** — the local component (`~/.claude/chittycontext/`) serves as an edge cache, while ChittyConnect's ContextConsciousness™ and MemoryCloude™ are the source of truth.

## State Location
`~/.claude/chittycontext/`

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
    ├── identity.json                # Entity metadata + canonical type
    ├── experience_accumulator.json  # Per-entity rolling totals (sessions, interactions, decisions, toolCalls, expertiseDomains)
    ├── context_ledger.jsonl         # Hash-chained, tamper-evident session_complete log (one JSON line per session)
    └── {project-slug}/
        ├── current_state.json   # Active working state (v2.1 schema)
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

### current_state.json (v2.1)
```json
{
  "version": "2.1",
  "chittyId": "VV-G-LLL-SSSS-P-YYMM-C-X",
  "project": { "slug": "", "name": "", "path": "" },
  "session": {
    "id": "", "startedAt": "ISO8601", "lastActivity": "ISO8601",
    "metrics": {
      "interactions": 0, "decisions": 0, "toolCalls": 0, "filesModified": [],
      "openTasks": 0, "completedTasks": 0, "taskFiles": 0,
      "livePending": 0, "liveInProgress": 0, "liveCompleted": 0, "liveSessionUuid": "",
      "stagedFiles": 0, "modifiedFiles": 0, "untrackedFiles": 0
    }
  },
  "coordinates": {
    "ty": { "type": "P", "characterization": "Synthetic" },
    "vy": { "posture": "active|drained|...", "trustScore": 0, "trustLevel": 0 },
    "ry": { "freshness": "fresh|stale", "causalParent": "prior session id" },
    "tau": "ISO8601 — session anchor timestamp"
  },
  "lane": "operational lane resolved from ~/.ops/operator-manifest.json (e.g. implementation, dev, stage, prod)",
  "context": { "summary": "", "activeGoals": [], "completedGoals": [], "blockers": [] },
  "git": {
    "branch": "", "lastCommit": "", "uncommittedFiles": [],
    "inRepo": false, "recentCommits": [], "activePRs": []
  },
  "activeRepos": [],
  "decisions": [
    { "timestamp": "ISO8601", "description": "", "reasoning": "", "alternatives": [] }
  ],
  "nextActions": [],
  "derived": {
    "metrics": {},
    "keyFacts": [],
    "pendingTasks": [],
    "completedTasks": [],
    "taskHighlights": [],
    "nextRecommendedAction": ""
  },
  "memoryHash": "sha256 of canonical signal block — drives no-op skip + ledger chain",
  "lastSessionEndedAt": "ISO8601",
  "syncedToBackend": false,
  "lastSyncAt": null
}
```

### What's new in v2.1 (vs. v2.0)
- **`coordinates`** — operator ontology coordinates (ty/vy/ry/tau) sourced from `~/.ops/operator-manifest.json` and binding state. `ry.causalParent` links to the previous session for lineage.
- **`lane`** — resolved dev/stage/prod from operator manifest.
- **`activeRepos`**, **`git.inRepo`**, **`git.recentCommits`**, **`git.activePRs`** — workspace repo + PR signals collected from the project root.
- **`decisions[]`** — now structured objects (`{timestamp, description, reasoning, alternatives}`) instead of bare strings.
- **`derived{}`** — read-only aggregations the SessionStart reader can render directly without re-deriving (`keyFacts`, `pendingTasks`, `completedTasks`, `taskHighlights`, `nextRecommendedAction`).
- **`memoryHash`** + **`lastSessionEndedAt`** — feed the `entities/{chittyId}/context_ledger.jsonl` hash chain.
- **`session.metrics.live*`** — live TodoWrite/TaskList capture from the active Claude Code session (`~/.claude/todos/{uuid}-agent-{uuid}.json`). When present, overrides stale prior pendingTasks/completedTasks.

### Concurrency contract
The writer skips on no-op (same `memoryHash` + same git/canonical metrics + same trust posture) and skips on **race** (on-disk file written by a different `session.id` whose `lastActivity` is newer than the current write's `timestamp`). Atomic `os.replace` guarantees per-file integrity; the race guard prevents an older session ending late from clobbering a newer one's state.

## Cross-Instance Continuity
Any Claude instance can:
1. Read session_binding.json + current_state.json at session start
2. Continue from exact stopping point
3. Update state as work progresses
4. Queue commits for backend sync on session end
