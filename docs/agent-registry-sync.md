# Coded sync: canonical md agents (chittymarket) → CF agent index (chittyentity)

Finding and design. Measured read-only on 2026-09-17. Nothing was changed in either
repo or in the live index.

## Verdict

Yes — but scoped. Sync **definition fields only, one-directional, canonical → CF**,
and treat identity reconciliation as a prerequisite rather than part of it.

## Measured state

**chittymarket** `canonical/agents/` holds 12 definitions. `plugins/chittyagent-dispatch/scripts/adapters/`
holds 7 adapters: `claude-code-agent`, `claude-code-hook`, `claude-code-mcp`,
`claude-skills`, `codex-skill`, `openclaw-agent`, `chatgpt-apps`. Every one writes a
**file**. There is no adapter that writes to the orchestrator index — confirming the
dispatch agent's own note that registration into `agent:index` / `skill:index` is "a
documented manual step with no adapter behind it."

**chittyentity** `workers/chittyagent-orchestrator/src/agent-tools.ts` stores
`agent:index` in KV as `{version, agents[], lastSync}`, where each entry is
`{id, name, description, domain, capabilities[], binding, tools, status, syncedAt}`.
`agent_register` (line 251) upserts `description`, `capabilities`, `domain`, `tools`
and stamps `syncedAt`. The write path already exists; nothing calls it.

**Live index (`agent_list`, 15 agents, all bound):** every single entry returns
`"(no description — run agent_register to add one)"` with `capabilities: []` and
`tools: 0`. The index is populated purely by service-binding discovery. `agent_register`
has never been run for any agent in the ecosystem.

**Overlap is 5 of 22 distinct names.**

| | Names |
|---|---|
| Both (join on `chittyagent-<id>`) | canon, chatgpt, cloudflare, connect, notion |
| Canonical only, no live worker (7) | autobot, claude, dispatch, neon, register, chittyauth-token-ops, chittystorage-sasquatch |
| Live only, no canonical md (10) | alchemist, auth, cleaner, dispute, finance, helper, intel, market, registry, scrape |

## The blocker is identity, not plumbing

Three distinct failures make a naive name join wrong:

1. **Near-miss names.** Canonical `chittyagent-register` vs live `chittyagent-registry`.
   A fuzzy match would silently bind a definition to the wrong worker; an exact match
   reports both as orphans. Neither is right without a human deciding.
2. **Off-convention names.** `chittyauth-token-ops` and `chittystorage-sasquatch` do not
   follow `chittyagent-*`. The live index derives `name` as `chittyagent-${id}`, so these
   cannot be addressed at all. `chittyauth-token-ops` plausibly corresponds to live
   `auth`, but that is an inference, not a link.
3. **The declared join key is barely populated.** Frontmatter `proxies:` — which already
   names the chittyentity worker path — exists on only **3 of 12** files (chatgpt,
   cloudflare, notion). `canon_uri:` exists on 11 of 12 (`chittyagent-autobot` lacks it).

So the sync key should be an explicit frontmatter field pointing at the worker, and the
first task is populating it for the 9 definitions that lack one — a decision per agent,
not a migration.

## What may and may not sync

The ontology already settles this. `chittyagent-cloudflare.md` states it: *"It is a
definition (T); the worker it routes to is the actor."* A definition describes; the
deployed worker acts.

| Field | Owner | Sync |
|---|---|---|
| `description`, `capabilities` | canonical md | push |
| `domain` | canonical md if declared, else CF default | push only when declared |
| `id`, `name` | identity mapping | never derived by the sync |
| `binding`, `status`, `tools` | CF runtime (binding discovery) | never written by the sync |
| `syncedAt`, `version` | CF | CF |

`binding`, `status` and `tools` are discovered facts about what is actually deployed.
A definition push that overwrote them would replace observation with aspiration — the
failure mode that makes a registry untrustworthy.

## Design

- **One direction.** canonical md → `agent_register`. No promotion of live values back
  into md without a human, mirroring the existing `dispatch.sh reconcile` convention
  for file projections.
- **Go through the MCP tool**, not raw KV writes. Registry mutation is sensitive intent,
  so it routes through ChittyConnect; no credential is handled by the adapter.
- **Hash-gate it.** Emit a manifest hash from the synced fields, store it alongside, and
  skip pushes when unchanged. This also makes drift detectable without diffing prose.
- **Never delete.** Absence from `canonical/agents/` marks an entry deprecated. A live
  worker is a deployed actor; a bad sync run must not be able to unregister it.
- **Four CI conditions:** canonical with no live entry; live entry with no canonical;
  hash mismatch; two projections of one agent disagreeing. The same parity pattern that
  caught 32 undocumented accounts in the chittyfinance chart of accounts — an authority
  claim nothing enforces is not authority.

Implementation belongs in `plugins/chittyagent-dispatch/scripts/adapters/` as an eighth
adapter (`chittyentity-registry.sh`), so it inherits the existing dispatch state
sentinel, audit log and drift hook rather than becoming a parallel mechanism.

## Sequence

1. Reconcile identity: decide register↔registry, chittyauth-token-ops↔auth, and whether
   the 10 live-only agents need definitions or are internal-only. Populate the join key.
2. Write the adapter, dry-run first (report what it *would* push).
3. Backfill descriptions and capabilities for the 5 joined agents.
4. Turn on the CI drift check once the orphan sets are deliberate rather than accidental.

Step 1 is a judgement call per agent and should not be automated.

## Not verified

Whether `skill:index` has the same empty-description pattern (only `agent:index` was
read), and whether any of the 10 live-only agents are intentionally undocumented.

## Correction: the naming question is already governed

`chittycanon://docs/tech/spec/chittyentity-projection-taxonomy`
(`chittycanon/specs/CHITTYENTITY_PROJECTION_TAXONOMY.md`, v0.2.2, DRAFT) already defines
ChittyAgent, ChittyActor, **ChittyAnima** and Chitty SDK, and the layout
`chittyentity/{chittyagents,chittyactors,chittyanimas,chittysdks}/*`.

**ChittyAnima** is defined as "animating intelligence, interpretation, transformation,
model, algorithm, workflow, lens, or generative process applied within an entity/
capability context" — with "Agents operationalize intelligence/Anima in context."

This supersedes the naming recommendation implied above, in two ways:

1. **Family is a field, not a prefix.** The spec's own projection relationship keeps
   `projection_id: chittyagent-connect` while declaring `projection_family: ChittyAgent`.
   Renaming slugs to carry the family is the opposite of the intended mechanism, and the
   spec states: "Never derive canonical architecture or ownership backward from a Worker
   name, directory, hostname, plugin name, MCP route, settings field, or CLI command."
2. **The terms are PROPOSED, not canonical.** They have not cleared simulation, guardian
   approval, or promotion to PROVISIONAL. The spec says consumers "MUST NOT persist the
   proposed labels as new canonical ontology values"; experimental use must stay local and
   removable. Explicitly listed as out of bounds: "silently overriding the current Agent
   Slug Convention," "inferring canonical ownership from a prefix, runtime, directory, or
   deployment name," and mass-moving Market-owned definitions without semantic
   classification and ownership reconciliation.

**Consequence for this sync:** key on `projection_id` — the stable canonical slug — and
carry `projection_family` as metadata. No rename is required, which removes the blast
radius entirely. The identity work that remains is genuine ambiguity (register/registry,
the off-convention slugs, unpopulated `proxies:`), not a naming migration.

The Path to PROVISIONAL (spec §"Path to PROVISIONAL") requires reconciling the proposed
terms against the Agent Slug Convention, registry records, ChittyConfig pointers,
ChittyMarket manifests, ChittyCan routing and live runtime projections — which is where a
`chittyanima-*` slug decision belongs, not here.
