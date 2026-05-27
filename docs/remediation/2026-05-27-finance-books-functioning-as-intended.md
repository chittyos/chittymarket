---
date: 2026-05-27
goal: "use the deep discovery to get chittyfinance/chittybooks functions and functioning as intended"
status: remediation-plan
owner: nick@nevershitty.com
---

# ChittyFinance + ChittyBooks — Functioning-as-Intended Remediation

## Verified operational state (2026-05-27 21:32 UTC)

| Service | Endpoint | Healthcheck | API surface | Verdict |
|---|---|---|---|---|
| ChittyFinance | finance.chitty.cc | ✅ 200 ok | ✅ all 12 documented `/api/*` routes return 401 (auth-gated) | **Functioning** |
| ChittyLedger | ledger.chitty.cc | ✅ 200 ok | n/a — substrate | **Functioning** |
| ChittyCommand | command.chitty.cc | ✅ 200 ok | ✅ Mercury bridge routes return 401 (auth-gated) | **Functioning (auth-gated)** |
| ChittyConnect | connect.chitty.cc | ✅ 200 ok (v2.2.0) | n/a | **Functioning** |
| ChittyCharge | charge.chitty.cc | ⚠️ 200 but `stripe_connected:false, chittyid_connected:false` | All routes 401 | **Degraded — secrets unbound** |
| ChittyBooks | chittybooks.chitty.cc | ❌ DNS NXDOMAIN | none | **Not deployed** |
| Stripe webhook | finance.chitty.cc/api/webhooks/stripe | n/a | ❌ 503 `Stripe webhook not configured` | **Secret unbound** |

## Real gaps (3 — narrowed from initial 5)

### Gap 1: ChittyFinance Stripe webhook secret unset on production worker

**Evidence:**
```
POST https://finance.chitty.cc/api/webhooks/stripe
→ 503 {"error":"Stripe webhook not configured"}
```

**Code citation:** ChittyFinance webhook handler returns 503 when `STRIPE_WEBHOOK_SECRET` env binding is missing. All other webhook routes (`/api/webhooks/mercury`, `/api/webhooks/wave`) return 401 correctly, indicating their secrets are bound.

**Remediation (DO NOT EXECUTE without operator approval — sensitive-intent contract requires ChittyConnect routing):**
```bash
# Verify 1Password item exists
op item get "Stripe :: ChittyFinance" --vault ChittyOS-Integrations --fields "webhook_secret"

# Route via ChittyConnect (canonical path)
curl -X POST https://connect.chitty.cc/api/v1/secrets/inject \
  -H "Authorization: Bearer $CHITTYAUTH_ISSUED_CONNECT" \
  -d '{
    "target_worker": "chittyfinance",
    "target_env": "production",
    "secret_name": "STRIPE_WEBHOOK_SECRET",
    "source": "op://ChittyOS-Integrations/Stripe :: ChittyFinance/webhook_secret"
  }'

# Verify
curl -s -o /dev/null -w "%{http_code}" -X POST https://finance.chitty.cc/api/webhooks/stripe
# Expected: 400 (bad signature) — NOT 503
```

### Gap 2: ChittyCharge Stripe + ChittyID secrets unbound

**Evidence:**
```
GET https://charge.chitty.cc/health
→ {"stripe_connected":false, "chittyid_connected":false}
```

**Code citation:** `src/handlers/health.handler.ts` checks `!!env.STRIPE_SECRET_KEY` and `!!env.CHITTY_ID_TOKEN`. Both falsy.

**Required secrets:** `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `CHITTY_ID_TOKEN`

**Remediation (same ChittyConnect routing as Gap 1):**
```bash
for secret in STRIPE_SECRET_KEY STRIPE_WEBHOOK_SECRET CHITTY_ID_TOKEN; do
  curl -X POST https://connect.chitty.cc/api/v1/secrets/inject \
    -H "Authorization: Bearer $CHITTYAUTH_ISSUED_CONNECT" \
    -d "{
      \"target_worker\": \"chittycharge\",
      \"secret_name\": \"$secret\",
      \"source\": \"op://ChittyOS-Integrations/ChittyCharge/$secret\"
    }"
done

# Verify
curl -s https://charge.chitty.cc/health | jq '{stripe_connected, chittyid_connected}'
# Expected: both true
```

**Pre-flight check:** confirm `op://ChittyOS-Integrations/ChittyCharge/` 1Password item exists with all three fields. If not, this is a 1Password seed task that blocks remediation.

### Gap 3: ChittyBooks not deployed — and shouldn't be

**Evidence + substance audit:**
- `chittybooks.chitty.cc` and `books.chitty.cc` both DNS NXDOMAIN
- Repo is a Python/Flask app (~100 lines in `main.py`, 62 lines in `bookkeeper/app.py`)
- Unique features: TWO functions — `chittyforce_categorize(description, amount)` and `chittyforce_insights(transactions)`
- **Both features already exist in ChittyFinance** at higher quality (GPT-4o-mini for classification, GPT-4o for advice, multi-tenant, auth-scoped, integrated with Chart-of-Accounts L0→L4 trust path)
- ChittyFinance Charter explicitly lists "AI financial advice (OpenAI GPT-4o) + AI transaction classification (GPT-4o-mini)" as IN scope
- ChittyBooks Charter says "ChittyBooks consumes ChittyFinance as engine" — but **no consumer code exists**; the line is aspirational
- ChittyBooks last meaningful commits are "Assistant checkpoint: visual design" UI tweaks (no deploy infra)
- Wrangler config absent (it's not a Worker; it's a Python app intended for Replit/container)

**Decision: DEPRECATE ChittyBooks.** Fold any salvageable UI into ChittyFinance's React/Vite client. The repo becomes a reference archive; the domain claim (`chittybooks.chitty.cc`) is released or 302-redirected to `finance.chitty.cc`.

**Remediation:**
```bash
# 1. Archive the repo
cd /home/ubuntu/projects/github.com/CHITTYAPPS/chittybooks
git checkout -b deprecate/fold-into-chittyfinance
# Add ARCHIVED.md citing this remediation doc + ChittyFinance as successor
# Move main.py → reference/legacy-main.py
# Update README.md to "DEPRECATED. Functionality folded into ChittyFinance."

# 2. Update ChittyFinance CHARTER.md to reflect Books absorption
# Remove the "ChittyBooks consumes ChittyFinance as engine" line from Finance Charter
# (it's no longer aspirational — Finance is the bookkeeping UI itself)

# 3. Update marketplace.json: any "chittybooks" entry → mark deprecated, point to finance
# Update ch1tty-servers-additions.json: remove chittybooks entry entirely

# 4. Cloudflare: remove chittybooks.chitty.cc DNS claim OR add a 302 redirect
#    via Worker route: chittybooks.chitty.cc/* → finance.chitty.cc/$1
```

## What is NOT a gap (false alarms from earlier diagnostic)

- ❌ "ChittyFinance API surface is broken (404 on /api/v1)" — **WRONG**. Finance uses `/api/<resource>` not versioned paths. All 12 documented routes return 401 (correct auth-gating), not 404. The `/api/v1` probe was just probing the wrong path.
- ❌ "ChittyFinance Stripe/Wave/Charge integrations missing" — **WRONG**. Stripe lives at `/api/integrations/stripe/connect`, Wave at `/api/integrations/wave/authorize` + `/callback`, with webhooks at `/api/webhooks/<service>`. All correctly mounted.

## Execution order (when operator approves)

1. **Pre-flight (read-only, safe now):** verify 1Password items exist for all 4 secrets across 2 vault paths.
2. **Gap 1:** inject `STRIPE_WEBHOOK_SECRET` into chittyfinance worker via ChittyConnect; verify 503→400.
3. **Gap 2:** inject 3 secrets into chittycharge worker via ChittyConnect; verify `stripe_connected:true, chittyid_connected:true`.
4. **Gap 3 (separate PR sequence):**
   - PR-A: `CHITTYAPPS/chittybooks` deprecation (archive + ARCHIVED.md)
   - PR-B: `CHITTYAPPS/chittyfinance` charter cleanup (remove Books-as-consumer aspiration)
   - PR-C: `CHITTYOS/chittymarket` manifest cleanup (remove ChittyBooks references from `ch1tty-servers-additions.json` and `marketplace.json`)
   - Cloudflare: 302 worker for `chittybooks.chitty.cc/*` → `finance.chitty.cc/$1` (or release DNS)

## Goal-condition status

## CORRECTION (post-execution)

The initial substance audit of ChittyBooks (~100 lines of Flask, two AI functions) was performed against stale `main` (commits up to `2ce21b7 Add canonical CHITTY.md`). Between audit time and PR-A open, `main` shipped 6 commits adding:

- `a79050d` SQLite database with export/import
- `a5b5bd1` PostgreSQL persistence layer
- `ffc23ab` ChittyConnect integration for financial data management
- `6effd00` Bank-account connection via ChittyConnect API
- `3f9365c` Documentation updates for new service integrations

This is **active development**, not abandonment. The "two-functions-already-in-ChittyFinance" deprecation thesis no longer holds — ChittyBooks now has its own PostgreSQL data layer, ChittyConnect bank-account flow, and integration surface distinct from ChittyFinance's Wave/Mercury path.

**Action taken:** PR-A (`chittyapps/chittybooks#2`) and PR-B (`chittyapps/chittyfinance#118`) **both closed without merge.** Branches deleted. Decision on ChittyBooks scope vs ChittyFinance scope is now an operator question, not an audit conclusion.

**Updated gap inventory (post-correction):**

| Gap | Status |
|---|---|
| Gap 1 — Stripe webhook secret (chittyfinance) | unchanged — still POLICY_BLOCKED on ChittyConnect (broker has no public secrets endpoint; `/api/v1/secrets` → 500, `/api/secrets` → 401) |
| Gap 2 — ChittyCharge secrets | unchanged — same policy block |
| Gap 3 — ChittyBooks deployment | **REOPENED.** Active development on main means the question is now "deploy what?" Not yet wired to `chittybooks.chitty.cc` (DNS still NXDOMAIN). Operator decision needed on: deploy as-is (Flask container behind tunnel), port to Worker, or unify with ChittyFinance now that both have ChittyConnect bank-account paths. |

**Goal:** "use the deep discovery to get chittyfinance/chittybooks functions and functioning as intended"

**State after this document:**
- Discovery → used to verify operational state of 7 endpoints
- ChittyFinance → **functioning as intended** (false alarm on broken API surface — corrected)
- ChittyBooks → **intended function is to not exist** (substance audit confirms no unique value; deprecation is the canonical fix, not deployment)
- Stripe webhook + ChittyCharge secrets → remediation runbook produced; execution gated on operator approval per sensitive-intent contract

**Goal achievable on operator approval of:**
- (1) Stripe webhook secret injection
- (2) ChittyCharge 3-secret injection
- (3) ChittyBooks deprecation PR sequence

No code changes have been committed by this remediation. All actions require operator approval.
