# Namespacing as a Schema and Drift Problem

> SCHEMA lane. Companion to the naming-CONVENTION proposal written concurrently in
> the canon lane (`docs/design/namespacing-and-review-path-unification.md`, branch
> `docs/namespacing-and-review-path-unification`). Canon answers *what the
> convention should be*. This document answers *what breaks when it changes, what
> is already drifted, and which repeated patterns should be promoted rather than
> re-specified*.
>
> Read-only analysis. No infrastructure was mutated. No projected file was edited.
> Every claim carries a file:line or a live API path; anything not verified in this
> session is marked UNVERIFIED.

> **Ref provenance (read this before trusting any line number below).** The shared
> checkout at `/home/ubuntu/projects/github.com/CHITTYOS/chittymarket` is **not on
> `main`** and is moved by other sessions mid-flight (observed parked on
> `feat/chittyagent-serv-fleet-caretaker` during this session). Every claim about
> chittymarket in this document is therefore derived from
> `git show origin/main:<path>`, and says so. Claims about other repositories
> (`chittyconfig`, `chittycounsel`, `get-chitty`, `chittysearch`, `ch1tty`,
> `chittyentity`) are from their working trees and are marked WORKING-TREE where it
> could matter.

---

## 0. Corrections to the established fact set

Three facts in this workstream had already collapsed under checking before this
lane opened. Three more collapse here — one of them a correction I first got
wrong myself, from reading the parked working tree.

### 0.1 RETRACTED — `resolve_output.py` holds **13** pairs on `origin/main`, and the workflow pair **is present**

An earlier revision of this document claimed 12 pairs and no `workflow` kind,
citing the working tree. **That was wrong, and it was wrong for the reason the
coordinator identified: the working tree was parked on a feature branch.** Two
sibling agents reached the same false conclusion from the same contaminated
checkout. Any conclusion built on the workflow kind being unrepresentable is void,
including the version of §5 this document originally carried.

`git show origin/main:plugins/chittyagent-dispatch/scripts/lib/resolve_output.py`
lines 21-33 — thirteen entries:

| runtime | kinds | count |
|---|---|---:|
| `claude-code` | agent, skill, command, hook, mcp-server, **workflow** | 6 |
| `codex` | agent, skill | 2 |
| `openclaw` | agent, skill | 2 |
| `universal` | skill | 1 |
| `claude-skills` | tool | 1 |
| `chatgpt-apps` | tool | 1 |
| | **total** | **13** |

`origin/main:resolve_output.py:26`:

```python
("claude-code", "workflow"):    ("plugins/{plugin}/workflows/{name}.js", "claude-code-workflow.sh"),
```

### 0.2 NEW FINDING — the parked branch **deletes** the only workflow projection route

This is what produced the false reading, and it is a finding rather than merely my
error. `git diff origin/main -- plugins/chittyagent-dispatch/scripts/lib/resolve_output.py`
is a single-line deletion:

```diff
-    ("claude-code", "workflow"):    ("plugins/{plugin}/workflows/{name}.js", "claude-code-workflow.sh"),
```

An unmerged branch removes the estate's **only** workflow projection pair. Nothing
in `dispatch.sh` can detect that removal as a regression, because `KNOWN_RUNTIMES`
is derived from `_MAP` itself (`origin/main:resolve_output.py:36`) — delete a pair
and the vocabulary silently shrinks to match. A self-derived vocabulary cannot
report its own erosion. This is the §3 drift class appearing inside the projection
mapping: the declaration and the check are the same object, so they cannot
disagree, and agreement is being mistaken for correctness.

### 0.3 FALSE — the capability inventory holds **110**, not 104 and not 108

The coordinator first stated ~104, then corrected to 108 on two agents'
measurements. Measured against `git show origin/main:capabilities.generated.json`:

- `total` field: **110**
- `len(capabilities)`: **110**
- unique names: **110** (no duplicates)
- `version: 1.2.0`

The declared `total` and the actual array length agree, which is worth noting
because it is the one place in this analysis where a declaration and its referent
*do* match. The 108 figure is unconfirmed here; both earlier figures were likely
measured from the parked working tree, whose diff against `origin/main` removes
162 lines from this file.

### 0.3 UNVERIFIED — the AI Gateway and AI Search inventory

No Cloudflare control-plane call was made in this session. The seven gateways
across four accounts, the three namespaces, the two instances, the
`finance-reference` null `type`/`source`, and the
`chittyevidence-<case_slug>-<case_id>` `paused_r2_not_enabled` state are all carried
forward as UNVERIFIED-HERE. They are consistent with
`CHITTYAPPS/chittysearch/docs/NAMESPACE-STRATEGY.md:17-31` ("Live state
(2026-09-05)") but that is a document, not the control plane.

> The live evidence index for the pending matter is written here as
> `chittyevidence-<case_slug>-<case_id>`. The concrete identifier is withheld
> deliberately: a reusable capability package must not carry a matter fact
> (legal-operating-defaults §15), and `scripts/check-matter-leak.py` enforces
> that. The shape `{service}-{case}-{docket}` is the whole evidentiary point;
> which matter it is, is not. Do not restore the value to "make the example
> concrete".


### 0.4 CONFIRMED — chittyconfig ships unprovisioned KV

`CHITTYOS/chittyconfig/wrangler.jsonc:27-28`:

```jsonc
{ "binding": "CONFIG_CANON", "id": "PLACEHOLDER_KV_CONFIG_CANON" },
{ "binding": "DRIFT_LOG",    "id": "PLACEHOLDER_KV_DRIFT_LOG" }
```

### 0.5 An unresolved contradiction in the estate record

`CHITTYOS/chittyregistry/audits/cloudflare-account-121-full-inventory-2026-05-27.md:407`
lists `chittyevidence-ksn` as an existing instance with `gateway=default`,
`hybrid_search=true`, public endpoint enabled. `CHITTYAPPS/chittysearch/README.md:63`
states flatly: "`chittyevidence-ksn` and `re-evidence-search` **never existed on
this account**." `CHITTYOS/ch1tty/focus-suggestions.json:158` and `:5029` record
`evidence/list_rags` returning all three as live on 2026-06-05.

These cannot all be true. This is itself an instance of the drift class named in
§3: three artifacts each assert a resource's existence from a different vantage,
none of them the control plane, and none carries an expiry. Read-only analysis
cannot settle it; settling it requires one control-plane list and a correction
sweep over whichever record loses.

---

## 1. Cross-service impact of a rename

A rename proposal with no consumer inventory is a proposal to break things
quietly. This is the inventory.

### 1.1 AI Search namespace names

| Consumer | Binding site | Name bound | Status |
|---|---|---|---|
| `get-chitty` | `CHITTYOS/get-chitty/cloudflare/wrangler.toml:18` — `namespace = "chitty-ecosystem"` | `chitty-ecosystem` | **BROKEN — namespace does not exist** |
| `get-chitty` | `CHITTYOS/get-chitty/src/edge/worker.ts:438` — comment: "lazy handle to the global `chitty-ecosystem` instance" | `chitty-ecosystem` | same binding, second reference |
| ChittyCanon (planned) | `CHITTYFOUNDATION/chittycanon/planning/CANON_CORPUS_RETRIEVAL.md:39-43,116,144` | `chitty-ecosystem` | planned consumer of a non-existent namespace |

**Task `3373ef77` verified: still broken.** The reference is live in
`wrangler.toml`, unchanged. The aggravating detail, recorded independently at
`CHITTYAPPS/chittysearch/docs/NAMESPACE-STRATEGY.md:135` and
`CANON_CORPUS_RETRIEVAL.md:43`: **Wrangler creates a missing namespace on deploy.**
So the binding does not fail closed. The next `get-chitty` deploy *defines the
trust boundary as a side effect*, with no description and no custody owner. For a
namespace that `NAMESPACE-STRATEGY.md:57` designates as **the trust boundary**,
that is a security-relevant failure mode, not a broken-link failure mode.

### 1.2 AI Search instance ids

| Consumer | Binding site | Id bound | Status |
|---|---|---|---|
| `chittycounsel` | `CHITTYOS/chittycounsel/wrangler.json:24` — `"AUTORAG_KSN_ID": "chittyevidence-ksn"` | `chittyevidence-ksn` | **BROKEN — instance does not exist** |
| `chittycounsel` | `src/rag.ts:2` (module header), `src/index.ts:112,121-122,214` (two call sites) | same | consumes it at runtime |
| `chittycounsel` | `CHARTER.md:43`, `CHITTY.md:30` | same | declared in the compliance triad |
| `chittyfinance` | `CHITTYAPPS/chittyfinance/.github/copilot-mcp.json:8` | `chittyevidence-ksn` | MCP server entry |
| `chittyfinance-wt-comptroller` | `.github/copilot-mcp.json:8` | same | second copy |
| `ch1tty` | `focus-suggestions.json:158,5029,5141` | same | three cached "confirmed live" records |

**Task `db15de2a` verified: still broken**, and worse than one binding. The id
appears in a worker var, a runtime client, two compliance-triad documents, two
Copilot MCP configs in a different org, and three cached capability records. A
rename touches **nine sites across four repositories in three GitHub orgs.**

Note the failure shape at `chittycounsel/wrangler.json:23-24`: the *id* is a var
(`AUTORAG_KSN_ID`) but the thing actually dialled is a separate opaque hostname
(`AUTORAG_MCP_URL` = `https://e1429000-….search.ai.cloudflare.com/mcp`). The id
and the endpoint are not derived from one another, so the id can be wrong while
the URL is right, or vice versa, and nothing reconciles them. That is a schema
defect, not a naming defect — see §2.

### 1.3 AI Gateway ids

No consumer in the scanned repositories binds a gateway id as a configuration
value. The only occurrence found is descriptive —
`chittyregistry/audits/cloudflare-account-121-full-inventory-2026-05-27.md:407`
records `gateway=default` as an observed property of an AI Search instance.

Consequence for the rename proposal: **gateway ids are the cheapest of the four
namespaces to rename** (no code consumers found), with the caveat that the
operator-facing `central` gateway carries the account spend cap referenced in
`~/.claude/CLAUDE.md` § Orchestration Budget Discipline, so renaming it moves a
cost-control surface. UNVERIFIED whether any out-of-repo caller (openclaw,
`chittyclaw`) hardcodes `central`.

### 1.4 chittyconfig KV binding names

`CONFIG_CANON` and `DRIFT_LOG` are referenced by **binding name** inside
chittyconfig only:

- `wrangler.jsonc:27-28` — declaration
- `src/health.ts` readiness roster (`kv_namespaces` family, dispatched through
  `probe()` → `checkKV`, `src/health.ts:~290-330`)
- `CHITTY.md:37,39` — the declared-bindings table

Renaming either is **internal and cheap**. What is *not* cheap is the divergence
documented in §3.2.

---

## 2. Is there a schema for any of this?

**No. And the absence is specific, not general — the ecosystem has the
machinery and has not pointed it at resource ids.**

Searches run (negative results reported as evidence about the search, per the
brief's instruction):

- `grep -rln "namespace_id|namespaceId|gateway_id|gatewayId|instance_id"` over
  `CHITTYFOUNDATION/chittyschema/identity/schemas/` → **zero files**.
- Same pattern over `CHITTYOS/chittyentity/workers/shared/*.ts` → **zero files**.

The canonical primitives in `chittyentity/workers/shared/` were read before
concluding. What is there:

| Primitive | What it validates | Why it is not this |
|---|---|---|
| `alchemize.ts:1-27` | A 10-clause **readiness contract** for promoting a worker into Code Mode; scored by `chittyagent-alchemist` `POST /api/v1/alchemize`; passing workers get registry tag `mcp-code-mode-ready` | Validates an MCP *manifest's* shape and a worker's *deploy readiness* — including clause 4, "real bindings day 1", enforced in `tests/workers-health.test.ts`. Closest existing thing to a declared-vs-actual gate, but scoped to MCP workers and run at deploy time, not to resource ids continuously. |
| `governance.ts` | `EntityTypeCode` — the P/L/T/E/A ontology | Entity types, not infrastructure ids |
| `remediation-loop.ts:1-19` | A Review → Evaluate → Remediate cycle over a pluggable `LoopSubjectKind`, Neon-backed, escalating to `agent_tasks.tasks` | The **execution harness** a detector would plug into. It is subject-agnostic by design. |
| `agent-protocol`, `ledger-write`, `chronicle-queue` | hop limits, audit writes, event queue | transport and audit, not validation |

So the honest finding is: **`alchemize.ts` clause 4 already states the rule
("real bindings day 1") and `remediation-loop.ts` already provides the loop to
enforce it continuously. Neither is wired to AI Search namespaces, AI Search
instances, AI Gateway ids, or KV ids.**

### 2.1 What a schema would have to declare

Three distinct things, currently conflated under the word "naming":

1. **Syntax** — the id's lexical form. This is what the canon lane is specifying.
   A JSON Schema `pattern` is sufficient and belongs beside the other meta-schemas
   in `chittyschema/identity/schemas/meta/` (which already hosts
   `repo-scope.schema.json` and `fractal-layout.schema.json`, served from the
   `CANONICAL_SCHEMAS` R2 bucket at `/meta/*`).
2. **Reference integrity** — that a bound id names a resource that *exists*.
   Not expressible in JSON Schema. Needs a control-plane probe. This is §3.
3. **Semantic class** — that the id's namespace matches the corpus's trust
   domain. `NAMESPACE-STRATEGY.md:57` makes this binding: *"the namespace is the
   trust boundary; the instance is the scope boundary."* The `legal-cases`
   rationale ("one instance per case for structural privilege isolation;
   first-party evidentiary documents only; AI recaps and work product excluded")
   is a **legal** constraint. A document that indexes work product into
   `legal-cases` is a privilege problem that no syntactic pattern catches.

**Owner: chittyschema**, for (1) and (3), with the reference-integrity half (2)
delegated per §4. Precedent: chittyschema already owns `repo-scope.schema.json`
validating `scope.json` manifests — the same shape of problem (validate a
declaration about infrastructure), one altitude down.

A schema that covers only (1) while (2) and (3) are the ones actually breaking
things would be a convention document wearing a schema's clothes.

---

## 3. Declared-versus-actual is a general drift class

**Yes. This is the deep finding, and chittyconfig is one instance of it, not its
origin.**

### 3.1 Name

**Unprovisioned-reference drift** — a declaration names a resource that does not
exist, or exists in a state the declaration does not describe, and *nothing in the
check path can tell the difference* because every available check validates the
declaration's **shape** rather than the resource's **existence**.

Its signature is that the broken configuration is **green**. That is what makes it
a class worth naming: an ordinary misconfiguration fails loudly on first use;
unprovisioned-reference drift passes its own gate and fails at the moment of
consequence, which for an evidence index or a trust boundary is the worst
available moment.

### 3.2 Where it appears — seven instances, six services, three orgs

1. **chittyconfig `/health` type gates.** Six of ten checks route through
   `checkBinding` (`src/health.ts:194`, dispatched at `:355-359` for the
   `r2_buckets`, `durable_objects`, and `services` families). Its own docstring is
   accurate and damning: *"Presence-only: the binding object exists and exposes the
   method we would call."* It returns `ok: true` for an R2 bucket that is absent, a
   service binding to an unpublished Worker, and a DO class with no live instance.
   `checkKV` (`:156-172`) is the one honest check in the file — it performs a real
   `.get(PROBE_KEY)` read, and its comment block documents why shape-probing alone
   was insufficient (a Secrets Store secret satisfied a `.get`-only probe and had
   its **credential resolved on the unauthenticated `/health` path**). That incident
   *is* this drift class, caught once, in one function.

2. **chittyconfig's own KV.** `wrangler.jsonc:27-28` — `PLACEHOLDER_KV_CONFIG_CANON`
   and `PLACEHOLDER_KV_DRIFT_LOG`. The config-governance service cannot store a
   canon document or append a drift event. Because `checkKV` is the honest check,
   these two *do* go red — the service fails closed on its own core function while
   the six shape-gated checks stay green. The green/red split is inverted relative
   to severity.

3. **chittyconfig `CHITTY.md` ↔ `wrangler.jsonc`, bidirectionally.**
   `CHITTY.md:41` declares a `SECRETS_STORE` binding (family
   `secrets_store_secrets`, store `e914522471964c3c8cf1e601770edcc3`). No binding
   of that name exists in `wrangler.jsonc`. The two that *do* exist —
   `CHITTYCONFIG_SERVICE_TOKEN` and `CHITTYCONNECT_SERVICE_TOKEN`
   (`wrangler.jsonc:40-58`) — are absent from the `CHITTY.md` table. The manifest
   and the deployment disagree in both directions at once.

4. **chittyconfig `DRIFT_LOG` type contradiction.** `CHITTY.md:39` types `DRIFT_LOG`
   as "KV **or D1**". `checkKV` (`:156-172`) rejects anything lacking
   `getWithMetadata`, which is KV's alone and which D1 does not expose. A
   D1-provisioned `DRIFT_LOG` — **a shape the manifest explicitly authorizes** —
   returns `ok:false, detail:"unusable"`, and because `evaluate()`'s verdict is
   true only when every check passes, pins `/health` at 503 permanently. The
   manifest authorizes a configuration the health check treats as fatal.

5. **`get-chitty` → `chitty-ecosystem`.** §1.1. Declared in `wrangler.toml:18`,
   does not exist, and *Wrangler will create it on deploy* — the declaration will
   eventually manufacture the resource rather than fail against it, defining a
   trust boundary with no description and no custody owner.

6. **`chittycounsel` → `chittyevidence-ksn`.** §1.2. Nine sites, four repos,
   including two compliance-triad documents (`CHARTER.md:43`, `CHITTY.md:30`) that
   assert the dependency as fact. The compliance triad is supposed to be the
   authoritative contract; here it is a third divergent record.

7. **`ch1tty/focus-suggestions.json`.** `:158`, `:5029`, `:5141` each record
   "confirmed live 2026-06-05" for three RAG instances, at least one of which
   another record says never existed (§0.5). Cached existence assertions with no
   expiry are unprovisioned-reference drift with a timestamp attached, which reads
   as freshness and is not.

Six of the seven are in **different services**. The class is estate-wide.

### 3.3 What the detector is

One sentence: **resolve every declared reference against the control plane that
owns the resource, and treat "cannot resolve" as a finding rather than as an
absence of evidence.**

Concretely, four parts:

**(a) Reference extraction.** Parse each service's declarations into
`(service, binding_name, family, declared_id, source_file:line)`. Sources:
`wrangler.jsonc` / `wrangler.toml` / `wrangler.json` bindings and vars; the
`CHITTY.md` declared-bindings table; `CHARTER.md` dependency lists. Three
extractors because the estate has three declaration formats and they disagree
(§3.2 item 3) — the disagreement is itself a finding and must survive extraction
rather than be normalised away.

**(b) Existence resolution.** For each `(family, declared_id)`, one control-plane
call: `kv_namespaces_list`, `r2_buckets_list`, `workers_list` for service
bindings, and the AI Search / AI Gateway list endpoints for the two namespaced
families. Compare by id. Critically, **this cannot be done from inside the running
Worker** — a Worker's `env` exposes a binding object, not the resource's identity.
The type-gate problem in `checkBinding` is not a coding mistake; it is the
*ceiling of what any in-isolate check can establish*. That is why the detector has
to live outside the request path, and why making `/health` stricter cannot fix
this.

**(c) State assertion, not just existence.** Existence is insufficient:
`finance-reference` exists with `type` and `source` both null and state `waiting`;
`chittyevidence-<case_slug>-<case_id>` exists with `enable:true, paused:true`. Both
would pass an existence check and neither can serve a query. The detector's
verdict must be *serviceable / present-but-unserviceable / absent*, and
`present-but-unserviceable` is the state the entire class hides in.

**(d) Emission.** A drift event in chittyconfig's own vocabulary
(`CLAUDE.md` § Drift model): `(domain, target, expected, observed, severity,
detected_at)`, appended to `DRIFT_LOG`, surfaced at `GET /drift`. Severity:
`critical` for a trust-boundary namespace or an evidence instance,
`warn` otherwise. Which requires `DRIFT_LOG` to be provisioned — the detector's
first finding is the detector's own storage, which is a satisfying property and
also a bootstrap dependency to sequence deliberately.

**What it is not.** Not a stricter `/health`. Not a lint rule. Not a convention
document. The three artifacts the estate has already produced for this problem
(`NAMESPACE-STRATEGY.md`, `CANON_CORPUS_RETRIEVAL.md`, the chittycounsel
diagnostic at `CHITTYCORP/CHITTYCOUNSEL/docs/diagnostics/chittycounsel-service-identity-collision-2026-08-01.md:301`)
each correctly *identified* an instance and each left the reference in place. A
fourth document will do the same. The gap is a running check, not a written rule.

---

## 4. The Alchemist — promotion assessment

### 4.1 Registry finding, verified first

**`alchemist` does not appear in `capabilities.generated.json`.** Verified against
**`origin/main`**, not the parked working tree:
`git show origin/main:capabilities.generated.json | grep -c -i alchemist` → **0**,
across all 110 capability records (§0.3). The finding survives the ref
correction — it is 0 on both refs.

Meanwhile all four components exist on disk:

- `CHITTYOS/ch1tty/docs/ALCHEMICAL_PROMOTION.md`
- `CHITTYOS/ch1tty/dist/alchemist.js`
- `CHITTYOS/chittyentity/workers/chittyagent-alchemist/`
- `CHITTYOS/chittyentity/chittyagents/alchemist/`

And it is load-bearing for a *different* service's promotion path:
`chittyentity/workers/shared/alchemize.ts:5-8` states that the contract "is
enforced at deploy time by `chittyagent-alchemist` `POST /api/v1/alchemize`,
which scores a candidate against the 10 clauses and promotes passing workers into
registry tag `mcp-code-mode-ready`."

So a component that **writes registry tags** is itself missing from the canonical
capability inventory. This is a registry finding in its own right, and it is the
same class as §3: an inventory asserting a capability set that does not match the
actual one. Per the brief's duplicate-check constraint, this is reported, not
remediated, and no new skill/agent/MCP server is proposed below without the
duplicate check stated.

### 4.2 The doctrine's own criteria

`ALCHEMICAL_PROMOTION.md` gives four tests. Applied honestly, including where they
fail.

| Criterion | Source | Test |
|---|---|---|
| **Recurrence weight** | §2, §4, §6 | accumulated weight = reinforced recalls + merged variants; "frequency × success-rate × recency × caller-diversity" |
| **Placement** | §3 | single canonical owner → vertical wraps that owner; **cross-backend with no single owner → the vertical owns the fan-out** |
| **Freeze the shape, not the wiring** | §2b | promote a typed shape with injection points; late-bind backends; codemode is the only adaptive joint |
| **Cold start from skills** | §6b | the skill registry is a pre-labeled combo corpus; *"look at the skill library first"* |
| **Outgrown-its-host smell** | §3 | "a composite living inside one of its inputs is itself an Alchemist signal" |

### 4.3 Candidate A — declared-vs-actual drift detection: **QUALIFIES**

**Recurrence.** Seven instances, six services, three GitHub orgs (§3.2). The
estate has hand-built the composite four separate times —
`NAMESPACE-STRATEGY.md` § "Consumer drift" (`:40-55`), `CANON_CORPUS_RETRIEVAL.md`,
the chittycounsel diagnostic, and `chittyconfig/src/health.ts` itself. By §4's
merge rule these are four *near-identical expressions of one pattern* that
individually never crossed a threshold; merged, the weight is unambiguous. This is
exactly the fragmentation §4's merge step exists to prevent, happening in prose
instead of in a pattern store.

**Placement.** Cross-backend with no single owner: it spans Cloudflare KV, R2, AI
Search, AI Gateway, Workers service bindings, and three declaration formats across
three orgs. §3's rule is explicit — *"a cross-backend composite with no single
owner → the vertical itself owns the fan-out orchestration. This is the legitimate
home for orchestration that spans canonical services."* It qualifies on the
criterion the doctrine wrote for precisely this case.

**Shape, not wiring.** The shape is stable (`extract → resolve → assert state →
emit drift event`). The wiring is the volatile part — six control-plane APIs that
change independently. §2b's injection-point model fits without strain: the
`resolve` capability is late-bound per family; adding AI Search as a seventh
family is a binding, not a rewrite.

**Outgrown-its-host smell.** Decisive. `checkBinding` is a drift detector frozen
inside one of its own inputs — chittyconfig's request path — where §3's ceiling
argument says it *cannot* do the job (a Worker's `env` cannot see resource
identity, §3.3b). Per §3 this is "itself an Alchemist signal: this has outgrown
its host."

**Verdict: promote.** Home per §3: a focused surface owning the fan-out — not an
inline facade in a gateway, and not bolted onto chittyconfig because that is
whichever service the author happened to be editing. **Duplicate check:**
`alchemist` → 0 hits in `capabilities.generated.json` (§4.1); searches for
`namespace_id|gateway_id|instance_id` across `chittyschema/identity/schemas/` and
`chittyentity/workers/shared/` → 0 files (§2). No existing capability covers it.
It should compose, not re-implement: `remediation-loop.ts` as the loop harness
(a new `LoopSubjectKind`), `alchemize.ts` clause 4 as the rule already written,
and chittyconfig's `DRIFT_LOG` / `GET /drift` as the emission surface. Most of the
substrate exists and is unwired.

### 4.4 Candidate B — namespace/instance id validation: **DOES NOT QUALIFY as a service**

Recurrence is real but **placement fails**. §3: *"a composite with a single
canonical owner → vertical wraps that owner."* Syntactic id validation and
semantic trust-class validation have a single canonical owner — **chittyschema**,
which already owns the meta-schema layer (`repo-scope.schema.json`,
`fractal-layout.schema.json`, served from `CANONICAL_SCHEMAS` at `/meta/*`).
Promoting this into its own service would put a second validation surface in the
ecosystem, which is the thing `NAMESPACE-STRATEGY.md` and ChittySearch both exist
to prevent.

**Verdict: a schema in chittyschema, not a promotion.** Specifically: one new
meta-schema for id syntax (the canon lane's output), plus a trust-class
constraint. Its reference-integrity half is Candidate A and belongs there.

### 4.5 Candidate C — the per-projection review-dispatch path: **DOES NOT QUALIFY (yet)**

Recurrence is asserted in the brief but was not measured in this session —
**UNVERIFIED**. More substantively, it fails §2b: a review-dispatch path that
differs per projection is not one composite expressed several ways; it is
*several different procedures* whose only commonality is their purpose. There is
no stable shape to freeze with injection points, so promotion would freeze an
accident. §6b's instruction applies — look at the skill library first and
establish whether a single shape exists — before any promotion claim.

**Verdict: not assessable on current evidence. Do not promote.** Re-assess after
measuring whether the paths share a shape.

---

## 5. The projection mapping as a schema problem

### 5.1 The asymmetry, stated correctly

All line references in this section are `git show origin/main:plugins/chittyagent-dispatch/scripts/lib/resolve_output.py`.

The brief's framing survives the ref correction intact: of the 13 pairs,
`("claude-code","workflow")` (`:26`) is the **only** workflow pair. The asymmetry
is real and it is an asymmetry in *which runtimes have a workflow route*, not an
absence of the kind:

- `codex` gets `SKILL.md` for both its kinds (`:27-28` — note both `agent` and
  `skill` resolve to the *same path template*, so the two kinds are
  indistinguishable on disk)
- `openclaw` gets one YAML agent or a `SKILL.md` (`:29-30`)
- `universal` is a document format only (`:31`)
- `claude-skills` and `chatgpt-apps` get a JSON tool manifest (`:32-33`)
- there is **no `cli` pair at all**

So a workflow is projectable to exactly one runtime, and a canonical definition of
kind `workflow` targeted at any other registered runtime resolves to `KeyError` →
exit 3 (`:38-59`).

The structural defect sits one level below that. `_MAP` (`:20-34`) is a flat
`dict` keyed by a `(runtime, kind)` tuple, and `KNOWN_RUNTIMES` (`:36`) is
**derived from the map's own keys** rather than declared. There is no equivalent
for kinds at all, which is why `main()`'s error message (`:56-57`) can name the
known runtimes but cannot name the known kinds — a caller passing an unknown
*kind* receives an error phrased as though the *runtime* were wrong. And as §0.2
shows, a self-derived vocabulary cannot detect a pair's deletion, because the
vocabulary shrinks with it.

### 5.2 Yes, it is a schema — and it is already behaving like one

The docstring claims the role explicitly: *"Single source of truth for
(runtime, kind) -> projection output path + adapter. Shared by dispatch.sh `sync`,
`audit`, and `reconcile` so the three can never disagree."* A single artifact that
three consumers are forbidden to disagree with, keyed by a composite type, is a
schema whose validation rule happens to be "is this key present."

What it validates: *this pair has a known output path.* What it does not
validate: **whether the target runtime can execute the kind being projected.**
Those are different predicates and the map conflates them, because membership is
doing double duty as both lookup and permission.

`dispatch.sh add-target` asks for the pair and the adapter. Nothing asks whether
the runtime has an agent host, a hook host, or an MCP client. So a **workflow
projected to a runtime with no agent host** produces a file at a valid path, with
a valid adapter, that nothing will ever run — a **structurally dead route** that
`audit` reports as present and `reconcile` reports as in-sync. The same
green-while-broken signature as §3. This mapping is the only place that could
catch it, and it is not looking.

The workflow kind is where this bites hardest, which is why the brief singled it
out. A projected `agent.md` or `SKILL.md` that no host loads is inert — a wasted
file. A projected **workflow** (`:26` → `workflows/{name}.js`, a JavaScript
module) asserts an *executable* contract. Adding a second workflow pair for a
runtime without a workflow host would yield a `.js` file that looks like a live
automation to every reader and to `audit`, and is not one. `_MAP` is the gate that
decision passes through, and today it waves it through.

### 5.3 What the constraint looks like

Three changes, smallest first.

**(1) Declare both vocabularies.** `KNOWN_KINDS` alongside `KNOWN_RUNTIMES`, both
declared rather than derived, so an unknown kind is diagnosable as such.

**(2) Separate capability from path.** Today one dict answers both "where does
this go" and "is this allowed." Split them:

```python
RUNTIME_CAPABILITIES = {
  "claude-code":   {"agent", "skill", "command", "hook", "mcp-server", "workflow"},
  "codex":         {"agent", "skill"},
  "openclaw":      {"agent", "skill"},
  "universal":     {"skill"},
  "claude-skills": {"tool"},
  "chatgpt-apps":  {"tool"},
}
```

Declaring it explicitly also makes §0.2's silent deletion visible: with the
capability set written down rather than derived, removing
`("claude-code","workflow")` from `_MAP` leaves `workflow` declared and
unroutable, which is a detectable inconsistency instead of a vocabulary that
quietly shrank.

`_MAP` then supplies the path for a pair already admitted by capability. Two
predicates, two artifacts, and `add-target` gains the question it currently cannot
ask: *what can this runtime execute?* Note that `RUNTIME_CAPABILITIES` above is
mechanically the current `_MAP` keyset — which is the point. Making it explicit
costs nothing today and makes the next addition answerable.

**(3) The executability constraint proper.** Capability membership is still a
*declaration*, so making it the final gate would reproduce §3's exact error one
level up — a declared capability with no actual host. The constraint has to
terminate in an observation:

> A `(runtime, kind)` pair is projectable only if the runtime declares it as a
> capability **and** that runtime's installation exposes a host for that kind.

The second clause is checkable for every runtime in the map: a Claude Code hook
needs a `hooks.json` the client loads; an MCP server needs a client that reads
`.mcp.json`; an openclaw agent needs an agent host in the openclaw install. This
is the same detector as §3.3 — *resolve the declaration against the thing that
would run it* — applied to projection targets instead of infrastructure
resources. Which is further evidence for §4.3: the detector generalises across
two unrelated domains in this workstream alone, and a shape that recurs across
unrelated domains is what §2 of the doctrine calls heat.

---

## 6. Open items, not done here

1. **One control-plane listing** to settle §0.3 (the gateway/namespace/instance
   inventory) and §0.5 (whether `chittyevidence-ksn` ever existed). Read-only, but
   requires Cloudflare API access across four accounts.
2. **Whether anything outside these repos binds gateway id `central`** (§1.3) —
   openclaw and `chittyclaw` were not scanned.
3. **Candidate C's shape** (§4.5) — measure whether the per-projection review
   paths share a composite shape before any promotion claim.
4. **The `alchemist` registry gap** (§4.1) — reported, not remediated. Fixing
   `capabilities.generated.json` is a write to a generated inventory and belongs
   to whoever owns its generator.
5. **The deleted workflow pair** (§0.2) — `feat/chittyagent-serv-fleet-caretaker`
   removes `("claude-code","workflow")` from `_MAP`. Whether that is intentional
   belongs to that branch's owner. It should not merge without an answer, since it
   removes the estate's only workflow projection route.
6. **The shared-checkout hazard itself** (ref provenance note above) — three
   agents in this workstream, including this one, drew conclusions from a parked
   working tree. Worth a convention: *claims about chittymarket cite
   `git show origin/main:<path>`, never the working tree.* Flagged as a candidate
   convention per reporting rules; not written as a rule here.
7. **`chittyevidence-<case_slug>-<case_id>` was not touched and must not be.** Live
   matter's evidence index, `infra_mutation_operator_gated`, owned by
   chittystorage-sasquatch, custody review required. Its
   `paused_r2_not_enabled` state is cited in §3.3c only as the canonical example
   of `present-but-unserviceable`.

---

## Cross-references

- `CHITTYAPPS/chittysearch/docs/NAMESPACE-STRATEGY.md` — namespace = trust
  boundary, instance = scope boundary; the prior consumer-drift inventory
- `CHITTYFOUNDATION/chittycanon/planning/CANON_CORPUS_RETRIEVAL.md` — a planned
  consumer of a non-existent namespace
- `CHITTYCORP/CHITTYCOUNSEL/docs/diagnostics/chittycounsel-service-identity-collision-2026-08-01.md:301`
  — `chittyevidence-ksn` recorded as already-known drift
- `CHITTYOS/ch1tty/docs/ALCHEMICAL_PROMOTION.md` — the promotion doctrine applied in §4
- `CHITTYOS/chittyentity/workers/shared/alchemize.ts` — clause 4, "real bindings day 1"
- `CHITTYOS/chittyentity/workers/shared/remediation-loop.ts` — the loop harness a detector plugs into
- `chittycanon://gov/governance#core-types` — P/L/T/E/A; entity types are unaffected by anything proposed here
