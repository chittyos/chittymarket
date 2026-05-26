---
name: capability-registry-audit
canon_uri: chittycanon://core/services/chittymarket#skills/capability-registry-audit
description: Audit a ChittyOS capability (tool, agent, skill, MCP server, plugin, manifest entry) against the canonical Capability Registry. Produces taxonomy entry, disposition decision, migration queue item, and decision log per the v0.2 runbook. Triggers on "audit capability", "classify capability", "registry audit", "is this a duplicate?", "/capability-registry-audit", or any new agent/tool/skill proposal.
kind: skill
plugin: chittyos-governance
runtimes:
  - claude-code
classification:
  - governance
  - compliance
---

# Capability Registry Audit

Runs the canonical audit process from `docs/capability-registry-audit-runbook.md` v0.2 on a single capability or a batch. Identity-first, evidence-grade. Never create a new canonical entry until existing inventory is searched.

**Reference:** the runbook is the spec. This skill is the executable workflow.

## When to invoke

- New tool / agent / skill / MCP server / plugin proposed
- Suspected duplicate
- New platform adapter or projection added
- Marketplace cleanup pass
- Any artifact touching legal / evidence / custody / governance
- Monthly governance cycle

## Inputs

Collect from the user (ask only what is missing — do not bounce trivially-derivable items):

```yaml
capability_name:        # current user-facing name
source_link:            # repo path, manifest entry, MCP endpoint, doc URL
current_runtime:        # ChatGPT | Claude Code | MCP | CLI | web | legal-space | other
primary_job:            # one sentence — what is the user accomplishing?
data_touched:           # files, records, entities, assets, logs, financials
privilege_level:        # none | read-only | write | filesystem | network | admin | forensic
evidence_impact:        # none | low | medium | high | legal-grade
requested_action:       # classify | add | merge | retire | migrate | expose
```

## Procedure

### Step 1 — Existing-first search (MANDATORY)

Before classifying anything, search the existing canonical inventory. Do all five in parallel:

1. **Canonical overlay (primary)** — `jq '.capabilities[] | select(.name | test("<keyword>"; "i") or .description | test("<keyword>"; "i"))' capabilities.generated.json`. This is the canonical Capability Record source as of Phase 1 (102 capabilities). Each record carries `capability_id` (chittycanon URI), `capability_group`, `execution_class`, `ontology` (P/L/T/E/A), `canonical_version`, and `discovery` rules.
2. `curl -s https://registry.chitty.cc/api/services | jq '.services[] | select(.name | test("<keyword>"; "i"))'`
3. Grep `marketplace.json` and `.claude-plugin/marketplace.json` for related names.
4. Read related CHARTER.md / CHITTY.md / CLAUDE.md for closest canonical capability.
5. Check Ch1tty `servers.json` and ChittyMCP tool list for live registrations.

The overlay is generated; if your audit produces a disposition that would change a record, the upstream generator must be re-run — do not hand-edit `capabilities.generated.json`. See `docs/architecture/CHITTYMARKET_CAPABILITY_ROUTER.md`.

**Gate:** if a canonical capability already exists with overlapping job-to-be-done, the new artifact is a **projection / adapter / duplicate candidate**, not a new root. Stop and route to Step 5 with `merge` or `project` disposition.

### Step 2 — Classify across the 5 axes

Apply the runbook taxonomy:

- **A. Job-to-be-done**: verify | collect | route | generate | govern | operate | resolve | remember
- **B. Environmental footprint**: context-only | read-only | write-capable | filesystem-local | network-service | admin-system | forensic-legal-grade
- **C. Evidentiary risk**: none | low | medium | high | legal-grade
- **D. Runtime projection**: skill | mcp-tool | local-cli | gateway-search-execute | web-portal | legal-space-only | retired
- **E. Entity mapping (P/L/T/E/A)**: at least one of Person / Location / Thing / Event / Authority — `chittycanon://gov/governance#core-types`

A capability with **no entity mapping is a smell** → disposition `hold` until re-audited.

### Step 3 — Capability Placement Decision Matrix

Walk top-to-bottom. First "Yes" wins:

1. Already exists under another name? → **Merge / Project**
2. Only a platform adapter for existing capability? → **Project**
3. Genuinely new job-to-be-done? → **Promote / Keep**
4. Only needs reasoning / templates / repeatable procedure? → **Skill**
5. Needs API/tool execution? → **MCP / Gateway**
6. Many tools, only some per task? → **Search-and-Execute Gateway**
7. Needs filesystem / device state / metadata preservation? → **Local-Only**
8. Touches live memory / bit-stream / hashes / custody / forensic state? → **Legal / Evidence Pipeline**
9. Touches governance / valuation / removal docs / claims / filings / disputes? → **Legal Space + Non-Repudiation Gate**
10. Obsolete / redundant / unsafe / ownerless? → **Retire**

### Step 4 — Apply governance gates

- **Non-repudiation gate** — any legal / governance / valuation / custody / forensic capability must carry hash + timestamp + source trail before activation. If missing, block with `hold`.
- **Per-channel projection allow/deny** — emit `allowed_projections` and `restricted_projections`. The compiler must refuse projections into channels not on the allow list. See runbook §12.
- **Sensitive intent routing** — anything touching credentials / secrets / deploy / registry mutation routes through `ch1tty → ChittyConnect`. Fail closed with `POLICY_BLOCKED_CHITTYCONNECT_UNAVAILABLE` if broker unavailable.

### Step 5 — Emit the four standard outputs

Produce all four. Do not skip any.

#### Output 1 — Taxonomy entry

```yaml
canonical_id:           # stable kebab-case ID
display_name:
job_to_be_done:
entity_mapping: [P|L|T|E|A]
source_of_truth:        # canonical repo + path
environmental_footprint:
evidentiary_risk:
canonical_version:      # semver — projections inherit, never fork
runtime_exclusions: []  # e.g. [openclaw] for security-restricted runtimes
allowed_projections: []
restricted_projections: []
non_repudiation_required: false
slim_mcp_hint:          # one-line cheat-sheet entry for the SessionStart index
owner:
status: active | experimental | deprecated
```

#### Output 2 — Disposition decision

Exactly one of: `keep | promote | project | merge | gateway | skill | local-only | legal-only | retire | hold`

```yaml
decision_id:
date:
capability_name:
canonical_id:
decision:
rationale:                 # why this disposition, citing the matrix step that triggered it
duplicates_found: []
migration_required: yes | no
next_action:
review_date:
```

#### Output 3 — Migration queue item (only if `migration_required: yes`)

```yaml
migration_item:
from_artifact:
to_canonical_capability:
action: merge | rename | reroute | retire | document | restrict
blocking_dependencies: []
risk_level: low | medium | high
owner:
status: backlog
completion_evidence:       # link to PR / commit / deploy that closes it
```

#### Output 4 — Decision log entry

Append to `docs/decisions/capability-audit-log.md` (create if missing). One entry per audit.

```yaml
decision_id:
date:
capability_name:
canonical_id:
source_links: []
current_state:
decision:
job_to_be_done:
entity_mapping: [P|L|T|E|A]
environmental_footprint:
evidentiary_risk:
rationale:
duplicates_found: []
migration_required: yes | no
migration_owner:
next_action:
review_date:
```

### Step 6 — Quality gates (block on failure)

The audit is not complete unless:

- [ ] Existing inventory was searched first.
- [ ] Exactly one primary job-to-be-done.
- [ ] At least one P/L/T/E/A entity mapping.
- [ ] Exactly one disposition.
- [ ] Evidence-touching items routed to Legal space.
- [ ] High-privilege items not broadly exposed.
- [ ] Platform variants tied to one canonical identity.
- [ ] Dual-manifest drift checked (canonical vs projection manifests).
- [ ] Non-repudiation gate applied where required.
- [ ] Retirement decisions include a replacement or rollback path.
- [ ] Decision log includes source links.

## Reporting

Return a single markdown report containing:

1. Capability under audit (1-line summary).
2. Existing-first search results (what was found, what wasn't).
3. Classification across all 5 axes.
4. Matrix walk: which question triggered the disposition.
5. The four standard outputs (above).
6. Quality-gate checklist with pass/fail per item.

## Batch mode

When auditing inventory (e.g., `marketplace.json`), prioritize in this order:

1. Obvious duplicates
2. Legal / evidence tools
3. High-privilege local tools
4. Gateway candidates
5. Stale marketplace entries

Cap each batch at 10–20 artifacts; produce one consolidated report with a per-item disposition table plus per-item full outputs in an appendix.

## Anti-patterns (refuse to produce)

- Creating a new canonical ID without an existing-first search.
- Emitting a disposition with no entity mapping.
- Promoting a platform-specific clone to canonical when an upstream capability already exists.
- Approving a legal/evidence capability without the non-repudiation gate.
- Allowing a projection into a channel not on the canonical `allowed_projections` list.
