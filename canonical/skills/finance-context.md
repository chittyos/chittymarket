---
name: finance-context
description: Company-specific operating context for all ARIBIA / IT CAN BE LLC finance work in ChittyFinance. Use for any finance, accounting, bookkeeping, Mercury, bank reconciliation, COA, allocation, Schedule E, Wave, Stripe, statement, payee/recipient, webhook, payment, or close task. Defines business identity vs technical data scope, the portfolio, ChittyFinance authority, Mercury integration and credential rules, the COA trust path, allocation engine, tooling priority, and guardrails.
canon_uri: chittycanon://core/services/chittymarket#skills/finance-context
kind: skill
plugin: chittyfinance
runtimes:
  - claude-code
  - codex
  - chatgpt
classification:
  - finance
  - banking
  - accounting
  - defaults
canonical_capability_ref: "chittycanon://capability/workspace/finance-context"
overlay:
  title: "Finance Context"
  capability_group: "workspace"
  group_assignment_source: "category"
  execution_class: "@chitty/reasoning"
  canonical_version: "1.0.0"
  projection_version_policy: "inherit-canonical"
  ontology:
    primary:
      - "P"
    secondary:
      - "L"
      - "T"
      - "E"
  authority:
    requires_chittyid: false
    requires_governance_authority: false
    non_repudiation_required: false
    evidence_gate: null
  execution:
    default_surface: "ch1tty"
    local_allowed: true
    context_cost: "medium"
    mutation_risk: "high"
  discovery:
    indexable: true
    session_index: "visible"
    ambient_by_intent: true
    verbs:
      - "reconcile"
      - "classify"
      - "report"
      - "sync"
      - "bank"
    fallback_search: true
  auth_flow:
    mode: "service-token"
    stores_credentials_in: "ChittySecrets"
    fail_closed_if_unavailable: true
  runtime_exclusions: {}
  phase0_audit:
    job_to_be_done: "govern"
    environmental_footprint: "admin-system"
    evidentiary_risk: "financial"
    advisory_disposition: "skill"
  legacy_category: "finance"
  deprecated_aliases: []
  visibility: "recommended"
  access: "readwrite"
  compatible_channels:
    - claude_code
    - chatgpt
    - codex
  source_links:
    - https://github.com/chittyapps/chittyfinance
    - https://docs.mercury.com/reference
---

# Finance Plugin — Company Context (ARIBIA / ChittyOS)

Read this before running any finance skill. It overrides generic ERP/corporate assumptions with the actual furnished-rental operating model.

> Outputs are working artifacts for review. Label placeholders `[mock]` and synthesis `[synthesis]`.

## 1. Financial authority

- **ChittyFinance** (`https://finance.chitty.cc`) is the financial subledger / system of record for normalized transactions, COA classification, property P&L, allocations, reporting, Schedule E workspaces, and forensic accounting.
- **Mercury** is the underlying banking/cash source of truth.
- **Wave** is secondary books/invoicing and is reconciled against ChittyFinance, not the reverse.
- **Stripe** is a payment processor/feed.
- Never create a parallel ledger, database, or schema for a finance workflow.
- Prefer existing ChittyFinance/ChittyConnect ingestion, reconciliation, and allocation paths over direct database writes.

### ChittyFinance API surface

| Domain | Endpoints |
|---|---|
| Summary / transactions | `/api/financial-summary`, `/api/transactions`, `/api/transactions/export?format=csv|ofx|qfx` |
| Data scopes / accounts | `/api/tenants`, `/api/tenants/:id/settings`, `/api/accounts` |
| Properties | `/api/properties`, `/api/properties/:id/{financials,rent-roll,pnl,valuation}`, `/api/leases/expiring?days=N` |
| Allocations | `/api/allocations/{rules,preview,execute,runs}` |
| Classification / COA | `/api/classification/{queue,suggest,classify,bulk-accept}`, `/api/chart-of-accounts` |
| Tax / reports | `/api/tax/schedule-e`, `/api/tax/line-summary`, `/api/reports/consolidated`, `/api/portfolio` |
| Imports | `/api/import/{turbotenant,mercury,hd-pro,amazon,rei-hub,wave-sync}` |
| Forensics | `/api/forensics/*` |
| Integrations | `/api/integrations/status`, `/api/mercury/{accounts,select-accounts}`, webhook receivers under `/api/webhooks/mercury/:tenantId` |

Check `GET /health` and `GET /api/v1/status` before claiming ChittyFinance is unavailable.

## 2. Business identity is not `tenant_id`

**Never use `tenant_id` as the legal/business ontology.** In ChittyFinance it is a technical data-scope/partition key. It may correlate with a business or property workspace but is not authoritative legal identity.

Resolve business identity from the canonical registry / executed governing records first. Use ChittyStorage/ChittyRegister business identity resolution when available. Do not infer identity from bank nicknames, secret names, or connector labels.

### Canonical businesses / ARIBIA subdivisions

- **IT CAN BE LLC** — Wyoming holding company; owns ARIBIA LLC.
- **ARIBIA LLC** — Illinois Series LLC.
  - **ARIBIA LLC – MGMT** — management series/business.
    - **FURNISHED-CONDOS.COM** — DBA/brand/connection projection of ARIBIA LLC – MGMT.
    - **Chitty Services** — DBA/brand/connection projection of ARIBIA LLC – MGMT.
  - **ARIBIA LLC – CITY STUDIO** — ARIBIA series/business.
  - **ARIBIA LLC – APT ARLENE** — ARIBIA series/business.
- **JEAN ARLENE VENTURING LLC** — separate S-corp/business.
- **MR NICE WEIRD LLC** — separate legal business.
- **Nicholas Bianchi personal** — person/personal banking boundary, not a business/DBA.
- **ChittyCorp LLC** — pending formation unless a higher-authority current registry says otherwise; do not book to it as an existing entity.

### Operational Mercury credential-boundary codes

These codes identify a Mercury credential/connection boundary. They are **not ontology values, GL codes, or legal names**.

| Code | Credential/connection projection | Canonical business identity |
|---|---|---|
| `ARIBIA` | ARIBIA LLC Mercury boundary | ARIBIA LLC |
| `FC` | FURNISHED-CONDOS.COM Mercury boundary | ARIBIA LLC – MGMT |
| `CHIT` | Chitty Services Mercury boundary | ARIBIA LLC – MGMT |
| `CITY` | CITY STUDIO Mercury boundary | ARIBIA LLC – CITY STUDIO |
| `APT` | APT ARLENE Mercury boundary | ARIBIA LLC – APT ARLENE |
| `ICB` | IT CAN BE LLC Mercury boundary | IT CAN BE LLC |
| `JAVL` | JEAN ARLENE VENTURING LLC Mercury boundary | JEAN ARLENE VENTURING LLC |
| `MNW` | MR NICE WEIRD LLC Mercury boundary | MR NICE WEIRD LLC |
| `NAJB` | Nicholas Bianchi personal Mercury boundary | Nicholas Bianchi (person) |

`APT` is the credential shortcode. Do not use `APTA` for Mercury credential resolution.

`FC` and `CHIT` can expose distinct Mercury account sets while resolving to the **same business identity**. Preserve connector provenance and Mercury external IDs; never duplicate a transaction or create duplicate ledgers because the same business is visible through multiple DBA connections.

## 3. Mercury banking integration

For **any Mercury task**, read `references/mercury.md` before acting. It contains the current operation matrix, canonical docs links, webhook lifecycle, statements/attachments, recipients/payees, invoices, transactions/categories, credential health, and read-vs-write routing.

Core rules:

1. **Webhook-first, reconcile second.** Use Mercury webhooks as the near-real-time path; use recurring reconciliation/backfill against Mercury as the source of truth.
2. **At-least-once delivery.** Deduplicate webhook events by Mercury event ID and maintain transaction idempotency.
3. **No fake financial activity.** Never create artificial payments, recipients, transfers, or transaction edits merely to keep a token active or preserve write scope.
4. **Credential health belongs inside the regular Mercury sync loop.** Normal read activity can keep read tokens active; write-scope inactivity must be reported if no legitimate write occurs.
5. **Reads and writes are separate credential/routing concerns.** Use `MERCURY_TOKEN_*` for read bindings and existing `MERCURY_WRITE_TOKEN_*` credentials for writes. Do not create a parallel `MERCURY_ISSUED_*` namespace unless Canon explicitly changes the contract.
6. **Write path fails closed.** When the relay/static-egress address, proxy token, Access credentials, write credential, IP verification, or policy gate is unavailable, stop the write. Never silently fall back to direct Cloudflare shared egress.
7. **Mutations require idempotency.** Generate deterministic idempotency keys and preserve audit receipts for write operations.
8. **Resolve business identity before credential label.** Connector names and secret suffixes are projections, not legal/business identity.

## 4. Properties (5; do not collapse)

| Property | Title / ownership | Managed by | Income → |
|---|---|---|---|
| City Studio — 550 W Surf C211 | ARIBIA-owned | ARIBIA LLC – MGMT | ARIBIA |
| Villa Vista / APT ARLENE — 4343 N Clarendon #1610 | ARIBIA-owned | ARIBIA LLC – MGMT | ARIBIA |
| Lakeside Loft — 541 W Addison #3S | personally titled | ARIBIA LLC – MGMT | JAVL |
| Cozy Castle — 550 W Surf C504 | personally titled | ARIBIA LLC – MGMT | personal |
| Morada Mami — Medellín | ARIBIA series/history | — | — |

Never derive property ownership solely from a Mercury nickname or ChittyFinance data scope.

## 5. COA and dimensions

ChittyFinance uses a database-backed COA and an L0→L4 trust path. The GL code answers **what the transaction is**, not which business/property it belongs to.

- `tenant_id` → technical data scope only.
- property → `property_id` / `unit_id` or canonical property mapping.
- business/legal identity → separate business/entity resolution.
- GL/COA code → account/category of the money movement.
- booking channel → separate metadata/dimension when available.

Examples of actual COA codes include `4005` rent, `5200` HOA dues, etc.; do not invent codes. Pull current COA from ChittyFinance before classifying.

Mercury custom category should carry a single intended dimension according to the current COA spec; do not overload it with composite property/entity/status strings.

### Classification trust path

| Level | Meaning | Path |
|---|---|---|
| L1 | AI suggestion | `POST /api/classification/suggest` |
| L2 | authoritative classification | `POST /api/classification/classify` |
| bulk accept | confidence ≥ 0.80 and amount ≤ $500 | `POST /api/classification/bulk-accept` |
| L4 | COA admin | owner/admin only |

## 6. Inter-company allocations

Use the allocation engine, not manual offsetting journal entries, for:

- `management_fee`
- `cost_sharing`
- `rent_passthrough`
- `custom_pct`

Preview before execute, then audit the allocation run.

## 7. Tooling priority

1. **ChittyFinance** for normalized finance state, COA, property, allocation, reporting, tax, and forensic data.
2. **Mercury connector/API via ChittyConnect** for live bank state, statements, recipients, webhooks, and operations not yet reflected in ChittyFinance.
3. **Wave / Stripe** for source-system detail as needed.
4. **Neon** read-only only when necessary; no new schemas/databases without explicit approval.
5. **Notion/Drive/registries** for metadata, governing records, and source documents—not a transaction ledger.

## 8. Per-skill retargeting

- **reconciliation** → Mercury ↔ ChittyFinance ↔ Wave; per-property cash; missing transaction/backfill; account binding; webhook coverage.
- **financial-statements** → property P&L/NOI and consolidated/entity reports from ChittyFinance.
- **journal-entry** → rental accounting; inter-company through allocation engine.
- **variance-analysis** → period-over-period by property and COA.
- **close-management** → ingest → classify → allocate → reconcile Mercury → report/tax roll-up.
- **audit-support** → forensic accounting/litigation support via ChittyFinance forensics; legal work product stays in the Legal space.

## 9. Guardrails

- No new database/schema/parallel ledger without explicit approval.
- Do not conflate business identity, DBA/brand, Mercury connection, credential code, property, account, GL code, or `tenant_id`.
- Never expose raw Mercury tokens in output, logs, source control, ChittyFinance rows, or agent context.
- Never use a bank nickname as authoritative legal identity.
- Preserve external IDs, connector provenance, idempotency keys, and audit receipts.
- For legal evidence use the canonical Legal evidence pipeline; do not dump bank documents ad hoc into Drive.
- Do not infer completion from docs/config alone; verify deployed/runtime behavior.
