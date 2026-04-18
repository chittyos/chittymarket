---
name: chittyschema-overlord
description: Schema governance subagent for the ChittyOS ecosystem. Use for database schema design, type generation, validators, breaking-change detection, fractal scope alignment, drift detection, and cross-service impact analysis. The full prompt lives in the chittyschema repo (per-service ownership).
model: opus
color: orange
canon_uri: chittycanon://core/services/chittyschema#agent-overlord
prompt_source: github://CHITTYFOUNDATION/chittyschema/main/identity/agents/chittyschema-overlord.md
prompt_url: https://raw.githubusercontent.com/chittyfoundation/chittyschema/main/identity/agents/chittyschema-overlord.md
owner_repo: CHITTYFOUNDATION/chittyschema
owner_path: identity/agents/chittyschema-overlord.md
---

<!--
This is a thin pointer entry. Per the ChittyOS per-service ownership pattern,
the canonical chittyschema-overlord agent prompt is owned by the chittyschema
repo at:

  CHITTYFOUNDATION/chittyschema → identity/agents/chittyschema-overlord.md

This file exists in chittymarket only for marketplace discovery. Do NOT edit
the prompt content here — edit it in chittyschema. Loaders that hydrate
plugin agents should resolve `prompt_source` (or `prompt_url` for raw fetch)
to fetch the canonical prompt.

Why per-service ownership:
- Single source of truth — no drift between marketplace cache and service repo
- The service that owns the data shapes owns the agent that governs them
- The Schema Owner Manifest at https://schema.chitty.cc/api/owners resolves
  per-service ownership for tables; this mirrors that for agents

See:
- chittycanon://gov/governance#core-types — canonical 5 entity types (P/L/T/E/A)
- https://github.com/chittyfoundation/chittyschema — chittyschema repo
- https://github.com/chittyfoundation/chittyschema/blob/main/identity/agents/chittyschema-overlord.md
-->

# ChittySchema Overlord (pointer)

The full agent prompt is owned by chittyschema and lives at `identity/agents/chittyschema-overlord.md` in the [chittyschema repo](https://github.com/chittyfoundation/chittyschema/blob/main/identity/agents/chittyschema-overlord.md).

To invoke this subagent, use the Task tool with `subagent_type: chittyschema-overlord`. Loaders that hydrate plugin agents should fetch the prompt from `prompt_url` above.
