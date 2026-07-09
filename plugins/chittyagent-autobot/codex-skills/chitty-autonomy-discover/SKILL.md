---
name: chitty-autonomy-discover
description: Phase 1 — MANDATORY ChittyOS Ecosystem Discovery. Queries ChittyRegistry for relevant services; reads the Pentad (CHARTER/CHITTY/CLAUDE/SECURITY/AGENTS) of any service the work will touch; checks ChittyCanon for canonical patterns; consults Ch1tty MCP for ecosystem state. Output is a `discovery.md` that the planner phase consumes. Closes the gap that led services to silently bypass canonical pipelines (e.g. building rclone-based ingestion instead of POSTing to /documents).
canonical_uri: chittycanon://skills/chitty-autonomy-discover
status: DRAFT
---

# Phase 1: Ecosystem Discovery

## Why this phase exists

Without forced discovery, agents build in a vacuum. Real-world failure mode (observed): an agent built a Drive→R2→/collect ingestion path because the user said "drop folder watcher", never consulting `POST /documents` (the canonical gatekeeper with dedup). The hookify rule `block-bypass-pipeline` would have flagged this in interactive Claude Code sessions, but the systemd-timer-driven runtime evaded it. The proper fix is a PRODUCT-level discovery gate, not a local hook.

This phase is **MANDATORY**. The parent orchestrator refuses to advance to Plan without it.

## Process

### 1. Verify Sovereignty cert is valid

```bash
cert_id=$(jq -r .cert_id < chittycontext/structured-autonomy/${feature}/SOVEREIGNTY.cert)
chittysecrets run --env-file=<(echo "CT_TOKEN=op://ChittyOS-Core/ChittyCert API Token/credential") -- bash -c '
  curl -sS -X POST https://cert.chitty.cc/api/v1/verify \
    -H "Authorization: Bearer $CT_TOKEN" \
    -d "{\"cert_id\": \"$cert_id\"}"' | jq -e .valid
```

If invalid, return to Phase 0 (re-affirm).

### 2. Query ChittyRegistry

```bash
curl -s https://registry.chitty.cc/api/services | jq '.[] | {name,tier,domain,status,canonicalUri}' \
  > chittycontext/structured-autonomy/${feature}/registry-snapshot.json
```

Then narrow to services likely relevant to the feature request:

```bash
# AI assist — pass feature description + registry snapshot to a sub-prompt to
# identify candidate upstream/downstream services. Output a relevance ranking.
```

### 3. Read the Pentad of each relevant service

For each candidate service S:

```bash
for doc in CHARTER.md CHITTY.md CLAUDE.md SECURITY.md AGENTS.md; do
  if [ -f ~/projects/github.com/CHITTY{FOUNDATION,OS,APPS}/$S/$doc ]; then
    cat ~/projects/github.com/CHITTY{FOUNDATION,OS,APPS}/$S/$doc
  else
    # Pentad incomplete — record the gap; do not block discovery itself
    echo "MISSING: $S/$doc" >> chittycontext/structured-autonomy/${feature}/pentad-gaps.txt
  fi
done
```

Pentad gaps in EXISTING services are recorded but do not block; pentad gaps in NEW services scaffolded by THIS workflow DO block at Phase 9 (Ship).

### 4. Consult Ch1tty MCP

If `ch1tty` MCP server is connected:

```
mcp_tool: ch1tty.ecosystem_awareness
args: { feature: "<feature>", relevant_services: [...] }
```

Records current production state, recent incidents, blocking dependencies.

### 5. Consult ChittyCanon for ontology

```bash
# Local cache
cat ~/.claude/chittycontext/canon/ontology.json | jq '.entity_types'

# Authoritative
curl -s https://canon.chitty.cc/api/v1/governance | jq '.entity_types'
```

If the work touches entity types (any of P/L/T/E/A), the planner will be required to cite `// @canon: chittycanon://gov/governance#core-types` in generated code.

### 6. Generate discovery.md

Single source-of-truth output for the planner phase:

```markdown
# Discovery — <feature>

**Cert:** <cert_id> (valid until <expires_at>)

## Relevant services
| Service | Tier | Domain | Role | Pentad complete? |
|---|---|---|---|---|

## Canonical patterns to follow
- Pipeline: …  (the relevant `chittycanon://core/services/X` and its endpoints)
- Auth: …
- Storage: …
- Audit: …

## Identified canonical pipelines (DO NOT BYPASS)
- `POST /documents` (gatekeeper) — content + metadata, dedup
- `POST /collect` (registration only — file already in R2)
- `POST /vault/ingest` (batch from local vaults)
- `POST chitty-cert/api/v1/issue` (cert issuance)
- `POST chittychronicle/api/v1/entries` (audit)

## Pentad gaps in existing services (informational)
- …

## Discovered constraints
- …
```

## Failure Modes

- ChittyRegistry unreachable → use `~/.claude/chittycontext/canon/ontology.json` cache + most recent registry-snapshot in any feature dir; mark discovery as `degraded`.
- Pentad missing for ALL relevant services → ABORT; the work touches services that are not yet documented and the autonomy run cannot proceed safely. User must Pentad the upstream services first.

## Output Contract

```json
{
  "phase": "discover",
  "status": "completed",
  "discovery_doc": "chittycontext/structured-autonomy/<feature>/discovery.md",
  "relevant_services": ["chittyconnect", "chittyevidence", ...],
  "canonical_pipelines": ["/documents", "/collect", ...],
  "pentad_gaps_existing": [...],
  "ontology_touched": ["P", "T"],
  "chronicle_entry": "<id>"
}
```
