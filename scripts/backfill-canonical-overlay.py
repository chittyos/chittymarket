#!/usr/bin/env python3
"""HISTORICAL MIGRATION ONLY: exact backfill of published Market policy.

This script is retained as a migration receipt and recovery aid. It is not part
of steady-state generation or CI authority. `scripts/market-reconcile.py` owns
ongoing materialization from canonical + marketplace sources.

This migration removes a circular dependency: published Market-owned canonical
definitions currently rely on capabilities.generated.json for their established
capability binding and governance metadata.

The script NEVER derives identity or governance from names, groups, tags, or
categories. It only transcribes an exact 1:1 record when all three exist:

  canonical/<kind>/<name>.md
  marketplace.json artifact with the current legacy id
  capabilities.generated.json record with that same legacy id

Aliases, renamed legacy ids, and unpublished canonicals are HOLD and are never
rewritten by this script.

Usage:
    python3 scripts/backfill-canonical-overlay.py audit
    python3 scripts/backfill-canonical-overlay.py write
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("ERROR: PyYAML required: pip install pyyaml")

ROOT = Path(__file__).resolve().parent.parent
CANONICAL = ROOT / "canonical"
MANIFEST = ROOT / "marketplace.json"
OVERLAY = ROOT / "capabilities.generated.json"

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
CAP_RE = re.compile(r"^chittycanon://capability/[a-z][a-z0-9-]*/[a-z0-9][a-z0-9-]*$")

# Literal governance/policy fields copied from the established overlay.
OVERLAY_FIELDS = (
    "capability_group",
    "group_assignment_source",
    "execution_class",
    "canonical_version",
    "projection_version_policy",
    "ontology",
    "authority",
    "execution",
    "discovery",
    "auth_flow",
    "runtime_exclusions",
    "phase0_audit",
    "legacy_category",
    "deprecated_aliases",
    "visibility",
    "compatible_channels",
    "source_links",
)


def load_json(path: Path):
    with path.open(encoding="utf-8") as fh:
        return json.load(fh)


def split_frontmatter(src: str):
    match = re.match(r"^(---\r?\n)(.*?)(\r?\n---\r?\n)(.*)$", src, re.DOTALL)
    if not match:
        return None
    return match.group(1), match.group(2), match.group(3), match.group(4)


def current_claim(fm: dict):
    values = []
    for key in ("canonical_capability_ref", "capability_id", "capability"):
        if key in fm:
            values.append((key, str(fm[key]).strip()))
    return values


def canonical_items():
    for dirname, kind in DIR_KIND.items():
        folder = CANONICAL / dirname
        if not folder.exists():
            continue
        for path in sorted(folder.glob("*.md")):
            src = path.read_text(encoding="utf-8")
            parts = split_frontmatter(src)
            if not parts:
                yield {
                    "path": path,
                    "error": "missing YAML frontmatter",
                }
                continue
            fm = yaml.safe_load(parts[1]) or {}
            if not isinstance(fm, dict):
                yield {"path": path, "error": "frontmatter is not a mapping"}
                continue
            name = str(fm.get("name") or path.stem)
            legacy_id = PREFIX[kind] + name
            yield {
                "path": path,
                "src": src,
                "parts": parts,
                "fm": fm,
                "name": name,
                "kind": kind,
                "legacy_id": legacy_id,
            }


def migration_block(rec: dict, artifact: dict) -> dict:
    cap = rec.get("capability_id")
    if not isinstance(cap, str) or not CAP_RE.match(cap):
        raise ValueError(f"invalid established capability_id {cap!r}")

    block = {"title": rec.get("name")}
    for field in OVERLAY_FIELDS:
        if field not in rec:
            raise ValueError(f"overlay record missing {field}")
        block[field] = rec[field]

    access = artifact.get("access")
    if access not in {"read", "write", "readwrite"}:
        raise ValueError(f"marketplace access must be read|write|readwrite, got {access!r}")
    block["access"] = access
    return {
        "canonical_capability_ref": cap,
        "overlay": block,
    }


def render_backfill(meta: dict) -> str:
    return yaml.safe_dump(
        meta,
        sort_keys=False,
        default_flow_style=False,
        allow_unicode=True,
        width=100000,
    ).rstrip()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("audit", "write"))
    args = parser.parse_args()

    manifest = load_json(MANIFEST)
    overlay = load_json(OVERLAY)
    artifacts = {
        x["id"]: x
        for x in manifest.get("artifacts", [])
        if isinstance(x, dict) and x.get("id")
    }
    capabilities = {
        x["legacy_id"]: x
        for x in overlay.get("capabilities", [])
        if isinstance(x, dict) and x.get("legacy_id")
    }

    exact = []
    additive = []
    holds = []
    errors = []
    already = []

    for item in canonical_items():
        if item.get("error"):
            errors.append((str(item["path"].relative_to(ROOT)), item["error"]))
            continue

        lid = item["legacy_id"]
        artifact = artifacts.get(lid)
        rec = capabilities.get(lid)

        # Only exact current-id matches are eligible. Alias/rename resolution is
        # a separate governed migration and must not be guessed here.
        if artifact is None or rec is None:
            holds.append((item["name"], lid, "no exact marketplace+overlay pair"))
            continue

        try:
            wanted = migration_block(rec, artifact)
        except ValueError as exc:
            errors.append((item["name"], str(exc)))
            continue

        claims = current_claim(item["fm"])
        existing_overlay = item["fm"].get("overlay")

        if claims or existing_overlay is not None:
            explicit = [value for _, value in claims if CAP_RE.match(value)]
            invalid = [(key, value) for key, value in claims if not CAP_RE.match(value)]
            if invalid:
                errors.append((item["name"], f"invalid existing identity claim: {invalid}"))
                continue
            if explicit and any(value != wanted["canonical_capability_ref"] for value in explicit):
                errors.append(
                    (
                        item["name"],
                        f"existing identity {explicit!r} conflicts with established "
                        f"{wanted['canonical_capability_ref']!r}",
                    )
                )
                continue
            if existing_overlay is not None:
                unexpected = {
                    key: (value, wanted["overlay"].get(key))
                    for key, value in existing_overlay.items()
                    if key not in wanted["overlay"] or value != wanted["overlay"].get(key)
                }
                if unexpected:
                    errors.append((item["name"], f"existing overlay values differ from established record: {unexpected}"))
                    continue
                missing = [key for key in wanted["overlay"] if key not in existing_overlay]
                permitted = {"compatible_channels", "source_links"}
                if set(missing) - permitted:
                    errors.append((item["name"], f"existing overlay missing non-additive established fields: {missing}"))
                    continue
                if missing:
                    additive.append((item, wanted, missing))
                    continue
            already.append((item["name"], lid))
            continue

        exact.append((item, wanted))

    print("=== canonical overlay backfill ===")
    print(f"exact candidates: {len(exact)}")
    print(f"additive candidates: {len(additive)}")
    print(f"already backfilled: {len(already)}")
    print(f"holds (unmatched/alias/unpublished): {len(holds)}")
    print(f"errors: {len(errors)}")

    for name, lid, reason in holds:
        print(f"HOLD  {name}: {lid} — {reason}")
    for name, reason in errors:
        print(f"ERROR {name}: {reason}")

    if errors:
        return 1

    if args.mode == "audit":
        for item, wanted in exact:
            print(
                f"BACKFILL {item['path'].relative_to(ROOT)} -> "
                f"{wanted['canonical_capability_ref']}"
            )
        for item, wanted, missing in additive:
            print(f"BACKFILL_FIELDS {item['path'].relative_to(ROOT)} -> {', '.join(missing)}")
        return 0

    for item, wanted in exact:
        open_delim, fm_text, close_delim, body = item["parts"]
        addition = render_backfill(wanted)
        new_fm = fm_text.rstrip() + "\n" + addition
        item["path"].write_text(
            open_delim + new_fm + close_delim + body,
            encoding="utf-8",
        )
        print(f"WROTE {item['path'].relative_to(ROOT)}")

    for item, wanted, missing in additive:
        open_delim, fm_text, close_delim, body = item["parts"]
        addition = yaml.safe_dump(
            {key: wanted["overlay"][key] for key in missing},
            sort_keys=False,
            default_flow_style=False,
            allow_unicode=True,
            width=100000,
        ).rstrip()
        indented = "\n".join("  " + line for line in addition.splitlines())
        new_fm = fm_text.rstrip() + "\n" + indented
        item["path"].write_text(
            open_delim + new_fm + close_delim + body,
            encoding="utf-8",
        )
        print(f"WROTE_FIELDS {item['path'].relative_to(ROOT)}: {', '.join(missing)}")

    print(f"wrote {len(exact)} full definition(s) + {len(additive)} additive definition(s); HOLDs unchanged")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
