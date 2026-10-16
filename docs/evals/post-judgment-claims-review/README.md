# post-judgment-claims-review — evals

Eval set for the canonical skill `canonical/skills/post-judgment-claims-review.md`, produced with the skill-creator loop. `evals.json` holds three evals with assertions; `prompts/` holds the synthetic prompts (no real parties, case numbers, addresses, or figures tied to a real matter); `CHANGELOG.md` records every change to an assertion or prompt and when it was made relative to the runs.

Runs: each run is an Opus-tier agent under a 100k-context cap, given the prompt and (with_skill only) the canonical skill plus legal-operating-defaults; a separate grader agent scored every assertion against the output files and wrote `grading.json`. Each cell below is a single run (n = 1). Run outputs are not committed; the layout used was `iteration-N/<eval>/{with_skill,without_skill}/{outputs/,grading.json}` with `eval_metadata.json` per eval.

| iteration | skill revision run | runs made |
|---|---|---|
| 1 | canonical text at 5efb93d (hard `case` gate) | eval-1 with/without; eval-2 with/without |
| 2 | + two-tier matter identifier, compact frame, tag fallback | eval-1 with/without (prompt names the unit; assertions tightened); eval-3 with/without |
| 3 | + proportional manifest, short pieces first, two-matter ordering, truthful index | eval-3 with_skill only (prompt unchanged; baseline from iteration 2) |

The committed skill text additionally carries a Stage 2 clause (first ask is for the posting detail when the reconciliation does not close) and the reviewer-round wording fixes (store tier, checklist items); neither has been run. Results per run are in `benchmark-summary.md` and `benchmark-aggregate.json`.
