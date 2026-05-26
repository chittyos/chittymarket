---
name: chittyxl
canon_uri: chittycanon://core/services/chittymarket#skills/chittyxl
description: ChittyXL session manager — auto-checkpointing at token-budget intervals, Notion sync, persistent state across long sessions.
kind: skill
plugin: chittyos-core
runtimes:
  - claude-code
  - codex
classification:
  - session
  - operations
---

# ChittyXL v2.0 - Session Persistence & Auto-Compacting Protocol

**Type**: Auto-Activated Session Skill
**Priority**: Critical
**Scope**: All Claude Code sessions

---

## Auto-Activation Behavior

This skill activates **silently** at session start. No initialization message required.

**Continuous Monitoring**:
- Track token usage: `current/budget` ratio
- Checkpoint triggers: 38k, 76k, 114k, 152k tokens (20% intervals of 190k)
- Hard limit: 171k tokens (90%) → force compact + session fork alert

---

## Core Protocol: Artifact-First Communication

### Chat Window (Strict Limits)
**ONLY use chat for**:
- Confirmations: ≤3 lines
- Blocking questions: 1 question max per message
- Checkpoint summaries: ≤150 words, bullet format

### Artifacts (Primary Output)
**ALWAYS use artifacts for**:
- Technical specs, schemas, APIs, data models
- Code: implementations, scripts, functions, configs
- Documentation: guides, protocols, procedures
- Analysis: results, reports, comparisons
- Data exports: CSV, JSON (especially for Notion import)

### Notion Tracker (State Persistence)
**URL**: https://www.notion.so/83e8d8f77e5a45bb96f7188c6fe092d3

**Sync on every checkpoint**:
- **Projects DB**: Context Notes, Decision Log, Blockers, Status
- **Actions DB**: Task details, Status, Notes, Parent Project relations
- **Session Metadata**: Continuation context, technical references, entity relationships

---

## Automatic Checkpoint Execution

**Triggers**: 38k, 76k, 114k, 152k, 171k tokens

**Process** (silent execution, report only result):
1. **Extract state**: Projects, actions, decisions, blockers, context
2. **Deduplicate**: Remove redundancy, keep only final decisions
3. **Sync to Notion**:
   - Update existing projects (match by name/ID)
   - Create/update actions (link to parent projects)
   - Store session metadata in Context Notes field
4. **Generate summary artifact**:
   - Format: Markdown with bullet points
   - Include: Projects updated, actions created/modified, next threshold
   - Optional: CSV export artifact for manual Notion import
5. **Report to user** (≤3 lines):
   ```
   Checkpoint #X complete | 76k/190k (40%) | Next: 114k
   Synced: 2 projects, 5 actions → Notion
   ```

**Anti-Pattern** ❌:
```
I'm now going to extract the conversation state by analyzing...
Then I'll deduplicate the entries by removing...
Next I'll sync to Notion by updating...
```

**Correct** ✓:
```
Checkpoint #2 complete | 76k/190k (40%) | Next: 114k
Synced: 2 projects, 5 actions → Notion
```

---

## User Commands

### `status`
Show current session state (≤5 lines):
```
ChittyXL: Active ✓
Tokens: 42k/190k (22%) | Next checkpoint: 76k (40%)
Active projects: 3 | Pending actions: 12
Last sync: 2 min ago | Tracker: [Notion link]
```

### `checkpoint`
Force immediate checkpoint (same process as auto-trigger).

### `continue`
Load last session state from Notion:
1. Query Projects DB: `Status != Completed AND Status != Archived`
2. Parse Context Notes: Extract `[SESSION:...]` metadata
3. Load Actions DB: Filter by parent project, `Status != Done`
4. Generate briefing artifact:
   - Active projects with current status
   - Pending actions grouped by project
   - Blockers/decisions from last session
   - Technical context (entity schemas, API references, etc.)
5. Present summary (≤150 words) + link to artifact

### `fork`
Save current state to Notion + generate session handoff:
```
State saved | Session ID: [timestamp]
Ready for fresh session - share this with new Claude instance:
"Load ChittyXL session [ID] from Notion tracker"
```

### `history`
Show last 5 checkpoints (table format in artifact):
```
| # | Tokens | Timestamp | Projects | Actions | Notes |
|---|--------|-----------|----------|---------|-------|
| 5 | 152k   | 14:32     | 3        | 15      | API schema finalized |
| 4 | 114k   | 14:15     | 3        | 12      | Added payment service |
```

---

## Notion Integration Details

### Projects Database
**Collection ID**: `999c414c-06c5-4064-a51b-921193830968`

**Key Fields**:
- **Name**: Project title (unique identifier)
- **Status**: Active | Paused | Completed | Archived
- **Context Notes**: Session metadata + continuation brief
  - Format: `[SESSION:timestamp] Brief description\n\n[ENTITIES] List\n[DECISIONS] Log`
- **Decision Log**: Timestamped entries of key decisions
- **Blockers**: Current impediments
- **Next Actions**: Summary of pending tasks
- **Last Updated**: Auto-timestamp on sync

### Actions Database
**Collection ID**: `6b52d580-f810-4009-964d-478039c144e1`

**Key Fields**:
- **Action**: Task description
- **Status**: Not Started | In Progress | Blocked | Done
- **Notes**: Technical details, context, references
- **Parent Project**: Relation to Projects DB (required)
- **Due**: Optional deadline
- **Tags**: Entity types, service names, etc.

### CSV Export Format
When generating Notion import CSVs, use this template:

**Projects**:
```csv
Name,Status,Context Notes,Decision Log,Blockers,Next Actions
"Project Name","Active","[SESSION:2025-01-16-14:32] Brief...","{timestamp} Decision","{blocker}","Next steps"
```

**Actions**:
```csv
Action,Status,Notes,Parent Project,Due,Tags
"Task description","In Progress","Technical notes","Project Name","2025-01-20","api,backend"
```

---

## Anti-Patterns (Forbidden)

❌ **Long explanations in chat**:
```
Let me explain the checkpoint process. First, I analyze the conversation
to extract all the projects we've discussed. Then I look for actions...
[200 words of process description]
```
✓ Put technical content in artifacts, confirm in ≤3 lines.

❌ **Inline code blocks >10 lines**:
```python
def complex_function():
    # 50 lines of code inline in chat
```
✓ Use code artifact, mention in chat: "Implementation in artifact ↑"

❌ **Multiple questions per message**:
```
Should I use REST or GraphQL? What about authentication?
Do you want PostgreSQL or MongoDB? Where should I deploy?
```
✓ Ask **one** blocking question, proceed with reasonable defaults otherwise.

❌ **Redundant confirmations**:
```
I've updated the database schema, created the API endpoints,
added authentication, written tests, and deployed to staging.
```
✓ "Schema updated | API deployed | Tests passing ✓"

❌ **Apologetic preambles**:
```
Sorry for the confusion earlier. Let me clarify what I meant...
```
✓ Just provide the clarification.

❌ **Over-explaining process**:
```
First I'll read the file, then I'll analyze the structure,
then I'll make the changes, then I'll verify...
```
✓ Just do it, report result.

---

## Performance Targets

✓ **<150 words** average per chat message
✓ **>80% content** in artifacts/Notion (not chat)
✓ **<20 seconds** checkpoint latency
✓ **Zero state loss** across session boundaries
✓ **1-exchange continuation** ("continue" → briefing in one turn)

---

## Session Lifecycle

### Start
- Silent activation (no "ChittyXL loaded" message)
- Initialize token counter: 0/190k
- Set next checkpoint: 38k

### During
- Monitor token usage continuously
- Auto-checkpoint at thresholds
- Enforce artifact-first protocol
- Sync state to Notion on every checkpoint

### End (User closes session)
- No explicit action needed
- State preserved in Notion
- Next session can load via `continue` command

### Resume (New session, existing work)
```
User: "continue"

ChittyXL: Loading session from Notion...

[Generates briefing artifact with projects/actions/context]

Active: 3 projects, 12 pending actions | Last checkpoint: 2h ago
Tracker: https://notion.so/...
```

---

## Debug & Monitoring

**Checkpoint Logs** (store in Notion Context Notes):
```
[LOG:2025-01-16-14:32] Checkpoint #3 | 114k tokens | 2 projects, 7 actions synced | Latency: 12s
```

**Notion Sync Status**:
- Success: Update Last Updated timestamp
- Failure: Alert user, retry once, fallback to CSV export artifact

**Alert at 90%** (171k tokens):
```
⚠️ Session capacity: 90% (171k/190k)
Compacting now... Consider `fork` for fresh session.
```

**Metrics to Track**:
- Checkpoints per session (target: 8-10 before hard limit)
- Average checkpoint latency (target: <20s)
- State persistence rate (target: 100%)
- Artifact usage ratio (target: >80%)

---

## Version & Support

**Version**: 2.0.0
**Released**: 2025-01-16
**Deployment**: Claude Code skill (auto-active)
**Tracker**: https://www.notion.so/83e8d8f77e5a45bb96f7188c6fe092d3

**Related Files**:
- `SESSION_PROTOCOL.md` - Detailed checkpoint algorithm
- `NOTION_TEMPLATES.md` - CSV import formats & field mappings
- `README.md` - Installation & usage guide

---

## Quick Reference

**Token Checkpoints**: 38k → 76k → 114k → 152k → 171k (hard limit)
**Chat Limit**: ≤150 words average, ≤3 lines for confirmations
**Artifacts**: All technical content, code, specs, analysis
**Notion**: Projects + Actions DBs, auto-sync on checkpoints
**Commands**: `status` | `checkpoint` | `continue` | `fork` | `history`
**Priority**: Conciseness > verbosity | Action > explanation | Artifacts > chat
