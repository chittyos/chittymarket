#!/usr/bin/env python3
"""Batch audit capability artifacts.

Input: JSON array of artifact objects.
Output: JSON object containing results and rollups.
"""
from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from typing import Any, Dict, List

from audit_artifact import audit


def load_items(path: str | None) -> List[Dict[str, Any]]:
    raw = sys.stdin.read() if not path or path == "-" else open(path, "r", encoding="utf-8").read()
    data = json.loads(raw)
    if not isinstance(data, list):
        raise SystemExit("input must be a JSON array")
    for index, item in enumerate(data):
        if not isinstance(item, dict):
            raise SystemExit(f"item {index} is not a JSON object")
    return data


def summarize(results: List[Dict[str, Any]]) -> Dict[str, Any]:
    dispositions = Counter(r["decision_log"]["decision"] for r in results)
    risks = Counter(r["decision_log"]["evidentiary_risk"] for r in results)
    footprints = Counter(r["decision_log"]["environmental_footprint"] for r in results)
    blocked = [r for r in results if r.get("missing_evidence")]
    return {
        "total": len(results),
        "dispositions": dict(sorted(dispositions.items())),
        "evidentiary_risks": dict(sorted(risks.items())),
        "environmental_footprints": dict(sorted(footprints.items())),
        "blocked_count": len(blocked),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Batch audit capability artifacts.")
    parser.add_argument("--input", "-i", help="Path to JSON array. Use '-' or omit for stdin.")
    parser.add_argument("--output", "-o", help="Write results to file instead of stdout.")
    parser.add_argument("--pretty", action="store_true", help="Pretty-print JSON output.")
    args = parser.parse_args()
    results = [audit(item) for item in load_items(args.input)]
    payload = {"summary": summarize(results), "results": results}
    rendered = json.dumps(payload, indent=2 if args.pretty else None, sort_keys=args.pretty)
    if args.output:
        with open(args.output, "w", encoding="utf-8") as handle:
            handle.write(rendered + "\n")
    else:
        print(rendered)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
