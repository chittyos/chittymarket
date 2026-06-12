#!/usr/bin/env python3
"""Single source of truth for (runtime, kind) -> projection output path + adapter.

Shared by dispatch.sh `sync`, `audit`, and `reconcile` so the three can never
disagree about where a canonical projects to. Adding a new runtime/kind here
updates all three at once.

CLI:
    resolve_output.py <repo_root> <plugin> <name> <kind> <runtime>
        -> prints "<out_path>\t<adapter_path>" or exits 3 if unknown.

Library:
    from resolve_output import resolve  # resolve(repo_root, plugin, name, kind, runtime)
"""
import os
import sys

# (runtime, kind) -> (relative output template, adapter filename)
# Templates use {plugin} and {name}. Adapter paths are relative to scripts/adapters/.
_MAP = {
    ("claude-code", "agent"):       ("plugins/{plugin}/agents/{name}.md",            "claude-code-agent.sh"),
    ("claude-code", "skill"):       ("plugins/{plugin}/skills/{name}/SKILL.md",      "claude-code-agent.sh"),
    ("claude-code", "command"):     ("plugins/{plugin}/commands/{name}.md",          "claude-code-agent.sh"),
    ("claude-code", "hook"):        ("plugins/{plugin}/hooks/hooks.json",            "claude-code-hook.sh"),
    ("claude-code", "mcp-server"):  ("plugins/{plugin}/.mcp.json",                   "claude-code-mcp.sh"),
    ("codex", "agent"):             ("plugins/{plugin}/codex-skills/{name}/SKILL.md", "codex-skill.sh"),
    ("codex", "skill"):             ("plugins/{plugin}/codex-skills/{name}/SKILL.md", "codex-skill.sh"),
    ("openclaw", "agent"):          ("plugins/{plugin}/openclaw-agents/{name}.yaml", "openclaw-agent.sh"),
    ("claude-skills", "tool"):      ("plugins/{plugin}/claude-skills/{name}.json",   "claude-skills.sh"),
    ("chatgpt-apps", "tool"):       ("plugins/{plugin}/chatgpt-apps/{name}.json",    "chatgpt-apps.sh"),
}

KNOWN_RUNTIMES = sorted({rt for rt, _ in _MAP})


def resolve(repo_root, plugin, name, kind, runtime):
    """Return (abs_out_path, abs_adapter_path) or raise KeyError for unknown (runtime, kind)."""
    rel_out, adapter = _MAP[(runtime, kind)]
    out = os.path.join(repo_root, rel_out.format(plugin=plugin, name=name))
    adapter_path = os.path.join(os.path.dirname(__file__), "..", "adapters", adapter)
    return out, os.path.normpath(adapter_path)


def main(argv):
    if len(argv) != 6:
        sys.stderr.write("usage: resolve_output.py <repo_root> <plugin> <name> <kind> <runtime>\n")
        return 2
    repo_root, plugin, name, kind, runtime = argv[1:]
    try:
        out, adapter = resolve(repo_root, plugin, name, kind, runtime)
    except KeyError:
        sys.stderr.write(
            f"unknown runtime '{runtime}' for kind '{kind}'. "
            f"Known runtimes: {', '.join(KNOWN_RUNTIMES)}.\n"
        )
        return 3
    print(f"{out}\t{adapter}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
