#!/usr/bin/env python3
"""Generate the OpenAI/ChatGPT workspace marketplace projection.

The Claude marketplace remains the broader authoring catalog and may contain
legacy external GitHub source entries. OpenAI workspace sync consumes the
repo-local projection at .agents/plugins/marketplace.json, which intentionally
includes only plugin directories that exist inside this repository.

External capabilities are not cloned here. They remain available through their
canonical app/agent/MCP surfaces until their owning repositories expose a
portable OpenAI plugin package.
"""

from __future__ import annotations

import json
import pathlib
import sys


def title_category(value: str) -> str:
    return value.replace("-", " ").replace("_", " ").title()


def main() -> int:
    root = pathlib.Path(__file__).resolve().parents[1]
    source_path = root / ".claude-plugin" / "marketplace.json"
    output_path = root / ".agents" / "plugins" / "marketplace.json"

    source = json.loads(source_path.read_text())
    plugins = []
    held = []

    for entry in source.get("plugins", []):
        source_value = entry.get("source")
        if isinstance(source_value, str) and source_value.startswith("./plugins/"):
            plugins.append(
                {
                    "name": entry["name"],
                    "source": {
                        "source": "local",
                        "path": source_value,
                    },
                    "policy": {
                        "installation": "AVAILABLE",
                        "authentication": "ON_INSTALL",
                    },
                    "category": title_category(entry.get("category", "ecosystem")),
                }
            )
        else:
            held.append(entry.get("name", "<unnamed>"))

    output = {
        "name": "chittymarket",
        "interface": {"displayName": "ChittyMarket"},
        "plugins": plugins,
    }

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(output, indent=2) + "\n")

    print(f"[openai-marketplace] wrote {output_path.relative_to(root)} ({len(plugins)} plugins)")
    if held:
        print(
            "[openai-marketplace] held non-local entries from OpenAI projection: "
            + ", ".join(held)
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
