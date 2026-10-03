#!/usr/bin/env python3
"""Inline-include grammar for workflow canonicals — ONE definition shared by the
claude-code-workflow adapter (which expands includes) and lib/audit.py (which must
re-project any canonical that has them), so the two cannot disagree about what a
canonical depends on.

A workflow script cannot import (the Workflow host runs one self-contained file), so a
canonical that wants shared pure code names a sibling file with a marker line, written at
column 0 inside its fenced js block:

    // @inline gauntlet.core.js

The adapter replaces that line with the sibling's contents (canonical/<kind>/<file>),
with each line-leading `export ` keyword removed, between deterministic BEGIN/END banners.

Include contract (any violation is a ValueError, and the adapter exits non-zero):
  - the name is a bare file name ending in .js: no path separator, no `..`, no leading dot
  - the file exists next to the canonical and is valid UTF-8
  - each file is included at most once per script
  - top-level exports are only `export const|let|function|async function` at column 0;
    `export default`, `export {...}`, `export * from`, and any column-0 `import` are rejected,
    because none of them can survive being inlined into a function body
  - the included file contains no inline markers of its own (no nesting)
  - the column-0 `export` lines are exactly the module's exports as node loads it, so the
    context-blind strip can never touch a line inside a template literal or comment
"""
import base64
import hashlib
import json
import os
import re
import shutil
import subprocess

INLINE_RE = re.compile(r"^// @inline (\S+)[ \t]*$", re.MULTILINE)
_NAME_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*\.js$")
_EXPORT_OK_RE = re.compile(r"^export (?=(?:const|let|function|async function)\b)", re.MULTILINE)
_EXPORT_ANY_RE = re.compile(r"^export\b", re.MULTILINE)
_IMPORT_RE = re.compile(r"^import\b", re.MULTILINE)
_EXPORT_DECL_RE = re.compile(r"^export (?:const|let|function|async function)\s+([A-Za-z_$][\w$]*)", re.MULTILINE)


def _node_exports(name, text):
    """The export names node itself sees when it loads `text` as a module. This is the
    independent check on the column-0 regex: a line inside a template literal or comment that
    merely starts with `export const ...` would be counted by the regex but not by node, and is
    rejected instead of being silently rewritten."""
    node = shutil.which("node")
    if not node:
        raise ValueError(f"inline include {name!r}: node is required to verify its exports")
    url = "data:text/javascript;base64," + base64.b64encode(text.encode("utf-8")).decode()
    p = subprocess.run([node, "--input-type=module", "-e",
                        f"const m = await import({json.dumps(url)}); console.log(JSON.stringify(Object.keys(m).sort()))"],
                       capture_output=True, text=True)
    if p.returncode != 0:
        tail = (p.stderr.strip().splitlines() or ["(no stderr)"])[-1]
        raise ValueError(f"inline include {name!r} does not load as a module: {tail[:200]}")
    return json.loads(p.stdout)


def inline_names(text):
    """Every include name referenced by a marker line in `text`, in order."""
    return INLINE_RE.findall(text)


def has_inline(path):
    """True if the file at `path` contains any inline marker. Audit uses this on the whole
    canonical (prose included): a superset of what the adapter expands, so audit can only
    over-check, never miss a dependency."""
    with open(path, encoding="utf-8") as f:
        return bool(INLINE_RE.search(f.read()))


def _load(name, canonical_dir):
    if not _NAME_RE.match(name) or ".." in name:
        raise ValueError(f"inline include {name!r} must be a bare sibling file name ending in .js")
    path = os.path.join(canonical_dir, name)
    if not os.path.isfile(path):
        raise ValueError(f"inline include {name!r} not found next to the canonical ({path})")
    with open(path, "rb") as f:
        raw = f.read()
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as e:
        raise ValueError(f"inline include {name!r} is not valid UTF-8: {e}")
    if INLINE_RE.search(text):
        raise ValueError(f"inline include {name!r} contains an inline marker; nesting is not supported")
    if _IMPORT_RE.search(text):
        raise ValueError(f"inline include {name!r} has an import; an inlined file must be self-contained")
    stripped = _EXPORT_OK_RE.sub("", text)
    bad = _EXPORT_ANY_RE.search(stripped)
    if bad:
        line = stripped[bad.start():].split("\n", 1)[0]
        raise ValueError(f"inline include {name!r}: unsupported export form {line[:60]!r} "
                         f"(only export const|let|function|async function)")
    declared = sorted(_EXPORT_DECL_RE.findall(text))
    actual = _node_exports(name, text)
    if declared != actual:
        raise ValueError(f"inline include {name!r}: column-0 export lines {declared} do not match the module's real "
                         f"exports {actual}; an `export ...` line inside a string or comment would be rewritten "
                         f"by inlining. Indent it or reword it.")
    return raw, stripped


def expand(script, canonical_dir):
    """Return `script` with every marker line replaced by its include. No marker: unchanged."""
    names = inline_names(script)
    if not names:
        return script
    dupes = sorted({n for n in names if names.count(n) > 1})
    if dupes:
        raise ValueError(f"inline include(s) referenced more than once: {', '.join(dupes)}")

    def sub(m):
        name = m.group(1)
        raw, body = _load(name, canonical_dir)
        digest = hashlib.sha256(raw).hexdigest()
        return (f"// ── BEGIN inlined {name} (sha256 {digest}) — generated from the canonical "
                f"include; edit that file, not this block.\n"
                f"{body.strip(chr(10))}\n"
                f"// ── END inlined {name}")

    return INLINE_RE.sub(sub, script)
