---
uri: chittycanon://docs/tech/spec/chittycan-command-taxonomy
namespace: chittycanon://docs/tech
type: spec
version: 0.1.0
status: DRAFT
registered_with: chittycanon://core/services/canon

title: ChittyCan Command Surface Taxonomy
author: chittyagent-canon

created: 2026-11-11T00:00:00Z
modified: 2026-11-11T00:00:00Z

visibility: INTERNAL
tags: [chittycan, cli, capability-registry, taxonomy, projection]
category: capability-governance

references:
  - chittycanon://gov/governance#core-types
  - chittycanon://docs/tech/spec/chittyentity-projection-taxonomy
  - chittycanon://core/services/chittymarket
---

# ChittyCan Command Surface Taxonomy

**Derived, not invented.** Every axis below already exists in canon. This document adds
no axis, no group value, and no verb. Where a command fits no existing value, it says so
rather than minting one.

## 0. Axis provenance (and one correction to the brief)

| Axis | Canonical home | Status |
|---|---|---|
| `capability_group` (11 values) | `canonical/<kind>/*.md` frontmatter → materialized in `capabilities.generated.json`; also segment 4 of `capability_id` | **in data**, 151/151 |
| `execution_class` (4 values) | same | **in data**, 151/151 |
| `ontology` `{primary,secondary}` over P/L/T/E/A | `chittycanon://gov/governance#core-types` | **in data**, 151/151 |
| JTBD verb (8 values) | `docs/capability-registry-audit-runbook.md` **§4A** ("Job-to-be-Done") | **process only — NOT a field on any record** |

Three corrections that change the shape of the answer:

1. **JTBD is §4A, not §2A**, and it is *not* a populated field. No record in
   `capabilities.generated.json` carries `job_to_be_done`; the key does not exist in the
   union of all 151 records' keys. JTBD appears only in the runbook table and in
   per-capability audit entries in `docs/decisions/capability-audit-log.md`
   (4 occurrences: `govern` ×3, `remember` ×1). So canon carries **three axes in data and
   one in process**.
2. **`discovery.verbs` is a different vocabulary and must not be mistaken for JTBD.**
   Its top values across 151 records are `search` 32, `review` 30, `build` 29,
   `refactor` 29, `query` 29, `connect` 22, `sync` 22, `fetch` 22, `register` 22 —
   free-form discovery search terms, not the 8 JTBD categories. Any tooling that reads
   `discovery.verbs` as the JTBD axis will produce a wrong taxonomy.
3. **`capabilities.generated.json` is not authoritative.** The projection taxonomy states:
   "Generated files such as `marketplace.json` and `capabilities.generated.json` are
   delivery projections and are not authoritative sources for entity type, identity class,
   projection ownership, proposed projection family, or capability ownership"
   (`docs/projection-taxonomy.md`). Identity comes from canonical frontmatter. The counts
   above are therefore a *measurement of the projection*, usable as evidence of population
   but not as the authority for any single record.

## 1. Mapping table — the enumerated surface

Group values are drawn only from the 11 that exist: `connect, build, govern, workspace,
ship, legal, local-lab, agent-runtime, internal, market, finance`. JTBD from §4A's 8.
`execution_class` from the 4 that exist, with the semantics measured from their members:

- `@chitty/ambient` — context/posture that loads itself; no external call (session
  managers, checkpoints, operating-defaults).
- `@chitty/reasoning` — interprets a corpus; judgment-bearing.
- `@chitty/workspace` — acts on the local repo/workspace/deploy surface.
- `@chitty/connectors` — calls an external service.

`capability_id` column: an existing record, or `—` for **no existing capability record**.

### 1a. `can <noun> <verb>` nouns

| Command | capability_group | JTBD (§4A) | execution_class | Ontology primary | Existing capability record |
|---|---|---|---|---|---|
| `session start` | workspace | remember | @chitty/ambient | **P** (+A secondary) | — |
| `dna export/import/status/history/restore/revoke` | govern | govern | @chitty/workspace | P (+A) | — |
| `dna session create/validate/inspect/end/list/add-gene` | workspace | remember | @chitty/ambient | P (+E) | — |
| `viewport status` | workspace | remember | @chitty/ambient | E (+P) | — |
| `market <action>` | market | route | @chitty/workspace | T | `chittycanon://capability/market/chittymarket-manager` |
| `remote` | connect | operate | @chitty/connectors | L (+A) | — ⚠ see §1d |
| `mcp` | connect | route | @chitty/connectors | T (+A) | — |
| `connect` | connect | route | @chitty/connectors | A (+P) | `chittycanon://capability/connect/chittyconnect-concierge` |
| `hook` | govern | govern | @chitty/workspace | E | — (hook *rules* are registered; the manager is not) |
| `ext` | market | route | @chitty/workspace | T | — |

### 1b. Flat verbs

| Command | capability_group | JTBD (§4A) | execution_class | Ontology primary | Existing capability record |
|---|---|---|---|---|---|
| `brief` | workspace | remember | @chitty/ambient | T (+P) | — |
| `checkpoint [msg]` | workspace | remember | @chitty/ambient | E | `chittycanon://capability/workspace/checkpoint-manager` |
| `checkpoints [limit]` | workspace | remember | @chitty/ambient | E | same as above |
| `nudge` | workspace | remember | @chitty/ambient | P | — |
| `doctor` | workspace | verify | @chitty/workspace | L (+T) | — |
| `evaluate` | govern | verify | @chitty/workspace | T (+E) | — |
| `cleanup` | workspace | operate | @chitty/workspace | T | `chittycanon://capability/workspace/session-cleanup` |
| `export` (ChittySecrets write) | connect | govern | @chitty/connectors | **A** | — ⚠ see §1d |
| `sync` (Notion↔GitHub) | connect | operate | @chitty/connectors | T (+E) | — |
| `compliance` | govern | govern | @chitty/workspace | A (+T) | `chittycanon://capability/govern/chittyos-compliance` |
| `analytics` | workspace | remember | @chitty/ambient | E | — |
| `predict` | workspace | remember | @chitty/reasoning | E (+P) | — |
| `suggestions` | workspace | remember | @chitty/reasoning | E (+P) | — |
| `architect <query>` | agent-runtime | resolve | @chitty/reasoning | T (+P) | `chittycanon://capability/agent-runtime/chittyhelper` |
| `open <name> [view]` | connect | operate | @chitty/connectors | L | — |
| `config` | workspace | operate | @chitty/workspace | P (+A) | — |

### 1c. `can chitty <args…>` — a namespace, not a command

`can chitty` is the natural-language interpreter **and** the host of load-bearing
dispatch verbs. `src/commands/chitty.ts` routes these before any NL handling:

| Sub-route | line | capability_group | JTBD | execution_class | Ontology | Record |
|---|---|---|---|---|---|---|
| `authenticate-context` \| `whoami` | 170 | govern | verify | @chitty/workspace | **P** (+A) | — |
| `log-tool` | 143 | govern | remember | @chitty/workspace | E (+T) | — |
| `learn <…>` / `learn <url>` | 150 | workspace | remember | @chitty/reasoning | T (+E) | — |
| `improve` | 163 | workspace | remember | @chitty/reasoning | E | — |
| `evaluate preferences` | 177 | govern | verify | @chitty/ambient | P | — |
| `update-notion` | 184 | connect | remember | @chitty/connectors | E (+T) | — |
| `insights`\|`stats`, `analytics`\|`dashboard`, `suggestions`\|`suggest`, `workflows`\|`list` | 117–137 | workspace | remember | @chitty/ambient | E | — |
| (fallthrough) NL interpretation | — | agent-runtime | route | @chitty/reasoning | T (+P) | — |
| `list-claimable-tasks` | **absent from all of `src/`** | — | — | — | — | — ⚠ |

**The brief under-counts `can chitty`'s load-bearing verbs.** It names three
(`authenticate-context`, `log-tool`, `whoami`); source carries at least **six** pre-NL
routes plus four analytics aliases. `improve` (PostToolUse hook), `learn` (PreToolUse
hook), `evaluate preferences` (UserPromptSubmit hook) and `update-notion`
(SessionStart/Stop hooks) are every bit as call-site-pinned as `authenticate-context`.
Any rename plan built on the brief's three-verb list will break four hook paths.

`list-claimable-tasks` is **absent from the entire `src/` tree** (`grep -rn
list-claimable-tasks src/` → zero hits at `e787416`). The brief's ×1 call site therefore
does not reach a route: it falls through to the natural-language interpreter, which will
attempt to interpret the literal string. It is a dead call site, not a command.

### 1d. Two name collisions that must not be resolved by name

The reconciler rule is binding: *"Never derive a capability identity from an artifact
name, display title, group, slug, package, or runtime path"* (`canonical/README.md`,
Identity-first reconciliation).

- `legacy_id: remote` → `chittycanon://capability/workspace/read-and-write-chittyos`
  is the **ChittyOS MCP gateway**. `can remote` manages *remotes* (rclone-style). Same
  token, different capability. Joining on the name would mis-bind the CLI command to the
  MCP gateway.
- `can export` is documented as "Securely store a secret in ChittySecrets" — a
  credential **write**, ontology primary **A**. Its name says "export". This is the single
  highest-risk naming defect on the surface: a reader, a shell-history grep, and a policy
  gate all read `export` as egress. Flagged ADVISORY→MAJOR pending operator decision; a
  rename is a separate decision from this taxonomy.

### 1e. Capability groups with no command

Of the 11 groups, these have **no** command on the enumerated surface:

| Group | Records | Commands |
|---|---|---|
| `build` | 32 | **0** |
| `legal` | 10 | **0** |
| `local-lab` | 6 | **0** |
| `internal` | 3 | **0** |
| `finance` | 1 | **0** |
| `ship` | 13 | 0 enumerated (`registry` exists off-brief — §2) |

`build` (32 records, the second-largest group) and `legal` (10, the highest-evidentiary
group) have no CLI projection at all. That is a coverage statement, not a defect: §4D of
the runbook lists "Local CLI/plugin" as *one* permitted projection among seven, and a
capability is not required to project into every surface. It does mean the CLI's noun set
cannot be the group set (§2).

### 1f. Commands that map to no existing capability record

**Count: 28 of the 35 enumerated rows above** (§1a 10 + §1b 16 + §1c 9; each `dna`
sub-family counted as one row, not per-subcommand). Seven carry a record: `market`,
`connect`, `checkpoint`, `checkpoints`, `cleanup`, `compliance`, `architect`. Zero records in the overlay have a
`legacy_id` naming a chittycan command. The `legacy_id` prefix vocabulary is
`skill-`, `plugin-`, `agent-`, `hook-`, `workflow-`, `claude-ai-`, and bare MCP server
names. There is **no `cli-` or `can-` prefix**. The entire chittycan surface is
unregistered as a capability class; the handful of matches in §1a–1b are CLI commands
that happen to project an existing *skill* capability (`market`, `hygiene`, `checkpoint`,
`cleanup`, `compliance`, `connect`, `architect`).

Per `canonical/README.md`, an unpublished definition with no explicit
`chittycanon://capability/...` reference is **HOLD**: it may remain authored, but the
reconciler refuses to create marketplace/overlay records for it. So all 28 are HOLD until
each is resolved to an owning capability — they are not eligible for minting by this
document.

## 2. Surface discovered beyond the brief's enumeration

The brief's "CLI surface today" is incomplete. `can --help` on the installed binary
(**0.6.4**) and `src/index.ts` at repo HEAD (**0.6.8** — `e787416`) both carry routes the
brief does not list. Installed and repo differ; neither alone is the surface.

| Route | Source | capability_group | JTBD | Record |
|---|---|---|---|---|
| `wip [action] [path]` | `src/index.ts:1271` | workspace | remember | — |
| `hygiene [path]` | `src/index.ts:1272` | workspace | **govern** (not `operate` — canon already decided) | `chittycanon://capability/workspace/repo-hygiene` ⚠ §2a |
| `scaffold <type>` | index.ts | build | generate | — |
| `run [cmd…]` | index.ts | connect | operate | — |
| `surface [subcommand]` | index.ts | market | route | — |
| `webmaster` / `wm` | index.ts | connect | operate | — |
| `learn <type>`, `growth`, `propose`, `progress`, `synthesize` | index.ts | workspace | remember | — |
| `registry` | control-plane | ship | verify | `chittycanon://capability/ship/query-service-registry` |
| `id <mint\|verify\|list\|session\|credentials>` | control-plane | govern | govern | — |
| `auth <register\|token\|service-token>` | control-plane | connect | govern | — |
| `router`, `cf`, `linear`, `neon` | control-plane | connect | operate | `neon` ↔ `chittycanon://capability/connect/read-and-write-neon-database` (verify) |
| `openai, anthropic, ollama, groq, replicate, together, huggingface, cohere` | control-plane | **no existing group** | route | — |
| 14-entry `CLI_CONFIGS` passthrough (`gh, docker, kubectl, git, npm, aws, gcloud, az, terraform, helm, cargo, pip, yarn, pnpm`) | `chitty.ts:24`, dispatched at `index.ts:123` | **no existing group** | route | — |

### 2a. JTBD already decided in canon — these four bind

`docs/decisions/capability-audit-log.md` is the only place canon has *assigned* JTBD
per capability. Four assignments exist. Where a command projects one of these, the
command's JTBD is **not** mine to choose:

| Decision-log entry | line | `job_to_be_done` | Projecting command |
|---|---|---|---|
| `chittycanon://capability/govern/repo-hygiene-governance` | 154–156 | `govern` | `can hygiene` |
| `chittycanon://capability/finance/finance-operating-defaults` | 848–852 (also 718–720) | `govern` | none |
| `specs/COGNITIVE_OPERATIONS_REGISTRY.md` projection | 1038 | `govern` | none |
| `chittycanon://capability/legal/document-storage` | 1095–1099 | `remember` | none |

Two consequences:

1. **`can hygiene` is `govern`, not `operate`.** The decision log entry at line 128
   distinguishes `repo-hygiene-governance` from `chittyagent-ship` precisely on trigger
   and cardinality, and assigns `govern`. An `operate` classification would contradict a
   ratified decision record. Corrected in §2.
2. **Two decided capabilities never materialized into the overlay.**
   `chittycanon://capability/govern/repo-hygiene-governance` and
   `chittycanon://capability/legal/document-storage` have decision-log entries but **no
   record** in `capabilities.generated.json` (which carries only
   `chittycanon://capability/workspace/repo-hygiene`). So `can hygiene` sits between two
   hygiene capabilities — one materialized and ungoverned, one governed and
   unmaterialized. Binding it requires that conflict resolved first; it is HOLD, not a
   match.

Two classes fit **no existing `capability_group`**: the 8 model-provider namespaces and
the 14 third-party CLI passthroughs. `connect` (52) is the nearest, but every `connect`
member is a ChittyOS-governed connector or a first-party integration; a bare `git`/`docker`
passthrough is neither a capability nor a connector — it is argv forwarding. **No 12th
group is proposed here.** The correct disposition per runbook §5 Step 5 is `document` or
`restrict`, decided by the operator, not a new group value.

## 3. Verdict on grammar

### 3.1 Does the CLI's noun set equal the `capability_group` set?

**No, and it cannot.** Measured:

- Coincide (2): `connect`, `market`.
- CLI nouns that are not groups (≥7): `session`, `dna`, `viewport`, `brief`,
  `checkpoint`, `mcp`, `hook`, `ext`, `remote`, plus every off-brief route in §2.
- Groups with no noun (5–6): `build`, `legal`, `local-lab`, `internal`, `finance`
  (and `ship` on the enumerated surface).

A 2-of-11 overlap is coincidence, not a grammar.

### 3.2 Which option canon supports

**(B), with one amendment — and (A) is affirmatively forbidden.**

**Why (A) is forbidden.** Reshaping to `can <capability_group> <jtbd-verb>` makes the
command path the identity carrier. Canon forbids exactly that:

> "Never derive a capability identity from an artifact name, display title, group, slug,
> package, or **runtime path**." — `canonical/README.md`, Identity-first reconciliation

and

> "Where an artifact is intentionally pointer-only, the pointer itself should resolve to
> the upstream canonical identity instead of **copying the identity payload**."
> — `docs/projection-taxonomy.md`, Projection linkage

A path-encoded group *is* a copied identity payload, and it drifts the moment a
capability is regrouped. The runbook's operating principle says the same from the other
direction: "one canonical identity and many permitted projections… those should be
treated as runtime projections, not separate products" (§1), and §4D lists
"Local CLI/plugin" as one projection kind among seven. A CLI command is a **projection**
of a capability. Projections *reference*; they do not *encode*.

**Why (B) is supported.** The projection taxonomy already names the exact fields:
`canonical_capability_ref`, `projection_id`, `projection_owner`, `projection_family`, and
instructs "Reuse existing supported registry/frontmatter/manifest fields wherever
possible… If another artifact format cannot preserve linkage, record that as a
migration/enforcement gap rather than minting a parallel identity model."
A command declaring its owning `capability_id` is that reuse. CI already blocks
"duplicate Market projection IDs, missing/mismatched projection owner/family metadata"
for agents — the same gate extends to commands.

**The amendment (what the brief's (B) gets wrong).** The brief says "the way skills
already carry `canon_uri:` frontmatter." Measured, there are **two different field names**
in `canonical/`:

- `canonical/skills/capability-registry-audit.md` → `canon_uri:`
- `canonical/commands/autonomy.md` → `canonical_uri:`

Neither is one of the four fields the projection taxonomy names, and neither points at a
`chittycanon://capability/...` id — both point at a *service* URI
(`chittycanon://core/services/chittymarket#skills/...`, `chittycanon://commands/autonomy`).
So the precedent (B) leans on is itself drifted. Option (B) must therefore be stated as:

> Every chittycan command declares `canonical_capability_ref:
> chittycanon://capability/<group>/<name>` plus a JTBD verb, in a single registry the
> CLI and CI both read. Reuse the projection taxonomy's field names, not `canon_uri` /
> `canonical_uri`, and file the two-name divergence as an enforcement gap.

**And one thing canon does not yet support (the (C) component).** JTBD is not a field on
any record. Making the taxonomy machine-checkable requires **adding `job_to_be_done` to
the canonical frontmatter contract** (`plugins/chittyagent-dispatch/agents/chittyagent-dispatch.md`,
"Canonical Document Format") and to the reconciler — a schema change, owned by
ChittyCanon/ChittyMarket governance, not by this document and not by hand-editing the
generated file. Until that lands, JTBD on a command is prose, exactly as it is on a
capability today.

**What canon is silent on:** `docs/projection-taxonomy.md` contains no CLI, grammar,
noun, or verb mandate (grep: zero hits). There is no canonical CLI grammar to comply
with. Canon governs *identity and linkage*, not *ergonomics*. Ergonomic nouns are
therefore a free choice — which is precisely why (B) costs nothing in UX.

## 4. Where the Wake-Up Sequence lands

`can session start` repurposed as the Wake-Up Sequence (board `26318e02`, decision B —
fold the shell hook into chittycan):

| Field | Value | Basis |
|---|---|---|
| `capability_id` | `chittycanon://capability/workspace/session-wake-up` *(PROPOSED — HOLD)* | `chittycanon://capability/<group>/<name>` form, 151/151 conforming |
| `capability_group` | `workspace` | 13 existing members are session/context/posture capabilities (`chittyxl-session-manager`, `chittycontext-checkpoints`, `context-resume`, `checkpoint-manager`) |
| JTBD | **`remember`** | §4A: "context, checkpoint, continuity, handoff" — exactly the sequence's job |
| `execution_class` | `@chitty/ambient` | every sibling session-manager carries it; the sequence loads context, it does not call out |
| Ontology primary | **P** | it is Entity genesis; a Claude context is Person / Synthetic per `chittycanon://gov/governance#core-types`. **Never T.** |
| Ontology secondary | `A`, `E` | binds authority (sponsor/progenitor, trust level) and emits a session-start event |

**Is `session` a legitimate noun?** **Yes — keep it.** It is not a `capability_group`, but
under (B) that is irrelevant: the noun is ergonomics, the `canonical_capability_ref` is
identity. `session` is the accurate domain noun for the thing (`workspace` would be a
worse name for a user, and `remember` as a top-level noun would collide with JTBD-as-verb).
Measured call-site cost of a rename: `can checkpoint` ×3 and `can viewport status` ×2 in
ChittyOS docs/scripts; `session start` is pre-adoption, so renaming it is cheap — but
there is no canonical reason to.

**One prerequisite, and it is a hard gate.** `src/commands/session.ts:85–96` mints a
ChittyID by local string concatenation. This is a **double** violation, worse than the
board task records:

```
const chittyId = `${version}-${generation}-${locale}-${service}-${type}-${ym}-${classification}-${checksum}`;
// 01   -  A   -  GLB  -  OSCL  -  P  -  YYMM  -  S  -  <4 hex>
```

1. **Local minting.** Canon requires `POST https://id.chitty.cc/mint` with
   `{entityType: "P"|"L"|"T"|"E"|"A"}`. Hookify rule `block-chittyid-generation` exists
   for this, registered as
   `chittycanon://capability/govern/block-chittyid-generation`. Board task `c66a4bb5`.
2. **Non-canonical format**, against the owning service's own triad
   (`CHITTYFOUNDATION/chittyid/CLAUDE.md` §22–30, which defines each segment):

   | Segment | Triad definition | `session.ts` emits | Verdict |
   |---|---|---|---|
   | `G` | Geographic region (1–9) | `"A"` | violates |
   | `SSSS` | Sequential ID (4 digits) | `"OSCL"` | violates |
   | `C` | Trust level (0–5) | `"S"` (Synthetic) | violates |
   | `XX` | Mod-97 checksum (2 digits) | 4 uppercase hex chars from `crypto.randomUUID()` | violates — wrong width, wrong alphabet, **no mod-97 computed at all** |

   An ID from this path fails validation at `id.chitty.cc` and at the channel-register
   endpoint, which checks format and mod-97 locally.

Per instruction this is **not fixed here**. It is recorded as a **CRITICAL** blocking
finding: the Wake-Up Sequence must not ship on `session start` until the mint is replaced
by the canonical `POST /mint`, because the sequence's whole job is to establish identity,
and it currently fabricates one in a shape nothing downstream accepts.

## 5. Findings

| Sev | Finding |
|---|---|
| **CRITICAL** | `src/commands/session.ts:96` mints a ChittyID locally **and** in a non-canonical shape (`A`/`OSCL`/4-char checksum vs `G`/`SSSS`/`XX`, no mod-97). Blocks Wake-Up adoption. Board `c66a4bb5`. Not fixed per instruction. |
| **MAJOR** | 28 of 35 enumerated rows, and the entire off-brief surface, carry no `canonical_capability_ref`. All are HOLD; the reconciler will refuse to create overlay records for them. |
| **MAJOR** | Option (A) is forbidden by `canonical/README.md` ("never derive identity from… runtime path") and `docs/projection-taxonomy.md` ("not copying the identity payload"). |
| **MAJOR** | JTBD is not a canonical field. Machine-checkable JTBD requires a frontmatter-contract + reconciler change, not a generated-file edit. |
| **MAJOR** | `canon_uri:` (skills) vs `canonical_uri:` (commands) — two field names for one concept, neither matching the projection taxonomy's four named fields. Enforcement gap. |
| **MAJOR** | `can chitty` has ≥6 pre-NL load-bearing routes (`authenticate-context`/`whoami`, `log-tool`, `learn`, `improve`, `evaluate preferences`, `update-notion`), not 3. A rename plan on the brief's list breaks four hook paths. |
| MINOR | `can export` writes a secret to ChittySecrets. The verb reads as egress; ontology primary is `A`. Rename is a separate decision. |
| MINOR | `legacy_id: remote` (ChittyOS MCP gateway) collides by name with `can remote` (remote manager). Do not join on name. |
| **MAJOR** | `can hygiene` must be JTBD `govern` per `capability-audit-log.md:156`, not `operate`. Canon had already decided; a fresh classification would have contradicted it. |
| **MAJOR** | Two decided capabilities never materialized: `govern/repo-hygiene-governance` (log:154) and `legal/document-storage` (log:1095) have no record in `capabilities.generated.json`. `can hygiene` straddles a materialized-but-ungoverned and a governed-but-unmaterialized capability. |
| MINOR | `CHITTYFOUNDATION/chittyid/CLAUDE.md` §26 lists entity types as **(P/L/T/E)** — it omits **A (Authority)**, violating `chittycanon://gov/governance#core-types`. Its bullets also say `YM`/`X` where its own format line says `YYMM`/`XX`. Filed against the owning triad, not copied here. |
| MINOR | `can chitty list-claimable-tasks` is a **dead call site** — the route is absent from all of `src/`; it falls through to NL interpretation. |
| MINOR | `canonical/commands/autonomy.md` uses `canonical_uri: chittycanon://commands/autonomy` — `commands` is not one of the five canonical namespaces (`core, docs, legal, gov, rel`). |
| MINOR | Installed `can` is 0.6.4; repo HEAD is 0.6.8. Neither alone is the surface. |
| ADVISORY | Model-provider namespaces (8) and `CLI_CONFIGS` passthroughs (14) fit no existing `capability_group`. Disposition `document` or `restrict` per runbook §5 Step 5. No 12th group proposed. |
| ADVISORY | JTBD §4A is cited as §2A in the brief; `discovery.verbs` is not the JTBD axis. |

## 6. Verdict

⚠ **REQUIRES REMEDIATION** — the taxonomy is derivable from canon with no new axis, but
the surface it describes is almost entirely unregistered, and the identity-linkage field
names it would use are themselves drifted.

**Recommended path: (B) as amended in §3.2.** Keep the ergonomic nouns. Add
`canonical_capability_ref` + `job_to_be_done` to the canonical frontmatter contract, land
the JTBD field in the reconciler, then register the chittycan surface command by command —
`session start` last, after the mint violation is closed.
