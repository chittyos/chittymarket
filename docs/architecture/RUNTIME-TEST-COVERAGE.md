# Runtime Test Coverage

This document describes what `scripts/runtime-tests/` actually verifies, what it does **not** verify, and how to extend coverage when a new runtime is added to the dispatch model.

## Why this exists

Adversarial review finding #4 against PR #42 (`feat(canonical): universalize runtime declarations on every canonical`) flagged that the "universal projection" claim is **unverified bytes** — projection files exist on disk, the adapters round-trip cleanly, and the manifest is idempotent, but nothing in CI ever attempts to *load* a projection in its target runtime.

The runtime smoke tests close that gap with the strongest validation available given current runtime tooling.

## What is tested

### Codex skills — `scripts/runtime-tests/codex-smoke.sh`

For each `plugins/<plug>/codex-skills/<name>/SKILL.md`:

1. File parses as a Markdown-frontmatter document (`---\n…\n---\n<body>`).
2. Frontmatter is valid YAML and a top-level mapping.
3. `name` and `description` are present, non-empty strings.
4. `name` matches the parent directory and conforms to the codex naming convention `^[a-z0-9][a-z0-9-]*[a-z0-9]$`.
5. Body is non-empty (codex skills are useless without instructions).
6. `description` is at least 20 characters (codex uses it as trigger prose).

If the `codex` CLI ever exposes a `skills load|validate` subcommand, the script will prefer that over the schema-mimic path. As of `codex-cli 0.114.0` no such subcommand exists, so the schema-mimic loader is the active path.

### OpenClaw agents — `scripts/runtime-tests/openclaw-smoke.sh`

For each `plugins/<plug>/openclaw-agents/<name>.yaml`:

1. File parses as a single YAML document and the top-level is a mapping.
2. Required keys `name`, `description`, `instructions` are present and non-empty.
3. Filename stem matches `name`; `name` conforms to `^[a-z0-9][a-z0-9-]*[a-z0-9]$`.
4. `description` ≥ 20 chars, `instructions` ≥ 40 chars.
5. No canonical-only keys (`kind`, `classification`, `runtimes`, `plugin`, `runtime_overrides`) and no Claude-Code-only keys (`model`, `color`, `tools`) leak through — that would indicate an adapter regression.

A real `openclaw` CLI is not yet publicly distributed. When it ships, the script will prefer a real `openclaw validate` invocation over the schema-mimic path.

## What is NOT tested

These remain explicit gaps. Document the gap; do not pretend it does not exist.

| Gap | Why it matters | When to close |
|---|---|---|
| Real `codex` runtime load (semantic) | Schema-mimic does not catch issues codex itself only detects at runtime (e.g. unsupported metadata fields, runtime-side trigger conflicts). | When `codex` CLI ships a `skills validate` subcommand. |
| Real `openclaw` runtime load | OpenClaw runtime is internal; we cannot exercise the actual agent loader from CI. | When OpenClaw publishes a CLI or library entrypoint. |
| Trigger phrase collision detection | Two skills with overlapping trigger language can confuse a real runtime even when both load. | Add cross-skill analyzer once a trigger taxonomy exists. |
| Description-quality semantics | A 20-character description passes the loader but is still poor. | Optional LLM-judged quality gate, off the critical path. |
| End-to-end "skill actually does the thing" | Behavioral testing of skills is fundamentally a runtime/agent concern, not a marketplace concern. | Owned by individual service test suites, not by chittymarket CI. |

## CI behavior

Both smoke jobs are wired into `.github/workflows/validate-chittymarket.yml`:

- They run after `validate` passes on any PR that touches `canonical/`, `plugins/`, `scripts/`, or the workflow itself.
- They use `continue-on-error: true` on the inner step plus a follow-up step that re-exits with the captured code. This pattern keeps the *job status* honest (red on failure) while letting us log a `::warning::` line explaining whether the failure is "real adapter bug" or "runtime simply not present" (current openclaw reality).
- Schema-mimic failures are treated as **hard failures**, not skips. The "skip cleanly when runtime is unavailable" requirement from the original spec is satisfied by the dedicated reporting step, not by silently passing — silently passing would re-introduce the exact gap this work was meant to close.

## How to extend for a new runtime

When a new runtime is added to the canonical dispatch model (say `vscode-agents`):

1. Add a `scripts/runtime-tests/<runtime>-smoke.sh` modeled on `openclaw-smoke.sh`. Mirror the contract enforced by the corresponding `plugins/chittyagent-dispatch/scripts/adapters/<runtime>-*.sh` adapter.
2. The validator should encode every invariant the adapter asserts in reverse — every key the adapter strips should be confirmed absent; every key the adapter requires should be confirmed present and well-typed.
3. Prefer a real CLI load when one is available; fall back to schema-mimic only when not.
4. Add a job block to `.github/workflows/validate-chittymarket.yml` modeled on `codex-smoke` / `openclaw-smoke`. Always `needs: validate` so the runtime smoke does not run on broken structural state.
5. Update the **What is tested** table above with the new runtime's invariants and the **What is NOT tested** table with anything intentionally left out.

## Current pass rates

(as of merge of `feat(ci): codex + openclaw runtime smoke tests`)

- Codex skills: 37/37 pass schema-mimic load
- OpenClaw agents: 10/10 pass schema-mimic load

Total projections under runtime smoke coverage: **47**.
