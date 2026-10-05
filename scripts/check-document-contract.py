#!/usr/bin/env python3
"""Check the ChittyMarket compliance document contract for architectural drift."""

from pathlib import Path
import re
import sys
import yaml

ROOT = Path(__file__).resolve().parent.parent
FILES = {
    "charter": ROOT / "CHARTER.md",
    "architecture": ROOT / "CHITTY.md",
    "agents": ROOT / "AGENTS.md",
    "security": ROOT / "SECURITY.md",
}
WORKFLOWS = ROOT / ".github" / "workflows"

SERVICE_URI = "chittycanon://core/services/chittymarket"
TIER_MARKER = "Tier 3"
CONTROL_PLANE = "capability supply chain"
NO_STANDALONE = "Standalone HTTP domain"
CERTIFIER = "chittycanon://core/services/chittycertify"

errors = []


def read(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError:
        errors.append(f"missing required file: {path.name}")
        return ""


def frontmatter(text: str, filename: str) -> dict:
    match = re.match(r"^---\n(.*?)\n---\n", text, re.DOTALL)
    if not match:
        errors.append(f"{filename}: missing YAML frontmatter")
        return {}
    try:
        data = yaml.safe_load(match.group(1)) or {}
    except yaml.YAMLError as exc:
        errors.append(f"{filename}: invalid YAML frontmatter: {exc}")
        return {}
    if not isinstance(data, dict):
        errors.append(f"{filename}: frontmatter is not a mapping")
        return {}
    return data


docs = {name: read(path) for name, path in FILES.items()}

for key, text in docs.items():
    filename = FILES[key].name
    if SERVICE_URI not in text:
        errors.append(f"{filename}: missing canonical service URI {SERVICE_URI}")
    if TIER_MARKER not in text:
        errors.append(f"{filename}: missing Tier 3 architecture marker")

for key in ("charter", "architecture"):
    filename = FILES[key].name
    fm = frontmatter(docs[key], filename)
    if fm.get("certifier") != CERTIFIER:
        errors.append(
            f"{filename}: certifier must be {CERTIFIER}, got {fm.get('certifier')!r}"
        )
    if fm.get("status") != "DRAFT":
        errors.append(
            f"{filename}: status must remain DRAFT during migration, got {fm.get('status')!r}"
        )
    if fm.get("visibility") != "INTERNAL":
        errors.append(
            f"{filename}: visibility must be INTERNAL for the private control plane, got {fm.get('visibility')!r}"
        )

charter = docs["charter"]
architecture = docs["architecture"]
agents = docs["agents"]
security = docs["security"]

for filename, text in (
    ("CHARTER.md", charter),
    ("CHITTY.md", architecture),
    ("AGENTS.md", agents),
):
    if NO_STANDALONE not in text:
        errors.append(f"{filename}: must explicitly declare standalone HTTP domain status")

for filename, text in (
    ("CHARTER.md", charter),
    ("CHITTY.md", architecture),
    ("AGENTS.md", agents),
    ("SECURITY.md", security),
):
    if CONTROL_PLANE not in text and "capability supply-chain" not in text:
        errors.append(f"{filename}: missing capability-supply-chain product role")

required_truth_markers = (
    "AUTHORED",
    "IDENTITY_RESOLVED",
    "PROJECTED",
    "RUNTIME_VERIFIED",
    "PUBLISHED",
    "INDEXED",
)
for marker in required_truth_markers:
    if marker not in architecture and marker not in agents:
        errors.append(f"release truth state {marker} missing from CHITTY.md/AGENTS.md contract")

for marker in (
    "Projection is not verification",
    "Generated artifacts are not authority",
    "Fail closed",
    "Private by default",
):
    if marker not in security:
        errors.append(f"SECURITY.md missing invariant: {marker}")

for filename, text in (
    ("CHARTER.md", charter),
    ("CHITTY.md", architecture),
    ("AGENTS.md", agents),
    ("SECURITY.md", security),
):
    if "CI_RUNNER" not in text:
        errors.append(f"{filename}: missing governed CI_RUNNER runner-selection contract")

for workflow in sorted([*WORKFLOWS.glob("*.yml"), *WORKFLOWS.glob("*.yaml")]):
    workflow_text = read(workflow)
    for line_number, line in enumerate(workflow_text.splitlines(), start=1):
        match = re.match(r"^\s*runs-on:\s*(.+?)\s*$", line)
        if not match:
            continue
        selector = match.group(1)
        if "vars.CI_RUNNER" not in selector:
            errors.append(
                f"{workflow.relative_to(ROOT)}:{line_number}: runs-on must resolve through "
                "vars.CI_RUNNER; change the policy guard in the same reviewed change for an exception"
            )

for stale_claim in (
    "Central manifest (single source of truth)",
    "Single source of truth",
    "ChittyMarket has **no runtime attack surface**",
    "Backend capability index",
):
    for filename, text in (
        ("CHARTER.md", charter),
        ("CHITTY.md", architecture),
        ("SECURITY.md", security),
    ):
        if stale_claim in text:
            errors.append(f"{filename}: stale architecture claim remains: {stale_claim}")

if errors:
    print("ChittyMarket document contract: FAIL")
    for error in errors:
        print(f"  - {error}")
    sys.exit(1)

print("ChittyMarket document contract: PASS")
