#!/usr/bin/env python3
"""Validate a capability-governor decision log JSON object."""
from __future__ import annotations

import argparse
import json
import sys
from typing import Any, Dict, List

REQUIRED = [
    "decision_id", "date", "capability_name", "canonical_id", "source_links",
    "current_state", "decision", "job_to_be_done", "environmental_footprint",
    "evidentiary_risk", "rationale", "duplicates_found", "migration_required",
    "migration_owner", "next_action", "review_date",
]

DECISIONS = {"keep", "promote", "project", "merge", "gateway", "skill", "local-only", "legal-only", "retire", "hold"}
JOBS = {"verify", "collect", "route", "generate", "govern", "operate", "resolve", "remember"}
RISKS = {"none", "low", "medium", "high", "legal-grade"}
FOOTPRINTS = {
    "context-only", "read-only connector", "write-capable", "network-service",
    "filesystem-local", "admin-system", "forensic-legal-grade",
}


def load_json(path: str | None) -> Dict[str, Any]:
    raw = sys.stdin.read() if not path or path == "-" else open(path, "r", encoding="utf-8").read()
    data = json.loads(raw)
    if not isinstance(data, dict):
        raise SystemExit("input must be a JSON object")
    return data


def validate(log: Dict[str, Any]) -> List[str]:
    errors: List[str] = []
    for field in REQUIRED:
        if field not in log:
            errors.append(f"missing required field: {field}")
    if log.get("decision") not in DECISIONS:
        errors.append("decision must be one of: " + ", ".join(sorted(DECISIONS)))
    if log.get("job_to_be_done") not in JOBS:
        errors.append("job_to_be_done must be one of: " + ", ".join(sorted(JOBS)))
    if log.get("evidentiary_risk") not in RISKS:
        errors.append("evidentiary_risk must be one of: " + ", ".join(sorted(RISKS)))
    if log.get("environmental_footprint") not in FOOTPRINTS:
        errors.append("environmental_footprint must be one of: " + ", ".join(sorted(FOOTPRINTS)))
    if not isinstance(log.get("source_links", []), list):
        errors.append("source_links must be a list")
    if not isinstance(log.get("duplicates_found", []), list):
        errors.append("duplicates_found must be a list")
    if log.get("decision") in {"legal-only", "merge", "retire"} and not log.get("source_links"):
        errors.append("high-impact decisions require source_links")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate a capability-governor decision log.")
    parser.add_argument("--input", "-i", help="Path to decision log JSON. Use '-' or omit for stdin.")
    args = parser.parse_args()
    log = load_json(args.input)
    errors = validate(log)
    if errors:
        print(json.dumps({"valid": False, "errors": errors}, indent=2))
        return 1
    print(json.dumps({"valid": True, "errors": []}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
