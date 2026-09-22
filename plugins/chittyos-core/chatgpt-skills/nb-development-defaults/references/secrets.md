# Credentials & Secrets

Load for ANY credential / secret / token / binding / OAuth / service-auth task. This is the highest-consequence domain in this environment.

> **1Password is RETIRED (operator-confirmed 2026-07-18).** Do NOT search 1P vaults, run `op` / `op run`, or treat 1P as the source of truth — that guidance is stale wherever it still appears (global `CLAUDE.md`, the `SECRET_MANAGEMENT_ARCHITECTURE`/`RUNBOOK` docs, older skill text). The canonical secret system is now **ChittySecrets** (see below).

## First instinct: credentials are NEVER your job

- **The operator (user) has ZERO credential access — a hard organizational constraint, not a preference.** They cannot retrieve, rotate, paste, or relay any secret. **No credential value may appear in chat — ever** (not from the user, not from tool output, not as an "example").
- For any credential intent, your **first move is to delegate to the broker** — `chittyconnect-concierge` (`/chico`) — BEFORE you ever reach for a secret CLI or a grep. Single read → lightweight broker fast-path; write/provisioning → the full concierge.
- **Never find, resolve, inject, or present a credential value yourself.** A bound service / the broker holds the binding and performs the authenticated action; you supply only the request payload. This includes: no `secrets_resolve` from an agent, no `wrangler secret get`, no `wrangler kv get secret:*`, no `echo $X_SECRET` / `printenv | grep TOKEN`, and no hand-authenticating to a gated host with `curl -H "CF-Access-Client-Id/Secret"`.
- **Wrangler `secrets_store_secrets` / KV bindings in a `wrangler.json` are binding *declarations*, not values** — the value lives encrypted in the store. Reading config tells you a secret exists, not what it is; never treat it as a credential inventory.
- The PreToolUse hook `route-credential-ops-to-broker.sh` hard-blocks direct value reads/placement (`op read`/`op item get`, `wrangler secret put|delete`) **and** (added 2026-07-18) CF-Access header auth, env-value extraction, and store-value reads — including inside `ssh '<cmd>'`. If it fires, you already failed to delegate. Emergency override only: `CHITTY_POLICY_BYPASS=1` or `touch ~/.ch1tty/EMERGENCY_BYPASS`.
- **Never grep-and-destroy a credential** — item-ID references make name-greps structurally unsound (a name-grep nearly broke 4 services).

## The canonical system: ChittySecrets

**ChittySecrets** (`@canonical-uri chittycanon://core/services/chittysecrets`) is the Layer 0 secret manager for ChittyOS — it replaces 1Password.

- **Hosts** (per the standard URL topology): primary worker `secrets.chitty.cc`; MCP endpoints `agent.chitty.cc/secrets` and `mcp.chitty.cc/secrets`. Health is public; everything else is CF-Access-gated (`chittycorp.cloudflareaccess.com`).
- **MCP tools:** `secrets_list` (names + metadata, **NO values**) and `secrets_resolve` (the **only** path that returns a value). `secrets_resolve` requires a verified **service principal** (CF Access JWT via `Cf-Access-Jwt-Assertion`); **human access is blocked** unless `break_glass` is set *and* the secret's policy allows it. Every list/resolve is audit-logged to ChittyChronicle (`chronicle.chitty.cc`) + the agent's DO storage.
- **Storage tiers:** hot = Cloudflare **Secrets Store** binding (`SECRETS_STORE`, store `e914522471964c3c8cf1e601770edcc3`, account ChittyCorp `0bc21e3a5a9de1a4cc843be9c3e98121`); cold/escrow = AES-GCM-encrypted in the `SecretAgent` Durable Object (recovered via `CHITTYSECRETS_MASTER_KEY`).
- **How agents get a value:** they don't — a bound service resolves via `env.SECRETS_STORE.get(NAME)` (async: `await`, in try/catch) or asks the broker, and uses the value without exposing it. Secret names are uppercase `^[A-Z][A-Z0-9_]{0,127}$`.

## Placement & classification

- **Classify before you place:** service URLs + Notion DB IDs → plain `vars` (NOT secrets); tokens / third-party creds / signing keys → Cloudflare Secrets Store (fronted by ChittySecrets).
- **Never KV as authority.** KV is cache / rotation state only.
- **One canonical copy per token, resolved at runtime.** Token sprawl into code/VM/scattered secrets caused a multi-week outage. The VM holds no hardcoded credential token.
- Vault/store placement by **security domain** — ask "what IS this credential," not "where is it used."

## Naming

- Prefer `CHITTYAUTH_ISSUED_<SERVICE>_TOKEN` / `_API_KEY`; `CHITTY_<SERVICE>_TOKEN` is legacy fallback (`getServiceToken()` resolves both). Inbound service auth validates `CHITTYCONNECT_SERVICE_TOKEN`.
- CF Access service-token pairs follow `CF_ACCESS_CLIENT_ID_<SERVICE>` / `CF_ACCESS_CLIENT_SECRET_<SERVICE>` (these are the identity a bound service presents to a gated host — the broker's to use, never yours to fetch).
- External-issuer pattern: `<ISSUER>_ISSUED_<TARGET>_<CAPABILITY>_<TYPE>` (e.g. `CLOUDFLARE_ISSUED_CHITTYCLAW_AI_GATEWAY_TOKEN`). Standard: `openclaw/standards/credential-naming.md`.

## Fail closed (canonical error codes)

Broker-down = policy error, never chat fallback: `POLICY_BLOCKED_CHITTYCONNECT_UNAVAILABLE`, `POLICY_BLOCKED_MANDATORY_BROKER_ROUTE`, `POLICY_BLOCKED_DESTINATION_UNVERIFIED`, `INSUFFICIENT_SCOPE`, `EXECUTION_DENIED_BY_POLICY`. Only `MISSING_CREDENTIAL_MATERIAL` may request operator provisioning (and must carry full resolution fields).

## Wrangler multi-env gotchas

- Env blocks do NOT inherit top-level `vars`/`routes`/`tail_consumers` — make each block self-contained.
- Deploy with explicit env: `npx wrangler deploy --env <env>` (mandatory). Runtime secrets arrive via the `SECRETS_STORE` binding, not `op run` (retired).
- **Never deploy via CF REST API** — it strips KV/DO/service bindings. Use `wrangler deploy --env production`.
- **Renaming a CF Worker creates a new worker** — secrets, DO migrations, DNS don't transfer; Queue-consumer workers can't be deleted.
- CF Secrets Store bindings are async — `await env.X.get()` in try/catch, never bare `env.X`. Migrating a plain secret to a Store binding is a **code** change, not just wrangler config.

## Canonical paths

- ChittySecrets source (Layer 0): `storage-ops/chittysecrets/` (Mac) · `~/projects/github.com/CHITTYOS/chittysecrets/` (VM) — `src/index.ts` (MCP tools + CF Access verify), `wrangler.json` (Secrets Store bindings).
- Broker source (chittyconnect repo): `src/lib/credential-broker.js`, `src/lib/credential-helper.js` (`getServiceToken`), `src/lib/credential-paths.js`, `src/services/secret-rotation.js`.
- Sensitive-intent contract: `~/.ch1tty/canon/system-wide-sensitive-intent-contract-v1.md`.
- **STALE — superseded by ChittySecrets, do not follow as current-state:** `process-ops/docs/SECRET_MANAGEMENT_ARCHITECTURE.md`, `.../SECRET_MANAGEMENT_MIGRATION_RUNBOOK.md`, `process-ops/migrate-secrets.sh` (all describe the retired 1P→CF-Secrets migration). Their wrangler-multi-env and rotation patterns remain useful; their 1P/SA/`op run` model does not.
