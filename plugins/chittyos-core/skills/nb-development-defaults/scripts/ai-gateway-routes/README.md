# AI Gateway dynamic routes (as code)

Source of truth for Cloudflare AI Gateway **dynamic routes** that ChittyOS tooling
depends on. Account `0bc21e3a5a9de1a4cc843be9c3e98121` (ChittyCorp), gateway `central`.
Apply / drift-check with `../apply-gateway-route.sh`.

## three-wise-men

Backs `cloudflare-ai-gateway/dynamic/three-wise-men`, the default model of
`../adversarial-review.sh` (separated adversarial review). This is **judgment
work**: reviewer output is acted on as findings, so the route must stay on a
frontier model (primary claude-opus-4-8, fallback claude-sonnet-4-5, 300s timeout,
1 retry each). Never downgrade it to a cheap or small-context model; see the
"Failure record" in the nb-development-defaults skill (an inadequate reviewer
returns confident empty findings that get ignored).

Why this exists: on 2026-10-02 zero dynamic routes existed on any gateway.
chittyclaw referenced `dynamic/three-wise-men` and `dynamic/adversarial-reviewer`,
both missing, so calls failed with 400 code 2005. Routes live only server-side in
CF, so nothing in git could notice them vanishing. `three-wise-men` was recreated by
hand (route 9f66f555-fa67-4479-b3df-c40528a43c77); this directory codifies it, and
`apply-gateway-route.sh --check` detects drift or absence (exit 1).

`dynamic/adversarial-reviewer` no longer exists and must not be recreated or used.

## JSON file shape

`name` (route name), `gateway` (default gateway; `--gateway` overrides), `elements`
(the exact array POSTed as a route version).
