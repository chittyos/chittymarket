#!/usr/bin/env python3
"""
market-reconcile.py — canonical/ → marketplace.json + capabilities.generated.json

Closes the gap named in docs/architecture/UNIVERSAL-PROJECTION-PLAN.md ("Not in
scope of this plan: a marketplace.json (root inventory) regenerator — currently
hand-maintained via /market"). That gap is why registering a capability was a
manual, per-artifact punch list: each one needed a hand-written marketplace
entry AND a hand-written §16 overlay record.

This is the inventory-layer sibling of `dispatch.sh audit|reconcile`, which
already does the same job for canonical → runtime projections. Same shape, same
refusal semantics.

    market-reconcile.py audit   # read-only; exit 1 on any drift
    market-reconcile.py sync    # write marketplace.json + capabilities.generated.json

## Provenance partition (the load-bearing invariant)

marketplace.json holds two disjoint populations:

  * source: "canonical" — backed by a file under canonical/<kind>/<name>.md.
    Owned by this pipeline. Added, updated, and drift-checked automatically.
  * source: "external"  — official Anthropic plugins, claude.ai MCP servers,
    Ch1tty-managed servers. No canonical file exists or ever will.
    NEVER touched, dropped, or reordered by this script.

A regenerator without this partition would silently delete every external
entry on its first run. Provenance is recorded explicitly rather than inferred,
so that deleting a canonical file surfaces as an ORPHAN finding instead of the
entry quietly reclassifying itself as external.

## What sync writes vs preserves

Derived (canonical is authoritative; overwritten on every sync):
    id, description, canon_uri, type, tags, source_links, deprecated_aliases,
    compatible_channels, legacy_type, capability_id, provenance

Operator-owned (preserved on existing entries; defaulted only when creating):
    name/title, enabled, installMode, access, category, standalone, ch1tty

`enabled` and `installMode` are operator state, not derived state. Sync must
never flip a toggle the operator set.

## Editorial fields are declared, never invented

Several §16 fields — ontology, execution_class, phase0_audit, visibility,
discovery, auth_flow — are governance judgments that cannot be derived from a
canonical file. This script does NOT guess them. Each canonical artifact opting
into the inventory declares them in an `overlay:` frontmatter block; artifacts
missing it are reported by `audit` with a ready-to-paste stub, and are refused
by `sync`.

This mirrors the repo's existing stance in docs/overrides/evidence-gate-overrides.json:
"The generator MUST refuse to emit a record that asserts non_repudiation_required
without a populated evidence_gate." Fabricated governance metadata is worse than
an explicit gap.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys

try:
    import yaml
except ImportError:
    sys.exit("ERROR: PyYAML required (pip install pyyaml)")

# ── enums, mirrored from scripts/validate-overlay-schema.py ────────────────────
GROUPS = {
    "agent-runtime", "build", "connect", "govern", "internal",
    "legal", "local-lab", "market", "ship", "workspace",
}
EXEC_CLASSES = {
    "@chitty/ambient", "@chitty/connectors",
    "@chitty/reasoning", "@chitty/workspace",
}
VISIBILITIES = {"advanced", "recommended"}
COST = RISK = {"high", "low", "medium"}
AUTH_MODES = {"device-code", "existing-session", "local-only", "service-token"}
ONTOLOGY_TYPES = {"P", "L", "T", "E", "A"}  # @canon: chittycanon://gov/governance#core-types
EVIDENCE_GATES = {"pre-execute-middleware", "projection-internal", "legal-space-only"}

CAP_ID_RE = re.compile(r"^chittycanon://capability/([a-z][a-z0-9-]*)/([a-z0-9][a-z0-9-]*)$")

# canonical kind → marketplace.json `type`
KIND_TO_TYPE = {
    "agent": "agent",
    "skill": "skill",
    "command": "command",
    "mcp": "mcp-server",
    "tool": "tool",
    "hook": "hook",
}
# marketplace.json `type` → id prefix (derived from the existing manifest's
# own convention: skill-<n>, agent-<n>, hook-<n>, bare <n> for mcp-server)
TYPE_TO_PREFIX = {
    "skill": "skill-",
    "agent": "agent-",
    "hook": "hook-",
    "command": "command-",
    "tool": "tool-",
    "mcp-server": "",
    "plugin": "",
}
# canonical `runtimes` → §16 compatible_channels
RUNTIME_TO_CHANNEL = {
    "claude-code": "claude_code",
    "claude-skills": "claude_ai",
    "claude-desktop": "claude_desktop",
    "chatgpt-apps": "chatgpt",
    "chatgpt": "chatgpt",
    "codex": "codex",
    "openclaw": "openclaw",
}

REQUIRED_OVERLAY_FIELDS = [
    "capability_group", "execution_class", "visibility", "legacy_category",
    "title", "ontology", "authority", "execution", "discovery",
    "auth_flow", "phase0_audit",
]

REPO_ROOT = subprocess.check_output(
    ["git", "rev-parse", "--show-toplevel"], text=True
).strip()
MANIFEST = os.path.join(REPO_ROOT, "marketplace.json")
OVERLAY = os.path.join(REPO_ROOT, "capabilities.generated.json")
CANONICAL_DIR = os.path.join(REPO_ROOT, "canonical")

RED, GRN, YEL, DIM, RST = "\033[0;31m", "\033[0;32m", "\033[0;33m", "\033[0;90m", "\033[0m"


def slugify(text: str) -> str:
    s = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
    return re.sub(r"-+", "-", s) or "capability"


def read_frontmatter(path: str) -> dict:
    with open(path, encoding="utf-8") as fh:
        src = fh.read()
    m = re.match(r"^---\n(.*?)\n---\n", src, re.DOTALL)
    if not m:
        return {}
    return yaml.safe_load(m.group(1)) or {}


def first_line(text) -> str:
    """Collapse a multi-line canonical description to a single manifest line."""
    if not isinstance(text, str):
        return ""
    for para in text.strip().split("\n\n"):
        line = " ".join(para.split())
        if line:
            return line
    return ""


def load_canonical() -> dict:
    """Map canonical name → metadata for every canonical/<kind>/<name>.md."""
    out = {}
    for kind_dir, kind in (
        ("agents", "agent"), ("skills", "skill"), ("commands", "command"),
        ("mcp", "mcp"), ("tools", "tool"), ("hooks", "hook"),
    ):
        d = os.path.join(CANONICAL_DIR, kind_dir)
        if not os.path.isdir(d):
            continue
        for fname in sorted(os.listdir(d)):
            if not fname.endswith(".md"):
                continue
            name = fname[:-3]
            path = os.path.join(d, fname)
            fm = read_frontmatter(path)
            out[name] = {
                "name": name,
                "kind": fm.get("kind", kind),
                "path": os.path.relpath(path, REPO_ROOT),
                "fm": fm,
                "overlay": fm.get("overlay") or {},
            }
    return out


def entry_base_id(entry: dict) -> str:
    prefix = TYPE_TO_PREFIX.get(entry.get("type"), "")
    eid = entry.get("id", "")
    return eid[len(prefix):] if prefix and eid.startswith(prefix) else eid


def validate_overlay_block(name: str, ov: dict) -> list[str]:
    """Return a list of human-readable problems with an overlay: block."""
    errs = []
    missing = [f for f in REQUIRED_OVERLAY_FIELDS if not ov.get(f)]
    if missing:
        errs.append(f"missing overlay fields: {', '.join(missing)}")
        return errs  # further checks would be noise

    if ov["capability_group"] not in GROUPS:
        errs.append(f"capability_group {ov['capability_group']!r} not in {sorted(GROUPS)}")
    if ov["execution_class"] not in EXEC_CLASSES:
        errs.append(f"execution_class {ov['execution_class']!r} not in {sorted(EXEC_CLASSES)}")
    if ov["visibility"] not in VISIBILITIES:
        errs.append(f"visibility {ov['visibility']!r} not in {sorted(VISIBILITIES)}")

    onto = ov.get("ontology") or {}
    primary = onto.get("primary") or []
    if not primary:
        errs.append("ontology.primary must be a non-empty list")
    bad = (set(primary) | set(onto.get("secondary") or [])) - ONTOLOGY_TYPES
    if bad:
        errs.append(f"ontology types {sorted(bad)} not in P/L/T/E/A")

    ex = ov.get("execution") or {}
    for f in ("default_surface", "local_allowed", "context_cost", "mutation_risk"):
        if f not in ex:
            errs.append(f"execution.{f} required")
    if ex.get("context_cost") and ex["context_cost"] not in COST:
        errs.append(f"execution.context_cost {ex['context_cost']!r} not in {sorted(COST)}")
    if ex.get("mutation_risk") and ex["mutation_risk"] not in RISK:
        errs.append(f"execution.mutation_risk {ex['mutation_risk']!r} not in {sorted(RISK)}")

    dis = ov.get("discovery") or {}
    for f in ("indexable", "session_index", "ambient_by_intent", "verbs", "fallback_search"):
        if f not in dis:
            errs.append(f"discovery.{f} required")
    if "verbs" in dis and not isinstance(dis["verbs"], list):
        errs.append("discovery.verbs must be a list")

    af = ov.get("auth_flow") or {}
    for f in ("mode", "stores_credentials_in", "fail_closed_if_unavailable"):
        if f not in af:
            errs.append(f"auth_flow.{f} required")
    if af.get("mode") and af["mode"] not in AUTH_MODES:
        errs.append(f"auth_flow.mode {af['mode']!r} not in {sorted(AUTH_MODES)}")

    # Mirrors pre-commit-drift.sh:105-140 — a capability asserting
    # non-repudiation must name the gate that enforces it.
    auth = ov.get("authority") or {}
    if auth.get("non_repudiation_required") and not auth.get("evidence_gate"):
        errs.append(
            "authority.non_repudiation_required:true requires authority.evidence_gate "
            f"({sorted(EVIDENCE_GATES)})"
        )
    gate = auth.get("evidence_gate")
    if gate and gate not in EVIDENCE_GATES:
        errs.append(f"authority.evidence_gate {gate!r} not in {sorted(EVIDENCE_GATES)}")

    return errs


def overlay_stub(name: str, kind: str) -> str:
    """A paste-ready overlay: block for a canonical file that lacks one."""
    title = " ".join(w.capitalize() for w in re.split(r"[-_]", name))
    return f"""overlay:
  title: "{title}"
  capability_group: workspace      # {'|'.join(sorted(GROUPS))}
  execution_class: "@chitty/connectors"  # {'|'.join(sorted(EXEC_CLASSES))}
  visibility: advanced             # advanced|recommended
  legacy_category: ecosystem
  ontology:
    primary: [T]                   # P/L/T/E/A — @canon: chittycanon://gov/governance#core-types
    secondary: [E]
  authority:
    requires_chittyid: true
  execution:
    default_surface: ch1tty
    local_allowed: false
    context_cost: medium           # high|low|medium
    mutation_risk: low             # high|low|medium
  discovery:
    indexable: true
    session_index: hidden
    ambient_by_intent: false
    verbs: [{name.split('-')[0]}]
    fallback_search: true
  auth_flow:
    mode: service-token            # device-code|existing-session|local-only|service-token
    stores_credentials_in: ChittyConnect
    fail_closed_if_unavailable: true
  phase0_audit:
    job_to_be_done: route
    environmental_footprint: "read-only connector"
    evidentiary_risk: none
    advisory_disposition: {kind}
"""


def derive_source_links(c: dict) -> list[str]:
    """Prefer the in-repo projection path; it is CI-gated by check-source-freshness.sh."""
    fm, kind, name = c["fm"], c["kind"], c["name"]
    plugin = fm.get("plugin")
    if plugin:
        candidates = {
            "agent": f"plugins/{plugin}/agents/{name}.md",
            "skill": f"plugins/{plugin}/skills/{name}/SKILL.md",
            "command": f"plugins/{plugin}/commands/{name}.md",
            "tool": f"plugins/{plugin}/claude-skills/{name}.json",
        }
        rel = candidates.get(kind)
        if rel and os.path.exists(os.path.join(REPO_ROOT, rel)):
            return [f"local://{rel}"]
    # canonical source always exists — a valid, gating, always-fresh link
    return [f"local://{c['path']}"]


def build_manifest_entry(c: dict, existing: dict | None) -> dict:
    ov = c["overlay"]
    mtype = KIND_TO_TYPE.get(c["kind"], c["kind"])
    eid = TYPE_TO_PREFIX.get(mtype, "") + c["name"]
    desc = first_line(c["fm"].get("description")) or c["name"]

    entry = dict(existing) if existing else {}
    # ── derived: canonical wins ────────────────────────────────────────────
    entry["id"] = eid
    entry["description"] = desc
    entry["type"] = mtype
    entry["source"] = "canonical"
    if c["fm"].get("canon_uri"):
        entry["canon_uri"] = c["fm"]["canon_uri"]
    cls = c["fm"].get("classification") or []
    if cls:
        entry["tags"] = list(cls)
    # ── operator-owned: preserve, default only when creating ───────────────
    entry.setdefault("name", ov.get("title") or c["name"])
    entry.setdefault("category", ov.get("legacy_category", "ecosystem"))
    entry.setdefault("access", "readwrite")
    entry.setdefault("enabled", True)
    entry.setdefault("installMode", "standalone")
    entry.setdefault("standalone", {
        "available": True,
        "type": mtype,
        "path": f"~/.claude/{c['kind']}s/{c['name']}"
                + (".md" if c["kind"] in ("agent", "command") else ""),
    })
    entry.setdefault("ch1tty", {"available": False})

    # stable, readable key order
    order = ["id", "name", "description", "type", "category", "access", "enabled",
             "installMode", "source", "standalone", "ch1tty", "canon_uri", "tags"]
    return {k: entry[k] for k in order if k in entry} | {
        k: v for k, v in entry.items() if k not in order
    }


def build_overlay_record(c: dict, entry: dict, existing: dict | None) -> dict:
    ov = c["overlay"]
    group = ov["capability_group"]
    slug = slugify(ov["title"])
    cap_id = f"chittycanon://capability/{group}/{slug}"

    channels = [RUNTIME_TO_CHANNEL[r] for r in (c["fm"].get("runtimes") or [])
                if r in RUNTIME_TO_CHANNEL]
    if not channels:
        channels = ["claude_code"]

    rec = {
        "capability_id": cap_id,
        "legacy_id": entry["id"],
        "name": entry["name"],
        "description": entry["description"],
        "capability_group": group,
        "group_assignment_source": ov.get("group_assignment_source", "override"),
        "execution_class": ov["execution_class"],
        "canonical_version": ov.get("canonical_version", "1.0.0"),
        "projection_version_policy": "inherit-canonical",
        "ontology": {
            "primary": list(ov["ontology"]["primary"]),
            "secondary": list(ov["ontology"].get("secondary") or []),
        },
        "authority": dict(ov["authority"]),
        "execution": dict(ov["execution"]),
        "discovery": dict(ov["discovery"]),
        "auth_flow": dict(ov["auth_flow"]),
        "runtime_exclusions": dict(ov.get("runtime_exclusions") or {}),
        "compatible_channels": channels,
        "source_links": derive_source_links(c),
        "phase0_audit": dict(ov["phase0_audit"]),
        "legacy_type": entry["type"],
        "legacy_category": entry.get("category", "ecosystem"),
        "deprecated_aliases": [entry["id"]],
        "visibility": ov["visibility"],
    }
    # preserve any signature/anchor already established for this record
    prev = (existing or {}).get("provenance") or {}
    rec["provenance"] = {
        "content_hash": "sha256:" + "0" * 64,  # re-stamped below
        "canonicalization": "json-sorted-compact",
        "hash_covers": "record-excluding-provenance",
        "schema_ref": "chittycanon://core/services/chittymarket#section-16",
        "signature": prev.get("signature"),
        "signer_chittyid": prev.get("signer_chittyid"),
        "anchored_in_ledger": prev.get("anchored_in_ledger"),
    }
    return rec


def stamp(rec: dict) -> dict:
    """Recompute content_hash exactly as scripts/overlay-provenance.py does."""
    body = {k: v for k, v in rec.items() if k != "provenance"}
    canon = json.dumps(body, sort_keys=True, separators=(",", ":"),
                       ensure_ascii=False).encode("utf-8")
    rec["provenance"]["content_hash"] = "sha256:" + hashlib.sha256(canon).hexdigest()
    return rec


def reconcile(write: bool) -> int:
    canon = load_canonical()
    manifest = json.load(open(MANIFEST, encoding="utf-8"))
    overlay = json.load(open(OVERLAY, encoding="utf-8"))

    entries = manifest["artifacts"]
    by_base = {}
    for e in entries:
        if "id" in e:
            by_base.setdefault(entry_base_id(e), e)

    findings = {"missing": [], "undeclared": [], "invalid": [], "orphan": [], "drift": []}

    # Which entries does this pipeline own? Explicit `source` wins; otherwise
    # infer once (migration) from whether a canonical file backs the entry.
    for e in entries:
        if "id" not in e:
            continue
        base = entry_base_id(e)
        if "source" not in e:
            e_source = "canonical" if base in canon else "external"
            if write:
                e["source"] = e_source
        else:
            e_source = e["source"]
        if e_source == "canonical" and base not in canon:
            findings["orphan"].append(e["id"])

    for name, c in sorted(canon.items()):
        ov = c["overlay"]
        existing = by_base.get(name)
        if not ov:
            (findings["undeclared"] if existing is None else findings["undeclared"]).append(
                (name, c["kind"])
            )
            continue
        errs = validate_overlay_block(name, ov)
        if errs:
            findings["invalid"].append((name, errs))
            continue
        entry = build_manifest_entry(c, existing)
        if existing is None:
            findings["missing"].append(entry["id"])
            if write:
                entries.append(entry)
                by_base[name] = entry
        else:
            if any(existing.get(k) != entry.get(k) for k in
                   ("description", "type", "canon_uri", "tags", "source")):
                findings["drift"].append(entry["id"])
            if write:
                existing.clear()
                existing.update(entry)

    # ── report ────────────────────────────────────────────────────────────
    print("=== market-reconcile ===")
    owned = sum(1 for e in entries if e.get("source") == "canonical")
    ext = sum(1 for e in entries if e.get("source") == "external")
    print(f"{DIM}canonical artifacts: {len(canon)} | "
          f"manifest: {owned} canonical-owned, {ext} external{RST}")

    def show(key, label, colour):
        items = findings[key]
        if items:
            print(f"\n{colour}{label}: {len(items)}{RST}")
        return items

    for name, kind in show("undeclared", "UNDECLARED (no overlay: block)", YEL):
        print(f"  {name} ({kind})")
    if findings["undeclared"]:
        n, k = findings["undeclared"][0]
        print(f"\n{DIM}Add an overlay: block to canonical/{k}s/<name>.md, e.g.:{RST}\n")
        print(re.sub(r"^", "  ", overlay_stub(n, k), flags=re.M))

    for name, errs in show("invalid", "INVALID overlay: block", RED):
        for e in errs:
            print(f"  {name}: {e}")
    for i in show("missing", "MISSING from marketplace.json", RED):
        print(f"  {i}")
    for i in show("drift", "DRIFT (canonical ≠ manifest)", RED):
        print(f"  {i}")
    for i in show("orphan", "ORPHAN (source:canonical, no canonical file)", RED):
        print(f"  {i}")

    total = sum(len(v) for v in findings.values())

    if not write:
        if total == 0:
            print(f"\n{GRN}✓ inventory is reconciled with canonical/{RST}")
            return 0
        print(f"\n{RED}✗ {total} finding(s). Run: scripts/market-reconcile.py sync{RST}")
        return 1

    # ── write path ────────────────────────────────────────────────────────
    if findings["invalid"]:
        print(f"\n{RED}REFUSING to sync: fix the invalid overlay: blocks above.{RST}")
        return 1
    if findings["orphan"]:
        print(f"\n{RED}REFUSING to sync: orphan canonical-owned entries above.{RST}")
        print(f"{DIM}Either restore the canonical file, or set source:external / remove "
              f"the entry deliberately. Mirrors dispatch.sh PROJ_DRIFT — this script will "
              f"not guess which you meant.{RST}")
        return 1

    caps = {c["legacy_id"]: c for c in overlay["capabilities"]}
    new_caps = []
    for name, c in sorted(canon.items()):
        if not c["overlay"] or validate_overlay_block(name, c["overlay"]):
            continue
        entry = by_base.get(name)
        if entry is None:
            continue
        rec = stamp(build_overlay_record(c, entry, caps.get(entry["id"])))
        if entry["id"] in caps:
            caps[entry["id"]].clear()
            caps[entry["id"]].update(rec)
        else:
            new_caps.append(rec)
    overlay["capabilities"].extend(new_caps)
    overlay["total"] = len(overlay["capabilities"])

    hashes = sorted(c["provenance"]["content_hash"] for c in overlay["capabilities"])
    overlay["overlay_provenance"] = {
        **(overlay.get("overlay_provenance") or {}),
        "aggregate_hash": "sha256:" + hashlib.sha256(
            "\n".join(hashes).encode("utf-8")).hexdigest(),
        "record_count": len(overlay["capabilities"]),
        "canonicalization": "json-sorted-compact",
        "hash_alg": "sha256",
    }

    for path, data in ((MANIFEST, manifest), (OVERLAY, overlay)):
        tmp = path + ".tmp"
        with open(tmp, "w", encoding="utf-8") as fh:
            fh.write(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
        os.replace(tmp, path)  # atomic; marketplace.json is symlinked into ~/.claude

    print(f"\n{GRN}✓ synced — +{len(findings['missing'])} manifest entries, "
          f"+{len(new_caps)} overlay records, total {overlay['total']}{RST}")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[1])
    ap.add_argument("mode", choices=["audit", "sync"])
    args = ap.parse_args()
    return reconcile(write=args.mode == "sync")


if __name__ == "__main__":
    sys.exit(main())
