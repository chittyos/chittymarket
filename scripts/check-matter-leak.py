#!/usr/bin/env python3
"""check-matter-leak — fail the build when a concrete legal matter appears in a
governed, published definition.

Standard enforced: legal-operating-defaults §15 — matter facts stay out of reusable
capability packages. §8 (no defaulting to a case) is enforced by each skill's own text;
this gate enforces §15, which a caveated "worked example" does not satisfy.

WHY A SHAPE MATCHER AND NOT A LIST OF MATTERS
A denylist naming real matters would itself be matter data, published in a public repo.
This gate therefore never learns which matters exist. It recognises the *shape* of a case
identifier; and for identifiers whose shape is indistinguishable from an ordinary slug
(a property address, an HOA name), it requires that any example sitting beside a case_*
field be drawn from the synthetic placeholder vocabulary below.

Usage:
  scripts/check-matter-leak.py             fail mode (CI) — exit 1 on any hit
  scripts/check-matter-leak.py --report    report mode — list hits, always exit 0
  scripts/check-matter-leak.py --ref REF   scan a git ref instead of the working tree
"""
import argparse, re, subprocess, sys

SCOPE = ["canonical", "plugins", "docs"]
EXTS = (".md", ".sql", ".json", ".sh", ".py", ".yaml", ".yml")
# This file states the rules, so it necessarily contains their shapes.
EXEMPT = {"scripts/check-matter-leak.py", "scripts/check-matter-leak.sh"}

# Synthetic placeholder vocabulary — the only values allowed beside a case field.
# Every entry is a format token or bracketed placeholder; none refers to a real matter,
# so this list is safe to publish.
PLACEHOLDER = re.compile(
    r"(<[a-zA-Z_]+>|\{[a-zA-Z_]+\}|\$\{?[A-Z_]+\}?|YYYY|NNNN|XXXX|placeholder|example\.com)")

# Structural names that legitimately sit on a case-context line and are not case values.
STRUCTURAL = re.compile(
    r"^(case|cases|case_id|case_slug|case_number|caseNumber|case-registry|case_registry|"
    r"evidence_cases|evidence_statement_of_facts|evidence_documents|evidence_intake_log|"
    r"chittyevidence-db|chittyevidence|chittyrouter|chittyledger|chittymarket|chittycases|"
    r"registry|slug|string|required|optional|null|true|false|draft|verified|locked)$")

# R1 — Cook County case-number shape. Case-insensitive; optional separators and case_ prefix.
# Digit runs only: a format table must use letter tokens (YYYY D NNNNNN), never synthetic
# digits, or it trips this rule by design.
R1 = re.compile(r"(?<![0-9A-Za-z])(case[_-])?(19|20)[0-9]{2}[ _-]?"
                r"(D|L|CH|CR|M[1-6]|P|MC|OP|AR)[ _-]?[0-9]{5,6}(?![0-9A-Za-z])", re.I)

# R2 — party-versus-party slug shape.
R2 = re.compile(r"(?<![a-z0-9])[a-z]{2,}[-_]v[-_][a-z]{2,}(?![a-z0-9])")

# R3 — capitalised caption "Surname v. Surname", unless the line carries a reporter
# citation, which marks it as published case law rather than a live matter.
R3 = re.compile(r"\b[A-Z][a-zA-Z]{2,}\s+v\.?\s+[A-Z][a-zA-Z]{2,}\b")
REPORTER = re.compile(r"[0-9]+\s+(U\.S\.|S\.\s?Ct\.|F\.[0-9]|F\.\s?Supp|N\.E\.|N\.W\.|"
                      r"S\.E\.|S\.W\.|P\.[0-9]|A\.[0-9]|Ill\.|Cal\.)")

# R4 — a case-context line that *offers an example*. Every recurrence observed so far took
# this exact form: an author placing a concrete-looking value next to a case_* field so the
# reader has something to look at. Restricted to example-bearing lines so that ordinary prose
# mentioning a case field is not flagged.
CASE_CTX = re.compile(r"(case_id|case_slug|case_number|caseNumber|case-slug|--case|"
                      r"Case ID|Case Number)")
EXAMPLE_MARKER = re.compile(r"(e\.g\.|for example|--case\s+\S|default\s+`)", re.I)
VALUEISH = re.compile(r"^[a-z0-9][a-z0-9_.-]{3,}$")
BACKTICKED = re.compile(r"`([^`]+)`")


def git(*args):
    return subprocess.run(["git", *args], capture_output=True, text=True).stdout


def scan(ref):
    files = (git("ls-tree", "-r", "--name-only", ref, "--", *SCOPE) if ref
             else git("ls-files", "--", *SCOPE)).splitlines()
    hits = []
    for f in files:
        if not f.endswith(EXTS) or f in EXEMPT:
            continue
        body = git("show", f"{ref}:{f}") if ref else open(f, encoding="utf-8", errors="replace").read()
        for n, line in enumerate(body.splitlines(), 1):
            if R1.search(line):
                hits.append((f, n, "case-number shape", line)); continue
            if R2.search(line):
                hits.append((f, n, "party-slug shape", line)); continue
            if R3.search(line) and not REPORTER.search(line):
                hits.append((f, n, "caption shape", line)); continue
            if CASE_CTX.search(line) and EXAMPLE_MARKER.search(line):
                # only values offered AS the example — i.e. positioned after the marker.
                # The field being described sits before it and is not a leak.
                marker = EXAMPLE_MARKER.search(line)
                tail = line[marker.end():]
                toks = BACKTICKED.findall(tail)
                bare = re.search(r"--case\s+([A-Za-z0-9_.-]+)", line)
                if bare:
                    toks.append(bare.group(1))
                for tok in toks:
                    if PLACEHOLDER.search(tok) or STRUCTURAL.match(tok) or not VALUEISH.match(tok):
                        continue
                    hits.append((f, n, "concrete example beside a case field", line)); break
    return hits


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--report", action="store_true")
    ap.add_argument("--ref", default="")
    a = ap.parse_args()

    hits = scan(a.ref)
    for f, n, rule, line in hits:
        print(f"\033[0;31m{f}:{n}\033[0m  [{rule}]")
        print(f"    \033[0;90m{line.strip()[:150]}\033[0m")

    if not hits:
        print("\033[0;32mNo matter leakage detected.\033[0m")
        return 0

    print(f"\n\033[0;33m{len(hits)} hit(s).\033[0m")
    print("""
A governed definition must not carry a concrete legal matter — not even as a caveated
"worked example". Caveats satisfy legal-operating-defaults §8 (do not default to a case);
they do not satisfy §15 (matter facts stay out of reusable capability packages).

Fix by replacing the value with a placeholder token, not by loosening this gate:
  case number  ->  YYYY D NNNNNN
  case slug    ->  <case_slug>
  case id      ->  <case_id>""")
    return 0 if a.report else 1


if __name__ == "__main__":
    sys.exit(main())
