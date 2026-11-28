#!/usr/bin/env bash
# xai-grok-bot.sh — project a canonical agent into an xAI Grok Bot profile.
#
# Grok Bot is xAI's hosted bot product. This adapter writes a profile only:
# name, description (the job statement), instruction text, and connectors.
# It does not call xAI, create a Bot, or read a secret.
#
# Usage:
#   xai-grok-bot.sh <canonical-path> <output-path>
#
# Connectors come from the canonical, in this order:
#   runtime_overrides.xai-grok-bot.connectors
#   else top-level connectors
# A list is names only. A mapping is a resolve-at-use-time instruction
# (string values, name-shaped). The adapter does not invent connectors,
# addresses, owners, or tiers, and it does not copy those fields through
# when the canonical happens to carry them.
#
# boundary_class legal-only is not eligible and exits 2.
# Absent boundary_class is allowed. Any other value is rejected.
# Missing connectors is rejected: guessing a server list is not a default.
#
# Strict: required fields missing => exit 2. Output is deterministic
# (sorted keys, no timestamps) so re-runs produce zero diff.
set -euo pipefail

canonical="${1:-}"
out="${2:-}"
[ -n "$canonical" ] && [ -n "$out" ] || { echo "usage: $0 <canonical-path> <output-path>" >&2; exit 2; }
[ -f "$canonical" ] || { echo "canonical not found: $canonical" >&2; exit 2; }

mkdir -p "$(dirname "$out")"

python3 - "$canonical" "$out" <<'PY'
import json, re, subprocess, sys
from pathlib import Path

import yaml

def fail(msg):
    print(msg, file=sys.stderr)
    raise SystemExit(2)

canonical_path, out_path = sys.argv[1], sys.argv[2]
src = Path(canonical_path).read_text(encoding="utf-8")
m = re.match(r"^---\n(.*?\n)---\n(.*)$", src, re.S)
if not m:
    fail(f"no frontmatter in {canonical_path}")
try:
    fm = yaml.safe_load(m.group(1)) or {}
except yaml.YAMLError as e:
    fail(f"canonical frontmatter is not valid YAML: {e}")
if not isinstance(fm, dict):
    fail("canonical frontmatter is not a mapping")
body = m.group(2).lstrip("\n").rstrip() + "\n"

if fm.get("kind") != "agent":
    fail(f"xai-grok-bot adapter requires kind=agent, got kind={fm.get('kind')!r}")

boundary = fm.get("boundary_class")
if boundary == "legal-only":
    fail("boundary_class legal-only is not eligible for an xAI Grok Bot projection")
if boundary not in (None, "business"):
    fail(f"boundary_class must be business or legal-only, got {boundary!r}")

overrides = (fm.get("runtime_overrides") or {}).get("xai-grok-bot") or {}
if overrides and not isinstance(overrides, dict):
    fail("runtime_overrides.xai-grok-bot must be a mapping")

name = overrides.get("name") or fm.get("name")
if not isinstance(name, str) or not name.strip() or re.search(r"\s|://|@", name):
    fail("canonical name must be a non-empty name, not an address")

desc_src = overrides.get("description")
if desc_src is None:
    desc_src = fm.get("job")
if desc_src is None:
    desc_src = fm.get("description")
if not isinstance(desc_src, str) or not desc_src.strip():
    fail("canonical missing required field: description")
first = desc_src.strip().split("\n\n", 1)[0]
description = " ".join(first.split()).strip()
if not description:
    fail("description is empty")

instructions = overrides.get("instructions")
if instructions is None:
    instructions = body
if not isinstance(instructions, str) or not instructions.strip():
    fail("canonical body is empty; Grok Bot instructions would be blank")
if not instructions.endswith("\n"):
    instructions += "\n"

USERINFO = re.compile(r"://[^/\s:]+:[^/\s@]+@")
NAME = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$")
CRED = re.compile(
    r"TOKEN|SECRET|PASSWORD|PASSWD|_KEY$|^KEY_|CONNECTION_STRING|DSN|CREDENTIAL|PRIVATE",
    re.I,
)

def reject_secret(text, where):
    if USERINFO.search(text):
        fail(f"{where} embeds credentials")

reject_secret(description, "description")
reject_secret(instructions, "instructions")

def as_name(value, where):
    if not isinstance(value, str) or not NAME.match(value):
        fail(f"{where} must be a name, not an address or a value")
    if CRED.search(value):
        fail(f"{where} looks like a credential")
    return value

if "connectors" in overrides:
    raw = overrides.get("connectors")
elif "connectors" in fm:
    raw = fm.get("connectors")
else:
    fail(
        "canonical must declare connectors (a list of names, or a resolve mapping). "
        "This adapter does not invent them."
    )

if isinstance(raw, list):
    if not raw:
        fail("connectors list is empty; declare a resolve mapping instead of an empty server list")
    connectors = [as_name(item, f"connectors[{i}]") for i, item in enumerate(raw)]
    if len(connectors) != len(set(connectors)):
        fail("connectors contains a duplicate name")
elif isinstance(raw, dict):
    if not raw:
        fail("connectors mapping is empty")
    connectors = {}
    for key, value in raw.items():
        as_name(str(key), "connectors key")
        connectors[str(key)] = as_name(value, f"connectors.{key}")
else:
    fail("connectors must be a list of names or a resolve mapping")

def source_ref(path: Path) -> str:
    try:
        root = subprocess.check_output(
            ["git", "-C", str(path.parent), "rev-parse", "--show-toplevel"],
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
        return path.resolve().relative_to(Path(root).resolve()).as_posix()
    except (subprocess.CalledProcessError, ValueError, OSError):
        return path.name

provenance = {"source": source_ref(Path(canonical_path))}
canon_uri = fm.get("canon_uri") or fm.get("canonical_uri")
if canon_uri is not None:
    if not isinstance(canon_uri, str) or not canon_uri.strip():
        fail("canon_uri must be a non-empty string when present")
    reject_secret(canon_uri, "canon_uri")
    provenance["canon_uri"] = canon_uri
if boundary is not None:
    provenance["boundary_class"] = boundary

doc = {
    "runtime": "xai-grok-bot",
    "profile": {
        "name": name.strip(),
        "description": description,
        "instructions": instructions,
    },
    "connectors": connectors,
    "provenance": provenance,
}
Path(out_path).write_text(
    json.dumps(doc, indent=2, sort_keys=True, ensure_ascii=False) + "\n",
    encoding="utf-8",
)
PY

echo "[xai-grok-bot] projected $canonical -> $out"
