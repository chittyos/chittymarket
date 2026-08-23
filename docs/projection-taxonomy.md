# ChittyMarket Projection Taxonomy

Normative source: `chittycanon://docs/tech/spec/chittyentity-projection-taxonomy`.

ChittyMarket is a **distribution and discovery projection**, not the ontology owner.

Marketplace entries, generated capability manifests, plugins, agents, skills, MCP entries, and runtime artifacts SHOULD point back to canonical capability/entity identities. Generated files such as `marketplace.json` and `capabilities.generated.json` are projections and MUST NOT become independent sources of truth for entity class or capability ownership.

Where a market artifact represents an agentic projection of a service, preserve both identities conceptually:

```text
canonical capability: ChittyConnect
entity projection:    chittyagent-connect
market projection:    plugin/agent/package entry
```

The market sync/dispatch layer should reconcile from canonical identity metadata and surface drift rather than silently minting a new capability from a plugin name, route, or local file.
