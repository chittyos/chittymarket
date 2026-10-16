# post-judgment-claims-review evals
This folder holds the eval set (evals.json, prompts/, CHANGELOG.md) and the benchmark results (benchmark-summary.md, benchmark-aggregate.json) for the skill.
Each eval was run with and without the skill by Opus-tier agents under a 100k-context cap, then graded by a separate grader agent against the assertions in evals.json.
All prompts are synthetic; they contain no real matter facts.
Run outputs are not committed.
The runs used this layout: iteration-N/<eval>/{with_skill,without_skill}/{outputs/,grading.json}.
