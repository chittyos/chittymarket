# ChittyMarket Projection Taxonomy

Normative source: `chittycanon://docs/tech/spec/chittyentity-projection-taxonomy`.

ChittyMarket is a **distribution and discovery projection**, not the ontology owner or canonical capability registry.

Marketplace entries, generated capability manifests, plugins, agents, skills, MCP entries, and runtime artifacts MUST preserve or resolve:

1. the owning canonical capability identity;
2. the governed projection identity/family when the artifact represents a ChittyEntity projection; and
3. the Market/runtime artifact identity being distributed.

Use existing supported registry/frontmatter/manifest fields to carry those relationships. Do not invent a parallel Market schema merely to encode them. If an existing artifact format cannot preserve canonical ownership, the dispatcher/reconciler should surface that as a hold/drift condition rather than minting identity from a plugin name or local path.

Generated files such as `marketplace.json` and `capabilities.generated.json` are delivery projections and MUST NOT become independent sources of truth for entity type, projection family, or capability ownership.

Example relationship:

```text
canonical capability: ChittyConnect
projection:           chittyagent-connect (ChittyAgent family)
market projection:    plugin/agent/package entry
runtime projection:   generated Claude/Codex/MCP artifact
```

## Reconciliation boundary

- **Reconcile** compares Market projection definitions and generated/runtime copies to their upstream canonical identity.
- **Dispatch** renders an approved Market projection into a runtime/delivery surface.
- **Verification** checks the rendered artifact and records drift/provenance.

These steps may be orchestrated together but must remain distinguishable in logs/state so a failed verification cannot be mistaken for a successful dispatch.

Market-local `canonical/` is the authoring source for **Market-owned projection definitions only**. ChittyCanon/ChittyRegistry remain authoritative for ecosystem ontology and capability ownership.
