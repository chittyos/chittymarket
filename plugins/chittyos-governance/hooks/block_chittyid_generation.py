#!/usr/bin/env python3
"""PreToolUse guard: refuse writes that generate a ChittyID locally.

Canon states the rule four times:
  chittyid/CHARTER.md:23   "no local generation is permitted"
  chittyid/CHARTER.md:119  "STRICT NO LOCAL GENERATION"
  chittyid/CLAUDE.md:146   "NEVER generated locally under ANY circumstances"
  chittyid/HYBRID_SYSTEM.md:105 "Server-only generation - NO local fallbacks allowed"

Before this guard existed, nothing enforced it: the declarative hookify rule
of the same name was never written, and the nine rules that were written sit in
~/.claude/hooks/, which hookify's cwd-relative glob
(core/config_loader.py:210-211) cannot see. Measured 2026-11-12: hookify's own
load_rules() returned 0 from every plausible cwd. Meanwhile chittycan had been
forging IDs on every SessionStart (fixed in chittyos/chittycan#231).

Protocol: Claude Code PreToolUse. Reads the tool call as JSON on stdin.
Exit 0 = allow. Exit 2 = block, with the reason on stderr.
Fails OPEN on any internal error — a broken guard must not wedge every write —
but says so loudly, because a silent no-op guard is the failure this file exists
to end.
"""

import json
import re
import sys

# --- what counts as local generation -----------------------------------------
# Each pattern is high-confidence: it builds or re-derives an identifier rather
# than reading one. Ordered most to least specific for clearer messages.

SEGMENT = r"[A-Za-z0-9_$.\[\]{}()'\"-]+"

PATTERNS = [
    (
        "mod-97 checksum computed locally",
        # 98 - (x % 97) in JS/TS/Python, with or without BigInt suffixes.
        re.compile(r"\b98n?\s*-\s*\(?[^;\n]{0,80}%\s*97n?", re.I),
    ),
    (
        "mod-97 checksum computed locally",
        re.compile(r"%\s*97n?\s*\)?\s*(?:\.toString|\)|;|,)", re.I),
    ),
    (
        "eight ChittyID segments assembled from parts",
        # `${a}-${b}-${c}-${d}-${e}-${f}-${g}-${h}` : 7+ interpolated joins.
        re.compile(r"(?:\$\{" + SEGMENT + r"\}-){6,}\$\{"),
    ),
    (
        "eight ChittyID segments assembled from parts",
        # f"{a}-{b}-..." in Python.
        re.compile(r"(?:\{" + SEGMENT + r"\}-){6,}\{"),
    ),
    (
        "ChittyID segments joined from an array",
        # Require 5+ commas: a ChittyID has 8 segments (7 commas), so this
        # ignores ordinary joins like [org, repo].join("-").
        re.compile(
            r"\[(?:[^\]\n]*,){5,}[^\]\n]*\]\s*\.join\(\s*['\"]-['\"]\s*\)", re.I
        ),
    ),
    (
        "an entity-type segment is reassigned, then the ID re-joined",
        # The gap must cross statement boundaries: the real site (chittycan
        # hook-handlers.ts:588) puts slice()/checksum lines, and therefore
        # semicolons, between the assignment and the join. An earlier version
        # used [^;] here and silently matched nothing.
        re.compile(
            r"segments?\s*\[[^\]\n]{1,20}\]\s*=[^\n]{0,80}[\s\S]{0,400}?"
            r"\.join\(\s*['\"]-['\"]",
            re.I,
        ),
    ),
    (
        "a local ChittyID generator is being defined",
        re.compile(
            r"(?:function|def|const|let|var|async)\s+"
            r"(?:generate|mint|create|make|new|build)"
            r"(?:Local)?Chitty_?Id\b",
            re.I,
        ),
    ),
    (
        "a local ChittyID generator is being defined",
        re.compile(
            r"(?:generate|mint|create|make|new|build)(?:Local)?Chitty_?Id"
            r"\s*[:=]\s*(?:async\s*)?(?:function|\()",
            re.I,
        ),
    ),
]

# --- what must NOT be caught --------------------------------------------------
# Paths that legitimately construct IDs, or only read them.

EXEMPT_PATH = re.compile(
    r"(?:"
    r"chittyfoundation/chittyid/"      # the minting service itself
    r"|chittymint/"                    # and its mint core
    r"|/__tests__/|/tests?/|\.test\.|\.spec\."   # fixtures and tests
    r"|/docs?/|\.md$"                  # prose may quote the format
    r"|block_chittyid_generation"      # this guard and its own tests
    r")",
    re.I,
)

# A mod-97 result that is COMPARED is a validator, not a generator.
VALIDATOR_HINT = re.compile(
    r"(?:===|!==|==|!=|\bassert\b|\bexpect\b|\bis_valid\b|\bisValid\b|"
    r"\bvalidate\b|\bverify\b|\bcheck(?:sum)?Matches\b)",
    re.I,
)

CONTENT_FIELDS = (
    "content",        # Write
    "new_string",     # Edit
    "new_str",
    "replace_all",    # harmless, present on Edit
)


def extract(tool_input):
    """Return (path, text) pairs this call would write."""
    out = []
    path = tool_input.get("file_path") or tool_input.get("path") or ""
    for field in CONTENT_FIELDS:
        val = tool_input.get(field)
        if isinstance(val, str) and val:
            out.append((path, val))
    # MultiEdit / batched edits
    for edit in tool_input.get("edits") or []:
        if isinstance(edit, dict):
            val = edit.get("new_string") or edit.get("new_str")
            if isinstance(val, str) and val:
                out.append((path, val))
    return out


def findings_for(path, text):
    if EXEMPT_PATH.search(path or ""):
        return []
    hits = []
    for label, rx in PATTERNS:
        m = rx.search(text)
        if not m:
            continue
        # Validator carve-out applies only to the checksum patterns: a compared
        # modulus reads an ID, it does not issue one.
        if "mod-97" in label:
            window = text[max(0, m.start() - 200) : m.end() + 200]
            if VALIDATOR_HINT.search(window):
                continue
        snippet = " ".join(m.group(0).split())[:120]
        hits.append((label, snippet))
    # De-duplicate repeated labels, keep first snippet.
    seen, uniq = set(), []
    for label, snippet in hits:
        if label in seen:
            continue
        seen.add(label)
        uniq.append((label, snippet))
    return uniq


def main():
    try:
        raw = sys.stdin.read()
        if not raw.strip():
            return 0
        payload = json.loads(raw)
    except Exception as exc:  # fail open, loudly
        print(f"[block-chittyid-generation] guard could not parse input: {exc}", file=sys.stderr)
        return 0

    tool = payload.get("tool_name") or payload.get("toolName") or ""
    if tool not in ("Write", "Edit", "MultiEdit", "NotebookEdit"):
        return 0

    tool_input = payload.get("tool_input") or payload.get("toolInput") or {}
    if not isinstance(tool_input, dict):
        return 0

    all_hits = []
    for path, text in extract(tool_input):
        for label, snippet in findings_for(path, text):
            all_hits.append((path, label, snippet))

    if not all_hits:
        return 0

    lines = [
        "BLOCKED: this write generates a ChittyID locally.",
        "",
        "Canon forbids it without exception:",
        "  chittyid/CHARTER.md:23, :119 · CLAUDE.md:146 · HYBRID_SYSTEM.md:105",
        '  "STRICT NO LOCAL GENERATION ... under ANY circumstances"',
        "",
        "What was detected:",
    ]
    for path, label, snippet in all_hits:
        lines.append(f"  - {label}")
        lines.append(f"      {path or '<no path>'}: {snippet}")
    lines += [
        "",
        "Do this instead:",
        '  POST https://id.chitty.cc/mint  with body {"entityType":"P"}  (P|L|T|E|A)',
        "  Use the returned ID verbatim. Never rewrite a segment and never",
        "  recompute the checksum — that forges an ID the mint did not issue",
        "  (see chittyos/chittycan#231).",
        "",
        "If the mint is degraded it returns its own trust-0 provisional ID with",
        "  fallback: true. Accept and mark that; do not construct a replacement.",
        "",
        "Legitimate exceptions, by path: the chittyid/chittymint services",
        "  themselves, tests and fixtures, and documentation.",
    ]
    print("\n".join(lines), file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
