# Issue #235 — NB Development canonical taxonomy cross-check

**Status:** evidence-backed review; registry identity verification **HOLD**. This document is not a registration or production DNS change.

## Authority

- `AGENTS.md`: ChittyCanon/ChittyRegister/ChittyRegistry own canonical identity; ChittyMarket owns package/projection definitions.
- `docs/projection-taxonomy.md`: normative `chittycanon://docs/tech/spec/chittyentity-projection-taxonomy` is **DRAFT**, and its new projection-family terminology is **PROPOSED**. Do not silently promote it to binding ontology.
- `chittyregistry/CHARTER.md`: Registry is the directory, Register is the compliance gate, Discovery is runtime lookup.
- Live `https://registry.chitty.cc/health` returned HTTP 200 and canonical URI `chittycanon://core/services/chitty-registry` (2026-11-06). A search for `chittymarket` returned zero entries; this does **not** prove absence of an authoritative registration.
- ChittyAgent Canon MCP standard lookup failed with SSE 404. Therefore service-fragment skill URIs are **not registry-verified**.

## Taxonomy crosswalk

| Surface | Identity and ownership rule | NB Development mapping | Disposition |
| --- | --- | --- | --- |
| Capability | Canonical job-to-be-done; identity owned upstream | Development lifecycle, CI repair, repository hygiene, governance, MCP routing, deployment checks | HOLD for registry identity |
| Service | Registered canonical owner | ChittyMarket owns projection definitions, not ecosystem ontology | KEEP |
| Skill | Reusable method/SOP | Eleven `plugins/nb-dev/skills/*/SKILL.md` | PROJECT |
| Plugin | Versioned distribution container | `nb-dev` v0.4.0 | PROJECT |
| Agent | Delegated executor, not just an orchestration procedure | `recursive-development-orchestrator` is a **skill**, not a persistent agent | KEEP as skill |
| MCP/app | Controlled integration/execution boundary | `chittyos-mcp-routing` describes routing; does not instantiate an MCP service | KEEP as skill |
| DNS route | Hostname/alias, not canonical capability | Gateway hostnames in the supplied 2026-11-06 `chitty.cc` export | HOLD |
| Runtime | Deployed and verified service instance | Schema/lint and CLI discovery do not prove native runtime loading | HOLD |

## Skill-to-source crosswalk

All eleven skill projections have corresponding Market-local canonical skill source documents. The canonical files declare `canon_uri: chittycanon://core/services/chittymarket#skills/<slug>`, `kind: skill`, `plugin: nb-dev`; the published `SKILL.md` projections omit those three fields. The URI is **claimed in Market source**, not independently validated in Canon/Registry.

| Skill slug | Canonical source | Runtime projection |
| --- | --- | --- |
| `chittyos-integration-auditor` | `canonical/skills/chittyos-integration-auditor.md` | `plugins/nb-dev/skills/chittyos-integration-auditor/SKILL.md` |
| `chittyos-mcp-routing` | `canonical/skills/chittyos-mcp-routing.md` | `plugins/nb-dev/skills/chittyos-mcp-routing/SKILL.md` |
| `ci-repair-loop` | `canonical/skills/ci-repair-loop.md` | `plugins/nb-dev/skills/ci-repair-loop/SKILL.md` |
| `deployment-verifier` | `canonical/skills/deployment-verifier.md` | `plugins/nb-dev/skills/deployment-verifier/SKILL.md` |
| `development-governance` | `canonical/skills/development-governance.md` | `plugins/nb-dev/skills/development-governance/SKILL.md` |
| `development-security-gates` | `canonical/skills/development-security-gates.md` | `plugins/nb-dev/skills/development-security-gates/SKILL.md` |
| `development-work-continuity` | `canonical/skills/development-work-continuity.md` | `plugins/nb-dev/skills/development-work-continuity/SKILL.md` |
| `manifest-forge-publisher` | `canonical/skills/manifest-forge-publisher.md` | `plugins/nb-dev/skills/manifest-forge-publisher/SKILL.md` |
| `pr-finalizer` | `canonical/skills/pr-finalizer.md` | `plugins/nb-dev/skills/pr-finalizer/SKILL.md` |
| `recursive-development-orchestrator` | `canonical/skills/recursive-development-orchestrator.md` | `plugins/nb-dev/skills/recursive-development-orchestrator/SKILL.md` |
| `repository-hygiene` | `canonical/skills/repository-hygiene.md` | `plugins/nb-dev/skills/repository-hygiene/SKILL.md` |

## DNS observations — no inferred service ownership

The user-provided Cloudflare zone export (2026-11-06 10:45:59) includes `mcp`, `mcp2`, `mcp-portal`, `cf-portal`, `dev`, `gws`, `msg`, `portal.actors` pointing to `gateway.agents.cloudflare.com`; and `ai-gateway`, `central-gateway`, `finance-gateway`, `legal-gateway`, `claw` pointing to `gateway.ai.cloudflare.com`. Shared CNAME target **does not establish** a shared registered service or interchangeable auth policy. The export also labels `mcp-chatgpt` a placeholder and spells `contexual.chitty.cc` without the second 't'. The Registry charter's `registry.chitty.cc` is absent from this zone export, **but the live Registry health endpoint responded HTTP 200**: the DNS export alone is not a complete runtime/route inventory.

## Required verification before promotion

1. Resolve each skill's canonical capability identity in Canon/Registry; verify service-fragment URI grammar and registration receipts. Do not invent capability IDs from slugs.
2. Resolve owner and auth boundary for each Cloudflare custom domain/Worker route using live configuration; distinguish alias from service instance.
3. Reconcile canonical source and generated projection metadata through existing dispatch/manifest tooling. Never treat missing `canon_uri` in a runtime skill projection as proof that canonical identity is absent.
4. Preserve separate states: authored, projected, validated, runtime-verified, signed, published, indexed.
5. Do not change DNS, auth, registry, or publication state without a separate authorized, reversible change.
