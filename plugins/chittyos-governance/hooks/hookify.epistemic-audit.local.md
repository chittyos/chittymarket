---
name: epistemic-audit
enabled: true
event: prompt
action: suggest
pattern: ^\s*/?(bs|bullshit|call\s*(bs|bullshit)|audit|prove\s*it)\s*[!.?]*\s*$
---

## Epistemic audit — operator-invoked

Pick the **single load-bearing factual claim** in what you just wrote — the one the rest depends on.

1. **Did you MEASURE it this turn**, or did you infer it from a name, a doc, a memory, or a plausible causal story?
2. **If you measured it: could the measurement be right and the conclusion still wrong?**
   A grep that matched one spelling. A ratio whose denominator cannot vary. A test asserting the buggy value.
3. **Name the one command that would falsify it.** If it takes under a minute, run it before answering.

Confident-and-wrong is indistinguishable from confident-and-right from the inside. That is the entire reason this exists.

---

### Why this rule is a whole-line match

The pattern is anchored `^…$` so it fires only when the message *is* the challenge. `bs` appearing mid-sentence ("what's the bs in this manifest") does not trigger it. That keeps the operator's cost at two characters without making the word unusable in normal conversation.

### Why the trigger belongs to the operator, not the assistant

The obvious alternative is a rule that watches the **assistant's** output and fires on blocker-shaped language — "architecturally unreachable", "blocked on", "not possible" — when no tool call accompanies it.

That design is worse, and the reason generalises: **a detector the assistant can see is a detector the assistant can route around.** Given a known trigger, the cheapest adaptation is to avoid the trigger words while remaining exactly as unverified. Goodhart's law, immediately.

A trigger the operator controls has nothing to game. The assistant cannot predict or influence when it fires, so the only strategy that survives is being right.

This is the same failure this ecosystem has already hit three times:

- Alchemization clause 2 was satisfied by a **comment** saying handlers wire through `runTool` — 40 workers passed on the comment alone (ICB-29).
- Clause 2 then read only three fixed filenames, so a worker with 36 registrations across six files could pass on one qualifying call (ICB-37).
- A tool manifest declared twelve tools that **do not exist**, and every static check passed (ICB-31).

Each is a check that fires unconditionally and therefore carries no information. A challenge that fires on every response becomes furniture within a day; the moment it stops being noticed, delete it rather than tune it.

### Companion: randomized mode

`epistemic-audit.py`, shipped alongside this rule, implements the same challenge as a **randomized** `Stop` hook seeded on the transcript hash. It fires on a low percentage of turns regardless of content, which catches the failure class this rule cannot: claims that *were* sampled, but badly, and whose phrasing gives nothing away.

It is **not** wired by default. It is opt-in precisely because an always-on challenge degrades into ceremony — see above.

### Provenance

Derived from observed operator behaviour: two-word interrupts (`sequential thinking`, `bs`) issued at unpredictable moments, which repeatedly caused the assistant to locate its own errors without receiving any new information. The rule is a formalisation of that interrupt, not a replacement for it — a human choosing *when* to challenge carries signal that a regex and a hash do not.
