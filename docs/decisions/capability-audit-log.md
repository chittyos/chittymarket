# Capability Audit — Decision Log

Append-only log of capability registry audits. One entry per audit per the
v0.2 runbook §6. Entries are emitted by the `capability-registry-audit`
skill.

---

## 2026-05-23 — Phase 1 overlay batch sweep

**Auditor:** capability-registry-audit (skill v1.0.0)
**Source:** `capabilities.generated.json` v1.1.0 (102 capabilities, generated 2026-05-11)
**Scope:** governance gates only — ontology coverage, non-repudiation gate, execution-class consistency.

### Findings

#### Pass — ontology coverage

- **0** capabilities missing primary P/L/T/E/A ontology mapping across all 10 capability groups.
- Quality gate §11 "Every artifact has one entity mapping" — **satisfied**.

#### Block — non-repudiation gate incomplete (legal group)

All 5 capabilities in `capability_group: legal` declare
`authority.non_repudiation_required: true` but carry `authority.evidence_gate: null`:

| capability_id | exec_class | mutation_risk |
|---|---|---|
| `chittycanon://capability/legal/search-evidence-documents` | `@chitty/reasoning` | high |
| `chittycanon://capability/legal/dispute-manager` | `@chitty/connectors` | high |
| `chittycanon://capability/legal/court-docket` | `@chitty/connectors` | high |
| `chittycanon://capability/legal/legal-arsenal` | `@chitty/connectors` | high |
| `chittycanon://capability/legal/chittymcp-claude-ai` | `@chitty/reasoning` | high |

Runbook §11 non-repudiation gate requires hash + timestamp + source trail
**before activation**. The flag is asserted but the enforcement mechanism
(`evidence_gate`) is unspecified. Per runbook §3.3 (Gemini round-2 brief),
the gate must live somewhere concrete — inside the projection, inside Ch1tty
`execute`, or as pre-execute middleware.

**Disposition:** `hold` on portal exposure for all 5. Disposition becomes
`legal-only` once `evidence_gate` is populated with one of:

- `pre-execute-middleware` (Ch1tty `execute` enforces before tool invocation)
- `projection-internal` (the projection itself verifies + emits receipt)
- `legal-space-only` (only callable inside Legal space runtime)

**Migration required:** yes. Owner: governance + legal plugin owners.
**Next action:** populate `authority.evidence_gate` in the upstream generator
for all 5 legal capabilities, then re-run the overlay generator. Block
portal/projection emit until populated.
**Review date:** 2026-06-06 (2-week window).

#### Pass — capability group distribution

```
agent-runtime:  4
build:         29
connect:       22
govern:        15
internal:       3
legal:          5
local-lab:      5
market:         1
ship:          12
workspace:      6
total:        102
```

No anomalous bucket sizes; no orphan groups. `market` (1) is acceptable — it
is the manager projection only; ChittyMarket is a registry, not a workspace
of market-typed capabilities.

### Quality gate checklist (this audit)

- [x] Existing inventory was searched first.
- [x] Primary job-to-be-done per capability (inherited from overlay).
- [x] At least one P/L/T/E/A entity mapping — all 102 pass.
- [ ] Exactly one disposition per audited capability — **5 legal capabilities `hold`, 97 carry-forward `keep`**.
- [ ] Evidence-touching items routed to Legal space — **blocked on evidence_gate population**.
- [x] Platform variants tied to one canonical identity — overlay enforces via `capability_id`.
- [x] Dual-manifest drift check — pre-commit drift hook (#17) covers this on commit.
- [ ] Non-repudiation gate applied where required — **incomplete; 5 records**.
- [x] Decision log includes source links.

### Source links

- `capabilities.generated.json`
- `docs/architecture/CHITTYMARKET_CAPABILITY_ROUTER.md`
- `docs/capability-registry-audit-runbook.md` v0.2 §11
- `docs/gemini-strategy-v1-followup.md` §B.2
