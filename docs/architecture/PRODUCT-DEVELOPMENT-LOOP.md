# ChittyMarket Product Development Loop

Status: active
Owner: ChittyMarket
Tracking issue: #125

## Purpose

This loop continuously evolves ChittyMarket toward a private, standards-aligned capability supply chain rather than a flat catalog of artifacts.

## Loop state machine

```text
OBSERVE
  -> SELECT
  -> IMPLEMENT
  -> VALIDATE
  -> RUNTIME_VERIFY
  -> ADVERSARIAL_REVIEW
  -> RECORD
  -> PROMOTE
  -> OBSERVE
```

The loop may stop or hold at any stage when evidence is insufficient. A hold is preferable to inventing identity, provenance, or runtime truth.

## Release truth states

Treat these as distinct facts:

- `AUTHORED` — source/projection definition exists.
- `IDENTITY_RESOLVED` — authoritative canonical capability reference is known.
- `PROJECTED` — target package/artifact was deterministically rendered.
- `VALIDATED` — static/schema/policy checks passed.
- `RUNTIME_VERIFIED` — target runtime/gateway/client actually loaded or executed the capability as expected.
- `SIGNED` — approved provenance/signing evidence exists.
- `PUBLISHED` — artifact is available on the intended distribution surface.
- `INDEXED` — discovery surfaces resolve to the published runtime/package.

Never collapse these into one boolean such as `enabled` or `synced`.

## Prioritization

Prefer work in this order:

1. Truth/integrity defects that can cause false publication or false runtime claims.
2. Security/privacy/authorization defects.
3. Identity and registry drift.
4. Broken deterministic generation or projection drift.
5. Native platform/standards compatibility.
6. Operator UX, discovery, and packaging.
7. New capability creation only after existing-first gap analysis.

## Current Loop 1

### Objective

Repair the truth layer before adding additional marketplace projections.

### Existing blockers

- #88 — generated capability overlay has no current-main deterministic generator.
- #96 — canonical capability/entity/projection linkage and verification-state enforcement are incomplete.
- #107 — agent naming/index/runtime drift.
- #123 — private/public publication incident and privacy boundary.
- #75 — native plugin/container projection gaps.
- #70 — market registration/auth path gap.

### Acceptance criteria

- Current-main deterministic reconciliation/generation exists.
- Generator refuses unresolved canonical identity rather than constructing capability IDs from group/title.
- Dispatch/projection state is distinct from runtime verification state.
- Compliance triad and security docs describe the same architecture.
- CI checks the new invariants.
- PR includes validation evidence and adversarial review.

## Daily report

Each daily run reports only material changes:

- shipped/merged changes and receipts;
- open PR/issue state that changed;
- registry/gateway/runtime drift detected;
- external standards/platform changes that require product action;
- blocker or hold reason;
- next bounded development unit.

The report should not claim a fix is live without runtime evidence.
