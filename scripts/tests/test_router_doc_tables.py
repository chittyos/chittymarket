#!/usr/bin/env python3
"""Pin the channel-compatibility predicate behind section 7.3 of the router doc.

WHY A UNIT TEST AND NOT THE CROSS-CHECK

generate-router-doc-tables.py cross-checks its exclusion counts against
views/by-channel.json, which catches the two from disagreeing on the overlay as it
stands. That guard is VACUOUS for the write-only clause: no capability in
capabilities.generated.json carries a `["write"]` exclusion, so deleting
`or (isinstance(exclusion, list) and exclusion == ["write"])` from the predicate changes
nothing about the rendered tables and the cross-check still passes. Verified by mutation.

The rule is nonetheless documented in 7.3's prose and implemented in
generate-capability-views.py, so it governs the next capability that uses it. This test
exercises it on synthetic records instead of waiting for one to appear.

NOT A BUG, BUT WORTH KNOWING: the token the overlay actually uses is
`["write_requires_policy_elevation"]` (5 records), which is NOT `["write"]` and therefore
counts as fully excluded, not read-compatible. The `["write"]` literal is dead in the
current data. Changing which token grants read compatibility would move the published
counts in views/by-channel.json, so it is deliberately not done here.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

# The script's filename is not a valid identifier, so load it by path.
import importlib.util

SCRIPT = Path(__file__).resolve().parents[1] / "generate-router-doc-tables.py"
spec = importlib.util.spec_from_file_location("router_doc_tables", SCRIPT)
assert spec and spec.loader
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

channel_included = mod.channel_included

FAILURES: list[str] = []


def check(label: str, actual: object, expected: object) -> None:
    if actual != expected:
        FAILURES.append(f"{label}: expected {expected!r}, got {actual!r}")


# A channel absent from runtime_exclusions is compatible.
check("absent/no key", channel_included({}, "chatgpt"), True)
check("absent/null", channel_included({"runtime_exclusions": None}, "chatgpt"), True)
check(
    "absent/other channel excluded",
    channel_included({"runtime_exclusions": {"openclaw": ["x"]}}, "chatgpt"),
    True,
)

# A write-only exclusion still permits read compatibility. This is the clause the
# cross-check cannot see, because no live record exercises it.
check(
    "write-only is read-compatible",
    channel_included({"runtime_exclusions": {"chatgpt": ["write"]}}, "chatgpt"),
    True,
)

# Anything else excludes — including the token the overlay actually uses, and including
# `write` alongside another reason.
check(
    "write_requires_policy_elevation excludes",
    channel_included(
        {"runtime_exclusions": {"chatgpt": ["write_requires_policy_elevation"]}}, "chatgpt"
    ),
    False,
)
check(
    "write plus another reason excludes",
    channel_included({"runtime_exclusions": {"chatgpt": ["write", "other"]}}, "chatgpt"),
    False,
)
check(
    "a bare string excludes",
    channel_included({"runtime_exclusions": {"chatgpt": "high mutation risk"}}, "chatgpt"),
    False,
)
check(
    "an empty list excludes",
    channel_included({"runtime_exclusions": {"chatgpt": []}}, "chatgpt"),
    False,
)

# The predicate must agree with generate-capability-views.py, which is the artifact CI
# already gates. Both are loaded and compared on the same synthetic records rather than
# trusted to have been copied correctly.
VIEWS_SCRIPT = Path(__file__).resolve().parents[1] / "generate-capability-views.py"
vspec = importlib.util.spec_from_file_location("capability_views", VIEWS_SCRIPT)
assert vspec and vspec.loader
vmod = importlib.util.module_from_spec(vspec)
vspec.loader.exec_module(vmod)
if hasattr(vmod, "channel_included"):
    for case in (
        {},
        {"runtime_exclusions": {"chatgpt": ["write"]}},
        {"runtime_exclusions": {"chatgpt": ["write_requires_policy_elevation"]}},
        {"runtime_exclusions": {"chatgpt": "a string"}},
    ):
        check(
            f"agrees with the view generator on {case}",
            channel_included(case, "chatgpt"),
            vmod.channel_included(case, "chatgpt"),
        )
else:
    print(
        "note: generate-capability-views.py inlines its channel rule rather than exposing "
        "channel_included(), so the two implementations are compared by reading, not by "
        "this test. Extracting it there would close that gap."
    )

if FAILURES:
    for failure in FAILURES:
        print(f"FAIL {failure}", file=sys.stderr)
    sys.exit(1)
print("✓ router doc channel predicate: all cases pass")
