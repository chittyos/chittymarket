# Capability Provenance & Signing

Status: **Phase 2a — content-addressing (live)** · Phase 2b — signing (gated) · Phase 2c — ledger anchor (gated)

The competitive moat for ChittyMarket is **signed, identity-bound, ledger-anchored
capability records** — no registry in the Claude Code / MCP space cryptographically
signs the capability itself (the best competitors reach is namespace verification or
human curation). This document defines the layered path and which layers are live.

## Layer 1 — Content addressing (LIVE)

Every record in `capabilities.generated.json` carries a `provenance` block:

```json
"provenance": {
  "content_hash": "sha256:<64hex>",        // over canonical(record − provenance)
  "canonicalization": "json-sorted-compact",
  "hash_covers": "record-excluding-provenance",
  "schema_ref": "chittycanon://core/services/chittymarket#section-16",
  "signature": null,
  "signer_chittyid": null,
  "anchored_in_ledger": null
}
```

A top-level `overlay_provenance.aggregate_hash` is the single SHA-256 anchor over
all record hashes (sorted, order-independent).

- **Stamp:** `scripts/overlay-provenance.py stamp` — idempotent; recomputes hashes.
- **Verify (CI gate):** `scripts/overlay-provenance.py verify` — recomputes and
  fails on any tamper/drift. Wired into `validate-chittymarket.yml` (step 2e).

The `content_hash` is the exact byte string Layer 2 signs and Layer 3 anchors —
content addressing is the substrate, complete and verified on its own.

## Layer 2 — Ed25519 signature (GATED — sensitive-intent)

Populate `signature` (Ed25519 over `content_hash`) and `signer_chittyid` (the
ChittyMarket publisher ChittyID). **Blocked on authorization:** the signing key
must be provisioned and read via **ChittyConnect** per the system-wide
sensitive-intent contract — it is never pasted, hardcoded, or committed. Verify
would check the signature against the publisher's public key on `/market enable`,
fail-closed if absent.

## Layer 3 — ChittyLedger anchor (GATED)

Post `overlay_provenance.aggregate_hash` (and optionally per-record hashes) as a
domain-tagged entry into **ChittyLedger** (the substrate; see the Finance/Evidence
projection model). `anchored_in_ledger` records the entry id, making the overlay's
integrity externally auditable against an immutable hash chain.

## Why layered

Layer 1 needs no secrets and ships real tamper-evidence today. Layers 2–3 are the
keyed/external steps that cross sensitive-intent and ecosystem boundaries — they
require operator authorization and ChittyConnect routing, so they are staged
separately rather than blocking the substrate.
