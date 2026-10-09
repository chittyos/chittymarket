# CLAUDE.md — Finance Operating Defaults (Claude bootstrap)

**Capability:** `finance-operating-defaults` (ChittyMarket, plugin `chittyos-finance`)
**Canonical:** `chittycanon://core/services/chittymarket#skills/finance-operating-defaults`
**Canonical source:** `canonical/skills/finance-operating-defaults.md` @ `35a996db27e798f276cd4d48149810ed4db2eb63`

Bookkeeping, chart-of-accounts, classification, reconciliation, Mercury banking/reconciliation, tax-form derivation, or
financial-datastore work — including requests that sound trivial — loads `finance-operating-defaults` BEFORE acting on the request. For Mercury work, resolve execution in order: ChittyConnect (provider lifecycle/auth/provenance) → `chittyconnect-finance` (finance identity/binding/dedupe/reconciliation adapter) → ChittyFinance/`chittyagent-finance` (canonical SOT/read validation). If the current channel lacks `chittyconnect-finance`, route the projection defect through `chittyagent-dev` → ChittyMarket/`chittymarket-manager`; never emulate the missing capability locally.

This file is a pointer. It states no rules of its own. Where it and the canonical document
appear to differ, the canonical document governs and this file is drift.

Dependency routing, the distribution boundary, and every operating rule are defined in the
canonical document. This file restates none of them — read the canonical document.
