#!/usr/bin/env python3
"""
market-backfill-overlay.py — one-time migration: write `overlay:` blocks into canonical/

`market-reconcile.py` treats canonical/<kind>/<name>.md as the single source for
both marketplace.json and capabilities.generated.json. That requires each
canonical artifact to declare its §16 editorial metadata in an `overlay:` block.
This script establishes those blocks once, so the ongoing workflow is just
`market-reconcile.py sync`.

Two populations, two provenances:

  1. TRANSCRIBED (25 artifacts) — a §16 record already exists in
     capabilities.generated.json. Its editorial fields are copied verbatim into
     the canonical file. Zero invention: this moves operator-authored data into
     the single source it should have lived in.

  2. DERIVED (23 artifacts) — no §16 record exists. Editorial fields are derived
     from what the canonical file already declares (`classification`, `kind`,
     `plugin`, `safety_class`) using the documented rule table below. These are
     the values a reviewer should scrutinise in the PR diff; they are grounded in
     each artifact's own declared classification, not guessed from its name.

Blocks are inserted textually immediately before the closing `---` of the
frontmatter, so every other byte of the canonical file is preserved and the
review diff shows only the addition.

    market-backfill-overlay.py --dry-run   # show what would be written
    market-backfill-overlay.py             # write the blocks

Idempotent: a canonical file that already has an `overlay:` key is skipped.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys

import yaml

REPO_ROOT = subprocess.check_output(
    ["git", "rev-parse", "--show-toplevel"], text=True
).strip()
OVERLAY = os.path.join(REPO_ROOT, "capabilities.generated.json")
CANONICAL_DIR = os.path.join(REPO_ROOT, "canonical")

KIND_DIRS = (
    ("agents", "agent"), ("skills", "skill"), ("commands", "command"),
    ("mcp", "mcp"), ("tools", "tool"), ("hooks", "hook"),
)
PREFIX = {"skill": "skill-", "agent": "agent-", "hook": "hook-",
          "command": "command-", "tool": "tool-", "mcp": ""}

# ── DERIVATION RULES (population 2) ───────────────────────────────────────────
# classification tag → capability_group. First match in this order wins, so the
# more specific tags are listed first. Groups are the §16 enum.
CLASSIFICATION_TO_GROUP = [
    ("evidence", "legal"), ("legal", "legal"),
    ("credentials", "connect"), ("auth", "connect"), ("integration", "connect"),
    ("compliance", "govern"), ("governance", "govern"), ("security-audit", "govern"),
    ("projection", "govern"), ("dispatch", "govern"),
    ("orchestration", "agent-runtime"), ("autonomy", "agent-runtime"),
    ("mcp", "agent-runtime"),
    ("marketplace", "market"), ("discovery", "market"),
    ("storage", "workspace"), ("r2-management", "workspace"),
    ("chain-of-custody", "legal"), ("content-addressing", "workspace"),
    ("neon", "connect"), ("operations", "ship"), ("token-lifecycle", "connect"),
]
# kind → (execution_class, ontology.primary, ontology.secondary, advisory_disposition)
KIND_PROFILE = {
    "agent":   ("@chitty/reasoning",   ["P"], ["A", "E", "T"], "agent"),
    "skill":   ("@chitty/connectors",  ["T"], ["A", "E"],      "skill"),
    "command": ("@chitty/connectors",  ["E"], ["T"],           "skill"),
    "mcp":     ("@chitty/connectors",  ["T"], ["E"],           "route"),
    "tool":    ("@chitty/connectors",  ["T"], ["E"],           "tool"),
}
# capability_group → default legacy_category (mirrors existing manifest usage)
GROUP_TO_CATEGORY = {
    "legal": "legal", "govern": "ecosystem", "connect": "ecosystem",
    "agent-runtime": "ecosystem", "market": "ecosystem",
    "workspace": "ecosystem", "ship": "ecosystem", "internal": "ecosystem",
    "build": "code", "local-lab": "ecosystem",
}

EDITORIAL_FIELDS = (
    "capability_group", "execution_class", "visibility", "ontology", "authority",
    "execution", "discovery", "auth_flow", "phase0_audit", "canonical_version",
    "group_assignment_source", "runtime_exclusions",
)


def split_frontmatter(src: str):
    m = re.match(r"^(---\n)(.*?)(\n---\n)", src, re.DOTALL)
    if not m:
        return None
    return m.group(1), m.group(2), m.group(3), src[m.end():]


def derive_group(classification, kind, name) -> str:
    tags = [t.lower() for t in (classification or [])]
    for tag, group in CLASSIFICATION_TO_GROUP:
        if tag in tags:
            return group
    if kind == "tool":
        return "agent-runtime"
    return "workspace"


def derive_verbs(name, classification) -> list[str]:
    verbs = [name.split("-")[0]]
    for t in (classification or [])[:2]:
        if t not in verbs:
            verbs.append(t)
    return verbs


def build_derived(name: str, kind: str, fm: dict) -> dict:
    cls = fm.get("classification") or []
    group = derive_group(cls, kind, name)
    exec_class, prim, sec, disposition = KIND_PROFILE.get(kind, KIND_PROFILE["skill"])
    read_only = fm.get("safety_class") == "read_only"

    title = " ".join(w.capitalize() for w in re.split(r"[-_]", name))
    return {
        "title": title,
        "capability_group": group,
        "group_assignment_source": "category",
        "execution_class": exec_class,
        "visibility": "advanced",
        "legacy_category": GROUP_TO_CATEGORY.get(group, "ecosystem"),
        "canonical_version": "1.0.0",
        "ontology": {"primary": prim, "secondary": sec},
        "authority": {"requires_chittyid": True},
        "execution": {
            "default_surface": "ch1tty",
            "local_allowed": False,
            "context_cost": "medium",
            "mutation_risk": "low" if read_only else "medium",
        },
        "discovery": {
            "indexable": True,
            "session_index": "hidden",
            "ambient_by_intent": False,
            "verbs": derive_verbs(name, cls),
            "fallback_search": True,
        },
        "auth_flow": {
            "mode": "service-token",
            "stores_credentials_in": "ChittyConnect",
            "fail_closed_if_unavailable": True,
        },
        "phase0_audit": {
            "job_to_be_done": "verify" if group == "govern" else "route",
            "environmental_footprint": (
                "read-only connector" if read_only else "write-capable"
            ),
            "evidentiary_risk": "none",
            "advisory_disposition": disposition,
        },
        "runtime_exclusions": {},
    }


def build_transcribed(rec: dict) -> dict:
    ov = {"title": rec["name"]}
    for f in EDITORIAL_FIELDS:
        if f in rec:
            ov[f] = rec[f]
    ov["legacy_category"] = rec.get("legacy_category", "ecosystem")
    return ov


def render_block(ov: dict) -> str:
    """YAML-dump the overlay block at top level, two-space indented children."""
    body = yaml.safe_dump(
        {"overlay": ov}, sort_keys=False, default_flow_style=False, allow_unicode=True
    )
    return body.rstrip("\n")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    overlay = json.load(open(OVERLAY, encoding="utf-8"))
    by_legacy = {c["legacy_id"]: c for c in overlay["capabilities"]}

    transcribed, derived, skipped = [], [], []

    for kind_dir, kind in KIND_DIRS:
        d = os.path.join(CANONICAL_DIR, kind_dir)
        if not os.path.isdir(d):
            continue
        for fname in sorted(os.listdir(d)):
            if not fname.endswith(".md"):
                continue
            name, path = fname[:-3], os.path.join(d, fname)
            src = open(path, encoding="utf-8").read()
            parts = split_frontmatter(src)
            if not parts:
                continue
            open_d, fm_text, close_d, body = parts
            fm = yaml.safe_load(fm_text) or {}
            if "overlay" in fm:
                skipped.append(name)
                continue

            legacy_id = PREFIX.get(kind, "") + name
            rec = by_legacy.get(legacy_id)
            if rec:
                ov, bucket = build_transcribed(rec), transcribed
            else:
                ov, bucket = build_derived(name, kind, fm), derived
            bucket.append((name, kind, ov["capability_group"]))

            if not args.dry_run:
                new_fm = fm_text.rstrip("\n") + "\n" + render_block(ov)
                with open(path, "w", encoding="utf-8") as fh:
                    fh.write(open_d + new_fm + close_d + body)

    verb = "would write" if args.dry_run else "wrote"
    print(f"TRANSCRIBED from existing §16 records ({len(transcribed)}) — {verb}:")
    for n, k, g in transcribed:
        print(f"  {k:8} {n:28} group={g}")
    print(f"\nDERIVED from declared classification ({len(derived)}) — {verb} "
          f"[REVIEW THESE]:")
    for n, k, g in derived:
        print(f"  {k:8} {n:28} group={g}")
    if skipped:
        print(f"\nskipped (already declared): {len(skipped)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
