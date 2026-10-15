# THE GAUNTLET — fixture corpus for `scripts/wt-reap.sh`

Authored by a context that did not write `wt-reap.sh`. Every comment and
claim inside that script was treated as the author's assertion, not as fact.
**Expected outcomes encode what the script CLAIMS** (header contract + the
four documented gates), not what it currently does. A FAIL here is a finding
about the script, not a bug in the runner.

## Run

    scripts/tests/wt-reap/run.sh              # all cases; exit 0 only if all pass
    scripts/tests/wt-reap/run.sh 03 27        # substring-select cases
    GAUNTLET_VERBOSE=1 ...                    # include the script's own output
    GAUNTLET_KEEP=1 ...                       # keep the per-case temp sandbox
    GAUNTLET_SABOTAGE=15-pr-open ...          # invert one verdict; proves red works

## Isolation

A test that escapes into the real tree is worse than no test.

1. **The chokepoint** is `assert_isolated` called as the first statement of
   `run_reap` — the real script is never launched until `$GIT_WT_ROOT` has
   been proven non-empty, under `/tmp|/var/tmp|/dev/shm`, and outside
   `$HOME/projects/worktrees` and `$HOME/projects/github.com`. Anything else
   exits 3 before `bash wt-reap.sh` runs. `run.sh` also calls it before setup
   and before assert; those two are belt, not braces.
2. The script runs under `env -i` with `HOME` redirected to a per-case temp
   dir, so even a lost `GIT_WT_ROOT` resolves the fallback to a nonexistent
   path and the script exits 2.
3. The runner snapshots `$HOME/projects/worktrees` (top-level entries plus
   `node_modules` to depth 4) before and after, and aborts with status 3 if
   it changed.
4. `run_reap` aborts with status 3 if the stub `gh` log does not record the
   script's unconditional `gh auth status` — an empty log means PATH
   injection failed and the real `gh` may have answered.

`gh` is replaced by PATH injection (`stubs/gh`) — the script itself is never
modified to make it testable.

## Case contract

Each `corpus/NN-name.sh` defines `WHAT_BREAKS` (one line: the consequence of
a wrong decision), `setup()` (builds the synthetic tree and calls `run_reap`),
and `assert()`. `defer "<reason>"` from `setup` reports DEFERRED — counted
separately, never as a pass.
