# ChittyMarket Projection Taxonomy

Normative design source: `chittycanon://docs/tech/spec/chittyentity-projection-taxonomy`.

That Canon document is currently `DRAFT`; its new/re-scoped `projection family` terminology remains **PROPOSED**. Existing Agent Slug Convention ownership remains binding until separately changed.

ChittyMarket is a **distribution and discovery surface** and the governed source for Market-owned projection definitions. It is not the ecosystem ontology owner or underlying canonical capability registry.

Marketplace entries, generated capability manifests, plugins, agents, skills, MCP entries, and runtime artifacts MUST preserve or resolve:

1. the owning canonical capability identity;
2. the current canonical projection-definition owner;
3. the governed projection identity and, if used experimentally, the proposed projection-family label; and
4. the Market/runtime artifact identity being distributed.

Use existing supported registry/frontmatter/manifest fields to carry those relationships. Do not invent a parallel Market schema merely to encode them. If an existing artifact format cannot preserve canonical ownership, the dispatcher/reconciler should surface that as a hold/drift condition rather than minting identity from a plugin name or local path.

Generated files such as `marketplace.json` and `capabilities.generated.json` are delivery projections and MUST NOT become independent sources of truth for entity type, identity class, projection ownership, proposed projection family, or capability ownership.

Example relationship:

```text
canonical capability: ChittyConnect
projection:           chittyagent-connect
projection owner:     ChittyMarket under current Agent Slug Convention
proposed family:      ChittyAgent (migration-design label only)
market projection:    plugin/agent/package entry
runtime projection:   generated Claude/Codex/MCP artifact
```

## Reconciliation boundary

- **Reconcile** compares Market projection definitions and generated/runtime copies to upstream canonical identity and ownership.
- **Dispatch** renders an approved Market projection into a runtime/delivery surface.
- **Verification** checks the rendered artifact and records drift/provenance.

These steps may be orchestrated together but must remain distinguishable in logs/state so a failed verification cannot be mistaken for a successful dispatch.

Market-local `canonical/` is the authoring source for **Market-owned projection definitions only**. ChittyCanon/ChittyRegistry remain authoritative for ecosystem ontology and canonical capability identity. Any ownership transfer out of Market requires a coordinated governance change; moving implementation code alone is insufficient.
