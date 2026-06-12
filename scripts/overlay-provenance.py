#!/usr/bin/env python3
"""overlay-provenance.py — content-addressing for the Capability Overlay.

Stamps and verifies a tamper-evident SHA-256 content hash on every record in
capabilities.generated.json. The content_hash is computed over the canonical
serialization of the record *excluding* its own provenance block, so stamping
is idempotent. This hash is the exact byte string a future Ed25519 signature
will sign and that anchors into ChittyLedger — i.e. the provenance substrate the
signing/trust moat is built on. Dependency-free (stdlib only).

Subcommands:
  stamp   recompute every record's content_hash, (re)write the provenance block
          and the top-level overlay_provenance aggregate. Idempotent.
  verify  recompute and compare; exit 1 on any mismatch (tamper / drift). CI gate.

Provenance block (per record):
  content_hash          "sha256:<hex>" over canonical(record - provenance)
  canonicalization      "json-sorted-compact" (sorted keys, no whitespace, UTF-8)
  hash_covers           "record-excluding-provenance"
  schema_ref            chittycanon URI of the §16 contract
  signature             null  — Ed25519 over content_hash; pending a
                              ChittyConnect-provisioned ChittyMarket signing key
  signer_chittyid       null  — publisher ChittyID; pending
  anchored_in_ledger    null  — ChittyLedger entry id; pending

The three null fields are honest status, not stubs: the content-integrity layer
is real and verified today; the keyed signature + ledger anchor are the
sensitive-intent follow-up that must route through ChittyConnect.
"""
import hashlib
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
OVERLAY = REPO / "capabilities.generated.json"
SCHEMA_REF = "chittycanon://core/services/chittymarket#section-16"
CANON = "json-sorted-compact"


def canonical_bytes(record: dict) -> bytes:
    """Deterministic serialization of a record, excluding its provenance block.

    Values in the overlay are strings/bools/ints/arrays/objects — no floats — so
    sorted-compact JSON is a stable canonical form.
    """
    body = {k: v for k, v in record.items() if k != "provenance"}
    return json.dumps(body, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")


def content_hash(record: dict) -> str:
    return "sha256:" + hashlib.sha256(canonical_bytes(record)).hexdigest()


def aggregate_hash(hashes) -> str:
    """Single anchor over all record hashes (order-independent: sorted)."""
    joined = "\n".join(sorted(hashes)).encode("utf-8")
    return "sha256:" + hashlib.sha256(joined).hexdigest()


def load():
    try:
        return json.loads(OVERLAY.read_text(encoding="utf-8"))
    except FileNotFoundError:
        print(f"ERROR: {OVERLAY} not found", file=sys.stderr); sys.exit(2)
    except json.JSONDecodeError as e:
        print(f"ERROR: {OVERLAY} invalid JSON: {e}", file=sys.stderr); sys.exit(2)


def stamp():
    data = load()
    caps = data.get("capabilities", [])
    hashes = []
    for c in caps:
        h = content_hash(c)
        hashes.append(h)
        prev = c.get("provenance") or {}
        c["provenance"] = {
            "content_hash": h,
            "canonicalization": CANON,
            "hash_covers": "record-excluding-provenance",
            "schema_ref": SCHEMA_REF,
            # Preserve any already-applied signature/anchor; default null (honest
            # status — keyed layer is the ChittyConnect-gated follow-up).
            "signature": prev.get("signature"),
            "signer_chittyid": prev.get("signer_chittyid"),
            "anchored_in_ledger": prev.get("anchored_in_ledger"),
        }
    data["overlay_provenance"] = {
        "aggregate_hash": aggregate_hash(hashes),
        "record_count": len(caps),
        "canonicalization": CANON,
        "hash_alg": "sha256",
        "anchored_in_ledger": (data.get("overlay_provenance") or {}).get("anchored_in_ledger"),
    }
    OVERLAY.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"stamped {len(caps)} records; aggregate {data['overlay_provenance']['aggregate_hash']}")
    return 0


def verify():
    data = load()
    caps = data.get("capabilities", [])
    errors = []
    hashes = []
    for i, c in enumerate(caps):
        ident = c.get("legacy_id") or f"record#{i}"
        prov = c.get("provenance")
        if not isinstance(prov, dict) or "content_hash" not in prov:
            errors.append(f"  [{ident}] missing provenance.content_hash — run: overlay-provenance.py stamp")
            continue
        expected = content_hash(c)
        hashes.append(expected)
        if prov["content_hash"] != expected:
            errors.append(f"  [{ident}] content_hash mismatch (tampered/stale)\n"
                          f"      stored:   {prov['content_hash']}\n"
                          f"      computed: {expected}")
    agg_stored = (data.get("overlay_provenance") or {}).get("aggregate_hash")
    agg_expected = aggregate_hash(hashes) if hashes else None
    if agg_stored != agg_expected and not errors:
        errors.append(f"  aggregate_hash mismatch: stored {agg_stored} != computed {agg_expected}")

    print("=== overlay provenance verification ===")
    print(f"  records: {len(caps)}")
    if errors:
        print(f"\n  \033[0;31m{len(errors)} mismatch(es):\033[0m")
        print("\n".join(errors))
        print("\n\033[0;31mProvenance verification FAILED.\033[0m")
        return 1
    print(f"  aggregate: {agg_stored}")
    print("  \033[0;32mAll clear — every record's content_hash matches; aggregate consistent.\033[0m")
    return 0


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in {"stamp", "verify"}:
        print("usage: overlay-provenance.py {stamp|verify}", file=sys.stderr)
        return 2
    return stamp() if sys.argv[1] == "stamp" else verify()


if __name__ == "__main__":
    sys.exit(main())
