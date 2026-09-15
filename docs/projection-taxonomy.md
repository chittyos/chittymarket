# ChittyMarket Projection Taxonomy

Normative design source: `chittycanon://docs/tech/spec/chittyentity-projection-taxonomy`.

That Canon document is currently `DRAFT`; its new/re-scoped `projection family` terminology remains **PROPOSED**. Existing Agent Slug Convention ownership remains binding until separately changed.

ChittyMarket is a **distribution and discovery surface** and the governed source for Market-owned projection definitions. It is not the ecosystem ontology owner or underlying canonical capability registry.

## Current state vs target state

The current Market generator/dispatcher does **not yet enforce canonical capability/entity/projection references on every generated artifact**, and its verification outcome is not yet persisted distinctly enough to treat provenance drift as a blocking invariant. Until that implementation lands, this document is target-state guidance for those linkage and audit guarantees, not a claim that the current scripts already enforce them.

### Target-state projection linkage

Marketplace entries, generated capability manifests, plugins, agents, skills, MCP entries, and runtime artifacts SHOULD converge on stable references for:

1. `canonical_capability_ref` — the owning canonical capability identity;
2. `canonical_entity_ref` — the canonical entity identity when the projection represents a specific entity;
3. `projection_ref` — the governed projection identity;
4. the current canonical projection-definition owner; and
5. the Market/runtime artifact identity being distributed.

The field names above are conceptual reference names, not authorization for a new schema. Reuse existing supported registry/frontmatter/manifest fields wherever possible. If current artifact formats cannot preserve the linkage, record that as a migration/enforcement gap rather than minting a parallel identity model.

Where an artifact is intentionally pointer-only, the pointer itself should resolve to the upstream canonical identity instead of copying the identity payload.

Generated files such as `marketplace.json` and `capabilities.generated.json` are delivery projections and are not authoritative sources for entity type, identity class, projection ownership, proposed projection family, or capability ownership.

Example relationship:

```text
canonical_capability_ref: ChittyConnect canonical service ID/URI
canonical_entity_ref:     <entity ID when applicable>
projection_ref:            chittyagent-connect
projection owner:          ChittyMarket under current Agent Slug Convention
proposed family:           ChittyAgent (migration-design label only)
market projection:         plugin/agent/package entry
runtime projection:        generated Claude/Codex/MCP artifact
```

## Reconciliation boundary

The intended separation is:

- **Reconcile** — compare Market projection definitions and generated/runtime copies to upstream identity/ownership references and report drift.
- **Dispatch** — render an approved Market projection into a runtime/delivery surface.
- **Verification** — validate the rendered result and persist an outcome distinct from dispatch success.

### Current enforcement gap

Today, dispatch state can report a successful sync before a later audit/verification failure is durably represented, and the generator does not yet guarantee canonical-reference fields on every output. Therefore:

- a successful current `sync` is not proof of canonical identity linkage;
- a successful current dispatch is not proof that verification passed;
- provenance/ownership drift should be treated as an observed gap until the dispatcher/generator is upgraded to persist and enforce those results.

The target state is that verification success/failure is persisted separately and identity/provenance drift can block enablement where policy requires it.

Market-local `canonical/` is the authoring source for **Market-owned projection definitions only**. ChittyCanon/ChittyRegistry remain authoritative for ecosystem ontology and canonical capability identity. Any ownership transfer out of Market requires a coordinated governance change; moving implementation code alone is insufficient.
