# Canonical Marketplace Definitions

This directory is the **authoring source for ChittyMarket-owned distribution definitions** for agents, skills, hooks, MCP entries, and related marketplace artifacts. It is **not** the ecosystem ontology or canonical capability registry.

Normative entity/projection taxonomy: `chittycanon://docs/tech/spec/chittyentity-projection-taxonomy`.

Canonical capability identity and ontology resolve through ChittyCanon / ChittyRegistry. Files here describe how those governed capabilities are projected into supported marketplace/runtime surfaces.

**The rule:** edit Market-owned projection definitions here, then dispatch them to configured runtimes. Do not copy or redefine Canon governance content here when it can be referenced by canonical ID/URI.

## Layout

```
canonical/
  <kind>/<name>.md                    # Market-owned projection definition
                                      # <kind>: agents | skills | commands | mcp | tools
  .dispatch-state/<kind>/<name>.json  # last-projected sentinel per definition
  .dispatch-log.jsonl                 # append-only dispatch audit log (gitignored)
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


## Identity-first reconciliation

`scripts/market-reconcile.py` is the migration-safe inventory compiler.

Identity rules:

- Never derive a capability identity from an artifact name, display title, group, slug, package, or runtime path.
- A new/unpublished definition must carry an explicit `chittycanon://capability/...` reference in an existing supported frontmatter identity field before it can be projected.
- During migration, an already-published `capabilities.generated.json` record may preserve the established binding for that same legacy artifact until the reference is backfilled into canonical frontmatter.
- A conflicting explicit reference is a hard error.
- An unpublished unresolved definition is `HOLD`: it may remain authored, but the reconciler refuses to create marketplace/overlay records for it.
- New projections also require explicit governance metadata and an explicit `access: read|write|readwrite` declaration; the compiler does not infer access from mutation risk or guess authority, auth, or placement policy.
- New compiled artifacts are disabled by default. Compilation is not publication or runtime verification.

Use:

```bash
python3 scripts/market-reconcile.py audit
python3 scripts/market-reconcile.py sync --name <canonical-name>
```

The audit is CI-safe: published identity conflicts fail; unpublished unresolved definitions are reported as holds. The sync path is fail-closed.
