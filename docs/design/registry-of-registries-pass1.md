# Registry-of-registries, pass 1 (read-only cross-verification)

Date 2026-10-09. Nothing registered, deregistered, deduped or created. Pass 1 is PARTIAL: it
covers inventories 1-5 and 7 with measurements; 6, 8-11 are UNVERIFIED (see end).

## Matrix

| # | Inventory | Entries | Live-correspondence | Live-but-missing | Authority |
|---|-----------|---------|---------------------|------------------|-----------|
| 1 | registry.chitty.cc/api/v1/tools | 50 (count field 50, array len 50) | not probed per entry (UNVERIFIED) | chittysecrets, chittyconfig, chittymarket, alchemist (all verified absent); also absent by exact name: chittytrust, chittycertify, chittyconnect, chittyrouter (alias such as chittyconcierge exists, so UNVERIFIED as true gaps) | directory, not canon |
| 2 | chittymarket/capabilities.generated.json | 108 (not ~104) | UNVERIFIED | UNVERIFIED | generated projection of canonical/ |
| 3a | chittymarket/marketplace.json | 0 under key plugins (schema may differ, UNVERIFIED) | n/a | n/a | UNVERIFIED |
| 3b | chittymarket/.claude-plugin/marketplace.json | 17 plugins | UNVERIFIED | UNVERIFIED | generated, do not edit |
| 4 | ~/.claude/plugins/installed_plugins.json | 65 | local install state | marketplace lists 17; install set is larger, different scope | local fact |
| 5 | ~/.claude/.mcp.json | 0 servers (only a _comment key) | n/a | the failing servers are PLUGIN-provided (plugin:chittyos-mcp, clawmaven, neon-mcp, agent-memory, promptguard, telegram), so they are configured-but-unreachable, not absent | consistent with Centralized Registration policy |
| 7 | resolve_output.py _MAP | 12 pairs | n/a | n/a | single mapping |

## Measured-fact corrections
- entity_type: T on 21 (all array endpoints), absent on 29 (all object endpoints), A on 0. CONFIRMED.
- chittyagent-npm twice: CONFIRMED, chitty_id 03-1-USA-4665-T-2607-1-36 and 03-1-USA-5363-T-2607-1-47.
- FALSE: _MAP has 12 pairs, not 13 (resolve_output.py:20-33), and it contains NO ("claude-code","workflow") pair; no workflow kind exists in this checkout. Either that was on another branch or the claim is stale.
- FALSE: capabilities total is 108, not ~104.
- NEW: 4 of the 21 self-registered entries (chittydiscovery, chittyregister, chittyregistry, chittyschema) carry a third ID scheme, did:chitty:foundation:<name>, not VV-G-LLL-SSSS-T-YYMM-C-XX. So the registry holds at least two ID schemes among its own entries.
- NEW: all 50 have category None or "service" only; no tier, repo, dependencies.
- Can the registry express A? The schema has an entity_type field and nothing in the data restricts it; whether the POST validator rejects A is UNVERIFIED (not tested, registration forbidden). The 3 Authority-class services: chittycert is present with NO entity_type; chittytrust and chittycertify are absent entirely.
- The 29 missing entity_type values: UNVERIFIED per entry. Proposal only: chittycert/chittyauth are A; services as T per the existing 21-entry convention is itself questionable (a Thing is an object without agency); needs ratification, not inference.
- Live probes: config.chitty.cc does not resolve (curl 000); chittyconfig/wrangler.jsonc still contains PLACEHOLDER_KV literals. agent.chitty.cc/health 200. secrets.chitty.cc and get.chitty.cc return 302 unauthenticated, so liveness and version 0.6.0 are UNVERIFIED from here.

## Worst bidirectional gap
chittysecrets is the ratified cold source of truth for every credential and is absent from the registry, while secrets.chitty.cc is edge-live (302). A grep of the registry reads "does not exist". Same class: chittyconfig and chittymarket, which this estate depends on.

## Capability-registry duplicate check (question: new service or view?)
Capability ids matching registry|drift|reconcile|inventory: Query Service Registry; Neon Schema Drift
chittyschema is the registered owner of drift detection; flow-hash-check (registry record: "Compares live Studio flow export hash against repo-committed JSON; raises a Notion alert on drift. Read-only") is the declared-vs-actual pattern already built once. Recommendation: a VIEW (a reconcile job reusing that pattern, owned by chittyschema), not a new service. Registration of any new entity is a sensitive intent and is proposal-only.

## Prior art found, not yet read
chittyentity/docs/design/reconcile-loop.md matches "registry-of-registries|master sheet". Peer session artifacts otherwise not located. UNVERIFIED content.

## UNVERIFIED / not done in pass 1
6 orchestrator KV skill:index/agent:index; 8 Cloudflare Workers/KV/R2/AI Gateway/AI Search enumeration across 4 accounts; 9 wrangler routes vs resolution; 10 canonical/ (agents 15, skills 44, commands 1, hooks 0 files counted) vs plugins/** projection drift; 11 asking chittyschema what it validates; per-entry liveness of registry entries; reading flow-hash-check source; reading reconcile-loop.md.
