# ChittyMarket Artifact Audit — Phase 0

**Date:** 2026-05-11  
**Source:** `marketplace.json` (109 entries; 7 separator comments excluded)  
**Auditor:** `capability-governor` skill v0.1 (deterministic heuristic classifier)  
**Total real artifacts audited:** 102

This is the **Phase 0 deliverable** from §10 of `chittymarket_revised_refactor_recommendation.md`. No behavior changes — view-layer only.

---

## Disposition rollup

| Disposition | Count | % | Meaning |
|---|---:|---:|---|
| `hold` | 37 | 36% | Insufficient evidence; needs source_links + canonical_id before classification |
| `gateway` | 33 | 32% | Route through Ch1tty / MCP gateway |
| `local-only` | 17 | 17% | Filesystem / admin / shell — local execution required |
| `legal-only` | 9 | 9% | Touches evidence / forensic / custody — non-repudiation gate required |
| `skill` | 6 | 6% | Repeatable reasoning / template / runbook |

## Environmental footprint rollup

| Footprint | Count | % |
|---|---:|---:|
| `network-service` | 33 | 32% |
| `write-capable` | 29 | 28% |
| `read-only connector` | 17 | 17% |
| `admin-system` | 9 | 9% |
| `filesystem-local` | 9 | 9% |
| `forensic-legal-grade` | 5 | 5% |

## Evidentiary risk rollup

| Risk | Count |
|---|---:|
| `none` | 91 |
| `legal-grade` | 5 |
| `high` | 3 |
| `medium` | 3 |

---

## Key finding: 100% blocked on `source_links`

**All 102 artifacts** are flagged as blocked because the current `marketplace.json` schema has no `source_links` field per entry. This is the single largest blocker for activating any classification.

**Phase 1 implication:** the capability overlay must add `source_links` as a required field for every artifact before any disposition can move from advisory → enforced.

---

## Per-disposition artifact inventory

### `legal-only` (9)

| Capability | Job | Footprint | Risk |
|---|---|---|---|
| Read and Write ChittyOS | route | forensic-legal-grade | none |
| Search Evidence Documents | collect | forensic-legal-grade | legal-grade |
| Fact Governance | generate | forensic-legal-grade | legal-grade |
| Dispute Manager | resolve | write-capable | legal-grade |
| Court Docket | generate | write-capable | legal-grade |
| Evidence Collection | collect | forensic-legal-grade | legal-grade |
| Legal Arsenal | generate | write-capable | high |
| Block Governance Edits | govern | admin-system | high |
| ChittyMCP (Claude.ai) | verify | forensic-legal-grade | high |

### `local-only` (17)

| Capability | Job | Footprint | Risk |
|---|---|---|---|
| Read and Write Cloudflare | route | admin-system | none |
| Read and Write Filesystem | generate | filesystem-local | none |
| ChittyXL Session Manager | verify | admin-system | none |
| ChittyContext Checkpoints | remember | filesystem-local | none |
| Deploy to Cloudflare Workers | operate | admin-system | none |
| Wrangler Audit | verify | admin-system | none |
| Supabase | generate | admin-system | none |
| Validate Entity Types | verify | filesystem-local | none |
| Claude = Person, Not Thing | govern | filesystem-local | none |
| Block ChittyID Generation | operate | filesystem-local | none |
| ChittyID Accountability | verify | filesystem-local | none |
| Session Identity Card | operate | filesystem-local | none |
| Canon Certification Gate | govern | admin-system | none |
| Block Direct Deploy | operate | admin-system | none |
| Require PR Workflow | operate | filesystem-local | none |
| Suggest ChittyConnect | operate | filesystem-local | none |
| Vercel (Claude.ai) | generate | admin-system | none |

### `gateway` (33)

| Capability | Job | Footprint | Risk |
|---|---|---|---|
| Read and Write Neon Database | route | network-service | none |
| Read and Write Source Code | verify | network-service | none |
| Read and Write Quality Metrics | generate | network-service | none |
| Sequential Thinking | route | network-service | none |
| Control your Mac | route | network-service | none |
| Control Chrome | route | network-service | none |
| Control Browser Automation | route | network-service | none |
| Fill and Analyze PDFs | generate | network-service | none |
| Read and Write Apple Notes | route | network-service | none |
| Read and Send iMessages | route | network-service | none |
| Health Check Services | operate | network-service | none |
| Query Service Registry | route | network-service | none |
| ChittyOS Compliance | operate | network-service | medium |
| Firecrawl | operate | network-service | none |
| ChittyHelper | operate | network-service | none |
| Registration Compliance | govern | network-service | medium |
| Claude Integration Architect | route | network-service | none |
| Neon Schema Drift | operate | network-service | none |
| Notion Proxy Agent | generate | network-service | none |
| Cloudflare Proxy Agent | generate | network-service | none |
| Notion (Claude.ai) | route | network-service | none |
| Cloudflare Developer Platform (Claude.ai) | route | network-service | none |
| Figma (Claude.ai) | generate | network-service | none |
| Mercury Banking (Claude.ai) | route | network-service | none |
| Hugging Face (Claude.ai) | route | network-service | none |
| Context7 (Claude.ai) | route | network-service | none |
| Gmail (Claude.ai) | generate | network-service | none |
| Google Calendar (Claude.ai) | route | network-service | none |
| Plaid Developer Tools (Claude.ai) | route | network-service | none |
| Jam Bug Reports (Claude.ai) | route | network-service | none |
| Trivago (Claude.ai) | route | network-service | none |
| Play Sheet Music (Claude.ai) | route | network-service | none |
| ChittyAgent Autobot | generate | network-service | none |

### `skill` (6)

| Capability | Job | Footprint | Risk |
|---|---|---|---|
| Cloudflare Pipelines | generate | write-capable | none |
| Session Cleanup | generate | write-capable | none |
| Checkpoint Manager | remember | write-capable | none |
| ChittyMarket Manager | verify | write-capable | none |
| Hugging Face Skills | operate | read-only connector | none |
| Skill Creator | generate | write-capable | none |

### `hold` (37)

| Capability | Job | Footprint | Risk |
|---|---|---|---|
| Agent SDK Dev | generate | write-capable | none |
| Code Review | operate | read-only connector | none |
| Context7 | generate | read-only connector | none |
| Frontend Design | generate | write-capable | none |
| GitHub | verify | write-capable | none |
| Go LSP | operate | read-only connector | none |
| Hookify | generate | write-capable | none |
| Feature Dev | generate | write-capable | none |
| Notion | generate | write-capable | none |
| Plugin Dev | generate | write-capable | none |
| PR Review Toolkit | operate | read-only connector | none |
| TypeScript LSP | operate | read-only connector | none |
| Superpowers | generate | write-capable | none |
| Code Simplifier | verify | write-capable | none |
| Ralph Loop | generate | write-capable | none |
| Playwright Plugin | generate | write-capable | none |
| Commit Commands | generate | write-capable | none |
| Security Guidance | operate | read-only connector | none |
| Serena Plugin | generate | write-capable | none |
| CLAUDE.md Management | verify | write-capable | medium |
| Python LSP | operate | read-only connector | none |
| Claude Code Setup | operate | read-only connector | none |
| Greptile | operate | read-only connector | none |
| Linear | generate | write-capable | none |
| Sentry | operate | read-only connector | none |
| Playground | generate | write-capable | none |
| Java LSP | operate | read-only connector | none |
| CodeRabbit | operate | read-only connector | none |
| Circleback | operate | read-only connector | none |
| Semgrep | operate | read-only connector | none |
| ChittyAgent | generate | write-capable | none |
| ChittyCommand | generate | write-capable | none |
| GitHub Workflows | generate | write-capable | none |
| Schema Validator | operate | read-only connector | none |
| ChittyConnect Concierge | generate | write-capable | none |
| ChittyCanon Code Cardinal | verify | read-only connector | none |
| ChatGPT Proxy Agent | generate | write-capable | none |

---

## Known heuristic false positives (manual review needed)

These artifacts landed in a disposition that doesn't match their primary purpose. Capture as overrides during Phase 1.

| Artifact | Auditor said | Should be | Why misclassified |
|---|---|---|---|
| Read and Write ChittyOS | `legal-only` | `gateway` | Description mentions 'evidence' (one of many routes); not primarily legal |

---

## Methodology

- **Tool:** `capability-governor` skill, `scripts/batch_audit.py`
- **Classification:** keyword-driven heuristic (job-to-be-done × environmental-footprint × evidentiary-risk)
- **Quality gate:** missing `source_links` blocks activation (per runbook §4 quality gates)
- **Output schema:** `references/output-templates.md` — taxonomy entry + decision log + migration queue item per artifact

## Next steps (Phase 1 starter)

1. Add `source_links` to every `marketplace.json` entry — sourced from existing `installMode`/`source` paths and repo references.
2. Add `capability_group` (JTBD) and `execution_class` (@chitty/*) overlay fields per addendum §16.1.
3. Re-run `batch_audit.py` once `source_links` are populated; hold count should drop from 37 → near zero.
4. Resolve known false positives via per-artifact overrides.
5. Cross-reference dispositions against the kill/merge/demote list in §11 of the revised recommendation.