# ChittyActor contract

## Canonical placement

- Actor implementation: `chittyentity/chittyactors/{name}`
- Shared Python substrate: `chittyentity/chittysdks/actor-base`
- Python import: `chitty_actor_base`
- Policy-bearing caller: `chittyagents/{name-or-domain}` where applicable
- Canonical skill catalog: ChittyMarket

## Actor role

A ChittyActor is a bounded executor/scraper/collector. It performs data acquisition or heavy containerized work. It does not own goal-directed policy, cross-capability routing, credential authority, or canonical agent identity.

## Shared primitives

`actor-base` owns reusable mechanics such as:

- generic action runner
- entrypoint mode routing
- credential-loading helpers
- error envelopes
- trace propagation
- generic action-registry execution

Consume these; do not recreate them in each actor.

## Profiles

### action

Use for request/response acquisition where one input selects one action and one output envelope is sufficient.

Typical files:

- `src/client.py`
- `src/actions.py`
- `src/main.py` using `run_actor`
- `src/__main__.py` using `entrypoint`
- optional `src/server.py` for standby/local HTTP

### batch

Use when acquisition is resumable, cursor-based, dataset-emitting, or expected to outlive a short-lived token.

Do not force the generic `actor_runner` onto this profile. Reuse only the compatible shared primitives such as error envelopes and trace IDs. Document checkpoint ordering, delivery semantics, token expiry behavior, and retry/failure classes in the Actor charter.

## Apify monorepo build contract

Actors consuming `actor-base` need a Docker build context that includes both:

- `chittyactors/{name}`
- `chittysdks/actor-base`

Use `.actor/actor.json`:

```json
{
  "dockerContextDir": "../../..",
  "dockerfile": "../Dockerfile"
}
```

The Dockerfile installs the canonical kit and then copies only the selected Actor:

```dockerfile
COPY chittysdks/actor-base /tmp/chitty-actor-base
RUN pip install --no-cache-dir /tmp/chitty-actor-base
COPY chittyactors/example/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt
COPY chittyactors/example/ ./
```

Current Apify CLI rejects `apify push` when `dockerContextDir` points outside the Actor folder. Use Git-backed monorepo source configuration for production builds: repository + branch + Actor folder.

## Deployment evidence states

Keep these distinct:

1. source committed
2. source connected to Apify
3. build started
4. build succeeded
5. build tag promoted/updated
6. Actor run succeeded
7. output contract verified

Do not infer a later state from an earlier one.
