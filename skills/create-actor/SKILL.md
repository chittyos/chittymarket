---
name: create-actor
description: Scaffold, repair, or standardize ChittyOS Python actors under chittyentity/chittyactors/{name} using the canonical chittysdks/actor-base package and current Apify/Docker conventions. Use when creating a new ChittyActor, converting an ad hoc scraper/executor into a compliant actor, fixing actor structure or deployment packaging, or preparing an Actor for Apify monorepo deployment. Do not use to create autonomous policy-bearing agents; those belong under chittyagents/.
---

# Create Actor

Create bounded ChittyOS data-acquisition executors without recreating shared runtime primitives.

## Workflow

1. Inspect the target repository before scaffolding.
   - Read `chittyactors/ACTOR_CONVENTIONS.md`.
   - Read `chittysdks/actor-base/{README.md,CHARTER.md,CHITTY.md}` when present.
   - Search for an existing actor with the same job-to-be-done before creating a new leaf.
   - Reuse an existing issue/work item when one exists.

2. Classify the requested component.
   - Use `chittyactors/{name}` only for bounded Python/Docker/Apify execution with no standalone goal-directed policy.
   - Route durable policy, authority, routing, retry strategy, or agent identity to `chittyagents/{name}` instead.
   - Prefer extending an existing Actor when the requested capability is another action against the same external system and credential boundary.

3. Select an Actor profile.
   - **action**: default for single-shot portal/API acquisition. Use `chitty_actor_base.actor_runner.run_actor` plus an `ACTION_REGISTRY`.
   - **batch**: use for resumable, dataset-emitting, long-running acquisition where the generic action runner is the wrong shape. Reuse `chitty_actor_base.error_envelope` and `chitty_actor_base.trace`; implement only the specialized loop.
   - Do not duplicate `actor_runner.py`, `entrypoint.py`, credential loading, error envelopes, or trace helpers inside an Actor.

4. Scaffold with `scripts/scaffold_actor.py` when creating a new Actor.
   - Required input: actor name.
   - Optional: `--profile action|batch`, `--title`, and `--output-root`.
   - Default output root is `chittyactors`.
   - Inspect and adapt generated placeholders; never leave fake endpoints, mock data, or invented credentials in production code.

5. Wire the canonical package.
   - Import package name: `chitty_actor_base`.
   - Repository package: `chittysdks/actor-base`.
   - Never add `sys.path.insert(.../shared)` or copy the package into the Actor.
   - For Apify monorepo builds, use repository-root Docker context and install `chittysdks/actor-base` in the Dockerfile.

6. Preserve credential boundaries.
   - Do not hardcode secrets.
   - Do not mint or persist long-lived provider credentials in the Actor.
   - Accept only credentials/tokens supplied through the existing ChittyConnect/ChittyAuth/1Password-governed path for the specific Actor contract.
   - If the Actor needs a new secret-bearing invocation path, treat that as a separate governed integration change.

7. Validate before shipping.
   - Python syntax/import checks.
   - Package install/import check for `chittysdks/actor-base`.
   - Actor-specific tests.
   - Docker build from the same monorepo context used by deployment when available.
   - Verify `.actor/actor.json` paths against the selected build mode.
   - For Apify, distinguish source update, build success, build-tag promotion, and run success.

8. Deploy through the governed path.
   - Current monorepo Actors that depend on `actor-base` require Git-backed Apify builds; actor-local `apify push` cannot carry a parent Docker context.
   - Do not mutate live Apify version/source configuration merely because scaffolding is complete.
   - When deployment is requested and authorized, verify the live Actor source mode, repository, branch, folder, build receipt, tag, and test run independently.

## Required Actor shape

For a standard action Actor, produce at least:

```text
chittyactors/{name}/
├── CHARTER.md
├── CHITTY.md
├── CLAUDE.md
├── Dockerfile
├── requirements.txt
├── .actor/
│   └── actor.json
└── src/
    ├── __init__.py
    ├── __main__.py
    ├── main.py
    ├── client.py
    ├── actions.py
    └── server.py
```

Keep portal-specific logic in `client.py` and action mapping in `actions.py`. Keep policy in the calling ChittyAgent.

## Acceptance criteria

Do not call the Actor ready until all applicable criteria pass:

- `chitty_actor_base` is installed/importable without repository-relative `sys.path` hacks.
- No shared primitive is locally duplicated.
- No credential is committed or persisted outside the approved contract.
- Actor leaf is bare kebab-case under `chittyactors/`.
- Compliance triad exists and describes purpose, owner, runtime, and invocation boundary.
- Docker/Apify configuration matches the real build context.
- Actor returns structured output or documented dataset rows and fails loudly on unsupported operations.
- Calling agent/invocation owner is documented.
- Live deployment claims are backed by build/run evidence, not source state alone.

## References

Read `references/chittyactor-contract.md` when deciding placement, profile, packaging, or deployment mode.
