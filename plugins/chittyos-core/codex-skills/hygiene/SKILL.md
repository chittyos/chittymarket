---
name: hygiene
description: Repository hygiene and crash-safe work capture for any repo. Use when a session starts or ends, before or after risky git work, when a repo looks messy, when branches have piled up, or when uncommitted work needs protecting from a crash. Triggers on "hygiene", "capture my work", "wip", "is this repo clean", "stale branches", "what did I leave uncommitted", "archive branches", "clean up branches", "/hygiene". Wraps the merged `can hygiene` and `can wip` surfaces so a synth can run them on a target repo without shelling out blind.
canon_uri: chittycanon://core/services/chittymarket#skills/hygiene
---

# Repository hygiene

Two surfaces, both merged and live in `chittycan` on `main`. This skill exists
so a synth can invoke them against a **target repo** with the right flags and
read the output correctly — the failure mode being an agent that runs a scan,
misreads an empty result, and reports "clean".

Requires a built `chittycan`. If `can` is not on PATH, use
`node <chittycan>/dist/index.js` — the CLI only runs against a built `dist/`.

**Check the installed version against the repo before trusting any band
(BINDING).** A globally installed `can` can be an older build than the source,
and the classifier fails silently in the expensive direction:

```bash
node -e "console.log(require('/home/ubuntu/.npm-global/lib/node_modules/chittycan/package.json').version)"
node -e "console.log(require('<chittycan>/package.json').version)"   # must match
```

Measured 2026-11-11: the installed CLI was **0.6.4**, whose
`dist/lib/hygiene/workflow-facts.js` has no `write-tree` at all — it predates
the `merge-tree --write-tree` fix, so (per that file's own comment) a conflict
marker count "was always 0 and every branch read as merging clean". With
`conflicts` pinned at 0, `driftBand()` can never return `gone` for a
conflicting branch and returns **`closing`** instead. Same repo, same minute:
0.6.4 proposed **20** closing branches "still merge clean"; merging
`origin/main` into each showed **14 of 20 conflicted**; after
`npm install -g .` from the repo at 0.6.8 the same command proposed **2**, and
`gone` went 119 → 148. The fix is in the source, so the only symptom is a
stale install, and the only tell is that the bands are wrong. Filed as
chittycan#229 (print the CLI version in the report header).

A mismatch is not a caveat to note afterwards — rebuild and reinstall
(`npm run build && npm install -g .`), then re-run, before acting on the output.

## Deciding which surface

| question | command |
|---|---|
| Is this repo's *configuration* healthy? | `can hygiene [path]` |
| What is uncommitted right now, and what should I do next? | `can wip status [path]` |
| Protect in-flight work before something risky | `can wip capture [path]` |
| What did a dead session leave behind? | `can wip list [path]` |
| Branches have piled up | `can wip branches [path]` |

`hygiene` audits repo config: tracked build artifacts, unignored output dirs,
missing commit-msg lint, absent hook layer, CI gates that cannot fail,
`wrangler main` pointing at uncommitted source.

`wip` is about work in flight and branch lifecycle. Different question,
different cadence, different blast radius.

## Reading the output without fooling yourself

**`can hygiene` exits 1 when it finds anything at or above the severity
threshold.** That is correct for a gate and wrong to treat as an error. Do not
report failure because the exit code was non-zero.

**Zero findings is not automatically good news.** Verify the scan actually ran
before reporting a repo clean. A JSON consumer must handle `Finding[]` — a
harness that read `.findings` off an array once reported `0 findings` on four
repos minutes after the same code reported six, and the result looked entirely
plausible. If a result surprises you, re-derive it a second way before
believing it.

Two rules fire on ~99% of repos (`no-commit-msg-lint` 137/138,
`no-local-hook-layer` 135/138). They are `low` and never gate. Treat them as an
ecosystem-wide observation, not a per-repo finding, and do not let them
dominate a report — the signal is `deployed-without-source` (7/138, zero false
positives) and `tracked-build-artifact`.

## Capture is safe to run unattended

`can wip capture` writes `refs/wip/<id>` through an isolated `GIT_INDEX_FILE`.
HEAD, the index, and the working tree are **provably untouched** — the
invariant is verified on every run, and a violation disables the operation,
falls back to plain file copies, and self-tests on a cooldown.

Consequences worth knowing:

- Safe against a repo other sessions are actively editing. It cannot lose work
  even when its inputs are wrong; the worst outcome is a redundant ref.
- It **refuses** mid-merge/rebase/cherry-pick. A conflicted tree is a partial
  result, not a state anyone chose, and capturing it records that partial state
  as if it were intended. If it refuses, do not work around it.
- Refs live under `refs/wip/`, never `refs/heads/`. A snapshot in the branch
  list reads as pending work someone should merge. It is a floor, not a
  proposal.
- It is not `git stash`. The stash is repository-global, so stashing from one
  worktree can pop an entry another session depends on. Never suggest stashing
  as an alternative here.

## Branches: judged by mergeability, never age

`can wip branches` classifies every local branch as a proposal to change the
default branch — which is a branch's only job.

- **merged** (no unique commits) — deletable; holds nothing
- **gone** (conflicts, or far enough behind that its assumptions expired) — archive
- **closing** — still cheap to rescue *today*, archaeology if left. **This is
  the only actionable band.** Report it first; it is the operator's real to-do
  list.
- current / drifting — leave alone

A 2-day-old branch whose diff no longer applies is dead; a 60-day-old branch
that still merges cleanly is alive. Never classify by age.

**Dry run is the default.** `--archive-gone` writes `refs/archive/` tips and
deletes nothing. `--prune-merged` archives, reads the ref back to confirm it
holds the same sha, and only then deletes. Archiving is not deleting: every
commit stays reachable via `git log refs/archive/<name>`, restorable with
`git branch <name> refs/archive/<name>`.

Never archive a `closing` branch — that hides it exactly when it most needs
seeing. The tool already refuses the default branch and anything a worktree has
checked out, and reports each refusal rather than skipping silently.

## Fleet scope needs explicit authorization

Running this across many repos at once writes refs to shared production
clones. A 147-repo sweep was blocked by a safety classifier for want of
explicit authorization naming that action, and the block was correct.

Per-repo on request: fine. Fleet-wide: get the operator to say so, naming the
scope. An instruction to "clean things up" is not authorization to write to
every repo on the machine.
