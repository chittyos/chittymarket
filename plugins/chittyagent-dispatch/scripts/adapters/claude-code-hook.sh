#!/usr/bin/env bash
# claude-code-hook.sh — project a canonical hook definition into a plugin's
# hooks.json (Claude Code hook config format).
#
# Usage:
#   claude-code-hook.sh <canonical-path> <output-path>
#
# Canonical frontmatter shape (kind: hook):
#   ---
#   name: <hook-name>
#   kind: hook
#   description: |
#     <prose>
#   plugin: <home-plugin>
#   runtimes: [claude-code]
#   hook:
#     event: PreToolUse | PostToolUse | UserPromptSubmit | SessionStart | ...
#     matcher: ".*"
#     entries:
#       - type: command
#         command: "..."
#   ---
#
# Merges the canonical entry into plugins/<plugin>/hooks/hooks.json under
# hooks.<event>[], appending or replacing the matching entry by name.
# Other hooks for the same event (or other events) are preserved.
# Idempotent.
set -euo pipefail

canonical="${1:-}"
out="${2:-}"
[ -n "$canonical" ] && [ -n "$out" ] || { echo "usage: $0 <canonical-path> <output-path>" >&2; exit 2; }
[ -f "$canonical" ] || { echo "canonical not found: $canonical" >&2; exit 2; }

mkdir -p "$(dirname "$out")"

python3 - "$canonical" "$out" <<'PY'
import sys, re, json, os, yaml

canonical_path, out_path = sys.argv[1], sys.argv[2]
src = open(canonical_path, encoding="utf-8").read()

m = re.match(r"^---\n(.*?\n)---\n(.*)$", src, re.DOTALL)
if not m:
    sys.exit(f"no frontmatter in {canonical_path}")

try:
    fm = yaml.safe_load(m.group(1)) or {}
except yaml.YAMLError as e:
    sys.exit(f"canonical frontmatter is not valid YAML: {e}")

name = fm.get("name")
if not name:
    sys.exit("canonical missing required field: name")

hook = fm.get("hook") or {}
if not hook or not isinstance(hook, dict):
    sys.exit("canonical missing hook: block (event/matcher/entries)")

event = hook.get("event") or "PreToolUse"
matcher = hook.get("matcher") or ".*"
entries = hook.get("entries") or []

# Read existing hooks.json if present, else start with canonical Claude Code shape.
if os.path.exists(out_path):
    with open(out_path, encoding="utf-8") as f:
        existing = json.load(f)
else:
    existing = {"hooks": {}}

hooks_root = existing.setdefault("hooks", {})
bucket = hooks_root.setdefault(event, [])

# Find an entry tagged with our canonical name (custom key `_chitty_canonical: <name>`),
# else append a new one.
tag = f"_chitty_canonical"
found_idx = None
for i, b in enumerate(bucket):
    if b.get(tag) == name:
        found_idx = i
        break

new_entry = {
    tag: name,
    "matcher": matcher,
    "hooks": entries,
}

if found_idx is None:
    bucket.append(new_entry)
else:
    bucket[found_idx] = new_entry

with open(out_path, "w", encoding="utf-8") as f:
    json.dump(existing, f, indent=2, sort_keys=False)
    f.write("\n")
PY

echo "[claude-code-hook] projected $canonical -> $out"
