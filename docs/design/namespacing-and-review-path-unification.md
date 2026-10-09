# Namespacing and Review-Path Unification — Pass 1 Proposal

Status: PROPOSAL. No infra mutation, no projected file edited; infra changes are operator-gated via
`ch1tty -> ChittyConnect`.

Discovery attempted (per BINDING discovery-first):
- Capability-registry duplicate check: RUN. `capabilities.generated.json`, `.total == 108`. Search for `namespac|gateway|naming|review|canon|config` returns only `Code Review`,
  `PR Review Toolkit`, `ChittyCanon Code Cardinal`, `Canon Certification Gate`. **No new skill,
  agent or MCP server is proposed**, so no registration is owed.
- `/helper` ownership query: ATTEMPTED. `GET agent.chitty.cc/helper/?q=...` returned HTTP 200 with a
  `refusal` body — no owner attribution. **PROVISIONAL on surface ownership**, which is UNVERIFIED.

## 0. Corrections to the established facts

**FALSE (as stated):** "`resolve_output.py` has exactly 13 `(runtime, kind)` pairs and only ONE
workflow pair (`claude-code`)."

Evidence — `plugins/chittyagent-dispatch/scripts/lib/resolve_output.py`, `_MAP`:
- `main`: **12** pairs, **zero** `workflow` pairs (`_MAP` spans lines 21-34).
- `guard/review-default-not-dynamic`, `feat/gauntlet-workflow`: **13** pairs, adding
  `("claude-code", "workflow"): ("plugins/{plugin}/workflows/{name}.js", "claude-code-workflow.sh")`.

So the 13th pair exists only on unmerged branches. The 13-pair statement describes a branch, not the
shipped mapping. This matters for §4: on `main` there is no `workflow` kind at all, so Claude Code's
`Workflow` advantage is not even representable in the single mapping that sync/audit/reconcile share.

**SIXTH stale branch found.** This proposal's base branch, `feat/chittyagent-serv-fleet-caretaker`,
also carries the retired default: `DEFAULT_MODEL="cloudflare-ai-gateway/dynamic/three-wise-men"` at
`plugins/chittyos-core/skills/nb-development-defaults/scripts/adversarial-review.sh:26`. `origin/main`
and `guard/review-default-not-dynamic` both carry the correct
`cloudflare-ai-gateway/anthropic/claude-opus-4-8` at line 34 of the same file. So the established
"five branches" list is incomplete, and the direct-model default is true of `main`, not of every tree.

UNVERIFIED: the gateways and their settings, the namespaces, the instance ids, per-gateway spend
limits. No provider API was called.

## 1. One naming convention

```
<domain>[-<scope>]           # gateway id, AI Search namespace
<domain>-<scope>-<entity>    # AI Search instance id
<SERVICE>_<PURPOSE>          # KV binding (code-facing, unchanged)
chitty-<service>-<purpose>-<env>   # KV namespace *title* (provider-facing)
```

- `domain` — the bounded concern, not the product, not the role: `legal`, `finance`, `ops`.
- `scope` — optional subdivision **and the privilege-isolation carrier**.
- No `env` or version token in a gateway or namespace id. Env belongs in the KV namespace title and
  the worker environment, not a shared router id: adding `-prod` to a live gateway renames the client
  URL path (`.../v1/{account}/central/compat`) — an outage for a cosmetic win.

**The `legal-cases` rule is accommodated, not overridden.** The stored rationale ("one instance per
case for structural privilege isolation; first-party evidentiary documents only") is a legal
boundary. The convention therefore makes per-case instances the *conforming* shape for the `legal`
domain: `legal-cases` is the namespace, and each case is an instance under it. A convention that
required renaming a live evidence index for a pending matter would be the wrong convention — so this
one does not. Instance ids inside `legal-cases` are **grandfathered permanently**, not
"renamed later".

Conformance, item by item:

| Surface | Id | Conforms? | Cost / breakage if renamed |
|---|---|---|---|
| Gateway (ChittyCorp) | `central` | NO — role, not domain | Breaks every client URL (`/central/compat`), incl. the review lane. **Do not rename.** Grandfather as the account router. |
| Gateway (ChittyCorp) | `finance` | YES | n/a |
| Gateway (ChittyCorp) | `chittycounsel` | NO — product name | Would become `legal-counsel`. Breaks ZDR+DLP-carrying client URLs. Defer; rename only at next client change. |
| Gateway (ChittyCorp) | `default` | NO — platform default | Cannot rename (provider-assigned). See §3. |
| Gateway (Digital Dossier) | `chitty` | NO — org name, no domain | Low traffic assumed (UNVERIFIED). Candidate for rename at next use. |
| Gateway (Furnished-Condos) | `furnished-condos` | NO — org name | Would be `property`. Cheap only if unused (UNVERIFIED). |
| Gateway (Furnished-Condos) | `default` | NO | Cannot rename. |
| Namespace | `default` (empty) | NO | **Empty — free to delete or ignore.** Cheapest conformance win available. |
| Namespace | `legal-cases` | YES (`legal`+`cases`) | n/a |
| Namespace | `finance` | YES | n/a |
| Instance | `chittyevidence-arias-2024d007847` | NO — `{service}-{case}-{docket}` | **Never rename.** Live evidence index, pending matter. Grandfathered. Conforming form would have been `legal-cases-arias2024d007847`. |
| Instance | `finance-reference` | Partially — `{namespace}-{role}`, missing entity | Conforming: `finance-reference-core`, or accept 2-token form for singleton instances. Cheap. |

Net: 3 of 12 conform. **The answer is not a rename campaign.** Adopt the convention as
*forward-binding only*: new ids must conform, existing ids are grandfathered with a recorded reason,
and a rename is only ever bundled with a change the client is already making.

## 2. The linkage gap

`finance` gateway and `finance` namespace match by coincidence: no provider field links them, and
`chittycounsel` has no namespace while `legal-cases` has no gateway. Name-matching is not a binding —
it silently breaks the moment one side is renamed (and §1 just said renames happen).

Proposal: bind them **in the repo, not in the provider**, because the provider offers no field.

- A checked-in `scripts/ai-gateway-routes/domains.json`: one record per domain naming its gateway id,
  its AI Search namespace, its instances, and its isolation rule (`per-instance` for `legal`,
  `metadata-filter` for `finance`).
- The **domain** is the primary key, not the ids — ids are attributes, so a rename edits one field
  and the binding survives.
- `apply-gateway-route.sh --check` reads this registry and reports a domain whose gateway or
  namespace is missing — which would have surfaced `chittycounsel`-with-no-namespace as a finding
  rather than as a shrug.
- Coincidental name matches are then explicit: `finance`/`finance` becomes a declared pair, and a
  future `finance-v2` gateway cannot quietly orphan the namespace.

This is a drift-checkable text file, not a provider mutation.

## 3. The ChittyCorp `default` gateway

`default` is `is_default: true` AND `authentication: false` AND uncapped: the account's default path
is its least constrained one. Any client that omits a gateway id, or fumbles one (exactly the
`/chittyclaw/` class of error), lands on the unauthenticated uncapped path.

Separate the two halves — they have different owners and different urgency:

- **`authentication: false` on the account default is a SECURITY decision.** An unauthenticated
  gateway reachable by default means any party who learns the account id can spend against it and can
  send prompts through it. Remediation: set `authentication: true` on `default`, and on
  Furnished-Condos `default` too. This is the one item worth an operator-gated change this pass.
- **Uncapped is a COST decision.** Remediation: a per-gateway spend limit and a rate limit on
  `default`, mirroring `central`'s 100/60s. Lower priority than auth, and currently
  **unmeasurable** — per-gateway spend limits are UNVERIFIED on three accounts (no field on the
  gateway object; the only schema endpoint is deprecated). Do not claim a cap exists until a live
  read shows one.
- **`is_default: true` should not be fought.** The provider assigns it; make the default safe rather
  than move the flag.

Staged, not applied: three field changes on two gateways, routed through ChittyConnect.

## 4. Review-path unification across projections

Where the path differs today:

- **Claude Code** can host a `workflow` — but only on unmerged branches (§0). On `main` the kind does
  not exist in `_MAP`.
- **Codex / OpenClaw / universal / claude-skills / chatgpt-apps** have no workflow pair and reach
  review through a chittyclaw CLI fan-out — `adversarial-review.sh` with its direct-model default
  (`…/adversarial-review.sh:34` on `main`), inheriting the 128KB ceiling and race (§5).
- `review/adversarial` (chittyconfig `post-review-status` workflow) fails closed by absence with
  `POLICY_BLOCKED_REVIEWER_UNCONFIGURED`. The producer job exits 0 and the status carries the red.
  One gate, one red — this is correct and should not be "fixed" by making the job red too.

A single architecture: **the review lane is one contract, not one runtime feature.** Every projection
invokes the same reviewer entry point with the same inputs (diff, base, scope) and the same exit
codes (2 = claw unavailable, 3 = model/route/delivery failure; on either, *the review did not run*).
`Workflow` is an orchestration convenience on one runtime, never the carrier of review semantics —
otherwise review quality becomes a function of which runtime you happened to project to.

**Standing observation, confirmed and promoted to a finding:** `dispatch.sh add-target` asks for the
`_MAP` pair and the adapter but never whether the runtime can *execute* the kind. `_MAP` is the only
place that could catch it, and it currently cannot — it is a bare dict with no capability column. A
`workflow` projected to a runtime with no agent host is a structurally dead route that sync, audit and
reconcile all agree on, because all three read the same mapping that never asked the question.

Proposal: give `_MAP` a third element per pair — `executable: true|false` — and have `add-target`
refuse a pair whose runtime cannot execute the kind. New `(runtime, kind)` pairs continue to belong
only in `resolve_output.py`. No projected file is touched.

## 5. The 128KB ceiling and the self-race as architecture

A reviewer that cannot accept a large diff becomes a reviewer of small diffs only — and nobody
notices, because the failure mode is not an error. The documented tell is **findings being ignored**,
not a bad finding. A 142KB diff split into three chunks by hand means *the implementer chose what the
reviewer saw*, which is exactly the separation the review lane exists to provide.

Proposal:

1. **Chunking is the reviewer's decision, never the implementer's.** The review entry point computes
   the split from the diff deterministically — by file boundary, largest-first, never splitting a
   hunk — so the same diff always splits the same way and a third party can reproduce it.
2. **A chunked review reports as chunked.** `n of m` in the status, and the union of findings. A
   review that silently covered 1/3 of a diff must not be reportable as a review.
3. **Over-ceiling with no chunker available is exit 3, not a truncated pass.** Fail closed, same as
   the reviewer-unconfigured red.
4. **The fixed-remote-path race is a correctness bug, not a concurrency nicety**: two runs clobbering
   one path can return another run's findings. Until the path is run-scoped, use a lock that *fails*
   rather than waits, so a second run is visibly refused instead of silently merged.
5. Large-context BYOK stays a **correctness** requirement: Workers AI models 413 on the baseline
   payload before any diff (llama-3.3-70b 24k, qwen2.5-coder-32b 32k).

## 6. Prioritised hardening, with the cheapest guard for each

| # | Harden | Cheapest guard that would have caught it |
|---|---|---|
| 1 | ChittyCorp `default`: unauthenticated account default | A `--check` assertion that no gateway has `is_default && !authentication`. One field read. |
| 2 | Five chittymarket branches would revert the retirement on merge | Already built: `scripts/tests/test-review-default-model.sh` (commit `440d272`, UNPUSHED) wired into `validate-chittymarket.yml`. **Pushing that branch is the single highest-value action in this pass.** It guards the default only; an explicit `REVIEW_MODEL=...dynamic/...` override is out of scope by design. |
| 3 | 128KB silent under-review | Assert the reviewer refuses (exit 3) above ceiling with no chunker — a unit test on the size branch, no network. |
| 4 | Reviewer self-race on a fixed remote path | A lock file whose acquisition failure is an error; a test that two concurrent invocations yield one run and one refusal. |
| 5 | `_MAP` projects a kind a runtime cannot execute | The `executable` column + an `add-target` refusal. A dict edit and one assertion. |
| 6 | chittyconfig `PLACEHOLDER_KV_*` (wrangler.jsonc:26-27) | A deploy-blocking grep for `PLACEHOLDER_` in `wrangler.jsonc`. Unprovisioned KV in the config-governance service is the worst possible place for it. |
| 7 | Gateway/namespace linkage by coincidence | `domains.json` + `--check` for a domain missing either half. |
| 8 | Uncapped spend on `default` | Blocked on measurement: per-gateway spend limits are UNVERIFIED on three accounts. Guard is "a domain record must declare a cap", not "a cap exists". |
| 9 | Naming drift on new ids | A `--check` regex over new gateway/namespace/instance ids, with an explicit grandfather list carrying a reason per entry. |

Items 2, 3, 5 and 6 are repo-local, no operator gate. Items 1 and 8 are the only infra-mutating ones
and route through ChittyConnect.
