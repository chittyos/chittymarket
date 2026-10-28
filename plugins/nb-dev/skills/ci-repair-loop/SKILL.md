---
name: ci-repair-loop
description: Diagnose and repair CI or build failures in ChittyOS. Use on failed builds, broken tests, typecheck, deployment pipelines and flaky CI.
---

# CI Repair Loop
- Inspect current build source, actual logs, commit SHA, environment and triggering event; distinguish build, test, deploy and runtime failures.
- Reproduce with existing project scripts where possible. Write a focused regression test before repair when appropriate.
- Fix the cause, not the symptom; do not silence tests or weaken checks to get green status.
- Rerun checks and verify new build logs against the changed SHA.
- Prefer existing Cloudflare Workers Builds and authorized self-hosted runners; never introduce paid GitHub Actions or duplicate staging workers by default.
- Record precise commands, exit status, logs and remaining uncertainty in canonical issue.
