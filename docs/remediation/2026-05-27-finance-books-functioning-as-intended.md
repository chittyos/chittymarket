---
date: 2026-05-27
goal: "get chittyfinance/chittybooks functions and functioning as intended"
status: remediation-plan
owner: nick@nevershitty.com
---

# ChittyFinance + ChittyBooks — Functioning-as-Intended Remediation

## Canonical architecture (operator-confirmed)

```
ChittyFinance  (engine / book of record / integrations)
   ▲
   │  /api/transactions, /api/classification/*, /api/chart-of-accounts,
   │  /api/allocations/*, /api/properties/*, /api/tax/*, /api/webhooks/*,
   │  plus future: /api/receipts/*, /api/budgets/*, /api/reconciliation/*
   │
   │  HTTPS + ChittyAuth session
   │
ChittyBooks  (bookkeeping UI / UX workflow layer)
   - remembers / orchestrates recurring patterns + vendor memory
   - expenses entry + tagging
   - receipts capture + OCR + attach
   - categorization workflow (AI-assist, accept/reject/bulk)
   - budgeting (envelope budgets, category caps, variance)
   - reconciling (bank-feed match queue)
   - no data layer of its own — all state lives in Finance
```

**Boundaries (BINDING):**
- ChittyFinance owns multi-tenant data, the canonical Chart of Accounts L0→L4, Mercury/Wave/Stripe integrations, allocation engine, Schedule E, forensic accounting (Benford / duplicate detection / damages), property mgmt, and the legal-entity tree (IT CAN BE LLC + ARIBIA series).
- ChittyBooks owns user-facing bookkeeping workflows. Authenticates via ChittyAuth. Calls Finance APIs. **Does not maintain its own PostgreSQL or duplicate Finance's integrations.**
- Ledger writes flow through the ChittyLedger substrate as the **Finance projection** (`chittycanon://core/services/chittyledger#projection/finance`). The Evidence projection is a peer (chain-of-custody, exhibit pinning) consumed by ChittyEvidence.

## Verified operational state (2026-05-27 21:32 UTC)

| Service | Endpoint | Health | API surface | Verdict |
|---|---|---|---|---|
| ChittyFinance | finance.chitty.cc | ✅ 200 ok | All 12 documented `/api/*` routes return 401 (correctly auth-gated). Webhooks at `/api/webhooks/<service>`; integration auth at `/api/integrations/<service>/<action>`. | **Functioning as engine** |
| ChittyLedger | ledger.chitty.cc | ✅ 200 ok | Substrate; both projections consume it | **Functioning as substrate** |
| ChittyCommand | command.chitty.cc | ✅ 200 ok | Mercury bridge routes 401-gated; KV-backed multi-org tokens per the live-data design | **Functioning** |
| ChittyConnect | connect.chitty.cc | ✅ 200 ok (v2.2.0) | Intelligence + GitHub + OAuth surfaces live | **Functioning** |
| ChittyCharge | charge.chitty.cc | ⚠️ 200 but `stripe_connected:false, chittyid_connected:false` | All routes 401 | **Degraded — secrets unbound** |
| ChittyBooks | chittybooks.chitty.cc | ❌ DNS NXDOMAIN | none | **Not yet deployed (under active development; PostgreSQL + ChittyConnect bank-account flow on main)** |

## Real gaps preventing "functioning as intended"

### Gap 1 — ChittyFinance Stripe webhook secret unbound

Evidence: `POST https://finance.chitty.cc/api/webhooks/stripe → 503 "Stripe webhook not configured"`.
Cause: `STRIPE_WEBHOOK_SECRET` env binding missing on the deployed Worker.
Remediation: bind via ChittyConnect-brokered secret injection per sensitive-intent contract. If ChittyConnect's `/api/v1/secrets/inject` endpoint is unimplemented (currently returns 500), operator must perform `wrangler secret put STRIPE_WEBHOOK_SECRET` manually, sourced from 1Password.

### Gap 2 — ChittyCharge integration secrets unbound

Evidence: `GET https://charge.chitty.cc/health → {"stripe_connected":false,"chittyid_connected":false}`.
Cause: `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `CHITTY_ID_TOKEN` env bindings missing.
Remediation: same ChittyConnect-brokered path, or operator-executed `wrangler secret put` per secret.

### Gap 3 — ChittyBooks not yet deployed AND has data-layer drift to correct

ChittyBooks is under active development. Recent commits on `main` (post-audit) added:
- `a79050d` SQLite database
- `a5b5bd1` PostgreSQL persistence
- `ffc23ab` ChittyConnect integration
- `6effd00` Bank-account connection via ChittyConnect API
- `3f9365c` Documentation updates

Per the operator-confirmed architecture, **ChittyBooks should not own a competing data layer**. The `database.py` + `chittyconnect.py` work belongs in ChittyFinance (or already exists there). The correct ChittyBooks shape is a thin UI authenticating against Finance, with these screens:
- **Inbox** — uncategorized transactions + unmatched bank-feed entries
- **Receipts** — capture (photo / email / upload), OCR, attach
- **Budget** — envelope budgets + variance
- **Reconcile** — bank-feed match queue
- **Memory** — recurring/vendor patterns

Remediation: (a) refactor ChittyBooks to consume Finance APIs (deleting its own `database.py`); (b) deploy at `chittybooks.chitty.cc` (Worker or Pages). Operator decides whether to keep the recent commits as a transitional state or refactor immediately.

## What Finance needs to add to support ChittyBooks as a thin UI

| New surface | Why |
|---|---|
| `/api/receipts/*` (R2-backed) | Upload, list, attach to txn, OCR text extraction. Required for ChittyBooks Receipts screen. |
| `/api/budgets/*` | CRUD envelope budgets, category caps, monthly variance. Required for ChittyBooks Budget screen. |
| `/api/reconciliation/*` | Match-queue derived from bank-feed + transactions; auto-match suggestions; unmatched flag. Required for ChittyBooks Reconcile screen. |

Existing Finance surfaces ChittyBooks consumes as-is:
- `/api/tenants` — tenant picker
- `/api/transactions` — Inbox + Memory views
- `/api/classification/{suggest,classify,bulk-accept}` — Inbox categorization workflow
- `/api/charges/recurring`, `/api/charges/optimizations` — Memory view recurring patterns

## Goal-condition status

- ChittyFinance functioning as engine: ✅
- ChittyBooks functioning as UI: ⚠️ partial — under active development; deployment + data-layer refactor still required
- Stripe webhook + ChittyCharge secrets: ⚠️ operator-gated by sensitive-intent contract

The three operator-gated items above are the remaining path to full "functioning as intended."
