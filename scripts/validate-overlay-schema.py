#!/usr/bin/env python3
"""validate-overlay-schema.py

Validate every record in capabilities.generated.json against the §16 Canonical
Capability Record contract. Dependency-free (stdlib only) so CI needs no install.

Checks per record:
  - all required top-level + nested fields present
  - enum fields within their allowed domain
  - capability_id matches chittycanon://capability/<group>/<slug> and its group
    segment equals capability_group
  - ontology codes ⊆ {P,L,T,E,A}, primary non-empty
  - canonical_version is semver-ish
Cross-record:
  - capability_id and legacy_id are unique

Exit 0 = all valid. Exit 1 = one or more violations (all listed). Exit 2 = I/O.
"""
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
OVERLAY = REPO / "capabilities.generated.json"

# @canon: chittycanon://gov/governance#core-types — all five P/L/T/E/A.
ONTOLOGY_CODES = {"P", "L", "T", "E", "A"}
EXECUTION_CLASSES = {
    "@chitty/ambient", "@chitty/connectors", "@chitty/reasoning", "@chitty/workspace",
}
GROUPS = {
    "agent-runtime", "build", "connect", "govern", "internal",
    "legal", "local-lab", "market", "ship", "workspace",
}
VISIBILITY = {"advanced", "recommended"}
COST = {"high", "low", "medium"}
RISK = {"high", "low", "medium"}
GROUP_SOURCE = {"category", "name-rule", "override"}
AUTH_MODE = {"device-code", "existing-session", "local-only", "service-token"}

REQUIRED_TOP = {
    "capability_id", "legacy_id", "name", "description", "capability_group",
    "group_assignment_source", "execution_class", "canonical_version",
    "projection_version_policy", "ontology", "authority", "execution",
    "discovery", "auth_flow", "runtime_exclusions", "compatible_channels",
    "source_links", "phase0_audit", "legacy_type", "legacy_category",
    "deprecated_aliases", "visibility", "provenance",
}
REQUIRED_PROVENANCE = {
    "content_hash", "canonicalization", "hash_covers", "schema_ref",
    "signature", "signer_chittyid", "anchored_in_ledger",
}
REQUIRED_EXECUTION = {"default_surface", "local_allowed", "context_cost", "mutation_risk"}
REQUIRED_DISCOVERY = {"indexable", "session_index", "ambient_by_intent", "verbs", "fallback_search"}
REQUIRED_AUTHFLOW = {"mode", "stores_credentials_in", "fail_closed_if_unavailable"}

CAP_ID_RE = re.compile(r"^chittycanon://capability/([a-z][a-z0-9-]*)/([a-z0-9][a-z0-9-]*)$")
SEMVER_RE = re.compile(r"^\d+\.\d+\.\d+$")


def validate():
    try:
        data = json.loads(OVERLAY.read_text(encoding="utf-8"))
    except FileNotFoundError:
        print(f"ERROR: {OVERLAY} not found", file=sys.stderr)
        return 2
    except json.JSONDecodeError as e:
        print(f"ERROR: {OVERLAY} invalid JSON: {e}", file=sys.stderr)
        return 2

    caps = data.get("capabilities")
    if not isinstance(caps, list):
        print("ERROR: .capabilities is not an array", file=sys.stderr)
        return 2

    errors = []
    seen_cap, seen_legacy = {}, {}

    def err(idx, ident, msg):
        errors.append(f"  [{idx}] {ident}: {msg}")

    for i, c in enumerate(caps):
        ident = c.get("legacy_id") or c.get("capability_id") or f"record#{i}"

        missing = REQUIRED_TOP - set(c.keys())
        if missing:
            err(i, ident, f"missing required fields: {', '.join(sorted(missing))}")

        cap_id = c.get("capability_id", "")
        m = CAP_ID_RE.match(cap_id) if isinstance(cap_id, str) else None
        if not m:
            err(i, ident, f"capability_id not chittycanon://capability/<group>/<slug>: {cap_id!r}")
        else:
            uri_group = m.group(1)
            cg = c.get("capability_group")
            if cg in GROUPS and uri_group != cg:
                err(i, ident, f"capability_id group '{uri_group}' != capability_group '{cg}'")
        if cap_id:
            seen_cap.setdefault(cap_id, []).append(ident)

        legacy_id = c.get("legacy_id")
        if legacy_id:
            seen_legacy.setdefault(legacy_id, []).append(ident)

        def check_enum(field, value, domain):
            if value not in domain:
                err(i, ident, f"{field}={value!r} not in {sorted(domain)}")

        check_enum("capability_group", c.get("capability_group"), GROUPS)
        check_enum("execution_class", c.get("execution_class"), EXECUTION_CLASSES)
        check_enum("visibility", c.get("visibility"), VISIBILITY)
        check_enum("group_assignment_source", c.get("group_assignment_source"), GROUP_SOURCE)

        cv = c.get("canonical_version", "")
        if not (isinstance(cv, str) and SEMVER_RE.match(cv)):
            err(i, ident, f"canonical_version not semver: {cv!r}")

        ont = c.get("ontology", {})
        if isinstance(ont, dict):
            prim = ont.get("primary", [])
            sec = ont.get("secondary", [])
            if not isinstance(prim, list) or not prim:
                err(i, ident, "ontology.primary must be a non-empty list")
            bad = (set(prim) | set(sec)) - ONTOLOGY_CODES if isinstance(prim, list) and isinstance(sec, list) else {"?"}
            if bad:
                err(i, ident, f"ontology codes not in P/L/T/E/A: {sorted(bad)}")
        else:
            err(i, ident, "ontology missing/not an object")

        ex = c.get("execution", {})
        if isinstance(ex, dict):
            em = REQUIRED_EXECUTION - set(ex.keys())
            if em:
                err(i, ident, f"execution missing: {', '.join(sorted(em))}")
            if "context_cost" in ex:
                check_enum("execution.context_cost", ex["context_cost"], COST)
            if "mutation_risk" in ex:
                check_enum("execution.mutation_risk", ex["mutation_risk"], RISK)
        else:
            err(i, ident, "execution missing/not an object")

        disc = c.get("discovery", {})
        if isinstance(disc, dict):
            dm = REQUIRED_DISCOVERY - set(disc.keys())
            if dm:
                err(i, ident, f"discovery missing: {', '.join(sorted(dm))}")
            if not isinstance(disc.get("verbs", None), list):
                err(i, ident, "discovery.verbs must be a list")
        else:
            err(i, ident, "discovery missing/not an object")

        af = c.get("auth_flow", {})
        if isinstance(af, dict):
            am = REQUIRED_AUTHFLOW - set(af.keys())
            if am:
                err(i, ident, f"auth_flow missing: {', '.join(sorted(am))}")
            if "mode" in af:
                check_enum("auth_flow.mode", af["mode"], AUTH_MODE)
        else:
            err(i, ident, "auth_flow missing/not an object")

        if not isinstance(c.get("compatible_channels"), list) or not c.get("compatible_channels"):
            err(i, ident, "compatible_channels must be a non-empty list")

        prov = c.get("provenance", {})
        if isinstance(prov, dict):
            pm = REQUIRED_PROVENANCE - set(prov.keys())
            if pm:
                err(i, ident, f"provenance missing: {', '.join(sorted(pm))}")
            ch = prov.get("content_hash", "")
            if not (isinstance(ch, str) and re.match(r"^sha256:[0-9a-f]{64}$", ch)):
                err(i, ident, f"provenance.content_hash not sha256:<64hex>: {ch!r}")
        else:
            err(i, ident, "provenance missing/not an object (run overlay-provenance.py stamp)")

    for cap_id, owners in seen_cap.items():
        if len(owners) > 1:
            errors.append(f"  duplicate capability_id {cap_id!r}: {owners}")
    for legacy_id, owners in seen_legacy.items():
        if len(owners) > 1:
            errors.append(f"  duplicate legacy_id {legacy_id!r}: {owners}")

    print("=== §16 capability-record schema validation ===")
    print(f"  records: {len(caps)}")
    if errors:
        print(f"\n  \033[0;31m{len(errors)} violation(s):\033[0m")
        print("\n".join(errors))
        print("\n\033[0;31mSchema validation FAILED.\033[0m")
        return 1
    print("  \033[0;32mAll clear — every record satisfies the §16 contract.\033[0m")
    return 0


if __name__ == "__main__":
    sys.exit(validate())
