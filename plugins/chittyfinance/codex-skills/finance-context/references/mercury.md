# Mercury Integration Reference

Use this file for Mercury banking, statement, webhook, payee/recipient, transaction, invoice, token, and write-path work.

## 1. Authorities and routing

- **Mercury** = banking source of truth.
- **ChittyFinance** = normalized financial subledger and reporting authority.
- **ChittyConnect** = integration/policy authority for Mercury access.
- **ChittySecrets / Cloudflare Secrets Store** = credential authority/custody.
- **mercury-proxy / static egress** = write-traffic egress path when write permissions require IP allowlisting.
- **ChittyLedger** = immutable audit receipts where supported.

Do not introduce another ledger or credential registry.

## 2. Official Mercury documentation

Primary index:
- https://docs.mercury.com/llms.txt
- https://docs.mercury.com/reference

Token/security:
- https://docs.mercury.com/docs/api-token-security-policies

Webhooks:
- https://docs.mercury.com/reference/webhooks
- GET webhooks: https://docs.mercury.com/reference/getwebhooks
- CREATE webhook: https://docs.mercury.com/reference/createwebhook
- UPDATE webhook: https://docs.mercury.com/reference/updatewebhook
- VERIFY webhook: https://docs.mercury.com/reference/verifywebhook
- DELETE webhook: https://docs.mercury.com/reference/deletewebhook

Statements:
- account statements: https://docs.mercury.com/reference/getaccountstatements
- treasury statements: https://docs.mercury.com/reference/gettreasurystatements

Recipients/payees:
- list recipients: https://docs.mercury.com/reference/getrecipients
- create recipient: https://docs.mercury.com/reference/createrecipient
- create recipient invite: https://docs.mercury.com/reference/createrecipientinvite
- list recipient invites: https://docs.mercury.com/reference/listrecipientinvites
- recipient attachments: https://docs.mercury.com/reference/listrecipientsattachments

Payments:
- direct send money: https://docs.mercury.com/reference/createtransaction
- request-to-send-money (approval queue): https://docs.mercury.com/reference/requestsendmoney

Transaction metadata/categories:
- update transaction metadata: https://docs.mercury.com/reference/updatetransaction
- edit custom category: https://docs.mercury.com/reference/editcategory

Accounts receivable:
- list customers: https://docs.mercury.com/reference/listcustomers
- create invoice: https://docs.mercury.com/reference/createinvoice

Before implementing an endpoint not listed here, consult Mercury `llms.txt` / current OpenAPI instead of guessing request fields or scopes.

## 3. Credential/connection codes

| Code | Connection/credential boundary | Business identity |
|---|---|---|
| ARIBIA | ARIBIA LLC | ARIBIA LLC |
| FC | FURNISHED-CONDOS.COM | ARIBIA LLC – MGMT |
| CHIT | Chitty Services | ARIBIA LLC – MGMT |
| CITY | CITY STUDIO | ARIBIA LLC – CITY STUDIO |
| APT | APT ARLENE | ARIBIA LLC – APT ARLENE |
| ICB | IT CAN BE LLC | IT CAN BE LLC |
| JAVL | JEAN ARLENE VENTURING LLC | JEAN ARLENE VENTURING LLC |
| MNW | MR NICE WEIRD LLC | MR NICE WEIRD LLC |
| NAJB | Nicholas Bianchi personal | Nicholas Bianchi (person) |

Rules:
- `APT` is canonical for the Mercury credential map. Reject `APTA` in credential resolution.
- `FC` and `CHIT` remain distinct credential/account projections but map to one business identity: ARIBIA LLC – MGMT.
- Distinct Mercury account IDs stay distinct even when business identity is shared.
- Deduplicate transactions by Mercury transaction/event identity, not by DBA label.

## 4. Secret/binding conventions

Existing read-token runtime contract:
- `MERCURY_TOKEN_<SLUG>` Cloudflare Secrets Store bindings.
- Legacy `MERCURY_API_KEY_<SLUG>` may exist as fallback; do not create new legacy variables.

Existing write-token contract:
- `MERCURY_WRITE_TOKEN_ARIBIA`
- `MERCURY_WRITE_TOKEN_FC`
- `MERCURY_WRITE_TOKEN_CHIT`
- `MERCURY_WRITE_TOKEN_CITY`
- `MERCURY_WRITE_TOKEN_APT`
- `MERCURY_WRITE_TOKEN_ICB`
- `MERCURY_WRITE_TOKEN_JAVL`
- `MERCURY_WRITE_TOKEN_MNW`
- `MERCURY_WRITE_TOKEN_NAJB`

Egress/auth bindings:
- `MERCURY_EGRESS_URL`
- `MERCURY_EGRESS_PROXY_TOKEN`
- `MERCURY_EGRESS_ACCESS_CLIENT_ID`
- `MERCURY_EGRESS_ACCESS_CLIENT_SECRET`

Do not create `MERCURY_ISSUED_*` in parallel unless ChittyCanon explicitly changes the convention.

## 5. Current ChittyConnect write-path contract

ChittyConnect PR #329 defines the write path. Do not assume deployed behavior until the PR is merged and runtime-verified.

Expected behavior after deployment:
- reads remain on the existing read path/profile;
- write credential is selected from a fixed code map;
- writes route through `https://mercury-proxy.chitty.cc/proxy` / configured `MERCURY_EGRESS_URL`;
- relay call carries `Authorization: Bearer <MERCURY_EGRESS_PROXY_TOKEN>` plus Cloudflare Access service-token headers and the Mercury write token;
- if relay address, proxy token, Access credentials, write token, or required verification is missing, **fail closed**;
- never fall back to direct Cloudflare shared egress for writes;
- all mutations require deterministic idempotency and an audit receipt;
- the relay egress IP currently validated in the implementation work is `147.224.157.155`; verify live state rather than hard-coding it as immutable.

Before enabling writes, verify:
1. Access app on `mercury-proxy.chitty.cc` allows only the intended service token.
2. `MERCURY_EGRESS_PROXY_TOKEN` exists and matches the relay's proxy token.
3. static egress health reports the expected allowlisted IP.
4. Mercury write token includes the needed scope and IP whitelist where required.
5. ChittyFinance/ChittyConnect preflight validation and idempotency are active.

## 6. Operation classification

### A. Read-safe / normally automatic

Use the Mercury connector or ChittyConnect read path without asking for a write approval when the request is purely retrieval/inspection:

- organization metadata
- accounts and balances
- account/card lists
- transaction lists/details
- merchant/category lists
- monthly account statements
- treasury accounts, transactions, and statements
- statement/transaction/recipient attachments
- recipients/payees (read)
- recipient invites (read)
- approval requests (read)
- customers/invoices (read)
- users (read)
- webhook list/details/status

For recurring sync/health, harmless reads also count as token use for Mercury's 45-day inactivity policy.

### B. Configuration mutations — execute only through governed write path

These do not move money directly but still mutate Mercury state:

- create/update/delete/verify webhook
- create/edit/delete custom category
- update transaction note/category
- create/update recipient/payee or recipient invite
- create/update customer
- create/cancel/update invoice

Requirements:
- resolve business identity first;
- select the intended credential boundary explicitly;
- use write token + relay path when the endpoint/scope requires it;
- apply idempotency where supported/required;
- record audit receipt;
- verify resulting state after mutation.

### C. Money movement / high-consequence writes

Examples:
- direct send-money transaction
- transfer money
- other immediate payment mutations

Requirements:
- use the static-egress write path;
- verify account, recipient, amount, payment method, memo, business identity, and approval policy;
- preserve requester/approver separation;
- never synthesize a payment to exercise a token;
- require explicit user authorization for a real payment unless an already-approved automation/policy authorizes the exact action.

### D. Approval-queued operations

Mercury `request-send-money` can create an approval request without the same static-IP requirement as direct send-money, per current Mercury docs. Treat it as a financial action requiring the applicable user approval/policy, but prefer it over direct send-money when the operating model requires a separate human approver.

## 7. Webhook lifecycle

Canonical receiver pattern:
`https://finance.chitty.cc/api/webhooks/mercury/<chittyfinance-scope-id>`

Supported event types include:
- `transaction.created`
- `transaction.updated`
- checking/savings/treasury/investment/credit balance updates

Webhook rules:
1. create only when the actual Mercury organization/credential boundary lacks the required webhook;
2. update/reactivate an existing webhook instead of creating a duplicate when possible;
3. use VerifyWebhook after create/update or after repairing edge/security failures;
4. delete only when the endpoint is definitively obsolete/duplicate and identity mapping is verified;
5. preserve the webhook signing secret in ChittyFinance's per-scope secret store; Mercury only returns the secret on creation;
6. verify `Mercury-Signature` with HMAC-SHA256 over `timestamp.raw_body`; do not reserialize JSON before verification;
7. respond quickly with 2xx; Mercury treats non-2xx as failure and uses documented retry behavior;
8. deduplicate by webhook event `id` because delivery is at-least-once.

`Active + Last delivery: Never + 0 failures` means unexercised, not failed. Use VerifyWebhook to test it.

## 8. Token health / 45-day policy

Mercury currently documents:
- tokens unused for 45 days are automatically deleted;
- higher permissions unused for 45 days may be downgraded to the actually-used permission level;
- admins receive advance warning before downgrade/deletion.

Operational policy:
- integrate credential liveness into the normal Mercury→ChittyFinance reconciliation loop;
- use normal read calls to exercise read credentials;
- do **not** manufacture a write to preserve write scope;
- report write-token inactivity/downgrade risk if no legitimate write-scope operation has occurred;
- if Mercury downgrades a write token to read-only, create/rotate the credential through the governed credential process rather than bypassing policy.

## 9. Statements and document handling

For ordinary finance operations:
- enumerate statements from Mercury per account;
- retain Mercury statement ID, account ID, period start/end, document type, and source URL/provenance;
- ingest statement metadata/document references through the existing finance/document workflow.

For litigation/evidence work:
- statement PDFs are evidence artifacts;
- invoke the legal Evidence Collection pipeline before downloading/staging them;
- preserve originals and chain-of-custody;
- do not use an ad-hoc Drive folder as the evidence system of record.

## 10. Recipients/payees

Mercury calls payees **recipients**.

Before creating a recipient:
- search existing recipients and invites first;
- verify business/individual name and payment method;
- avoid duplicate recipients caused by spelling/nickname differences;
- prefer a recipient invite when the counterparty should securely submit their own banking/tax details;
- never expose bank-account or tax-form data in general logs/agent output.

## 11. Transactions and COA interaction

- Mercury transaction/category metadata is source-system metadata, not ChittyFinance's authoritative COA.
- Do not treat Mercury QuickBooks-style `glAllocations.glCodeName` as authoritative unless Mercury's GL list has been explicitly replaced with the ChittyFinance COA contract.
- ChittyFinance classification follows its L1→L2 trust path.
- If updating a Mercury custom category, preserve the one-dimension rule established by the current finance COA design; do not encode entity/property/status/channel composites into one string.

## 12. Reconciliation loop

Maintain one canonical flow:

1. resolve business identity and credential boundary;
2. verify credential authentication health;
3. enumerate accounts and balances;
4. verify webhook registration/status and repair when governed write capability is available;
5. compare recent Mercury transactions/events against ChittyFinance;
6. backfill only genuinely missing records through the existing ingestion path;
7. preserve `tenant_id` as data scope, separate legal/business binding, account external ID, connector provenance, and idempotency;
8. report only actionable auth/webhook/identity/material reconciliation failures.

Do not create a second scheduled token-health job when this loop already runs frequently enough.
