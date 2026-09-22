#!/usr/bin/env python3
"""Validate ChittyMarket agent projection identity and optionally reconcile live index.

Static mode is CI-safe and reads only repository state. Live mode additionally
GETs the orchestrator agent index and reports exact/local-only/live-only drift;
it never performs registration or mutation.
"""
from __future__ import annotations

import argparse
import difflib
import json
import re
import sys
import urllib.request
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
CANONICAL = ROOT / "canonical" / "agents"
OWNER = "chittycanon://core/services/chittymarket"
FAMILY = "ChittyAgent"
PROJECTION_RE = re.compile(r"^chittyagent-[a-z0-9][a-z0-9-]*$")
LIVE_URL = "https://agent.chitty.cc/orchestrator/api/v1/registry/agents"

sys.path.insert(0, str(ROOT / "plugins/chittyagent-dispatch/scripts/lib"))
from resolve_output import resolve  # noqa: E402


def frontmatter(path: Path) -> dict:
    src = path.read_text(encoding="utf-8")
    m = re.match(r"^---\n(.*?)\n---(?:\n|$)", src, re.DOTALL)
    if not m:
        raise ValueError(f"{path}: missing YAML frontmatter")
    data = yaml.safe_load(m.group(1)) or {}
    if not isinstance(data, dict):
        raise ValueError(f"{path}: frontmatter is not a mapping")
    return data


def projection_metadata(path: Path) -> dict:
    src = path.read_text(encoding="utf-8")
    if src.startswith("---\n"):
        return frontmatter(path)
    data = yaml.safe_load(src) or {}
    if not isinstance(data, dict):
        raise ValueError(f"{path}: projection is not a mapping")
    return data


def canonical_agents():
    for path in sorted(CANONICAL.glob("*.md")):
        fm = frontmatter(path)
        yield path, fm


def static_reconcile() -> tuple[dict, list[str]]:
    errors: list[str] = []
    agents = []
    seen_projection: dict[str, str] = {}
    pointer_aliases = []

    for path, fm in canonical_agents():
        name = str(fm.get("name") or "")
        projection_id = str(fm.get("projection_id") or "")
        owner = str(fm.get("projection_owner") or "")
        family = str(fm.get("projection_family") or "")
        aliases = [str(x) for x in (fm.get("deprecated_aliases") or [])]
        plugin = str(fm.get("plugin") or "")
        runtimes = [str(x) for x in (fm.get("runtimes") or [])]

        if path.stem != name:
            errors.append(f"{path}: filename stem {path.stem!r} != declared name {name!r}")
        if not PROJECTION_RE.match(projection_id):
            errors.append(f"{path}: projection_id {projection_id!r} is not chittyagent-<domain>")
        if owner != OWNER:
            errors.append(f"{path}: projection_owner {owner!r} != {OWNER!r}")
        if family != FAMILY:
            errors.append(f"{path}: projection_family {family!r} != {FAMILY!r}")
        if name != projection_id and name not in aliases:
            errors.append(f"{path}: persona/address mismatch requires deprecated alias {name!r}")
        previous = seen_projection.get(projection_id)
        if projection_id and previous:
            errors.append(f"duplicate projection_id {projection_id!r}: {previous}, {path}")
        elif projection_id:
            seen_projection[projection_id] = str(path.relative_to(ROOT))

        projections = []
        for runtime in runtimes:
            try:
                out, _adapter = resolve(str(ROOT), plugin, name, "agent", runtime)
            except KeyError:
                errors.append(f"{path}: unknown agent runtime {runtime!r}")
                continue
            out_path = Path(out)
            if not out_path.exists():
                errors.append(f"{path}: missing {runtime} projection {out_path.relative_to(ROOT)}")
                continue
            try:
                pfm = projection_metadata(out_path)
            except Exception as exc:
                errors.append(str(exc))
                continue
            for key, expected in (
                ("projection_id", projection_id),
                ("projection_owner", owner),
                ("projection_family", family),
            ):
                if str(pfm.get(key) or "") != expected:
                    errors.append(
                        f"{out_path.relative_to(ROOT)}: {key}={pfm.get(key)!r} != canonical {expected!r}"
                    )
            if name != projection_id and name not in [str(x) for x in (pfm.get("deprecated_aliases") or [])]:
                errors.append(
                    f"{out_path.relative_to(ROOT)}: missing deprecated persona alias {name!r}"
                )
            projections.append(str(out_path.relative_to(ROOT)))

        agents.append(
            {
                "canonical": str(path.relative_to(ROOT)),
                "name": name,
                "projection_id": projection_id,
                "projection_owner": owner,
                "projection_family": family,
                "deprecated_aliases": aliases,
                "runtimes": runtimes,
                "projections": projections,
            }
        )

    # Detect duplicate/mismatched plugin agent declarations. Market-generated
    # files should be one-name/one-file. Thin pointers owned by another repo may
    # intentionally use a Market discovery filename that differs from the
    # upstream declared persona; require explicit pointer ownership metadata.
    declared: dict[str, list[str]] = {}
    for path in sorted((ROOT / "plugins").glob("*/agents/*.md")):
        try:
            fm = frontmatter(path)
        except Exception as exc:
            errors.append(str(exc))
            continue
        name = str(fm.get("name") or "")
        if not name:
            errors.append(f"{path.relative_to(ROOT)}: missing declared agent name")
            continue
        declared.setdefault(name, []).append(str(path.relative_to(ROOT)))
        if path.stem != name:
            if fm.get("owner_repo") and fm.get("prompt_source"):
                pointer_aliases.append(
                    {
                        "path": str(path.relative_to(ROOT)),
                        "declared_name": name,
                        "owner_repo": str(fm.get("owner_repo")),
                        "prompt_source": str(fm.get("prompt_source")),
                    }
                )
            else:
                errors.append(
                    f"{path.relative_to(ROOT)}: filename stem {path.stem!r} != declared name {name!r} without external pointer ownership"
                )
    for name, paths in sorted(declared.items()):
        if len(paths) > 1:
            errors.append(f"duplicate projected agent name {name!r}: {paths}")

    return {
        "agents": agents,
        "projection_ids": sorted(seen_projection),
        "pointer_aliases": pointer_aliases,
    }, errors


def live_reconcile(static: dict, url: str) -> tuple[dict, list[str]]:
    errors: list[str] = []
    req = urllib.request.Request(url, headers={"User-Agent": "chittymarket-agent-identity/1.0"})
    with urllib.request.urlopen(req, timeout=10) as response:
        payload = json.load(response)
    live = payload.get("agents") if isinstance(payload, dict) else None
    if not isinstance(live, list):
        raise ValueError("live orchestrator response does not contain agents[]")

    live_names = []
    live_ids = []
    descriptions_missing = []
    for row in live:
        aid = str(row.get("id") or "")
        name = str(row.get("name") or "")
        domain = str(row.get("domain") or "")
        expected_name = f"chittyagent-{aid}" if aid else ""
        expected_domain = f"{aid}.agent.chitty.cc" if aid else ""
        if not aid or not name:
            errors.append(f"live row missing id/name: {row!r}")
            continue
        if name != expected_name:
            errors.append(f"live {aid}: name {name!r} != {expected_name!r}")
        if domain != expected_domain:
            errors.append(f"live {aid}: domain {domain!r} != {expected_domain!r}")
        if not PROJECTION_RE.match(name):
            errors.append(f"live {aid}: nonconforming name {name!r}")
        if not str(row.get("description") or "").strip():
            descriptions_missing.append(name)
        live_ids.append(aid)
        live_names.append(name)

    dup_names = sorted({x for x in live_names if live_names.count(x) > 1})
    dup_ids = sorted({x for x in live_ids if live_ids.count(x) > 1})
    if dup_names:
        errors.append(f"live duplicate names: {dup_names}")
    if dup_ids:
        errors.append(f"live duplicate ids: {dup_ids}")

    canonical = set(static["projection_ids"])
    live_set = set(live_names)
    canonical_only = sorted(canonical - live_set)
    live_only = sorted(live_set - canonical)
    near = {}
    for name in canonical_only:
        matches = difflib.get_close_matches(name, live_only, n=3, cutoff=0.78)
        if matches:
            near[name] = matches

    return {
        "url": url,
        "live_count": len(live),
        "exact": sorted(canonical & live_set),
        "canonical_only": canonical_only,
        "live_only": live_only,
        "near_collisions": near,
        "descriptions_missing": sorted(descriptions_missing),
    }, errors


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--live", action="store_true", help="compare read-only against live orchestrator index")
    ap.add_argument("--live-url", default=LIVE_URL)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    try:
        static, errors = static_reconcile()
        live = None
        if args.live:
            live, live_errors = live_reconcile(static, args.live_url)
            errors.extend(live_errors)
    except Exception as exc:
        print(f"agent identity reconcile hard error: {exc}", file=sys.stderr)
        return 2

    result = {"static": static, "live": live, "errors": errors}
    if args.json:
        print(json.dumps(result, indent=2, sort_keys=True))
    else:
        print("=== ChittyMarket agent identity reconcile ===")
        print(f"canonical agents: {len(static['agents'])}")
        print(f"unique projection ids: {len(static['projection_ids'])}")
        print(f"external pointer aliases: {len(static['pointer_aliases'])}")
        if live is not None:
            print(f"live agents: {live['live_count']}")
            print(f"exact live matches: {len(live['exact'])}")
            print(f"canonical-only: {len(live['canonical_only'])} {live['canonical_only']}")
            print(f"live-only: {len(live['live_only'])} {live['live_only']}")
            print(f"near collisions: {live['near_collisions']}")
            print(f"live missing descriptions: {len(live['descriptions_missing'])}")
        if errors:
            print(f"ERRORS ({len(errors)}):")
            for error in errors:
                print(f"  - {error}")
        else:
            print("PASS: static projection identity is internally consistent")

    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
