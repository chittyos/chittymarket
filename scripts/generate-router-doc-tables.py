#!/usr/bin/env python3
"""Render section 7 of the capability-router doc from the generated overlay.

WHY THIS EXISTS

Every table in "7. Phase 0/1 Current Distribution" was hand-maintained, and every one of
them had drifted: the doc claimed 110 capabilities against a live 114, `legal` 6 against
9, `local-lab` 5 against 6, and its own By Context Cost table summed to 104 rather than
to any stated total. The views under views/ did NOT drift, because CI regenerates them
and fails on a diff (.github/workflows/validate-chittymarket.yml, "Capability view
idempotency"). The doc had no such gate, so it was the only unguarded projection of the
overlay — and a reader has no way to tell a stale table from a current one.

So section 7 stops being written and starts being rendered, from the same artifacts the
views are rendered from, under the same idempotency gate.

The counts come from views/*.json wherever a view already publishes them, rather than
being recomputed here from capabilities.generated.json. Recomputing would create a second
implementation of each tally that could disagree with the view while both looked right —
the exact failure this script exists to end. Only the two distributions no view publishes
(execution class, assignment attribution) are counted here, straight off the overlay.

Usage:
  generate-router-doc-tables.py            rewrite the generated block in place
  generate-router-doc-tables.py --check    exit 1 if the block is stale (CI)
"""
from __future__ import annotations

import argparse
import json
import sys
import importlib.util
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CAP_FILE = ROOT / "capabilities.generated.json"
VIEWS_DIR = ROOT / "views"
DOC = ROOT / "docs" / "architecture" / "CHITTYMARKET_CAPABILITY_ROUTER.md"


def _load_view_generator():
    """Load generate-capability-views.py by path; its filename is not an identifier.

    The channel rule is imported from there rather than restated here. Restating it is
    what produced a section 7.3 that contradicted its own Compatible column.
    """
    path = Path(__file__).resolve().parent / "generate-capability-views.py"
    spec = importlib.util.spec_from_file_location("capability_views", path)
    if spec is None or spec.loader is None:
        raise SystemExit(f"cannot load {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


channel_included = _load_view_generator().channel_included

BEGIN = "<!-- BEGIN GENERATED: router-distribution — scripts/generate-router-doc-tables.py -->"
END = "<!-- END GENERATED: router-distribution -->"

# The channels section 7.3 reports, in the order the doc has always used.
CHANNELS = (
    "claude_code",
    "claude_desktop",
    "codex",
    "ch1tty",
    "openclaw",
    "chatgpt",
    "claude_ai",
)


def load_view(name: str) -> dict:
    return json.loads((VIEWS_DIR / f"{name}.json").read_text(encoding="utf-8"))


def pct_table(counts: dict[str, int], total: int, header: str) -> list[str]:
    """A count+percent table, ordered by count descending then name, with a Total row.

    Ties break on name so the output is stable across runs: `market` and `finance` both
    sit at 1, and a Counter's insertion order would otherwise let them swap places and
    show up as spurious drift in the --check gate.
    """
    rows = [f"| {header} | Count | Percent |", "|---|---:|---:|"]
    for key, value in sorted(counts.items(), key=lambda kv: (-kv[1], kv[0])):
        rows.append(f"| {key} | {value} | {value / total * 100:.1f}% |")
    rows.append(f"| Total | {total} | 100% |")
    return rows


def count_table(counts: dict[str, int], header: str, total: int | None = None) -> list[str]:
    rows = [f"| {header} | Count |", "|---|---:|"]
    for key, value in sorted(counts.items(), key=lambda kv: (-kv[1], kv[0])):
        rows.append(f"| {key} | {value} |")
    if total is not None:
        rows.append(f"| Total | {total} |")
    return rows


def render() -> str:
    overlay = json.loads(CAP_FILE.read_text(encoding="utf-8"))
    caps = overlay["capabilities"]
    total = len(caps)
    if overlay.get("total") != total:
        raise SystemExit(
            f"capabilities.generated.json declares total={overlay.get('total')} but holds "
            f"{total} records. Fix the overlay before rendering a doc from it."
        )

    by_job = load_view("by-job")["counts"]
    by_channel = load_view("by-channel")["counts"]
    by_cost = load_view("by-context-cost")["counts"]
    by_authority = load_view("by-authority")["counts"]

    # Cross-check the views against the overlay they are generated from. A view that CI
    # says is idempotent can still be idempotent against a DIFFERENT overlay than the one
    # this doc claims to describe; these two sums are what would catch that.
    if sum(by_job.values()) != total:
        raise SystemExit(
            f"views/by-job.json sums to {sum(by_job.values())}, overlay holds {total}. "
            "Run scripts/generate-capability-views.py first."
        )
    for channel in CHANNELS:
        if channel not in by_channel:
            raise SystemExit(f"views/by-channel.json has no entry for '{channel}'.")

    # Not published by any view: counted here, off the overlay.
    by_class = Counter(c["execution_class"] for c in caps)
    by_source = Counter(c.get("group_assignment_source", "unassigned") for c in caps)

    # Which groups the capabilities excluded from a channel belong to, so 7.3's second
    # column says WHAT is missing rather than only how many.
    #
    # This uses the view generator's own predicate, imported at module load, not a second
    # reading of the overlay. A first draft of this script derived exclusions from
    # `compatible_channels`
    # and produced a table that contradicted itself — `claude_desktop` at 0 excluded while
    # naming four excluded groups — because the view counts by `runtime_exclusions` with
    # write-only exclusions still read-compatible, and `compatible_channels` is a
    # different field that most records do not enumerate.
    def excluded_groups(channel: str) -> str:
        groups = Counter(
            c["capability_group"] for c in caps if not channel_included(c, channel)
        )
        if not groups:
            return "—"
        return "/".join(g for g, _ in sorted(groups.items(), key=lambda kv: (-kv[1], kv[0])))

    # Cross-check: the Excluded column and the Excluded-groups column are two renderings
    # of the same set, so they cannot be allowed to disagree. The contradiction above is
    # what this catches.
    for channel in CHANNELS:
        excluded = sum(1 for c in caps if not channel_included(c, channel))
        if excluded != total - by_channel[channel]:
            raise SystemExit(
                f"'{channel}': views/by-channel.json implies {total - by_channel[channel]} "
                f"excluded, the overlay predicate finds {excluded}. The view and this "
                "script disagree about channel compatibility."
            )

    out: list[str] = [BEGIN, ""]
    out.append(
        f"Current generated overlay: **{total} capabilities**. Every table in this section "
        f"is rendered by `scripts/generate-router-doc-tables.py` from "
        f"`capabilities.generated.json` and `views/*.json`, and CI fails on drift. Do not "
        f"edit these tables by hand — the edit will be overwritten and the gate will catch it."
    )
    out += ["", "## 7.1 By Job", ""]
    out += pct_table(by_job, total, "Group")
    out += ["", "## 7.2 By Execution Class", ""]
    out += count_table(dict(by_class), "Execution Class", total)
    out += [
        "",
        "## 7.3 By Channel Compatibility",
        "",
        "Compatibility follows the router rule used by `views/by-channel.json`: an absent "
        "exclusion means compatible; a write-only exclusion still permits read compatibility.",
        "",
        "| Channel | Compatible | Excluded | Excluded groups |",
        "|---|---:|---:|---|",
    ]
    for channel in CHANNELS:
        compatible = by_channel[channel]
        out.append(
            f"| `{channel}` | {compatible} | {total - compatible} | {excluded_groups(channel)} |"
        )
    out += ["", "## 7.4 By Context Cost", ""]
    out += count_table(by_cost, "Cost", sum(by_cost.values()))
    out += [
        "",
        "## 7.5 By Authority",
        "",
        "Authority flags are non-exclusive — a capability may carry several (a `legal` write "
        f"requires both `requires_case` and `non_repudiation_required`), so this column sums "
        f"to more than {total}.",
        "",
    ]
    out += count_table(by_authority, "Flag")
    out += ["", "## 7.6 Assignment Attribution", ""]
    out += count_table(dict(by_source), "Source", total)
    out += ["", END]
    return "\n".join(out)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="exit 1 if the block is stale")
    args = parser.parse_args()

    text = DOC.read_text(encoding="utf-8")
    block = render()

    if BEGIN in text:
        if END not in text:
            raise SystemExit(f"{DOC.name} has a BEGIN marker with no END marker.")
        head, rest = text.split(BEGIN, 1)
        _, tail = rest.split(END, 1)
        updated = head + block + tail
    else:
        # First run: replace the hand-written section 7 body, from its heading to the
        # horizontal rule that starts section 8.
        heading = "# 7. Phase 0/1 Current Distribution"
        if heading not in text:
            raise SystemExit(f"{DOC.name} has neither the generated markers nor '{heading}'.")
        head, rest = text.split(heading, 1)
        marker = "\n---\n\n# 8."
        if marker not in rest:
            raise SystemExit("Cannot find the start of section 8 to bound section 7.")
        _, tail = rest.split(marker, 1)
        updated = f"{head}{heading}\n\n{block}\n{marker}{tail}"

    if updated == text:
        print(f"✓ {DOC.name} section 7 is current")
        return 0
    if args.check:
        print(f"::error::{DOC.name} section 7 is stale.", file=sys.stderr)
        print(
            "Run 'python3 scripts/generate-router-doc-tables.py' and commit the doc.",
            file=sys.stderr,
        )
        return 1
    DOC.write_text(updated, encoding="utf-8")
    print(f"✓ rendered {DOC.name} section 7")
    return 0


if __name__ == "__main__":
    sys.exit(main())
