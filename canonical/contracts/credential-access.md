---
name: credential-access-contract
canon_uri: chittycanon://core/contracts/credential-access
version: 1.0.0
status: proposed
extends: chittycanon://gov/governance#sensitive-intent   # system-wide-sensitive-intent-contract-v1
source_of_truth: chittyos-core/skills/nb-development-defaults/references/secrets.md
owner: chittyconnect-concierge (/chico)
applies_to: [worker, mcp-server, agent, chittyscript, plugin, skill, pentad-SECURITY]
---

# Credential Access Contract (v1)

The single canonical contract for how ANY ChittyOS artifact touches credentials.
Templates and services **cite this URI**; they do not restate its prose. Restating
is what drifts (three templates independently rotted to "1Password"). One contract,
controlled projections, enforced in CI.

## Invariants (non-negotiable)

1. **Operator-zero-access.** The operator never retrieves, rotates, pastes, or
   relays a secret. No secret value appears in code, config, logs, or chat — ever
   (not from the user, not from tool output, not as an "example").
2. **Resolution is a bound-service privilege.** A secret value is resolved ONLY
   inside a bound service, via `getServiceToken(env, "<service>")` or
   `await env.SECRETS_STORE.get("<NAME>")` (async, try/catch). A **consumer never
   resolves a value**.
3. **Consumers carry one identity.** An off-service consumer presents only its own
   `CHITTYCONNECT_SERVICE_TOKEN` (the inbound identity ChittyConnect validates). It
   **must not** hold or present `CF_ACCESS_CLIENT_ID` / `CF_ACCESS_CLIENT_SECRET` —
   those are the bound service's identity, and hand-authenticating to a gated host
   with them is a blocked pattern.
4. **Route through the broker.** Any credential / deploy / registry-mutation intent
   routes through ChittyConnect (`chittyconnect-concierge`, `/chico`).
5. **Fail closed.** Broker/route unavailable is a policy error, never a fallback:
   `POLICY_BLOCKED_CHITTYCONNECT_UNAVAILABLE`, `POLICY_BLOCKED_MANDATORY_BROKER_ROUTE`,
   `POLICY_BLOCKED_DESTINATION_UNVERIFIED`, `INSUFFICIENT_SCOPE`,
   `EXECUTION_DENIED_BY_POLICY`. Only `MISSING_CREDENTIAL_MATERIAL` may request
   provisioning (with full resolution fields).
6. **Storage + naming.** Tokens/keys/signing material live in the Cloudflare Secrets
   Store (fronted by **ChittySecrets**, Layer 0). Never `[vars]`, never KV-as-truth.
   Names: `CHITTYAUTH_ISSUED_<SERVICE>_<TOKEN|API_KEY>` (legacy `CHITTY_<SERVICE>_TOKEN`
   is fallback; `getServiceToken()` resolves both). Service URLs / DB IDs are `vars`,
   not secrets. **1Password is RETIRED** — never a source of truth.

## Roles

| Role | May resolve a value? | Identity it presents |
|---|---|---|
| Bound service (Worker) | Yes — `getServiceToken` / `SECRETS_STORE.get` | its Secrets-Store binding / CF Access service token |
| Consumer (off-service: Apps Script, CLI, external) | **No** | one `CHITTYCONNECT_SERVICE_TOKEN` → bound egress route |
| Broker (`/chico`) | Yes — owns the lane | CF Access service token (its own) |
| Operator (human) | **No** | none |

## Conformance (what a compliant template/service must show)

- [ ] Cites `chittycanon://core/contracts/credential-access`.
- [ ] Contains no reference to 1Password / `op run` / `op read` as a secret source.
- [ ] Consumer surfaces contain no `CF_ACCESS_CLIENT_*`.
- [ ] No secret-value reads in a consumer surface (`SECRETS_STORE.get`, `secrets_resolve`,
      `wrangler secret get`, `printenv|grep TOKEN`, `echo $*_SECRET`).
- [ ] Secrets in Secrets Store; names `CHITTYAUTH_ISSUED_*`; none in `[vars]`/KV.
- [ ] Fail-closed on broker-down with a canonical `POLICY_BLOCKED_*` code.

## Enforcement

CI gate `check-credential-contract.sh` (ChittyGuardian, non-bypassable) asserts the
conformance list above on every template and service. A template that restates the
rules instead of citing this URI, or that names 1Password, or that puts
`CF_ACCESS_CLIENT_*` in a consumer, fails the merge.
