---
name: capability-governor
canon_uri: chittycanon://core/services/chittymarket#skills/capability-governor
description: govern chittyos capability inventory, marketplace agents, skills, tools, plugins, mcp routes, and platform projections through an identity-first audit loop. use when asked to classify a capability, design or refactor a tool marketplace, deduplicate agents, decide whether something belongs as a skill/plugin/gateway/local integration/legal workflow, create a migration or retirement decision, audit system footprint, or enforce evidence-grade routing for legal, governance, valuation, custody, dispute, or forensic capabilities.
kind: skill
plugin: chittyos-governance
runtimes:
  - claude-code
classification:
  - governance
  - compliance
---

# Capability Governor

## Purpose

Use this skill to run a repeatable capability-governance loop for ChittyOS-style ecosystems. The skill coordinates canonical identity, job-to-be-done taxonomy, system-footprint routing, evidentiary risk, platform projection, and artifact lifecycle decisions.

Treat the marketplace as an identity-first, evidence-grade capability system, not a flat catalog of tools. Each capability should have one canonical identity and multiple controlled projections.

## Core rule

Always identify an existing canonical capability before creating a new one. Do not invent new schemas, databases, registries, or service boundaries. If source data is insufficient, return `hold` with the missing evidence.

## Workflow

1. Intake the artifact or inventory batch.
2. Search or inspect existing capability definitions, manifests, registries, skills, gateway routes, and legal/evidence workflows when available.
3. Assign a primary job-to-be-done.
4. Map the artifact to core entity anchors: person, location, thing/asset, event, action, or record.
5. Score environmental footprint.
6. Score evidentiary risk.
7. Decide canonical identity: keep, promote, project, merge, gateway, skill, local-only, legal-only, retire, or hold.
8. Produce the standard output package: taxonomy entry, disposition decision, decision log, and migration queue item.

## Classification axes

Use `references/decision-matrix.md` for placement decisions.
Use `references/projection-matrix.md` for runtime/channel exposure.
Use `references/output-templates.md` for standard output formats.
Use `references/runbook.md` for the full governance cycle.

## Script usage

For deterministic artifact classification, run:

```bash
python scripts/audit_artifact.py --input artifact.json --pretty
```

For a batch file containing a JSON array of artifacts, run:

```bash
python scripts/batch_audit.py --input artifacts.json --output audit-results.json
```

To validate a decision log, run:

```bash
python scripts/validate_decision_log.py --input decision-log.json
```

## Disposition rules

Assign exactly one primary disposition:

- `keep`: valid existing canonical capability.
- `promote`: should become canonical after existing-first search.
- `project`: platform-specific projection of an existing canonical capability.
- `merge`: duplicate or overlapping artifact to consolidate.
- `gateway`: expose through search-and-execute or MCP gateway.
- `skill`: package as repeatable ChatGPT workflow, template, or operating procedure.
- `local-only`: requires filesystem, local state, privileged device access, or metadata preservation.
- `legal-only`: touches legal claims, evidence, custody, forensic state, valuation, disputes, filings, removal documents, or non-repudiable business records.
- `retire`: obsolete, unsafe, ownerless, superseded, or redundant.
- `hold`: insufficient evidence or unresolved canonical identity.

## Non-repudiation gate

Route any artifact touching legal, governance, valuation, removal documents, custody, disputes, forensic state, hashes, timestamps, or evidence records to `legal-only` unless the user explicitly provides an already-approved canonical legal/evidence route. Require source links, timestamp policy, hash policy, and decision log before activation.

## Output standard

Return:

1. Capability taxonomy entry.
2. Disposition decision.
3. Decision log.
4. Migration queue item.
5. Missing evidence, if any.

Keep summaries concise, but include enough source IDs, file links, repo references, or manifest names to make the decision auditable.
