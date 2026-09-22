#!/usr/bin/env python3
"""
Identity-first reconciliation for ChittyMarket.

Canonical Market projection definitions feed marketplace.json and
capabilities.generated.json. Identity is never minted from a name, title,
group, slug, or package path.

Resolution:
1. A valid explicit capability reference in canonical frontmatter wins.
2. During migration, an already-published overlay record may supply the
   established binding for that same legacy artifact.
3. A new/unpublished definition without a valid explicit capability
   reference is HOLD and cannot be projected.
4. A conflicting explicit reference is ERROR.
5. A new record also requires an explicit overlay governance block; this
   compiler does not guess risk/auth/policy metadata.

Audit is read-only. Unpublished unresolved definitions are reported as HOLD
but do not fail CI because they are not distributed. Sync is fail-closed.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import os
import re
import sys
from datetime import date
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("ERROR: PyYAML required: pip install pyyaml")

ROOT = Path(os.environ.get("CHITTYMARKET_ROOT", Path(__file__).resolve().parent.parent))
MANIFEST = ROOT / "marketplace.json"
OVERLAY = ROOT / "capabilities.generated.json"
CANONICAL = ROOT / "canonical"

CAP_RE = re.compile(
    r"^chittycanon://capability/(?P<group>[a-z][a-z0-9-]*)/(?P<slug>[a-z0-9][a-z0-9-]*)$"
)

DIR_KIND = {
    "agents": "agent",
    "skills": "skill",
    "commands": "command",
    "mcp": "mcp-server",
    "tools": "tool",
    "hooks": "hook",
}
PREFIX = {
    "agent": "agent-",
    "skill": "skill-",
    "command": "command-",
    "mcp-server": "",
    "tool": "tool-",
    "hook": "hook-",
}
RUNTIME_CHANNEL = {
    "claude-code": "claude_code",
    "claude-skills": "claude_ai",
    "claude-desktop": "claude_desktop",
    "chatgpt-apps": "chatgpt",
    "chatgpt": "chatgpt",
    "codex": "codex",
    "openclaw": "openclaw",
}
NEW_OVERLAY_REQUIRED = {
    "capability_group",
    "execution_class",
    "canonical_version",
    "ontology",
    "authority",
    "execution",
    "discovery",
    "auth_flow",
    "phase0_audit",
    "visibility",
    "legacy_category",
}


def load_json(path: Path):
    with path.open(encoding="utf-8") as fh:
        return json.load(fh)


def write_json(path: Path, data) -> None:
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    tmp.replace(path)


def read_frontmatter(path: Path) -> dict:
    src = path.read_text(encoding="utf-8")
    match = re.match(r"^---\r?\n(.*?)\r?\n---(?:\r?\n|$)", src, re.DOTALL)
    if not match:
        return {}
    data = yaml.safe_load(match.group(1)) or {}
    return data if isinstance(data, dict) else {}


def first_line(value) -> str:
    if not isinstance(value, str):
        return ""
    for para in value.strip().split("\n\n"):
        line = " ".join(para.split())
        if line:
            return line
    return ""


def load_canonical() -> list[dict]:
    out = []
    for dirname, kind in DIR_KIND.items():
        folder = CANONICAL / dirname
        if not folder.exists():
            continue
        for path in sorted(folder.glob("*.md")):
            fm = read_frontmatter(path)
            out.append(
                {
                    "name": str(fm.get("name") or path.stem),
                    "kind": kind,
                    "path": path.relative_to(ROOT).as_posix(),
                    "fm": fm,
                }
            )
    return out


def legacy_id(item: dict) -> str:
    return PREFIX[item["kind"]] + item["name"]


def explicit_identity(fm: dict) -> tuple[str | None, str | None]:
    claims = []
    invalid = []
    for key in ("canonical_capability_ref", "capability_id", "capability"):
        value = fm.get(key)
        if value is None:
            continue
        value = str(value).strip()
        if CAP_RE.match(value):
            claims.append((key, value))
        else:
            invalid.append((key, value))

    unique = {value for _, value in claims}
    if len(unique) > 1:
        detail = ", ".join(f"{key}={value}" for key, value in claims)
        return None, f"conflicting capability identity claims: {detail}"
    if invalid:
        detail = ", ".join(f"{key}={value}" for key, value in invalid)
        if unique:
            return next(iter(unique)), f"non-capability identity field also present: {detail}"
        return None, f"capability field is not a chittycanon://capability/... URI: {detail}"
    return (next(iter(unique)) if unique else None), None


def artifact_index(manifest: dict) -> dict[str, dict]:
    return {x["id"]: x for x in manifest.get("artifacts", []) if isinstance(x, dict) and x.get("id")}


def capability_index(overlay: dict) -> dict[str, dict]:
    return {
        x["legacy_id"]: x
        for x in overlay.get("capabilities", [])
        if isinstance(x, dict) and x.get("legacy_id")
    }


def validate_existing_binding(rec: dict, explicit: str | None, invalid: str | None) -> list[str]:
    errors = []
    cap_id = rec.get("capability_id")
    match = CAP_RE.match(str(cap_id or ""))
    if not match:
        return [f"published overlay has invalid capability_id {cap_id!r}"]
    if invalid:
        errors.append(invalid)
    if explicit and explicit != cap_id:
        errors.append(f"canonical identity {explicit!r} conflicts with published binding {cap_id!r}")
    if rec.get("capability_group") != match.group("group"):
        errors.append(
            f"published capability_group {rec.get('capability_group')!r} conflicts with capability_id group {match.group('group')!r}"
        )
    return errors


def validate_new_overlay(explicit: str, block) -> list[str]:
    if not isinstance(block, dict):
        return ["new projection requires an explicit overlay governance block"]
    missing = sorted(k for k in NEW_OVERLAY_REQUIRED if k not in block)
    if missing:
        return ["overlay block missing: " + ", ".join(missing)]
    match = CAP_RE.match(explicit)
    if block.get("capability_group") != match.group("group"):
        return [
            f"overlay.capability_group {block.get('capability_group')!r} conflicts with canonical identity group {match.group('group')!r}"
        ]
    return []


def channels(fm: dict) -> list[str]:
    out = []
    for runtime in fm.get("runtimes") or []:
        channel = RUNTIME_CHANNEL.get(str(runtime))
        if channel and channel not in out:
            out.append(channel)
    return out or ["claude_code"]


def provenance_hash(rec: dict) -> str:
    body = {k: v for k, v in rec.items() if k != "provenance"}
    raw = json.dumps(body, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    return "sha256:" + hashlib.sha256(raw).hexdigest()


def build_new_overlay(item: dict, explicit: str) -> dict:
    fm = item["fm"]
    block = copy.deepcopy(fm["overlay"])
    title = block.pop("title", None) or item["name"]
    rec = {
        "capability_id": explicit,
        "legacy_id": legacy_id(item),
        "name": title,
        "description": first_line(fm.get("description")) or item["name"],
        "capability_group": block["capability_group"],
        "group_assignment_source": block.pop("group_assignment_source", "override"),
        "execution_class": block["execution_class"],
        "canonical_version": block["canonical_version"],
        "projection_version_policy": block.pop("projection_version_policy", "inherit-canonical"),
        "ontology": block["ontology"],
        "authority": block["authority"],
        "execution": block["execution"],
        "discovery": block["discovery"],
        "auth_flow": block["auth_flow"],
        "runtime_exclusions": block.pop("runtime_exclusions", {}),
        "compatible_channels": channels(fm),
        "source_links": [f"local://{item['path']}"],
        "phase0_audit": block["phase0_audit"],
        "legacy_type": item["kind"],
        "legacy_category": block["legacy_category"],
        "deprecated_aliases": block.pop("deprecated_aliases", [legacy_id(item)]),
        "visibility": block["visibility"],
        "provenance": {
            "content_hash": "",
            "canonicalization": "json-sorted-compact",
            "hash_covers": "record-excluding-provenance",
            "schema_ref": "chittycanon://core/services/chittymarket#section-16",
            "signature": None,
            "signer_chittyid": None,
            "anchored_in_ledger": None,
        },
    }
    rec["provenance"]["content_hash"] = provenance_hash(rec)
    return rec


def build_new_manifest(item: dict, rec: dict) -> dict:
    fm = item["fm"]
    risk = (rec.get("execution") or {}).get("mutation_risk", "medium")
    entry = {
        "id": legacy_id(item),
        "name": rec["name"],
        "description": rec["description"],
        "type": item["kind"],
        "category": rec["legacy_category"],
        "access": "read" if risk == "low" else "readwrite",
        "enabled": False,
        "installMode": "standalone",
        "source": "canonical",
        "standalone": {"available": True, "type": item["kind"]},
        "ch1tty": {"available": False},
        "canon_uri": fm.get("canon_uri") or fm.get("canonical_uri"),
        "capability": rec["capability_id"],
        "tags": list(fm.get("classification") or []),
    }
    return {k: v for k, v in entry.items() if v is not None}


def update_existing(item: dict, entry: dict | None, rec: dict) -> None:
    fm = item["fm"]
    desc = first_line(fm.get("description"))
    if entry is not None:
        if desc:
            entry["description"] = desc
        entry["type"] = item["kind"]
        entry["source"] = "canonical"
        entry["capability"] = rec["capability_id"]
        canon_uri = fm.get("canon_uri") or fm.get("canonical_uri")
        if canon_uri:
            entry["canon_uri"] = canon_uri
        if fm.get("classification"):
            entry["tags"] = list(fm["classification"])

    block = fm.get("overlay")
    if isinstance(block, dict):
        rebuilt = build_new_overlay(item, rec["capability_id"])
        old_prov = rec.get("provenance") or {}
        rebuilt["provenance"]["signature"] = old_prov.get("signature")
        rebuilt["provenance"]["signer_chittyid"] = old_prov.get("signer_chittyid")
        rebuilt["provenance"]["anchored_in_ledger"] = old_prov.get("anchored_in_ledger")
        rebuilt["provenance"]["content_hash"] = provenance_hash(rebuilt)
        rec.clear()
        rec.update(rebuilt)
    elif desc:
        rec["description"] = desc
        rec["source_links"] = [f"local://{item['path']}"]
        if rec.get("provenance"):
            rec["provenance"]["content_hash"] = provenance_hash(rec)


def reconcile(mode: str, selected_name: str | None) -> int:
    manifest = load_json(MANIFEST)
    overlay = load_json(OVERLAY)
    artifacts = artifact_index(manifest)
    caps = capability_index(overlay)

    errors = []
    holds = []
    changes = []
    selected = []

    for item in load_canonical():
        if selected_name and item["name"] != selected_name:
            continue
        selected.append(item["name"])
        lid = legacy_id(item)
        entry = artifacts.get(lid)
        rec = caps.get(lid)
        explicit, invalid = explicit_identity(item["fm"])

        if rec is not None:
            for msg in validate_existing_binding(rec, explicit, invalid):
                errors.append((item["name"], msg))
            if not any(name == item["name"] for name, _ in errors) and mode == "sync":
                update_existing(item, entry, rec)
                changes.append((item["name"], "updated existing projection"))
            continue

        if invalid:
            holds.append((item["name"], invalid))
            continue
        if not explicit:
            holds.append((item["name"], "unpublished definition has no explicit canonical capability identity"))
            continue

        new_errors = validate_new_overlay(explicit, item["fm"].get("overlay"))
        if new_errors:
            for msg in new_errors:
                holds.append((item["name"], msg))
            continue

        if mode == "sync":
            rec = build_new_overlay(item, explicit)
            entry = build_new_manifest(item, rec)
            manifest.setdefault("artifacts", []).append(entry)
            overlay.setdefault("capabilities", []).append(rec)
            artifacts[entry["id"]] = entry
            caps[rec["legacy_id"]] = rec
            changes.append((item["name"], "created disabled projection"))

    if selected_name and not selected:
        errors.append((selected_name, "canonical definition not found"))

    print("=== ChittyMarket identity-first reconcile ===")
    print(f"mode={mode} selected={selected_name or 'all'}")

    if errors:
        print(f"\nERRORS ({len(errors)}):")
        for name, msg in errors:
            print(f"  {name}: {msg}")

    if holds:
        print(f"\nHOLDS ({len(holds)}):")
        for name, msg in holds:
            print(f"  {name}: {msg}")

    if mode == "audit":
        if errors:
            print("\nFAIL: published identity/linkage errors detected.")
            return 1
        print("\nPASS: published projections preserve an established capability binding.")
        if holds:
            print("Unpublished unresolved definitions remain HOLD and cannot be synced.")
        return 0

    if errors or holds:
        print("\nREFUSED: sync is fail-closed until selected identity/policy holds are resolved.")
        return 1

    overlay["total"] = len(overlay.get("capabilities", []))
    overlay["generated_at"] = date.today().isoformat()
    overlay["source"] = (
        "canonical Market projection definitions + marketplace distribution state; "
        "existing governance retained during migration until backfilled into canonical"
    )
    hashes = sorted(
        rec.get("provenance", {}).get("content_hash", "")
        for rec in overlay.get("capabilities", [])
        if rec.get("provenance", {}).get("content_hash")
    )
    overlay["overlay_provenance"] = {
        **(overlay.get("overlay_provenance") or {}),
        "aggregate_hash": "sha256:" + hashlib.sha256("\n".join(hashes).encode("utf-8")).hexdigest(),
        "record_count": len(overlay.get("capabilities", [])),
        "canonicalization": "json-sorted-compact",
        "hash_alg": "sha256",
    }

    write_json(MANIFEST, manifest)
    write_json(OVERLAY, overlay)

    print(f"\nWROTE: {len(changes)} projection change(s)")
    for name, msg in changes:
        print(f"  {name}: {msg}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("audit", "sync"))
    parser.add_argument("--name", help="limit reconciliation to one canonical definition")
    args = parser.parse_args()
    return reconcile(args.mode, args.name)


if __name__ == "__main__":
    raise SystemExit(main())
