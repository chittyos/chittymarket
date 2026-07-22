#!/usr/bin/env python3
"""Drift + orphan audit for the canonical -> runtime projection pipeline.

Computes a canonical x declared-runtime sync matrix against live repo state and
classifies every cell. This is the read-only authority that `dispatch.sh audit`
prints and `dispatch.sh reconcile` acts on. It is deliberately a *reporting view*
over the same path resolution `sync` uses (lib/resolve_output.py), so audit can
never disagree with sync about where a canonical projects to.

Drift classes (per cell = one canonical x one declared runtime):
  IN_SYNC         projection bytes == recorded sentinel == re-projection of canonical
  CANON_AHEAD     canonical edited since last sync (canonical_sha != recorded)  -> needs sync
  PROJ_DRIFT      projection bytes != recorded sentinel, canonical unchanged    -> direct edit to a derived file
  MISSING_PROJ    declared runtime has no projected file on disk                -> never projected / deleted
  NEVER_SYNCED    canonical has no .dispatch-state entry at all                 -> bootstrap needed

Orphan classes (not tied to a declared cell):
  ORPHAN_TARGET   .dispatch-state records a runtime the canonical no longer declares
  ORPHAN_PROJ     a file exists in a projection location with no canonical backing

Exit code: 0 if fully clean, 1 if any drift/orphan found, 2 on hard error.
"""
import json
import os
import re
import shutil
import subprocess
import sys

sys.path.insert(0, os.path.dirname(__file__))
from resolve_output import resolve, _MAP  # noqa: E402

try:
    import yaml
except ImportError:
    sys.stderr.write("[audit] PyYAML required (pip install pyyaml)\n")
    sys.exit(2)

_FM_RE = re.compile(r"^---\n(.*?\n)---\n", re.DOTALL)


def git_hash(path):
    """git hash-object of a file, or None if absent."""
    if not os.path.exists(path):
        return None
    return subprocess.check_output(["git", "hash-object", path], text=True).strip()


def parse_frontmatter(path):
    src = open(path, encoding="utf-8").read()
    m = _FM_RE.match(src)
    fm = yaml.safe_load(m.group(1)) if m else {}
    if not isinstance(fm, dict):
        raise ValueError(f"{path}: frontmatter must be a mapping")
    return fm


def declared_runtimes(fm):
    val = fm.get("runtimes", [])
    if val is None:
        return []
    if not isinstance(val, list):
        raise ValueError("`runtimes` must be a list")
    return [str(r).strip() for r in val if str(r).strip()]


def reproject_sha(repo_root, adapter, canonical, out):
    """Re-run the adapter to a temp path and return the SHA it *would* produce.

    This is what distinguishes CANON_AHEAD (canonical changed, re-projection
    differs from sentinel) from PROJ_DRIFT (canonical unchanged, on-disk file
    edited). It also catches adapter non-determinism (re-projection != sentinel
    with no canonical change).
    """
    import tempfile
    with tempfile.TemporaryDirectory() as temp_dir:
        tmp = os.path.join(temp_dir, os.path.basename(out))
        # Merge adapters (notably claude-code-mcp) require the existing
        # projection as their input baseline. Seed the temporary target with
        # that baseline; using an empty NamedTemporaryFile produces invalid
        # JSON and does not model what sync actually does.
        if os.path.exists(out):
            shutil.copy2(out, tmp)
        subprocess.run([adapter, canonical, tmp], check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        return git_hash(tmp)


def audit(repo_root):
    canonical_dir = os.path.join(repo_root, "canonical")
    state_dir = os.path.join(canonical_dir, ".dispatch-state")
    cells = []        # per (canonical, runtime) findings
    orphans = []

    # Track every projection path we legitimately expect, to find ORPHAN_PROJ later.
    expected_proj_paths = set()

    # Walk canonicals: canonical/<sub>/<name>.md
    canonicals = []
    for sub in sorted(os.listdir(canonical_dir)):
        subdir = os.path.join(canonical_dir, sub)
        if not os.path.isdir(subdir) or sub == ".dispatch-state":
            continue
        for fn in sorted(os.listdir(subdir)):
            if fn.endswith(".md") and fn != "README.md":
                canonicals.append((sub, fn[:-3], os.path.join(subdir, fn)))

    for sub, name, can in canonicals:
        fm = parse_frontmatter(can)
        plugin = str(fm.get("plugin", "")).strip()
        kind = str(fm.get("kind", "agent") or "agent").strip()
        runtimes = declared_runtimes(fm)
        can_sha = git_hash(can)
        st_path = os.path.join(state_dir, sub, f"{name}.json")
        state = json.load(open(st_path)) if os.path.exists(st_path) else None

        if state is None:
            for rt in runtimes:
                cells.append(dict(cls="NEVER_SYNCED", canonical=f"{sub}/{name}",
                                  runtime=rt, detail="no .dispatch-state entry"))
            continue

        recorded_can = state.get("canonical_sha")
        recorded_targets = state.get("targets", {})

        for rt in runtimes:
            try:
                out, adapter = resolve(repo_root, plugin, name, kind, rt)
            except KeyError:
                cells.append(dict(cls="MISSING_PROJ", canonical=f"{sub}/{name}",
                                  runtime=rt, detail=f"unknown (runtime={rt}, kind={kind})"))
                continue
            expected_proj_paths.add(os.path.normpath(out))
            cur_sha = git_hash(out)
            sentinel = recorded_targets.get(rt)

            if cur_sha is None:
                cells.append(dict(cls="MISSING_PROJ", canonical=f"{sub}/{name}",
                                  runtime=rt, detail=f"{os.path.relpath(out, repo_root)} absent"))
                continue
            if sentinel is None:
                cells.append(dict(cls="NEVER_SYNCED", canonical=f"{sub}/{name}",
                                  runtime=rt, detail="declared runtime never recorded in state"))
                continue
            if cur_sha == sentinel and can_sha == recorded_can:
                cells.append(dict(cls="IN_SYNC", canonical=f"{sub}/{name}", runtime=rt, detail=""))
                continue
            # Something diverged. Re-project to classify.
            would = reproject_sha(repo_root, adapter, can, out)
            if can_sha != recorded_can:
                cells.append(dict(cls="CANON_AHEAD", canonical=f"{sub}/{name}", runtime=rt,
                                  detail="canonical edited since last sync; re-sync to project"))
            elif cur_sha != sentinel:
                cells.append(dict(cls="PROJ_DRIFT", canonical=f"{sub}/{name}", runtime=rt,
                                  detail="projection edited directly; canonical is authoritative",
                                  would_reproject_to=would, recorded=sentinel, on_disk=cur_sha,
                                  canonical_path=os.path.relpath(can, repo_root),
                                  out_path=os.path.relpath(out, repo_root)))
            else:
                cells.append(dict(cls="IN_SYNC", canonical=f"{sub}/{name}", runtime=rt, detail=""))

        # ORPHAN_TARGET: state records a runtime the canonical no longer declares.
        for rt in recorded_targets:
            if rt not in runtimes:
                orphans.append(dict(cls="ORPHAN_TARGET", canonical=f"{sub}/{name}", runtime=rt,
                                    detail="recorded in state but no longer declared in canonical"))

    # ORPHAN_PROJ: files sitting in projection locations with no canonical backing.
    # Scan each known projection directory shape under plugins/.
    plugins_dir = os.path.join(repo_root, "plugins")
    if os.path.isdir(plugins_dir):
        for plugin in sorted(os.listdir(plugins_dir)):
            pdir = os.path.join(plugins_dir, plugin)
            if not os.path.isdir(pdir):
                continue
            # Only audit projection dirs that are exclusively generated outputs.
            for rel in ("codex-skills", "openclaw-agents", "claude-skills", "chatgpt-apps"):
                proj_root = os.path.join(pdir, rel)
                if not os.path.isdir(proj_root):
                    continue
                for dirpath, _dirs, files in os.walk(proj_root):
                    for f in files:
                        fp = os.path.normpath(os.path.join(dirpath, f))
                        if fp not in expected_proj_paths:
                            orphans.append(dict(cls="ORPHAN_PROJ", canonical="-", runtime=rel,
                                                detail=os.path.relpath(fp, repo_root)))

    return cells, orphans


def main(argv):
    repo_root = subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip()
    as_json = "--json" in argv[1:]
    cells, orphans = audit(repo_root)

    drift = [c for c in cells if c["cls"] != "IN_SYNC"]
    findings = drift + orphans

    if as_json:
        print(json.dumps({
            "repo": repo_root,
            "summary": {
                "canonicals_x_runtime_cells": len(cells),
                "in_sync": len(cells) - len(drift),
                "drift": len(drift),
                "orphans": len(orphans),
                "total_findings": len(findings),
            },
            "findings": findings,
        }, indent=2))
        return 1 if findings else 0

    # Human matrix.
    by_class = {}
    for c in cells:
        by_class.setdefault(c["cls"], 0)
        by_class[c["cls"]] += 1
    print("=== dispatch audit — canonical × runtime sync matrix ===\n")
    print(f"  cells: {len(cells)}   in-sync: {by_class.get('IN_SYNC', 0)}   "
          f"drift: {len(drift)}   orphans: {len(orphans)}\n")
    if not findings:
        print("  \033[0;32mAll clear — every declared projection matches its canonical.\033[0m")
        return 0
    for f in findings:
        loc = f["canonical"] if f["canonical"] != "-" else ""
        print(f"  \033[0;33m{f['cls']:<13}\033[0m {loc} -> {f['runtime']}")
        if f.get("detail"):
            print(f"               {f['detail']}")
    print(f"\n  {len(findings)} finding(s). Run `dispatch.sh reconcile` to heal "
          f"(canonical-wins), or `--json` for machine output.")
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
