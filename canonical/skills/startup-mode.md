---
name: startup-mode
description: The operator's standing cost-discipline posture for this self-funded phase, and the single written source for it. Load it before any decision that creates, keeps, or justifies recurring spend — provisioning or re-provisioning a database, adding a Neon project or branch, adding a metered binding or paid SDK, adding a cron or long-lived poller that touches Postgres, adding CI to a private repo, choosing Postgres vs D1 vs R2 SQL vs KV vs Sheets, or claiming that a change saves money. Also load it when the words "startup mode", "lean", "cost", "spend", "cheaper", "scale to zero", or "off Neon" appear. It is gated on `policy.startup_mode.active` in the operator manifest — read that flag first, because when it is false the posture does not apply. It carries the three levers, the measurement precondition (comptroller cannot measure infra spend — Neon's consumption API is the source), the non-linear poller problem, and the boundary of what startup mode may never override.
canon_uri: chittycanon://core/services/chittymarket#skills/startup-mode
kind: skill
classification:
  - governance
  - defaults
  - cost
  - infrastructure
runtimes:
  - claude-code
  - codex
plugin: chittyos-core
canonical_capability_ref: "chittycanon://capability/workspace/startup-mode"
overlay:
  title: "Startup Mode"
  capability_group: "workspace"
  group_assignment_source: "name-rule"
  execution_class: "@chitty/ambient"
  canonical_version: "1.0.0"
  projection_version_policy: "inherit-canonical"
  ontology:
    primary:
      - "P"
    secondary:
      - "E"
      - "T"
  authority:
    requires_chittyid: true
  execution:
    default_surface: "ch1tty"
    local_allowed: true
    context_cost: "low"
    mutation_risk: "low"
  discovery:
    indexable: true
    session_index: "summary"
    ambient_by_intent: true
    verbs:
      - "default"
      - "measure"
      - "gate"
    fallback_search: true
  auth_flow:
    mode: "local-only"
    stores_credentials_in: "n/a"
    fail_closed_if_unavailable: false
  runtime_exclusions: {}
  phase0_audit:
    job_to_be_done: "verify"
    environmental_footprint: "admin-system"
    evidentiary_risk: "none"
    advisory_disposition: "local-only"
  legacy_category: "ecosystem"
  deprecated_aliases: []
  visibility: "recommended"
  access: "readwrite"
  compatible_channels:
  - claude_code
  - claude_ai
  - claude_desktop
  - chatgpt
  - codex
  - openclaw
  source_links:
  - local://canonical/skills/startup-mode.md
---

# Startup mode

The operator is in a **self-funded phase running deliberate cost reduction**. Startup
mode is that posture. It constrains **what you build and what you keep running** — it is
not a licence to build less carefully.

**This document is the source.** Before it existed, startup mode lived only in past
conversations and was reconstructed at least twice (2026-07-13, then 2026-09-17), drifting
each time. It supersedes and replaces these as sources of truth:

| Superseded | Where |
|---|---|
| `feedback_startup_mode` | chittyfinance project memory |
| `startup-mode-taskboard-state` | workspace memory |
| `startup-mode-neon-exit` | chittycan project memory |
| `neon-core-never-idles` | chittyregister project memory — the measured basis for *Pollers*, below |
| `[STARTUP MODE]` header + "Knowledge & Constraints" | `chittyentity/workers/MASTERBOARD.md`, `chittyreception/MASTERBOARD.md` |

Those notes stay as history. Cite **this** file when acting. If you learn something new
about the posture, amend this file in the same session — the recorded lesson behind this
skill is that *decisions must land in canon at decision time*, and the policy itself was
the counter-example.

## Is startup mode ON? Read the flag first (BINDING)

`~/.ops/operator-manifest.json` → **`policy.startup_mode.active`** is the switch. Read it
before applying anything below. Until 2026-10-03 this skill only ever read
`monthly_ceiling_usd` from that object and treated the posture as unconditional, so the
operator had a toggle that nothing honoured — turning it off changed no behaviour.

```bash
jq -r '.policy.startup_mode.active' ~/.ops/operator-manifest.json
```

- **`true`** — the posture applies in full. Everything below is binding.
- **`false`** — startup mode is OFF. Do **not** apply the three levers, do not argue a
  design down on recurring-spend grounds, and do not cite this skill as a constraint. Say
  in one line that startup mode is off, then decide on the merits.
- **absent, unreadable, or not a boolean** — treat as **ON**. Fail closed: the cost of
  wrongly economising is a slower design, and the cost of wrongly spending is a bill the
  operator did not choose. Say which one you read and that you defaulted.

Off does not mean *spend freely*. The ceiling, the measurement precondition and the
"what startup mode does NOT override" section are separate concerns — a disabled posture
is not a disabled budget. What switches off is the **argument**, not the accounting.

Report the flag's value whenever you invoke the posture to block or reshape a decision,
so a reader can tell a live constraint from a stale one.

## The three levers

1. **No always-on compute where a cache will do.** Serverless and event-driven by
   default. A process that is merely awake still bills.
2. **Let Neon scale to zero, protected by a cheap middleware layer.** Neon's idle
   timeout is **300 s by default** and is configurable per endpoint (`suspend_timeout_seconds: 0`
   means "use the default") — read the endpoint's actual value rather than assuming five
   minutes. The canonical shape is `chittyagent-tasks`: *Neon authoritative, Notion intake,
   KV hot cache* with short TTLs (60 s lists / 600 s items) that absorb agent polling so the
   database gets a genuine idle window. **On write paths carrying enforcement or custody
   data, use a Queue, not KV** — KV is eventually consistent, and a lost row makes caps
   under-enforce.
3. **Migrate off Neon where possible; never *default* to re-provisioning Postgres.**
   Several stores are Postgres-backed by inertia, not by need. Placement is an open
   decision every time, not an inherited one.

## Measurement precondition (BINDING)

**Do not cite `comptroller` for infrastructure spend.** Comptroller tracks **AI-gateway
spend only** (order of $0.20 MTD across all services). It holds no Neon compute data, so
it cannot validate or falsify lever 2 — and, per *Pollers* below, it is itself the largest
driver of the cost it cannot see. The old "check comptroller first" precondition is
unsatisfiable as written, and waiting on it has blocked this work before.

The measurement of record for database spend is **Neon's own consumption history** —
`active_time` / `cpu_used_sec` per project for the current billing period — read via the
Neon MCP or Neon's REST consumption endpoint. Discover the current endpoint from Neon's
live API rather than trusting a path written here.

Rules:

- **Measure before you claim.** No "this reduces cost" without the project-level number
  that shows it.
- **Measure after you ship.** A merged saving is $0 saved until re-measured. Landing the
  PR is not the evidence; the post-merge `active_time` is.
- **Measure before you migrate.** A store that is nearly empty is nearly free to port;
  that is an argument for the port, and it is also why the saving may be nil.
- If the measurement is unavailable, say the lever is unverified. Do not substitute a
  proxy metric and present it as spend.

## Pollers: why lever 2 has never worked, and why fixing one changes nothing

Measured 2026-09-17 on the shared Neon project **ChittyOS-Core**
(`restless-grass-40598426`, endpoint `ep-green-water-ael1lksw`): continuously awake since
2026-09-03, pinned at the 0.25 CU floor 24/7 — ~180 CU-hours/month, order **$25–30/month**
for a database doing no real work (measured average 0.246 CU against a 0.25 floor). Nothing
is misconfigured. The compute is re-woken before it can ever suspend.

**Three pollers each independently guarantee no suspension:**

| poller | cadence | where |
|---|---|---|
| ChittyComptroller `pollMetrics()` | `*/5` cron, always-on, no cache | `CHITTYOS/chittyops services/comptroller/worker.ts:447` |
| chittystorage embed backfill | `*/2` cron | `CHITTYOS/chittystorage src/embed.ts:133` |
| chittyverify fractal-evaluator | `while True` + `sleep(30)`, long-lived connection | `CHITTYOS/chittyverify jobs/fractal-evaluator/evaluator.py:59` |

**Because each one alone defeats the idle window, fixing any single one saves nothing.
The saving is non-linear — it arrives only when the last one is fixed.** Any report that
claims a saving from one of these in isolation is wrong. Expect a large drop when all land,
not a flatline: the remaining `*/15` crons (8 across chittyentity's agents, plus
chittyregister's) are **unverified for Neon use** — if they touch it, the compute wakes
~4×/hr for ~5 min, ≈33% duty cycle. Then re-measure.

Three traps:

- **A wrangler-config audit cannot find the decisive one.** The fractal-evaluator is a
  **Nomad job on the homelab cluster** holding a persistent connection, invisible to any
  sweep of `wrangler.jsonc` files. Audit the cluster too.
- **The cost-control service is the largest driver.** Comptroller is marked
  pause-exempt/always-on, so nothing throttles it, and it measures AI-gateway spend only,
  so it is structurally blind to the Neon compute it causes. Its CHARTER promises `<5 min`
  anomaly *latency* — a latency guarantee, not a polling-frequency one.
- **The query cost is irrelevant.** These queries are sub-millisecond; the cost is
  *wakefulness* alone. Optimising the query, or choosing which query runs, achieves
  nothing.

**The fix is an intermediary, not a slower cron.** A slower cadence or query caching buys
the saving by evaluating caps on stale totals. Publishing cost rows to a Queue as the
**single ingress** makes "no messages" a *proof* that no spend landed — so skipping the
database is exact rather than stale, and detection latency improves. Work in flight:
`chittyops#121` (measurement), `chittyops#122` (the queue rework — retarget onto
`chittyagents/comptroller/src/engine.ts`; the two copies differ by ~164 lines, a port not a
cherry-pick), `chittyops#125` (removes the service's crons), `chittyverify#60`,
`chittystorage#84`. **Verify each state live before citing it** — as of 2026-09-21 none had
merged.

**`chittyentity#585` is not this fix.** The idle-gate PR is open, not a draft, untouched
since 2026-08-09 — and it gates `chittyagent-tasks`, which is *not* one of the three
decisive pollers. Merging it does not move ChittyOS-Core. It is still the reference
implementation of the idle-gate pattern; it is not a discharge of lever 2.

Apply to any new timer or long-lived loop that touches a database:

- Does this need to run on a timer at all, or can it be event-driven?
- If it must, does it check a KV activity marker (or an empty queue) before opening a
  connection?
- Is it a Worker cron, or something a wrangler audit will never see?

## Placement: Postgres vs D1 vs R2 SQL vs KV vs Sheets

When a binding is broken, missing, or being re-provisioned, **do not** reach for
"recreate the Postgres/Hyperdrive binding." Run this:

1. **Measure the footprint** — tables, rows, write rate, storage.
2. **Check portability.** `TIMESTAMPTZ`, `UUID`, `JSONB`, `ON CONFLICT` all map cleanly
   to D1/SQLite. Real blockers: Postgres extensions and GIN indexes — especially
   `pg_trgm` fuzzy matching (FTS5 or `LIKE` may suffice if fuzzy match is not
   load-bearing) — and **exact-decimal money**, which SQLite has no equivalent for.
3. **Match the shape to the substrate.** Append-only event data with time-bucketed
   aggregates belongs in **Pipelines → Iceberg on R2, queried with R2 SQL**: serverless
   over R2, so there is no compute to keep awake and the sleep problem ceases to exist
   rather than being managed. R2 SQL gained window functions, `DISTINCT`, set operations
   and further aggregates on 2026-06-21, which is what made this viable. Check
   Cloudflare's **current** Pipelines/R2 pricing before quoting a figure — do not trust a
   number written here. See the `chitty-pipelines` skill for the stream→SQL→sink→R2 shape.
4. **Sheets is a sanctioned substrate, within limits.** The MASTERBOARDs mandate
   "Database-in-a-Sheet" — `chittyentity/workers/MASTERBOARD.md:45` says *"Google Sheets as
   the primary DB; Neon only for critical state"*; `chittyreception/MASTERBOARD.md:44` says
   *"Sheets as the primary DB; Cloudflare KV for caching."* Sheets is acceptable for
   intake, triage and lead data. It has no transactions, no query layer, and no custody
   guarantees, so it is **not** acceptable for anything in *What startup mode does NOT
   override*. If you believe Database-in-a-Sheet is retired, get that decided and amend
   this file — do not narrow the option set silently.
5. **Surface the choice** — Postgres vs D1 vs R2 SQL vs KV vs Sheets vs defer. Never pick
   silently.

**Carry the Postgres guarantees you are dropping.** Iceberg has no unique constraint and
Pipelines SQL transforms are stateless, so an `ON CONFLICT (…) DO NOTHING` idempotency
strategy — e.g. deliberately re-fetching a high-water-mark boundary and relying on the
conflict to no-op — **double-counts** after the move. Tighten the high-water mark to
strict `gt`, or dedup at query time. Fix it deliberately in the migration; do not
discover it in the system that enforces caps. Materialized views and their refresh
functions also do not come along.

### Both precedents matter

- **Move:** `chittycanon` #54 — 11 tables of mostly-read governance data whose Hyperdrive
  config pointed at a retired account. Correct to move. But **its cost justification is
  false**: canon sits inside the shared ChittyOS-Core project, which stays up for everyone
  else, so moving canon out saves approximately nothing. The real grounds are the
  ChittyCorp→ChittyFoundation account split and decoupling. Say the true reason. (The
  project's table/schema/storage totals quoted in earlier reconstructions are
  **unverified** — re-measure before using them in an argument.)
- **Stay:** `chittyfinance` — 22 exact-decimal money columns with no SQLite equivalent.
  The recommendation was to **stay on Neon** while keeping new code D1-portable (drizzle
  `db.batch`, plain conditional `UPDATE`, `INSERT … SELECT`; no WebSocket or pooled
  drivers, no Postgres-only constructs unless the choice is surfaced). This is startup
  mode operating correctly: price it, then decline.

Declining is a valid outcome. "Cheaper" and "adequate" are different findings.

## Metered CI

Private repos mean **Actions minutes are metered** — recurring spend, in scope here.

- No browser/toolchain downloads in CI (a Chromium install per PR is the expensive part).
- Tests needing an absent browser must **skip loudly**, with a message saying how to run
  them locally. A skip may never be reported as a pass.
- Many workflows are gated on `vars.CI_ENABLED`, which is unset (as of 2026-09-21,
  nearly every chittyentity workflow references it). The gate's mechanism is in the workflow files; **no file records
  why**, so treat any explanation of its origin as unsourced. **Verify before flipping it:**
  enabling the variable can light up 20+ workflows across every open PR at once. Prefer one
  narrowly-scoped workflow over a global switch.
- **A `CI_ENABLED`-skipped job reports neutral, not failed, and therefore does not satisfy
  `nb-development-defaults` precondition 2** ("the CI gates on this repo can actually
  fail"). Where startup mode has gated CI off, the execute-now licence is **withdrawn** for
  that repo — propose instead, or stand up one real gate first. Startup mode does not get to
  disable the gate and then borrow its authority.
- Check the schedule comment against the schedule. A cron documented at one cadence and
  running at another has shipped in this fleet; cite the file:line when you find one.

## Spend ceiling

**$20/month, fleet-wide, ratified by the operator 2026-09-21.** Read it live from
`~/.ops/operator-manifest.json` → `policy.startup_mode.monthly_ceiling_usd`; the manifest
is authoritative if this line and it ever disagree. Its origin is
`chittyreception/MASTERBOARD.md:43` (*"Keep monthly spend <$20"*, blank in the chittyentity
twin), promoted from one app's limit to the whole fleet's on ratification.

**Act as though the fleet is already over it, because it is.** ChittyOS-Core's idle Neon
compute alone measured **$25–30/month** on 2026-09-17 (see *Pollers*) — more than the
entire ceiling, for a database doing no work. Two consequences, both binding:

- The poller work is not an optimisation, it is the ceiling. Treat `chittyops#121/#122/#125`,
  `chittyverify#60`, `chittystorage#84` as the path back under $20, and re-measure after the
  last one lands.
- Any **new** recurring line item needs the ceiling cited and the headroom stated. There is
  currently no headroom, so "it's only a few dollars" is not an argument — it is the whole
  remaining budget several times over.

Sibling, not duplicate: per-session LLM/subagent spend is governed by **Orchestration
Budget Discipline** in `~/.claude/CLAUDE.md`. Read it there.

## What startup mode does NOT override

This is the section that gets abused. Startup mode changes **substrate and cadence**. It
never changes **whether the work is done right**.

1. **It never suppresses a record.** The test is open-form: **any record whose absence
   would be a data-loss finding** must still be written — fact-governance data, evidence
   custody, the ChittyLedger hash chain, ChittyID minting, audit and custody trails are
   examples, not the whole list. Moving a write from Postgres to Sheets, R2, or a queue is a
   placement decision; **dropping it is not a cost measure, it is data loss.**
   The substitute must be **acknowledged, durable, readable back, and alerting on
   failure.** A fire-and-forget `fetch(...).catch(console.error)` satisfies none of those
   and does not count. Neither does an eventually-consistent KV write on an enforcement
   path: a swallowed refresh failure that reads "missing snapshot" as "nothing to breach"
   fails **open**, and that has already happened here.
2. **It does not license mocks, fake data, placeholder endpoints, or non-working routes.**
   The No-Mocks rule is binding and independent. "We'll wire it when we can afford it" is
   a placeholder.
3. **It does not license skipping discovery or separated adversarial review.** Stated
   already in `legal-operating-defaults`: startup mode "constrains what you build, and it
   does not license skipping the review and discovery conditions." The execute-now licence
   in `nb-development-defaults` still requires its three preconditions — see the CI note
   above for how startup mode can *remove* that licence.
4. **It does not touch credential routing.** Connection strings and tokens route through
   ChittySecrets / ChittyConnect regardless of substrate. A cheaper database does not get
   a hardcoded URL.
5. **It does not override matter isolation or privilege boundaries** in legal work.
6. **It is not a reason to leave the fix unshipped** — and shipping is not the finish
   line. An unmerged saving is $0 saved; a merged saving is $0 saved until re-measured.
   Item 6 does not relax *Measure before you claim*.

### The live divergence — read it, do not copy it

`chittyreception` branches on an env flag `STARTUP_MODE`. What it actually does, verified:

- `src/lib/chittyos-integration.ts:270-285` — the Sheets write is **additive**, not a
  failover: the block falls through to the ChittyChronicle POST with no `else`. It posts to
  `…/AKfycbz_CHITTY_DRL_INGEST/exec`, which is a **placeholder deploy ID**, and swallows
  failure with `.catch(console.error)`. That is item 1 and item 2 both, in four lines.
- `src/routes/webhooks.ts:437` and `:516` skip the Postgres mirror for messages and calls,
  but each is followed by a `chronicle.logEvent(…)` — the event is recorded elsewhere, so
  these are placement, not loss.
- `src/routes/webhooks.ts:496-511` skips `createAuditLog('identity.phone.linked')` with
  **no fallback at all**. That is the one genuine record loss, and the defect worth filing.
- While reading that file: `:503` mints with `'PERSON'`. Canon is exactly `P|L|T|E|A` per
  `chittycanon://gov/governance#core-types`. File both.

Note before filing: `chittyreception` is itself marked for sunset
(`chittyentity/workers/MASTERBOARD.md:28`) and the skip-write pattern was **not** ported —
`STARTUP_MODE` appears nowhere in `chittyentity/workers/` or `chittyagents/`.

## Triggers — when to apply this contract

Check this file when any of these appear in the diff or the plan:

- A new or re-provisioned database binding, Neon project, or Neon branch.
- A new Hyperdrive config, or any new binding to a metered service.
- A new paid SaaS SDK or dependency.
- A new cron, scheduled handler, or long-lived poll loop — Worker **or** Nomad job — on
  anything that touches a database, or a cadence change to one.
- A new CI workflow, or a toolchain install step, in a private repo.
- Any claim in a PR body, commit message, or report that a change reduces cost.
- Enterprise-SaaS replacement work in flight: OpenPhone → Twilio, Neon → D1/Sheets/R2 SQL,
  1Password → ChittySecrets (1Password is retired and non-functional on this host).

## Reporting

When startup mode changes a decision, state three things: **the measured number**, **the
substrate chosen and what it gives up**, and **whether the saving is real or the
justification is something else**. A cost claim without a number is not a finding.
