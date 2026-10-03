#!/usr/bin/env bash
# claude-code-workflow.sh — project a canonical workflow definition to a Claude Code
# plugin workflow script (plugins/<plugin>/workflows/<name>.js), invoked from any
# session as Workflow({name: "<plugin>:<name>"}).
#
# Usage:
#   claude-code-workflow.sh <canonical-path> <output-path>
#
# Canonical shape (canonical/workflows/<name>.md, kind: workflow):
#   ---
#   name: <name>
#   kind: workflow
#   description: |
#     <prose>
#   plugin: <home-plugin>
#   runtimes: [claude-code]
#   ---
#   <prose explaining the design — NOT projected>
#
#   ````js
#   export const meta = { name: '<name>', ... }
#   ...script body...
#   ````
#
# Why markdown + one fenced block rather than a bare .js canonical: every canonical
# discoverer (dispatch.sh, lib/audit.py, scripts/market-reconcile.py,
# scripts/check-agent-identity.py) globs *.md and reads YAML frontmatter for
# kind/plugin/runtimes/identity/overlay. A .js canonical would need a second
# metadata parser in each of them.
#
# Contract:
#   - Exactly ONE opening fence line whose info string is `js` or `javascript`
#     (```js, ````js, ...). Zero or several is an error. Use ```` because workflow
#     scripts contain backticks.
#   - The block closes on the LAST line in the body that equals the opening fence.
#     A fence-looking line inside a template literal therefore cannot truncate the
#     script. The price is that a later fenced block of the SAME fence length would
#     be swallowed, so any later line that opens a same-length fence WITH an info
#     string (````text, ````bash, ...) is rejected outright. A later same-length
#     block with NO info string is not detectable structurally; the syntax check
#     below makes swallowing it LIKELY to fail, not guaranteed. Use a shorter fence
#     (```) for any prose code block after the script.
#   - The block is written verbatim, nothing prepended: the Workflow host expects the
#     file to begin with `export const meta`, so the adapter enforces that too.
#   - Inline includes. Workflow scripts cannot import, so a column-0 marker line
#     `// @inline <file>.js` inside the block is replaced by that sibling file
#     (canonical/<kind>/<file>.js) with line-leading `export ` keywords removed, between
#     deterministic BEGIN/END banners carrying its sha256. The grammar and every rule
#     (bare sibling name, no imports, only export const|let|function, no nesting, no
#     duplicates) live in lib/inline_includes.py, shared with lib/audit.py so audit
#     re-projects exactly the canonicals the adapter expands. No marker: output is the
#     block verbatim. The node --check below runs on the EXPANDED script, so a name the
#     include and the script both declare fails the projection.
#   - `meta.name` must equal the frontmatter name. `name` may appear anywhere among
#     meta's top-level keys (it does not have to be first).
#   - The extracted script must pass `node --check` in the host's shape (top-level
#     `return` is legal there, so the body is wrapped in `export default async
#     function(){}` and `export const meta` becomes `const meta`). A truncation
#     inside a template literal leaves an unterminated backtick and fails here.
#   - Nothing is created on failure: the output directory is made only after every
#     check passes, and the file is written to a temp sibling then renamed, so a
#     failed run never leaves a partial or stale-overwritten projection.
#   - Output always ends with exactly one newline — byte-stable for audit re-projection.
#   - Any failure exits non-zero.
set -euo pipefail

canonical="${1:-}"
out="${2:-}"
[ -n "$canonical" ] && [ -n "$out" ] || { echo "usage: $0 <canonical-path> <output-path>" >&2; exit 2; }
[ -f "$canonical" ] || { echo "canonical not found: $canonical" >&2; exit 2; }

lib_dir="$(cd "$(dirname "$0")/../lib" && pwd)"

python3 - "$canonical" "$out" "$lib_dir" <<'PY'
import os, re, shutil, subprocess, sys, tempfile
import yaml

canonical_path, out_path, lib_dir = sys.argv[1], sys.argv[2], sys.argv[3]
sys.path.insert(0, lib_dir)
from inline_includes import expand  # noqa: E402
src = open(canonical_path, encoding="utf-8").read()

m = re.match(r"^---\n(.*?\n)---\n(.*)$", src, re.DOTALL)
if not m:
    sys.exit(f"no frontmatter in {canonical_path}")
try:
    fm = yaml.safe_load(m.group(1)) or {}
except yaml.YAMLError as e:
    sys.exit(f"canonical frontmatter is not valid YAML: {e}")
if not isinstance(fm, dict):
    sys.exit(f"{canonical_path}: frontmatter must be a mapping")
for req in ("name", "description"):
    if not fm.get(req):
        sys.exit(f"canonical missing required field: {req}")
if str(fm.get("kind", "")).strip() != "workflow":
    sys.exit(f"{canonical_path}: kind must be 'workflow' for this adapter, got {fm.get('kind')!r}")

lines = m.group(2).split("\n")
opens = [(i, mo.group(1)) for i, l in enumerate(lines)
         for mo in [re.match(r"^(`{3,})\s*(js|javascript)\s*$", l, re.IGNORECASE)] if mo]
if len(opens) != 1:
    sys.exit(f"{canonical_path}: expected exactly one ```js fenced block, found {len(opens)}")
start, fence = opens[0]
closes = [j for j in range(start + 1, len(lines)) if lines[j].rstrip() == fence]
if not closes:
    sys.exit(f"{canonical_path}: unterminated {fence} fence opened at body line {start + 1}")
later = [j for j in range(start + 1, len(lines))
         if re.match(r"^" + re.escape(fence) + r"(?!`)\s*\S", lines[j])]
if later:
    sys.exit(f"{canonical_path}: another {fence} fenced block opens at body line {later[0] + 1} after the js block; "
             f"it would be swallowed into the script. Use a shorter fence for prose code blocks.")
script = "\n".join(lines[start + 1:closes[-1]]).strip("\n") + "\n"

if not script.startswith("export const meta"):
    sys.exit(f"{canonical_path}: workflow script must begin with `export const meta` (the Workflow host requires it)")

def meta_top_level_name(text):
    """Return the string value of `name` among meta's TOP-LEVEL keys, in any position.
    A small scanner: tracks bracket depth and skips string/template literals and comments, so a
    nested `name:` (e.g. inside phases) or one inside a string is never mistaken for meta.name."""
    m = re.match(r"export const meta\s*=\s*\{", text)
    if not m:
        return None
    i, depth, n = m.end(), 0, len(text)
    while i < n:
        c = text[i]
        if c in "'\"`":
            q = c; i += 1
            while i < n and text[i] != q:
                i += 2 if text[i] == "\\" else 1
            i += 1; continue
        if text.startswith("//", i):
            i = text.find("\n", i); i = n if i < 0 else i; continue
        if text.startswith("/*", i):
            i = text.find("*/", i); i = n if i < 0 else i + 2; continue
        if c in "{[(":
            depth += 1
        elif c in "}])":
            if depth == 0:
                return None          # end of meta, no top-level name
            depth -= 1
        elif depth == 0:
            km = re.compile(r"(?<![\w$])name\s*:\s*(['\"])([^'\"]*)\1").match(text, i)
            if km and (i == 0 or not (text[i - 1].isalnum() or text[i - 1] in "_$")):
                return km.group(2)
        i += 1
    return None

meta_name = meta_top_level_name(script)
if meta_name != fm["name"]:
    sys.exit(f"{canonical_path}: meta.name {meta_name!r} != frontmatter name {fm['name']!r}")

try:
    script = expand(script, os.path.dirname(os.path.abspath(canonical_path)))
except ValueError as e:
    sys.exit(f"{canonical_path}: {e}")

node = shutil.which("node")
if not node:
    sys.exit(f"{canonical_path}: node is required to syntax-check the workflow script; refusing to project unchecked")
wrapped = ("export default async function (args, agent, parallel, phase, log) {\n"
           + "const meta" + script[len("export const meta"):] + "\n}\n")
with tempfile.TemporaryDirectory() as td:
    chk = os.path.join(td, "check.mjs")
    with open(chk, "w", encoding="utf-8") as f:
        f.write(wrapped)
    p = subprocess.run([node, "--check", chk], capture_output=True, text=True)
    if p.returncode != 0:
        detail = "\n".join(l for l in p.stderr.splitlines() if l.strip())[-600:]
        sys.exit(f"{canonical_path}: extracted script fails node --check (truncated or overran its fence?):\n{detail}")

out_dir = os.path.dirname(os.path.abspath(out_path))
os.makedirs(out_dir, exist_ok=True)
fd, tmp = tempfile.mkstemp(dir=out_dir, prefix=".wf-", suffix=".tmp")
try:
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(script)
    os.replace(tmp, out_path)
except BaseException:
    if os.path.exists(tmp):
        os.unlink(tmp)
    raise
PY

echo "[claude-code-workflow] projected $canonical -> $out"
