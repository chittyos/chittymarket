#!/usr/bin/env python3
"""Generate deterministic materialized capability views from capabilities.generated.json.

The view schemas already exist. This script makes their documented generator executable
and idempotent. By default it preserves the committed generated_at value; pass
--generated-at YYYY-MM-DD when intentionally refreshing the materialized views.
"""
from __future__ import annotations

import argparse
import json
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CAP_FILE = ROOT / "capabilities.generated.json"
VIEWS_DIR = ROOT / "views"
VIEW_NAMES = ("by-job", "by-channel", "by-context-cost", "by-authority")
CHANNELS = (
    "claude_code",
    "claude_desktop",
    "codex",
    "openclaw",
    "chatgpt",
    "claude_ai",
    "ch1tty",
)


def existing_generated_at() -> str:
    dates = set()
    for name in VIEW_NAMES:
        path = VIEWS_DIR / f"{name}.json"
        if not path.exists():
            continue
        try:
            value = json.loads(path.read_text(encoding="utf-8")).get("generated_at")
        except (json.JSONDecodeError, OSError):
            continue
        if value:
            dates.add(str(value))
    if len(dates) == 1:
        return dates.pop()
    if len(dates) > 1:
        raise SystemExit(
            "materialized views disagree on generated_at; pass --generated-at explicitly"
        )
    raise SystemExit("no existing generated_at found; pass --generated-at explicitly")


def compact_summary(cap: dict) -> dict:
    return {
        "id": cap.get("capability_id", ""),
        "name": cap.get("name", ""),
        "group": cap.get("capability_group", ""),
        "execution_class": cap.get("execution_class", ""),
        "visibility": cap.get("visibility", ""),
        "group_assignment_source": cap.get("group_assignment_source", "unknown"),
    }


def job_summary(cap: dict) -> dict:
    return {
        "capability_id": cap.get("capability_id", ""),
        "name": cap.get("name", ""),
        "execution_class": cap.get("execution_class", ""),
        "visibility": cap.get("visibility", ""),
        "advisory_disposition": (cap.get("phase0_audit") or {}).get(
            "advisory_disposition", ""
        ),
        "group_assignment_source": cap.get("group_assignment_source", "unknown"),
    }


def sorted_groups(grouped: dict[str, list[dict]]) -> dict[str, list[dict]]:
    return {
        key: sorted(grouped[key], key=lambda item: (item.get("name", ""), item.get("id", item.get("capability_id", ""))))
        for key in sorted(grouped)
    }


def write_view(name: str, description: str, grouped: dict[str, list[dict]], generated_at: str, *, counts_first: bool) -> None:
    groups = sorted_groups(grouped)
    counts = {key: len(items) for key, items in groups.items()}
    out = {
        "version": "1.1.0",
        "generated_at": generated_at,
        "view": name,
        "description": description,
    }
    if counts_first:
        out["counts"] = counts
        out["groups"] = groups
    else:
        out["groups"] = groups
        out["counts"] = counts
    (VIEWS_DIR / f"{name}.json").write_text(
        json.dumps(out, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--generated-at", help="Explicit provenance date (YYYY-MM-DD)")
    args = parser.parse_args()

    data = json.loads(CAP_FILE.read_text(encoding="utf-8"))
    caps = data.get("capabilities", [])
    if not isinstance(caps, list):
        raise SystemExit("capabilities.generated.json: capabilities must be a list")
    generated_at = args.generated_at or existing_generated_at()

    by_job: dict[str, list[dict]] = defaultdict(list)
    by_channel: dict[str, list[dict]] = defaultdict(list)
    by_cost: dict[str, list[dict]] = defaultdict(list)
    by_auth: dict[str, list[dict]] = defaultdict(list)

    for cap in caps:
        by_job[cap.get("capability_group", "unknown")].append(job_summary(cap))

        summary = compact_summary(cap)
        exclusions = cap.get("runtime_exclusions") or {}
        for channel in CHANNELS:
            exclusion = exclusions.get(channel)
            include = channel not in exclusions or (
                isinstance(exclusion, list)
                and exclusion == ["write"]
            )
            if include:
                by_channel[channel].append(summary)

        cost = (cap.get("execution") or {}).get("context_cost", "medium")
        by_cost[cost].append(summary)

        authority = cap.get("authority") or {}
        flags = [
            key
            for key, value in authority.items()
            if value is True and key != "requires_chittyid"
        ]
        if not flags:
            by_auth["requires_chittyid_only (default)"].append(summary)
        for flag in flags:
            by_auth[flag].append(summary)

    VIEWS_DIR.mkdir(parents=True, exist_ok=True)
    write_view("by-job", "Capabilities grouped by JTBD (bare names)", by_job, generated_at, counts_first=False)
    write_view("by-channel", "Capabilities grouped by supported channel", by_channel, generated_at, counts_first=True)
    write_view("by-context-cost", "Capabilities grouped by execution context cost", by_cost, generated_at, counts_first=True)
    write_view("by-authority", "Capabilities grouped by required authority scope", by_auth, generated_at, counts_first=True)

    print(f"Generated 4 capability views from {len(caps)} capabilities @ {generated_at}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
