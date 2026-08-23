# Canonical Marketplace Definitions

This directory is the **authoring source for ChittyMarket-owned distribution definitions** for agents, skills, hooks, MCP entries, and related marketplace artifacts. It is **not** the ecosystem ontology or canonical capability registry.

Normative entity/projection taxonomy: `chittycanon://docs/tech/spec/chittyentity-projection-taxonomy`.

Canonical capability identity and ontology resolve through ChittyCanon / ChittyRegistry. Files here describe how those governed capabilities are projected into supported marketplace/runtime surfaces.

**The rule:** edit Market-owned projection definitions here, then dispatch them to configured runtimes. Do not copy or redefine Canon governance content here when it can be referenced by canonical ID/URI.

## Layout

```
canonical/
  <name>.md                    # Market-owned projection definition
  .runtimes.json               # runtime adapter registry
  .dispatch-state/<name>.json  # last-projected sentinel per definition
  .dispatch-log.jsonl          # append-only audit log of dispatch runs
```

Each projection definition should preserve or resolve the owning canonical capability and, where applicable, entity projection identity. Generated runtime files are delivery projections, not new canonical capabilities.

## Frontmatter schema

See `plugins/chittyagent-dispatch/agents/chittyagent-dispatch.md` ("Canonical Document Format" section) for the binding frontmatter contract.

**Binding rule: canonical frontmatter MUST be strict YAML.** Multi-line `description:` values must use a block scalar (`|`), not a single-line string with literal `\n` escape sequences:

```yaml
description: |
  Use this agent when ...

  <example>
  Context: ...
  user: "..."
  </example>
```

## Workflow

1. Resolve/verify the owning canonical capability and projection identity.
2. Edit the Market-owned projection definition here.
3. Run `plugins/chittyagent-dispatch/scripts/dispatch.sh sync <name>` to project to configured runtimes.
4. Commit projection diffs alongside the definition change, or use the governed in-place dispatch flow.
5. Reconcile drift rather than promoting a divergent runtime copy by default.

## Direct edits to projected files

Direct edits to generated runtime files are forbidden by convention. If a runtime copy has already changed, run `dispatch.sh reconcile <name>` to surface the drift. Promotion back into the Market projection definition must preserve upstream canonical capability ownership and must not import conflicting governance content.

## Status

The Market canonical/dispatch layer is a projection-authoring system. Migration of existing agents/skills into this directory remains incremental as dispatch adapters and canonical identity links are verified.
