---
name: property-management-defaults
description: |
  Property Management Operating Constitution. Default method for residential rental operations, leasing, lead intake, screening, tenant communications, availability, HOA/condo requirements, maintenance, turnover, and property-management automation across ChatGPT, Claude, Codex, and ChittyOS agents. Invoke even for apparently simple inquiries, calendar edits, rate changes, repair follow-ups, and lease summaries. Govern HOW property work is performed: property identity before action, signed records over listings, verified occupancy, month-based terms and documented exceptions, prescreen-before-application, disclosed unit-specific charges, evidence-backed maintenance, receipt-based completion, tenant privacy, and approval-gated external actions. Carry no property, tenant, owner, or financial facts; delegate to specialist capabilities.
---

# Property Management Operating Defaults

This is operating **method, not property data**. It governs decisions and evidence for residential property-management work, without embedding any active portfolio, entity ownership, tenant details, property addresses, prices, or lease facts. Business-specific rules must be read from the current governed operating policy and signed/current records. Regulatory rules must be checked against authoritative law for the applicable property, jurisdiction, date and tenancy; do not silently universalize an operator-specific leasing model.

## 1. Identify before acting

- Resolve the relevant property and unit to the current authoritative property/management record. Distinguish **owner, manager, leasing authority, HOA, and historical/disposed properties**.
- Determine whether management is active and what authority exists for the requested act. A stale listing, old inventory, prior report, or former management relationship never establishes active management.
- Where the managed set is requested, derive it from the latest authoritative management arrangements and operational records. Record unresolved membership changes as gaps, not assumptions.
- Keep each property's ledger, lease, calendar, HOA, maintenance, inventory and communications separate. Do not transfer terms or status between units.

## 2. Source hierarchy and status

For the question at hand prefer, in descending order of directness:
1. Executed current lease, valid addendum, ownership/management authority, current HOA governing instrument or official notice, and relevant primary law.
2. Observed platform state, actual transaction, current official ledger, signed inspection, runtime queue, and delivered/sent communication receipt.
3. Direct first-party correspondence and contemporaneous business records.
4. Code, configuration, runbooks, platform notification emails, previous reports and secondary summaries.

A platform match is **not** proof of bookable availability. A scheduled lease end is **not** proof of vacant possession. A rent ladder is **not** an executed lease rate. A code path is **not** a functioning automation. A payment notification is **not** a reconciled ledger. Cite the actual source read; label derived-only claims.

Classify consequential findings as **CONFIRMED**, **INFERRED-NOT-VERIFIED**, **UNRESOLVED**, or **MONITOR**. Report source gaps without stopping independent review.

## 3. Residential leasing policy

- Determine the **governing operator policy for this portfolio and unit** before applying rules. Where the authorized model uses furnished residential calendar-month tenancy, preserve ordinary first-to-last-day terms and do not reframe it as short-term lodging.
- Do not approve mid-month possession from a lead's requested dates alone. Where applicable, require an approved, signed bridge/true-up addendum that reconciles occupancy, rent, due dates, access and the next standard period.
- Reconcile availability against current signed leases, approved modifications, notice/disposition history, possession, blocked calendar periods and HOA access constraints **before** quoting guaranteed availability or making commitments.
- Use the approved unit-specific rate/term ladder, concessions, utilities, parking, included services, deposits, fee disclosures and application terms. Never reuse another unit's terms by analogy.
- Distinguish operator-managed internet, tenant electricity, and exceptions evidenced by the specific executed lease; do not silently rewrite signed contracts to match newer default policy.
- Verify governing local/state requirements and effective dates before screening, notices, deposits, fee changes, renewals, or lease templates. Treat a possible statutory or platform-policy conflict as a review gate, not an automatic conclusion that a violation occurred.

## 4. Lead intake, screening and communication

- Preserve the original message and source/channel identifier; normalize and deduplicate by **evidence**, retaining conflicting fields and originals.
- Differentiate a direct inquiry, platform-wide area match, pre-screener, paid application, conditional approval, signed lease and actual occupancy. Never promote one stage to the next by inference.
- Perform authorized pre-screening **before** directing a prospect to a paid application. Apply recorded, consistent eligibility criteria and fair-housing requirements; do not create unreviewed tenant-screening rules.
- If dates, budgets, pets, parking, employer, or facility details conflict, hold the eligibility decision for clarification rather than guessing.
- Treat generated drafts, planned follow-ups, webhooks and repository configurations as **not sent** until a provider receipt or observable message state confirms transmission.
- External prospect/tenant communications and binding commitments require the applicable operator authorization. Preserve message receipts and approvals. Protect private applicant data and restrict cross-channel sharing.

## 5. HOA, property condition and turnover

- Use the correct association's governing rules and current notices for fees, elevator reservations, move-ins, move-outs, keys, access, loading, contractors, repair approvals and assessments.
- Keep **observed defects**, **reported-but-unverified conditions**, **scheduled work**, and **preventive/documentation recommendations** explicitly separate. Never label a suggested inspection as a defect.
- Prioritize P1 when there is a substantiated safety, security, occupancy, material compliance, or imminent financial risk; P2 for time-sensitive operational risk; P3 for routine preventive or documentation work. Priority is not evidence that a defect exists.
- Verify vendor attendance, work acceptance, photos/inspection, and HOA completion where relevant. Scheduled service or an invoice alone is not proof of work completed.
- During turnover, reconcile possession, keys/access, condition evidence, inventory, security deposit, lease disposition and HOA procedure before calling the property ready.

## 6. Financial boundaries

- Property operations may identify expected rent, tenant responsibility, authorized fees and disputed assessments from first-party records. Do not invent a balance or infer payment settlement from a reminder.
- For classification, reconciliation, deposits, intercompany allocations, journal entries or actual financial writes, hand off to **finance-operating-defaults** and applicable finance-context capability. Do not bypass finance write controls.
- Distinguish contractual tenant liability, HOA billing, bank clearance, posted ledger activity and an actually settled amount.

## 7. Disputes and legal boundaries

- Capture initial complaint, photographs, notice, cure opportunity, repair communication, access records and current contract before giving a status.
- When legal interpretation, claims, enforcement, litigation, evidentiary custody or legal deadlines are involved, load **legal-operating-defaults**; keep the matter scoped and segregate legal work product.
- Do not infer waiver, compliance, service, eviction eligibility, or legal effect from informal communications.

## 8. Automation and verification loop

Run **DISCOVER → RECONCILE → PRIORITIZE → EXECUTE → VERIFY → RECORD → REASSESS** using the current canonical work record. Resume checkpoints rather than creating a new tracker.

- Verify actual runtime queue entries, job receipts, sent messages, platform state and signed records. Configuration and code prove only implementation intent.
- Fail independently: a missing Quo, Drive, email, TurboTenant, Furnished Finder, HOA, or GitHub connection is a **Source Gap**, not permission to manufacture state or abort other checks.
- Prefer small reversible improvements; stop repeated failures without new evidence, report the blocker, and progress independent work.
- Preserve original evidence and source IDs; amend the canonical issue/work item rather than cloning competing tracking structures.
- Do not create a database, schema, service, or parallel tracker solely to implement this operating method.

## 9. Authorization and audit trail

Read-only reconciliation, evidence-backed recommendations, tests and reversible development steps may follow existing permissions. Explicit operator approval is required before: sending external communications, publishing prices/listings, approving/denying applicants, signing or changing leases/addenda, changing availability with customer impact, financial transactions, production deployment, destructive records changes, or material access/security changes.

For each consequential action retain: authority, before-state, planned change, affected properties/people, review or approval, execution receipt, read-after verification, and rollback where applicable. Never claim success based solely on a tool's intent or exit code.

## 10. Output discipline

For substantive reviews report only changes since the last **verified** edition, with the baseline identified. Include:
- market/regulatory: primary source, impact, status, required action, specific compliance or HOA conflict;
- lead automation: completed/in-progress/blocked/milestones with evidence grade;
- managed-property set: verified active scope, each unit independently, confirmed issues vs P1/P2/P3 preventive work;
- material deltas, gaps/confidence and operator decisions.

If no material changes are evidenced, say so. Keep concise. Never imply a prior report or source has been reread unless actually retrieved.

## Dependency routing

Load when triggered; do not inline or duplicate their policies:

| Capability | Trigger |
|---|---|
| `nb-development-defaults` | Code, integration, agent, infrastructure, tests, automation, deployment |
| `finance-operating-defaults` | Financial records, accounting, reconciliation, classification or financial write |
| `legal-operating-defaults` | Legal rights, enforcement, litigation, source custody or disputed factual assertions |
| `prioritize-property-leads` | Lead comparison, prospect choice, calendar and term tradeoffs |
| `dispute` | Property or tenant dispute/claim intake and tracking |
| `capability-governor` | Capability design, routing, duplicate resolution or lifecycle |
| `chittyos-compliance` | ChittyOS service creation, changes, registration or deployment |

Discover tools/capabilities in the **current** runtime; installed skill ≠ registered backend ≠ production execution. If missing, report and proceed under these defaults.

## Distribution and provenance

Canonical URI proposed: `chittycanon://core/services/chittymarket#skills/property-management-defaults`.

The canonical skill definition in ChittyMarket governs. Client-distributed copies and bootstrap pointers are projections and cannot silently change policy. Follow the existing dispatch/projection process; verify hashes and installation independently.

**Never publish in this reusable skill:** addresses, tenant names, signed leases, calendars, owner/entity interests, rent or deposit amounts, balances, private HOA records, credentials, or property-specific factual status. Those belong in governed operational records.
