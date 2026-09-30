---
name: retrospect
canon_uri: chittycanon://core/services/chittymarket#skills/retrospect
description: Evidence-grounded retrospection — reflect on a session or task, validate the reflection against ground truth (transcript, logs, artifacts), then distill to generalizable principles that travel beyond the specific context. Triggers on "retrospect", "reflect on this session", "what did we learn", "validate my reflection", "after-action review", "what would you do differently", "distill learnings", or at natural session close when significant work was completed.
kind: skill
plugin: chittyos-core
runtimes:
  - claude-code
  - codex
  - gemini
classification:
  - learning
  - governance
  - process
---

# Retrospect

A three-phase evidence-grounded retrospection process. Designed to prevent the compounding of unvalidated self-assessments across sessions — the same failure mode as inheriting wrong completion claims from prior sessions, applied to reflection itself.

## When to invoke

- At session close after significant multi-step work
- After a debugging or migration effort with multiple failed attempts
- When the user asks "what did we learn", "reflect on this", or "what would you do differently"
- After any session where architecture decisions were made or corrected

---

## Phase 1 — Reflect

Produce a narrative account of the session. Cover:

1. **What was attempted** — the starting intent
2. **What failed and why** — be specific about root causes, not just symptoms
3. **What succeeded** — the actual unlock moments, not just the final state
4. **What was corrected by the user** — explicit corrections are high-signal; name them
5. **What surprised you** — discoveries that weren't anticipated

Do not sanitize. Include the embarrassing parts. Unvalidated reflection is journaling; this is diagnosis.

---

## Phase 2 — Validate

Check the narrative against ground truth before distilling.

```bash
# Count actual user turns
grep -c '"type":"USER_INPUT"' $TRANSCRIPT_PATH

# Find premature completion claims
python3 -c "
import json
with open('$TRANSCRIPT_PATH') as f:
    for line in f:
        d = json.loads(line)
        if d.get('type') == 'PLANNER_RESPONSE':
            c = str(d.get('content',''))
            if any(w in c.lower() for w in ['complete', 'done', 'migrated', 'finished']):
                print(d.get('step_index'), c[:100])
"

# Find first mentions of key entities/concepts
# Find where errors first appeared vs when they were resolved
# Check: did the reflection overstate or understate durations/counts?
```

Correction rules:
- If you said "N turns" — check the actual count
- If you said something was "the key moment" — verify it appears before the resolution, not after
- If you described yourself as discovering something — check whether the user pointed you there first
- If you described a pattern as "once" — check how many times it actually recurred

**The reflection is a hypothesis. Validate it.**

---

## Phase 3 — Distill

Strip away everything context-specific. For each lesson from Phase 1:

Ask: *If I removed all the nouns (service names, error codes, tool names) — does this principle still hold?*

If yes → it's a generalizable learning. If no → it's a tactic, not a principle.

Format each learning as:
```
**[Principle name]**
One sentence of the generalizable claim.
One sentence of what it looks like when violated.
```

Target: 4–8 principles. More than 8 usually means you haven't distilled enough.

---

## Anti-patterns (do not do these)

- **Sanitized narrative** — only describing what worked, not what failed
- **Tactic-level learnings** — "next time I'll check for MCP_OBJECT" is not a principle
- **Unvalidated claims** — saying "I did X" without checking whether you did
- **Length as thoroughness** — a long reflection with no distillation is just logging

---

## Output format

```markdown
## Session Retrospect — [date]

### Reflection
[narrative]

### Validation
[what the transcript confirmed or corrected]

### Principles
**[Name]** — [claim]. Violated when [symptom].
```

Save to: `$ARTIFACTS_DIR/retrospect-[YYYY-MM-DD].md`
