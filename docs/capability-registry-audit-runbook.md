# Capability Registry Audit Runbook

**Version:** 0.2
**Purpose:** Repeatable process for auditing, classifying, consolidating, routing,
and retiring ChittyOS capabilities without losing canonical identity, evidentiary
integrity, or channel-specific usability. Grounded in canonical agents, dynamic
projection, forensic rigor, search-and-execute gateways, and artifact retirement.

This is the **process** that governs the ChittyMarket refactor — not the refactor
itself. The refactor strategy lives in `docs/refactor-prompt.md`.

---

## 1. Operating Principle

Every capability should have **one canonical identity** and many permitted projections.

A capability may appear in ChatGPT, local filesystem tools, MCP gateways, portals,
CLIs, or legal workflows, but those should be treated as **runtime projections**,
not separate products unless they perform materially different jobs.

**Default stance:**

> Identify existing canonical capability first.
> Do not create a new agent, tool, database, schema, or registry entry until the
> existing inventory has been checked.

---

## 2. When to Run This Process

| Trigger                         | Required Action                  |
| ------------------------------- | -------------------------------- |
| New tool / agent proposed       | Intake and classify before build |
| Duplicate capability found      | Compare and merge/route/retire   |
| New platform adapter added      | Validate projection rules        |
| Marketplace cleanup             | Batch audit inventory            |
| Legal/evidence workflow touched | Check evidentiary integrity      |
| MCP / gateway routing changed   | Revalidate exposure model        |
| Monthly governance cycle        | Run portfolio pass               |

---

## 3. Required Inputs

| Input                  | Description                                                      |
| ---------------------- | ---------------------------------------------------------------- |
| Capability name        | Current user-facing or repo name                                 |
| Source location        | Repo, manifest, skill, MCP endpoint, app, doc, or asset link     |
| Current owner          | Person/team/system responsible                                   |
| Current runtime        | ChatGPT, local, MCP, CLI, web app, legal space, etc.             |
| Primary job-to-be-done | What the user is trying to accomplish                            |
| Data touched           | Files, legal records, entities, assets, logs, emails, financials |
| Privilege level        | None, read-only, write, filesystem, network, admin, forensic     |
| Evidence impact        | None, low, medium, high, legal-grade                             |
| Existing duplicates    | Similar capabilities, old agents, adapters, scripts              |
| Current status         | Active, experimental, deprecated, unknown                        |

---

## 4. Classification Axes

Every artifact must be classified across **four axes** (plus the v0.2 entity check).

### A. Job-to-be-Done

| Category | Examples                                                |
| -------- | ------------------------------------------------------- |
| Verify   | audit evidence, validate claims, check records          |
| Collect  | ingest documents, gather files, preserve metadata       |
| Route    | dispatch tools, expose capabilities, search-and-execute |
| Generate | draft docs, reports, filings, summaries                 |
| Govern   | approve, certify, log decisions, enforce policy         |
| Operate  | deploy, monitor, repair, clean, sync                    |
| Resolve  | disputes, issues, claims, negotiations                  |
| Remember | context, checkpoint, continuity, handoff                |

### B. Environmental Footprint

| Footprint            | Definition                                     | Likely Placement                |
| -------------------- | ---------------------------------------------- | ------------------------------- |
| Context-only         | Uses only conversation text                    | Skill / prompt workflow         |
| Read-only connector  | Reads existing docs, repos, files              | Connector / gateway             |
| Write-capable        | Updates records or artifacts                   | Controlled tool                 |
| Filesystem-local     | Needs local paths, metadata, bulk files        | Local plugin / CLI              |
| Network/service      | Calls APIs or deployed services                | MCP / gateway                   |
| Admin/system         | Changes infra, auth, configs                   | Restricted operator             |
| Forensic/legal-grade | Preserves chain of custody, hashes, timestamps | Legal space / evidence pipeline |

### C. Evidentiary Risk

| Risk        | Definition                                  | Requirement                                    |
| ----------- | ------------------------------------------- | ---------------------------------------------- |
| None        | No durable record implications              | Normal handling                                |
| Low         | Internal productivity artifact              | Source link preferred                          |
| Medium      | Business record or decision support         | Decision log required                          |
| High        | Affects claims, disputes, money, compliance | Source IDs required                            |
| Legal-grade | Court, evidence, custody, sworn claims      | Hash, timestamp, citation map, immutable trail |

### D. Runtime Projection

| Projection                 | Use When                                                     |
| -------------------------- | ------------------------------------------------------------ |
| Skill                      | Repeatable ChatGPT workflow with instructions/templates      |
| MCP tool                   | Needs callable service/tool execution                        |
| Local CLI/plugin           | Needs filesystem, high privilege, or local state             |
| Gateway search-and-execute | Many tools exist but should stay out of context until needed |
| Web app / portal           | Requires UI, human review, dashboards                        |
| Legal space only           | Touches evidence, claims, filings, or case records           |
| Retired                    | Duplicate, obsolete, unsafe, or superseded                   |

### E. Entity Mapping (v0.2)

Every capability must map to at least one **core entity** under the canonical
P/L/T/E/A ontology (`chittycanon://gov/governance#core-types`):

| Code | Entity    | When a capability maps here                              |
| ---- | --------- | -------------------------------------------------------- |
| P    | Person    | Acts on/about an actor with agency (user, agent, party)  |
| L    | Location  | Acts on/about a jurisdiction, venue, node, machine       |
| T    | Thing     | Acts on/about a document, asset, file, artifact          |
| E    | Event     | Acts on/about a transaction, decision, action, ingest    |
| A    | Authority | Acts on/about a credential, cert, policy, decision       |

A capability with no entity mapping is a smell — either it has no canonical
target (retire candidate) or the mapping was skipped (hold for re-audit).

---

## 5. Audit Workflow

### Step 1 — Intake

```yaml
capability_name:
source_link:
current_location:
owner:
current_runtime:
requested_action: classify | add | merge | retire | migrate | expose
primary_job:
data_touched:
known_duplicates:
legal_or_evidence_impact: yes | no | unknown
entity_mapping: [P|L|T|E|A]
```

### Step 2 — Existing-First Search

1. Search existing registry / inventory (ChittyRegistry, `marketplace.json`).
2. Search related repos and manifests.
3. Search skills and MCP gateways (Ch1tty `servers.json`, ChittyMCP tool list).
4. Search Legal space if evidence-related.
5. Identify closest canonical capability.

**Gate:** If a canonical capability already exists, the new artifact becomes a
**projection**, **adapter**, or **duplicate candidate** — not a new root.

### Step 3 — Canonical Identity Decision

| Question                                              | Decision Impact                |
| ----------------------------------------------------- | ------------------------------ |
| Does this perform a genuinely new job?                | May become canonical           |
| Is it only a platform-specific version?               | Projection                     |
| Is it a wrapper around an existing tool?              | Adapter                        |
| Does it duplicate another artifact?                   | Merge / retire                 |
| Does it require different custody or privilege rules? | Separate controlled projection |

Canonical identity record:

```yaml
canonical_id:
display_name:
job_to_be_done:
source_of_truth:
entity_mapping: [P|L|T|E|A]
allowed_projections:
restricted_projections:
owner:
status:
```

### Step 4 — Score Risk and Privilege

```yaml
evidentiary_risk: none | low | medium | high | legal-grade
environmental_footprint: context-only | read-only | write-capable | filesystem-local | network-service | admin-system | forensic-legal-grade
system_footprint: metadata-only | connector-read | write-capable | filesystem | memory-forensic | admin
```

**Rule:** the higher of evidentiary risk or environmental footprint controls routing.

### Step 5 — Placement Decision (Capability Placement Decision Matrix)

Walk the questions top-to-bottom. First "Yes" wins.

| Question                                                                           | If Yes | Decision                               |
| ---------------------------------------------------------------------------------- | -----: | -------------------------------------- |
| Does it already exist under another name?                                          |    Yes | **Merge / Project**                    |
| Is it only a platform adapter for an existing capability?                          |    Yes | **Project**                            |
| Does it perform a new job-to-be-done?                                              |    Yes | **Promote / Keep**                     |
| Does it only need reasoning, templates, or repeatable procedure?                   |    Yes | **Skill**                              |
| Does it need API/tool execution?                                                   |    Yes | **MCP / Gateway**                      |
| Does it require many possible tools but only some per task?                        |    Yes | **Search-and-Execute Gateway**         |
| Does it need local filesystem, device state, or metadata preservation?             |    Yes | **Local-Only**                         |
| Does it touch live memory, bit-stream capture, hashes, custody, or forensic state? |    Yes | **Legal / Evidence Pipeline**          |
| Does it touch governance, valuation, removal docs, claims, filings, or disputes?   |    Yes | **Legal Space + Non-Repudiation Gate** |
| Is it obsolete, redundant, unsafe, or ownerless?                                   |    Yes | **Retire**                             |

#### Scoring overlay

| Axis                 | Low               | Medium          | High                         |
| -------------------- | ----------------- | --------------- | ---------------------------- |
| **System Footprint** | context-only      | connector/API   | filesystem/admin/forensic    |
| **Evidentiary Risk** | no durable record | business record | legal/custody/non-repudiable |
| **Context Cost**     | light             | moderate        | heavy/specialized            |
| **Reuse Frequency**  | rare              | recurring       | core workflow                |

#### Final disposition (assign exactly one)

`keep | promote | project | merge | gateway | skill | local-only | legal-only | retire | hold`

### Step 6 — Produce Disposition

| Disposition | Meaning                               |
| ----------- | ------------------------------------- |
| Keep        | Valid canonical capability            |
| Promote     | Should become canonical               |
| Project     | Keep as channel-specific projection   |
| Merge       | Consolidate into canonical capability |
| Gateway     | Expose through search-and-execute     |
| Local-only  | Do not expose broadly                 |
| Legal-only  | Keep inside Legal/evidence workflow   |
| Retire      | Remove or mark obsolete               |
| Hold        | Insufficient source data              |

---

## 6. Decision Log Template

```yaml
decision_id:
date:
capability_name:
canonical_id:
source_links:
current_state:
decision: keep | promote | project | merge | gateway | local-only | legal-only | retire | hold
job_to_be_done:
entity_mapping: [P|L|T|E|A]
environmental_footprint:
evidentiary_risk:
rationale:
duplicates_found:
migration_required: yes | no
migration_owner:
next_action:
review_date:
```

---

## 7. Migration Queue Template

```yaml
migration_item:
from_artifact:
to_canonical_capability:
action: merge | rename | reroute | retire | document | restrict
blocking_dependencies:
risk_level:
owner:
status: backlog | active | blocked | done
completion_evidence:
```

---

## 8. Retirement Criteria

Retire an artifact when:

* It duplicates a canonical capability.
* It is a platform-specific clone with no unique function.
* It bypasses evidence/custody controls.
* It requires obsolete manifests or schemas.
* It confuses users with redundant entries.
* It has no owner or active runtime.
* It can be replaced by gateway search-and-execute.

Retirement record:

```yaml
retired_artifact:
replacement_capability:
reason:
source_links:
effective_date:
rollback_path:
```

---

## 9. Monthly Governance Cycle

* **Week 1 — Inventory Refresh** — pull manifests, list active artifacts, flag unowned/duplicates.
* **Week 2 — Classification** — apply JTBD, risk, footprint, entity; identify conflicts.
* **Week 3 — Decisions** — keep / merge / gateway / retire; create migration queue.
* **Week 4 — Publish** — update taxonomy map, queue, retirement list, holds.

---

## 10. Output Package

Each completed cycle produces:

1. Capability Taxonomy Map
2. Canonical Capability Registry Update
3. Duplicate / Merge List
4. Gateway Candidate List
5. Local-Only / Legal-Only Restricted List
6. Retirement List
7. Migration Queue
8. Decision Log

---

## 11. Quality Gates

An audit is not complete unless:

* Existing inventory was searched first.
* Every artifact has one primary job-to-be-done.
* Every artifact has one entity mapping (P/L/T/E/A).
* Every artifact has one disposition.
* Evidence-touching items are routed to Legal space.
* High-privilege items are not broadly exposed.
* Platform variants are tied to one canonical identity.
* Dual-manifest audit ran: canonical definitions vs. projection manifests; mismatches treated as drift.
* Non-repudiation gate: anything touching legal/governance/valuation/custody has hash + timestamp + source trail before activation.
* Retirement decisions include a replacement or rollback path.
* Decision log includes source links.

---

## 12. Per-Channel Projection Matrix (v0.2)

Define what each environment may expose:

| Channel             | May expose                                                 | Must not expose                                       |
| ------------------- | ---------------------------------------------------------- | ----------------------------------------------------- |
| ChatGPT             | Skills, gateway search-and-execute, read-only connectors   | Filesystem-local, admin/system, forensic-legal-grade  |
| Claude Code (local) | All projections including filesystem-local                 | Anything bypassing ChittyConnect for secrets          |
| Claude.ai web       | Skills, gateway, read-only connectors                      | Filesystem-local                                      |
| Codex / Codex App   | Skills via dispatch, gateway                               | Filesystem operations outside daemon scope            |
| OpenClaw            | Skills via dispatch, restricted MCP                        | Network/service without security review               |
| Legal space         | Forensic-legal-grade only, with non-repudiation gate       | Productivity skills, ad-hoc connectors                |
| MCP gateway         | Network/service tools registered via Ch1tty                | Local CLI / filesystem-only capabilities              |
| Portal / web app    | Human-review and dashboard surfaces                        | Direct evidence mutation without Legal-space routing  |

---

## 13. Minimal First Implementation

Tracker columns:

| Column           |
| ---------------- |
| Capability       |
| Source Link      |
| Current Runtime  |
| Job-to-be-Done   |
| Entity Mapping   |
| Canonical ID     |
| Footprint        |
| Evidentiary Risk |
| Duplicates       |
| Disposition      |
| Owner            |
| Next Action      |
| Review Date      |

First batch: 10–20 artifacts. Prioritize:

1. obvious duplicates;
2. legal/evidence tools;
3. high-privilege local tools;
4. gateway candidates;
5. stale marketplace entries.

---

## 14. Repeatable Command Pattern

```text
Run Capability Registry Audit on [artifact or inventory batch].

Identify existing canonical capability first.
Classify by job-to-be-done, entity mapping (P/L/T/E/A), environmental footprint,
evidentiary risk, and runtime projection.
Assign one disposition: keep, promote, project, merge, gateway, local-only,
legal-only, retire, or hold.
Return taxonomy entry, decision log, migration action, and required source links.
Do not create new schema or database.
```

---

## 15. Next Step

Turn this runbook into a reusable Skill named `capability-registry-audit` that
generates four standard outputs:

1. taxonomy entry;
2. disposition decision;
3. migration queue item;
4. decision log.

---

## v0.2 Additions (delta from v0.1)

1. **Dual-manifest audit** — audit canonical registry definitions and platform
   projection manifests together; treat mismatches as drift (§11).
2. **Entity-first checkpoint** — every capability maps to at least one P/L/T/E/A
   entity (§4.E, intake, decision log).
3. **System-footprint scoring** — depth-of-intervention axis alongside
   environmental footprint (§5.4).
4. **Per-channel projection matrix** — explicit allow/deny per channel (§12).
5. **Non-repudiation gate** — legal/governance/valuation/custody/forensic state
   must carry hash + timestamp + source trail before activation (§11).

The core thesis: this is not marketplace cleanup. It is an **identity-first,
evidence-grade capability governance system**.
