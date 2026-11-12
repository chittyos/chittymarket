#!/usr/bin/env python3
"""Mutation tests for the block-chittyid-generation guard.

Every BLOCK case is a real string from the 2026-11-11 fleet sweep, so the guard
is measured against code that actually shipped. Every ALLOW case is something
that must keep working, because a guard that blocks legitimate writes gets
disabled, and a disabled guard is the failure this file exists to prevent.

Run: python3 test_block_chittyid_generation.py
Exit 0 = all cases behave; exit 1 = a case regressed, with the diff printed.
"""

import json
import subprocess
import sys
from pathlib import Path

GUARD = Path(__file__).with_name("block_chittyid_generation.py")

# (name, expect_block, tool, file_path, content)
CASES = [
    # ---- must BLOCK: real sites from the sweep -----------------------------
    (
        "chittycan session.ts:96 template assembly",
        True, "Write", "src/commands/session.ts",
        'const chittyId = `${version}-${generation}-${locale}-${service}'
        '-${type}-${ym}-${classification}-${checksum}`;',
    ),
    (
        "chittycan hook-handlers.ts:588 segment rewrite + rejoin",
        True, "Edit", "src/commands/hook-handlers.ts",
        'segments[4] = "P";\n'
        '    const baseSegments = segments.slice(0, -1);\n'
        '    segments[segments.length - 1] = checksum;\n'
        '    correctedId = segments.join("-");',
    ),
    (
        "local mod-97 with BigInt",
        True, "Write", "src/lib/ids.ts",
        'const checksum = String(98n - (BigInt(numericStr) % 97n)).padStart(2, "0");',
    ),
    (
        "local mod-97 without BigInt (T4's old blind spot)",
        True, "Write", "src/lib/ids.ts",
        'const checksum = String(98 - (Number(s) % 97)).padStart(2, "0");',
    ),
    (
        "array join of segments",
        True, "Write", "src/lib/idfix.ts",
        'return [v, g, l, s, t, ym, c, x].join("-");',
    ),
    (
        "generator function definition (JS)",
        True, "Write", "server/storage.ts",
        'function generateChittyId(type, category) {\n  return "..." ;\n}',
    ),
    (
        "generator function definition (Python)",
        True, "Write", "chittyos_core_wrapper.py",
        'def generateChittyID(entity_type):\n    return f"{vv}-{g}-{lll}-{ssss}-{t}-{ym}-{c}-{xx}"',
    ),
    (
        "generateLocalChittyId arrow assignment",
        True, "Write", "src/intelligence/experience-anchor.js",
        'const generateLocalChittyId = (t) => { return build(t); };',
    ),
    (
        "python f-string eight-segment assembly",
        True, "Write", "wrapper.py",
        'cid = f"{vv}-{g}-{lll}-{ssss}-{t}-{ym}-{c}-{xx}"',
    ),

    # ---- must ALLOW: legitimate work ---------------------------------------
    (
        "calling the mint correctly",
        False, "Write", "src/lib/chittyid.ts",
        'const r = await fetch("https://id.chitty.cc/mint", {\n'
        '  method: "POST", body: JSON.stringify({ entityType: "P" }) });\n'
        'const { chittyId } = await r.json();',
    ),
    (
        "a validator that COMPARES a mod-97 checksum",
        False, "Write", "src/chittyid/chittyid-validator.js",
        'const expected = String(98 - (sum % 97)).padStart(2, "0");\n'
        'if (expected !== segments[7]) return false;\n'
        'return isValid;',
    ),
    (
        "a validator using assert",
        False, "Write", "src/validate.ts",
        'const check = 98n - (BigInt(n) % 97n);\n'
        'expect(String(check)).toBe(segments[7]);',
    ),
    (
        "the mint service itself (exempt path)",
        False, "Write", "chittyfoundation/chittyid/src/chittyid-mint.ts",
        'const id = `${vv}-${g}-${lll}-${ssss}-${t}-${ym}-${c}-${xx}`;',
    ),
    (
        "a test fixture with a hardcoded ID",
        False, "Write", "server/__tests__/ids.test.ts",
        'const SAMPLE = "03-1-USA-0650-T-2606-1-24";',
    ),
    (
        "documentation quoting the format",
        False, "Write", "docs/CHITTYID.md",
        'Format: `${VV}-${G}-${LLL}-${SSSS}-${T}-${YYMM}-${C}-${XX}`',
    ),
    (
        "an unrelated dash join of two things",
        False, "Write", "src/util.ts",
        'const key = [org, repo].join("-");',
    ),
    (
        "a non-write tool is ignored",
        False, "Bash", "", 'echo "${a}-${b}-${c}-${d}-${e}-${f}-${g}-${h}"',
    ),
    (
        "reading an ID from a row",
        False, "Write", "src/db.ts",
        'const chittyId = row.chitty_id;\nreturn chittyId;',
    ),
]


def run(tool, file_path, content):
    payload = {"tool_name": tool, "tool_input": {"file_path": file_path, "content": content}}
    p = subprocess.run(
        [sys.executable, "-I", str(GUARD)],
        input=json.dumps(payload),
        capture_output=True,
        text=True,
        timeout=20,
    )
    return p.returncode, p.stderr


def main():
    failures = []
    for name, expect_block, tool, path, content in CASES:
        rc, err = run(tool, path, content)
        blocked = rc == 2
        status = "ok " if blocked == expect_block else "FAIL"
        want = "block" if expect_block else "allow"
        got = "block" if blocked else "allow"
        print(f"  [{status}] {want:>5} -> {got:<5}  {name}")
        if blocked != expect_block:
            failures.append((name, want, got, err.strip()[:300]))

    print()
    if failures:
        print(f"{len(failures)} of {len(CASES)} cases regressed:\n")
        for name, want, got, err in failures:
            print(f"- {name}: wanted {want}, got {got}")
            if err:
                print(f"    guard said: {err.splitlines()[0] if err else ''}")
        return 1
    print(f"all {len(CASES)} cases behave ({sum(1 for c in CASES if c[1])} block, "
          f"{sum(1 for c in CASES if not c[1])} allow)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
