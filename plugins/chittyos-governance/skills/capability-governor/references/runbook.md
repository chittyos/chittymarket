# Capability Registry Audit Runbook

## Operating principle

Every capability has one canonical identity and many permitted projections. Platform-specific versions are adapters or projections unless they perform materially different jobs.

## Triggers

Run this process when:

- a new tool, agent, plugin, skill, or MCP route is proposed;
- duplicate tools are found;
- marketplace taxonomy changes;
- a legal/evidence workflow is touched;
- a gateway, manifest, or adapter changes;
- a monthly capability governance cycle starts.

## Required inputs

- capability name;
- source link or file path;
- current owner;
- current runtime;
- primary job-to-be-done;
- data touched;
- privilege level;
- evidence impact;
- known duplicates;
- current status.

## Process

1. Create intake record.
2. Perform existing-first search.
3. Determine canonical identity.
4. Classify job-to-be-done.
5. Map entity anchors.
6. Score environmental footprint.
7. Score evidentiary risk.
8. Select runtime projection.
9. Assign one disposition.
10. Write decision log.
11. Add migration or retirement item if needed.

## Monthly governance cycle

### Week 1: inventory refresh

- Pull active manifests.
- List current skills, tools, agents, plugins, gateways, and local integrations.
- Identify new, stale, unowned, or changed artifacts.

### Week 2: classification

- Apply job-to-be-done taxonomy.
- Score footprint and evidentiary risk.
- Identify canonical identity conflicts.

### Week 3: decisions

- Mark keep, merge, gateway, local-only, legal-only, skill, retire, or hold.
- Assign owners.
- Record rationale.

### Week 4: publish

- Publish taxonomy map.
- Publish migration queue.
- Publish retirement list.
- Publish unresolved holds.

## Quality gates

The audit is not complete unless:

- existing inventory was checked first;
- every artifact has one primary job;
- every artifact has one disposition;
- evidence-touching items are routed through legal/evidence controls;
- high-privilege items are not broadly exposed;
- platform variants are tied to one canonical identity;
- retirement decisions include replacement or rollback path;
- source links are recorded.
