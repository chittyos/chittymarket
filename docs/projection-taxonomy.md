# ChittyMarket Projection Taxonomy

Normative design source: `chittycanon://docs/tech/spec/chittyentity-projection-taxonomy`.

That Canon document is currently `DRAFT`; its new/re-scoped `projection family` terminology remains **PROPOSED**. Existing Agent Slug Convention ownership remains binding until separately changed.

ChittyMarket is a **distribution and discovery surface** and the governed source for Market-owned projection definitions. It is not the ecosystem ontology owner or underlying canonical capability registry.

## Current state vs target state

Capability identity and dispatch/verification separation are now enforced for the resolved canonical-owned Market population. Agent projection identity is also explicit and CI-gated through `projection_id`, `projection_owner`, and `projection_family`. Remaining target-state work is narrower: entity identity where an artifact represents a specific entity, authoritative resolution of HOLD/alias populations, and native runtime verification beyond schema-only smoke tests.

### Projection linkage

Marketplace entries, generated capability manifests, plugins, agents, skills, MCP entries, and runtime artifacts SHOULD converge on stable references for:

1. `canonical_capability_ref` — the owning canonical capability identity;
2. `canonical_entity_ref` — the canonical entity identity when the projection represents a specific entity;
3. `projection_ref` — the governed projection identity;
4. the current canonical projection-definition owner; and
5. the Market/runtime artifact identity being distributed.

The generic names above remain conceptual across artifact kinds. Reuse existing supported registry/frontmatter/manifest fields wherever possible. For Market-owned canonical agents, the concrete frontmatter contract is `projection_id: chittyagent-<domain>`, `projection_owner: chittycanon://core/services/chittymarket`, and `projection_family: ChittyAgent`; dispatch preserves those fields into supported runtime projections. If another artifact format cannot preserve linkage, record that as a migration/enforcement gap rather than minting a parallel identity model.

Where an artifact is intentionally pointer-only, the pointer itself should resolve to the upstream canonical identity instead of copying the identity payload.

Generated files such as `marketplace.json` and `capabilities.generated.json` are delivery projections and are not authoritative sources for entity type, identity class, projection ownership, proposed projection family, or capability ownership.

Example relationship:

```text
canonical_capability_ref: ChittyConnect canonical service ID/URI
canonical_entity_ref:     <entity ID when applicable>
projection_id:             chittyagent-connect
projection_owner:          chittycanon://core/services/chittymarket
projection_family:         ChittyAgent
market projection:         plugin/agent/package entry
runtime projection:        generated Claude/Codex/MCP artifact
```

## Reconciliation boundary

The intended separation is:

- **Reconcile** — compare Market projection definitions and generated/runtime copies to upstream identity/ownership references and report drift.
- **Dispatch** — render an approved Market projection into a runtime/delivery surface.
- **Verification** — validate the rendered result and persist an outcome distinct from dispatch success.

### Remaining enforcement gaps

The following are still not equivalent to native runtime proof or complete ecosystem identity reconciliation:

- a successful dispatch does not prove the target runtime loaded the artifact; runtime verification remains a separate durable state;
- `canonical_entity_ref` is only required where an artifact represents a specific canonical entity and is not yet universal;
- canonical-only and live-only agent projections are reported by `scripts/check-agent-identity.py --live` but are not auto-promoted or auto-retired;
- production orchestrator registration/description writes remain a sensitive mutation and are not performed by reconciliation checks.

Static CI now blocks duplicate Market projection IDs, missing/mismatched projection owner/family metadata, unmanaged plugin agent filename/name mismatches, duplicate declared plugin-agent names, and projection metadata drift.

Market-local `canonical/` is the authoring source for **Market-owned projection definitions only**. ChittyCanon/ChittyRegistry remain authoritative for ecosystem ontology and canonical capability identity. Any ownership transfer out of Market requires a coordinated governance change; moving implementation code alone is insufficient.
