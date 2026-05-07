#!/usr/bin/env bash
# claude-code-agent.sh — project a canonical agent definition to Claude Code agent format.
#
# Usage:
#   claude-code-agent.sh <canonical-path> <output-path>
#
# Behavior:
#   - Strips canonical-only top-level frontmatter keys (kind, classification, runtimes,
#     plugin, runtime_overrides) and their indented children. All other frontmatter
#     bytes are preserved verbatim — important because Claude Code agent descriptions
#     often contain literal escape sequences that aren't safe to YAML round-trip.
#   - If runtime_overrides.claude-code exists, its keys are appended to the projected
#     frontmatter (overriding any same-named keys above).
#   - Writes result to <output-path>.
#   - Idempotent.
set -euo pipefail

canonical="${1:-}"
out="${2:-}"
[ -n "$canonical" ] && [ -n "$out" ] || { echo "usage: $0 <canonical-path> <output-path>" >&2; exit 2; }
[ -f "$canonical" ] || { echo "canonical not found: $canonical" >&2; exit 2; }

mkdir -p "$(dirname "$out")"

python3 - "$canonical" "$out" <<'PY'
import sys, re

canonical_path, out_path = sys.argv[1], sys.argv[2]
src = open(canonical_path, "r", encoding="utf-8").read()

m = re.match(r"^---\n(.*?\n)---\n(.*)$", src, re.DOTALL)
if not m:
    sys.exit(f"no frontmatter in {canonical_path}")
fm_text = m.group(1)
body = m.group(2).lstrip("\n")

CANONICAL_ONLY = {"kind", "classification", "runtimes", "plugin", "runtime_overrides"}

# Walk lines. A top-level key starts at column 0 with `key:`. Strip canonical-only
# keys plus their indented children. Capture runtime_overrides.claude-code subtree.
lines = fm_text.splitlines()
i = 0
kept = []
override_lines = []
in_overrides = False
in_overrides_claude = False
overrides_indent = None
claude_indent = None

def is_top_key(line):
    return bool(re.match(r"^[A-Za-z_][\w-]*\s*:", line))

while i < len(lines):
    line = lines[i]
    if is_top_key(line):
        key = line.split(":", 1)[0].strip()
        if key == "runtime_overrides":
            # Capture claude-code subtree, drop everything else.
            i += 1
            while i < len(lines) and (lines[i].startswith(" ") or lines[i].startswith("\t") or lines[i] == ""):
                sub = lines[i]
                stripped = sub.lstrip()
                indent = len(sub) - len(stripped)
                if indent == 2 and stripped.startswith("claude-code:"):
                    # Enter claude-code block: capture nested lines, re-indent to 0.
                    i += 1
                    while i < len(lines) and (lines[i].startswith("    ") or lines[i].startswith("\t\t") or lines[i] == ""):
                        nested = lines[i]
                        if nested == "":
                            override_lines.append("")
                        else:
                            override_lines.append(nested[2:])  # strip 2 of the 4 spaces
                        i += 1
                    continue
                i += 1
            continue
        if key in CANONICAL_ONLY:
            i += 1
            # Skip indented children.
            while i < len(lines) and (lines[i].startswith(" ") or lines[i].startswith("\t")):
                i += 1
            continue
    kept.append(line)
    i += 1

# Strip leading/trailing blank lines.
while kept and kept[0].strip() == "":
    kept.pop(0)
while kept and kept[-1].strip() == "":
    kept.pop()

projected_fm = "\n".join(kept)
if override_lines:
    while override_lines and override_lines[0].strip() == "":
        override_lines.pop(0)
    while override_lines and override_lines[-1].strip() == "":
        override_lines.pop()
    if override_lines:
        projected_fm += "\n" + "\n".join(override_lines)

open(out_path, "w", encoding="utf-8").write(f"---\n{projected_fm}\n---\n\n{body}")
PY

echo "[claude-code-agent] projected $canonical -> $out"
