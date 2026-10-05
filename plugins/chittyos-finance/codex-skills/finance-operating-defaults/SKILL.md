---
name: finance-operating-defaults
description: |
  Finance Operating Constitution — books only. The default operating posture for bookkeeping, chart-of-accounts, classification, reconciliation, and financial-write work, across every runtime (Claude, ChatGPT, Codex, ChittyOS agents). Load it whenever the work touches a chart of accounts, a ledger, a classification, a reconciliation, a tax-form derivation, or any write to a financial datastore — including when the request sounds trivial ("just fix that one account", "reseed the chart", "mark it deductible"). It governs HOW books work is conducted: the document is authoritative over the projection, a plan is not a write, never hand-write apply SQL, partial state is the default failure, reconcile by digest, tax semantics are separable from structure, production writes are operator-gated, trust path L0–L4, rollups hold no transactions, state the gaps, mutation-test every guard. It carries no entity facts and never will — no ownership percentages, no account numbers, no balances. The moment a financial figure is filed or asserted in a matter, it hands off to `legal-operating-defaults`.
canon_uri: chittycanon://core/services/chittymarket#skills/finance-operating-defaults
---

# Finance Operating Defaults

The operating constitution for books work. It is **method, not entity**: it says how to
change a chart of accounts, a classification, or a ledger row — never what any particular
business owns, owes, or earned.

**Scope note.** This is an operating discipline for *bookkeeping and accounting work
product*. It is not tax advice, not an audit opinion, and it does not decide anything that
requires a CPA or an attorney. Where an output would be filed, asserted, or relied on in a
dispute, §11 hands off and `legal-operating-defaults` governs.

Every principle below was written from a real failure. The reasoning is the rule — a
one-line restatement of any of them loses the thing that makes it bind.

---

## 1. The document is authoritative over the projection

The chart of accounts derives from the governing **document** — the IRS form lines
(Form 8825, Schedule E, and their successors) and the written chart specification. Code,
schema, seed data, and the live database are **projections** of that document.

- The direction is one-way: document → code → database. Never the reverse.
- A projection that disagrees with the document is **drift**, not a correction. Fix the
  projection, or amend the document deliberately and re-derive.
- The seed carries a parity assertion against the document. That assertion is the mechanism
  by which the direction is enforced; removing or bypassing it inverts the hierarchy
  silently.
- "The database says X" is evidence about the projection, not about what the chart *is*.

## 2. A plan is not a write

**A correct plan and a correct write are different artifacts, and only one of them changes
anything.**

The failure: a chart-of-accounts seed plan was correct in every respect, and the SQL
hand-written to apply it omitted a column. The plan was reviewed; the compiled statement was
not. Four production rows still carry the wrong value.

- Verify the **statement that will execute**, not the plan that describes it.
- Column-by-column: enumerate every column the plan says it sets, and confirm each one
  appears in the statement. An omitted column fails silently — it does not error, it just
  leaves the old value in place.
- A plan approved is not a change applied, and a change applied is not a change verified.
  These are three separate acts and each needs its own evidence.

## 3. Never hand-write apply SQL for the books

The seed script carries `assertDocumentParity()`. Raw SQL sent through an MCP, a console, or
a one-off script **bypasses that assertion**. That bypass is what caused §2.

- Books writes go through the seed/apply path that carries the parity check. If the path
  cannot express the change, extend the path — do not route around it.
- A hand-written statement is acceptable only for **reading** and for the snapshot in §4.
- This includes "just this one row". The one-row exception is how the guard stops existing.

## 4. `neon-http` has no interactive transactions

The driver in the request path commits every statement independently. There is no `BEGIN`
that holds, so **partial state is the default failure mode, not an edge case**.

- A multi-statement change will, on failure, leave some statements applied and some not.
  Plan for that outcome rather than treating it as unlikely.
- **A snapshot precedes any apply.** Capture the current value of every row and every column
  the change will touch, before the first statement runs. Without it there is nothing to
  roll back to, because there is no transaction to abort.
- Where the change must be atomic, it does not belong on this path. Say so rather than
  hoping the statements all land.

## 5. Reconcile live against projection by digest, not inspection

After an apply, compare the live rows to the expected projection by computing a digest over
the full row set — every column that matters, in a stable order — and comparing digests.

- **Eyeballing a list is how a four-row drift survives.** A human reading ninety-five rows
  reliably confirms what they expect to see.
- A digest mismatch localizes by bisecting the row set, not by re-reading it.
- Reconciliation reads every column the change claimed to set, including the ones nobody
  thought about. A column never read is a column never verified (§10).

## 6. Tax-semantics changes are separable from structural ones

A change to **deductibility, tax treatment, or form-line mapping** is a different class from
a change to **hierarchy, naming, codes, or parentage**.

- Ship them as separate, independently auditable changes. A deductibility change must never
  ride inside a hierarchy change, where review attention is on the tree.
- Each class has a different reviewer question. Structural: "is the tree right?" Semantic:
  "does this change what is owed?"
- When a single change genuinely requires both, say so explicitly and audit the semantic
  part on its own terms anyway.

## 7. Production financial writes are operator-gated

No write to a production financial datastore proceeds on inference. The operator gates it,
and the gate is only meaningful if what is presented is complete:

- **The compiled statement** that will execute (§2), not a description of it.
- **The snapshot** taken under §4.
- **A rollback recipe that restores every column the change touched — including
  `updated_at`.** A rollback that restores the value but not the timestamp leaves the row
  looking recently and deliberately set, which corrupts the audit trail as surely as the
  wrong value did.
- **The blast radius**: which rows, how many, and what reads them downstream.

## 8. Trust path L0–L4; no silent promotion

Classifications carry a trust level. A suggestion does not become authoritative by being
agreed with, by being old, or by being convenient.

- **Promotion requires its audit row.** If the audit row was not written, the promotion did
  not happen, whatever the status column says.
- An empty audit table beside a populated classification table means the write path bypassed
  the audit path. That is a defect in the importer, not a gap in the data.
- Never infer a trust level from a value's plausibility. L0 that looks right is still L0.

## 9. Rollups hold no transactions

A rollup, header, or parent account is a summation node. It never carries a posted
transaction.

- **Enforce non-posting at the storage chokepoint**, not per route. A rule enforced in one
  handler is a rule absent from every other handler, every importer, and every script.
- The same applies to the pickers and APIs that offer accounts for selection: if a header
  can be chosen, it will be.

## 10. State the gaps

Every substantive books output names, explicitly:

- **Unverified counts** — numbers reported but not independently recomputed.
- **Columns never read** — what the reconciliation did not look at.
- **Assumptions standing in for evidence** — where a value was taken on faith, and from whom.
- **What would resolve each gap** — the query, the document, or the person.

A clean-looking reconciliation that hides its gaps is worse than a messy one that names them.

## 11. Hand off to legal when a figure enters a filing, pleading, or dispute

**The boundary is the act of filing or asserting, not the subject matter.**

- **Tax-form derivation stays in finance.** Mapping accounts to Form 8825 or Schedule E
  lines, computing a figure from the books, preparing a return workpaper, reconciling to a
  statement — all of that is books work and this constitution governs it. Tax work is not
  legal work merely because it is tax work.
- **The moment a figure is filed with an authority, served, produced, or asserted in a
  matter**, `legal-operating-defaults` governs it: the figure becomes a factual assertion
  with a lifecycle state, a provenance chain, a verifier, and matter isolation. It is no
  longer a number in the books; it is evidence.
- Read narrowly on purpose. "All tax work is legal work" would swallow this entire skill and
  leave routine bookkeeping ungoverned.
- At the handoff, carry forward: the derivation (which accounts, which rule, which period),
  the source rows, and every §10 gap still open. A figure handed to legal with its gaps
  stripped is a figure legal cannot verify.

## 12. Mutation-test every guard

A guard that has never been seen to fail is decoration.

- For every parity assertion, non-posting constraint, audit trigger, or validation: **break
  what it guards and watch it fail.** Omit the column, post to the header, skip the audit row.
- A passing test suite written alongside the guard proves internal consistency, not that the
  guard fires. The only evidence a guard works is having watched it reject something.
- This applies to the guards in §§1, 3, 8, and 9 specifically — each one exists because
  something slipped past an unverified check.

---

## Dependency routing

**Do not inline the contents of these. Resolve them when the trigger fires, not before.**

### Always, for anything technical

| Capability | When |
|---|---|
| `nb-development-defaults` | Any task involving code, infrastructure, automation, storage, connectors, pipelines, APIs, schemas, deployment, or system design |

Apply **startup-mode** with it unless the operator expressly overrides.

### Conditional

| Capability | Trigger |
|---|---|
| `legal-operating-defaults` | A financial figure is filed, served, produced, or asserted in a matter (§11) |
| `fact-governance` | A financial figure becomes a governed factual assertion in a matter |
| `chittyconnect-concierge` (`/chico`) | Any credential, secret, binding, connection-string, or deploy intent — **always**, never resolved inline |
| `chittyagent-neon` | Neon project, branch, role, or connection work behind the books datastore |
| `chittyschema-overlord` | Schema design, drift detection, or migration governance on a financial schema |
| `capability-governor` | A capability, skill, agent, MCP route, or projection is created or changed |
| `chittyos-compliance` | ChittyOS service creation, modification, registration, certification, or deployment |
| `chitty-deploy` | Deploying the finance service to Cloudflare Workers |

### Connections this capability composes with

These are **existing** connectors. This skill references them; it does not define,
re-declare, or wrap them.

| Connection | Canonical reference | Role in books work |
|---|---|---|
| Mercury banking | `chittycanon://capability/connect/mercury-banking-claude-ai` | Read-side bank activity; the source records a reconciliation ties out against |
| Neon database | `chittycanon://capability/connect/read-and-write-neon-database` | The books datastore. §4 applies to every write through it |
| ChittyMCP gateway | `chittycanon://capability/legal/chittymcp-claude-ai` | Already exposes ledger and finance tools over Claude.ai. A **tool surface**, not a books method — the tools it offers are governed by the principles above, not excused from them |
| ChittyFinance service MCP | `https://finance.chitty.cc/mcp` — a real auth-gated route (401, where an unknown path 404s), on a service registered in ChittyRegistry as `chittyfinance` (`did:chitty:foundation:chittyfinance`, `/health` → ok). **Not yet registered in Ch1tty `servers.json`**, so no channel reaches it through the gateway today | The service's own tool surface. Auth routes through `/chico`; never resolve a token inline. Gateway registration is a backend change and is likewise `/chico`-routed — do not add it to a local MCP config |

**Credentials are never handled here.** Every credential, secret, token, or binding intent
routes to `chittyconnect-concierge`. This capability neither resolves nor displays a secret
value, in any projection.

---

## Distribution boundary

Published projections of this capability carry **operating method and routing metadata
only**.

Never published, in any projection or marketplace record:

- Ownership percentages, membership interests, or capital accounts
- Account numbers, account codes, or chart-of-accounts values
- Balances, amounts, transaction rows, or period figures
- Entity names, property names, tenant identities, or counterparty identities
- Tax-return content, filing positions, or correspondence with an authority
- Credentials, connection strings, or secrets

Entity facts live in the entity's own governed store, never in a published capability
definition. This is the same rule `legal-operating-defaults` §15 applies to matter facts,
for the same reason: a reusable package that carries one operator's facts is not reusable
and leaks on publication.

---

## Provenance

Runtime projections of this capability are **delivery artifacts, not policy authorities.**

- **Dispatch projections** (claude-code, codex, openclaw, universal) carry the full body plus
  `name` and `canon_uri`. The canonical content sha they were generated from is tracked in
  `canonical/.dispatch-state/skills/finance-operating-defaults.json`, not in the projected
  file.
- **Bootstrap pointers** for ChatGPT, Codex bootstrap, Claude bootstrap, and ChittyOS agent
  bootstrap are generated by `scripts/generate-bootstrap-pointers.sh finance-operating-defaults`.
  They carry only identity, canonical location, source hash, and load-order guidance — never
  finance policy text.
- **ChatGPT skill metadata** lives at
  `plugins/chittyos-finance/skills/finance-operating-defaults/agents/openai.yaml` and is
  generated by the same command. It contains UI/invocation metadata only.
- Repository projection is **not** live-runtime proof. A client install/refresh must still make
  the skill visible in that runtime before availability may be claimed.
