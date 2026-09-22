#!/usr/bin/env python3
"""Durable dispatch/verification state for ChittyMarket projections.

The same state file records separate truths:

- dispatch: a projection was rendered and written.
- verification.projection: the repo-level projection audit passed/failed.
- verification.runtime: a native runtime/client verification passed/failed.

Projection verification MUST NOT set runtime verification.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path


def load_json(path: Path):
    with path.open(encoding="utf-8") as fh:
        return json.load(fh)


def write_json(path: Path, data) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    tmp.replace(path)


def dispatch_state(canonical_sha: str, targets: dict, projected_at: str) -> dict:
    """Create a state record where dispatch succeeded but verification is pending."""
    return {
        # Legacy compatibility while audit/reconcile migrate to dispatch.*.
        "canonical_sha": canonical_sha,
        "targets": targets,
        "dispatch": {
            "status": "projected",
            "projected_at": projected_at,
            "canonical_sha": canonical_sha,
            "targets": targets,
        },
        "verification": {
            "projection": {
                "status": "pending",
                "verified_at": None,
                "method": "dispatch-audit",
                "findings": [],
            },
            "runtime": {
                "status": "not_run",
                "verified_at": None,
                "method": None,
                "targets": {},
            },
        },
    }


def record_dispatch(path: Path, canonical_sha: str, targets_raw: str, projected_at: str) -> int:
    try:
        targets = json.loads(targets_raw)
    except json.JSONDecodeError as exc:
        print(f"[dispatch-state] invalid targets JSON: {exc}", file=sys.stderr)
        return 2
    if not isinstance(targets, dict):
        print("[dispatch-state] targets JSON must be an object", file=sys.stderr)
        return 2

    write_json(path, dispatch_state(canonical_sha, targets, projected_at))
    return 0


def normalize_state(state: dict) -> dict:
    """Upgrade a legacy state record in memory without claiming verification."""
    dispatch = state.get("dispatch")
    if not isinstance(dispatch, dict):
        state["dispatch"] = {
            "status": "projected",
            "projected_at": None,
            "canonical_sha": state.get("canonical_sha"),
            "targets": state.get("targets", {}),
        }

    verification = state.get("verification")
    if not isinstance(verification, dict):
        verification = {}
        state["verification"] = verification

    verification.setdefault(
        "projection",
        {
            "status": "pending",
            "verified_at": None,
            "method": "dispatch-audit",
            "findings": [],
        },
    )
    verification.setdefault(
        "runtime",
        {
            "status": "not_run",
            "verified_at": None,
            "method": None,
            "targets": {},
        },
    )
    return state


def compact_finding(finding: dict) -> dict:
    return {
        "class": finding.get("cls"),
        "canonical": finding.get("canonical"),
        "runtime": finding.get("runtime"),
        "detail": finding.get("detail", ""),
    }


def selected_finding(finding: dict, selected: set[str]) -> bool:
    if not selected:
        return True
    canonical = finding.get("canonical")
    if canonical == "-":
        return True
    if not canonical:
        return False
    name = canonical.split("/", 1)[-1]
    return name in selected


def iter_state_files(state_dir: Path):
    for subdir in sorted(p for p in state_dir.iterdir() if p.is_dir()):
        for path in sorted(subdir.glob("*.json")):
            yield subdir.name, path.stem, path


def record_projection_verification(
    state_dir: Path,
    report: dict,
    verified_at: str,
    selected_names: list[str],
) -> int:
    selected = set(selected_names)
    all_findings = report.get("findings", [])
    if not isinstance(all_findings, list):
        print("[dispatch-state] audit report findings must be an array", file=sys.stderr)
        return 2

    scope_findings = [f for f in all_findings if selected_finding(f, selected)]
    global_findings = [f for f in all_findings if f.get("canonical") == "-"]

    global_state = {
        "scope": sorted(selected) if selected else ["all"],
        "projection": {
            "status": "failed" if scope_findings else "passed",
            "verified_at": verified_at,
            "method": "dispatch-audit",
            "summary": report.get("summary", {}),
            "findings": [compact_finding(f) for f in scope_findings],
        },
        "runtime": {
            "status": "not_run",
            "verified_at": None,
            "method": None,
            "targets": {},
        },
    }
    write_json(state_dir / "_verification.json", global_state)

    by_canonical: dict[str, list[dict]] = {}
    for finding in all_findings:
        canonical = finding.get("canonical")
        if canonical and canonical != "-":
            by_canonical.setdefault(canonical, []).append(finding)

    found_names = set()
    failed_names = set()

    for sub, name, path in iter_state_files(state_dir):
        if selected and name not in selected:
            continue
        found_names.add(name)
        state = normalize_state(load_json(path))
        canonical_key = f"{sub}/{name}"
        findings = by_canonical.get(canonical_key, [])

        state["verification"]["projection"] = {
            "status": "failed" if findings else "passed",
            "verified_at": verified_at,
            "method": "dispatch-audit",
            "findings": [compact_finding(f) for f in findings],
        }
        # Explicit invariant: projection audit never upgrades runtime truth.
        state["verification"].setdefault(
            "runtime",
            {
                "status": "not_run",
                "verified_at": None,
                "method": None,
                "targets": {},
            },
        )
        write_json(path, state)

        if findings:
            failed_names.add(name)
            print(
                f"[dispatch] verify {canonical_key}: FAILED ({len(findings)} finding(s))",
                file=sys.stderr,
            )
        else:
            print(
                f"[dispatch] verify {canonical_key}: projection audit passed; "
                "runtime verification remains "
                f"{state['verification']['runtime'].get('status', 'not_run')}"
            )

    missing = selected - found_names
    for name in sorted(missing):
        print(f"[dispatch] verify: no dispatch state for {name}", file=sys.stderr)

    if global_findings:
        print(
            f"[dispatch] verify: {len(global_findings)} global orphan finding(s)",
            file=sys.stderr,
        )

    return 1 if failed_names or missing or global_findings else 0


def main() -> int:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)

    p_dispatch = sub.add_parser("record-dispatch")
    p_dispatch.add_argument("state_path")
    p_dispatch.add_argument("canonical_sha")
    p_dispatch.add_argument("targets_json")
    p_dispatch.add_argument("projected_at")

    p_verify = sub.add_parser("record-projection-verification")
    p_verify.add_argument("state_dir")
    p_verify.add_argument("audit_report_json")
    p_verify.add_argument("verified_at")
    p_verify.add_argument("names", nargs="*")

    args = parser.parse_args()

    if args.command == "record-dispatch":
        return record_dispatch(
            Path(args.state_path),
            args.canonical_sha,
            args.targets_json,
            args.projected_at,
        )

    if args.command == "record-projection-verification":
        try:
            report = json.loads(args.audit_report_json)
        except json.JSONDecodeError as exc:
            print(f"[dispatch-state] invalid audit report JSON: {exc}", file=sys.stderr)
            return 2
        return record_projection_verification(
            Path(args.state_dir),
            report,
            args.verified_at,
            args.names,
        )

    return 2


if __name__ == "__main__":
    raise SystemExit(main())
