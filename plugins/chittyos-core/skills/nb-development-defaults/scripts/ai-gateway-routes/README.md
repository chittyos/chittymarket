# AI Gateway dynamic routes (as code)

Source of truth for Cloudflare AI Gateway **dynamic routes** that ChittyOS tooling
depends on. Account `0bc21e3a5a9de1a4cc843be9c3e98121` (ChittyCorp), gateway `central`.
Apply / drift-check with `../apply-gateway-route.sh <route>.json [--check] [--smoke]`.

## Current state: no routes are defined

There are no route files here and no dynamic routes on `central`. The separated
reviewer (`../adversarial-review.sh`) uses a **direct** large-context BYOK model,
`cloudflare-ai-gateway/anthropic/claude-opus-4-8`, not a route.

A route file is added here **only through a deliberate design**: one purpose-built
route per job (strategic dynamic-route development), reviewed like code, applied
with `apply-gateway-route.sh`, and drift-checked with `--check`. Do not add a
catch-all route.

## Retired: three-wise-men (2026-10-03, per operator)

`dynamic/three-wise-men` was a catch-all "curated trio of frontier models" route
from the old `chittyclaw` gateway. It was killed deliberately. On 2026-10-02 it was
recreated on `central` and codified here; the operator deleted it again on
2026-10-03 and this file was removed so nobody re-applies it. **Do not recreate it**,
under that name or as the reviewer route. `dynamic/adversarial-reviewer` ($0.00,
32k context) is likewise retired and must not be recreated.

## Rules for any future route

- **The reviewer's identity check does not cover route edits.** `adversarial-review.sh`
  verifies the answer came from the *requested* model; for a dynamic route that is the
  route name, so a route edited to point at a cheap model still passes. Drift-check
  with `apply-gateway-route.sh --check`, and/or read the `cf-aig-model` /
  `cf-aig-provider` response headers, which name what actually served.
- **Never give a review/judgment route a cheap fallback.** Cloudflare's guidance for
  Budget Limit nodes is to fall back to a cheaper model instead of blocking. For a
  judgment route that is the documented failure mode (confident empty findings): it
  must fail closed on budget exhaustion. Cheap fallback is fine for generation routes.
- Routes **can** be created over the REST API (`POST .../gateways/{g}/routes` with
  `{name, elements}`, verified 2026-10-02); the list endpoint returns `.data.routes`,
  the detail endpoint `.result` (verified 2026-10-03).

## JSON file shape

`name` (route name), `gateway` (default gateway; `--gateway` overrides), `elements`
(the exact array POSTed as a route version).
