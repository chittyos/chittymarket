---
name: enforce-auth-canonical
enabled: true
event: prompt
action: suggest
pattern: (\bauth\b|oauth|oidc|token|secret|api[_\-]?key|credential|mint|rotation|chittyauth|chittyconnect|better[_\-]?auth|neon[_\-]?auth)
---

## Auth Canonical Guardrail

Auth/security work detected.

Before making or approving auth changes, enforce this canonical flow:

1. `chittyauth` owns auth policy and secret issuance semantics.
2. `chittyauth` stays provider-agnostic; Neon/Better Auth is a backend provider.
3. Canonical secret names are `chittyauth_issued_*`; legacy names are migration-only.
4. Integrations route through `chittyconnect`, which delegates auth architecture to `chittyauth-neon-warden`.

Required anti-rogue checks:

- No direct provider logic scattered across services.
- No local secret mint authority outside `chittyauth`.
- No canonical doc/config overwrite by legacy naming.
