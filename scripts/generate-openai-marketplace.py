#!/usr/bin/env python3
"""Generate OpenAI/ChatGPT marketplace and portable plugin projections.

The Claude marketplace remains the broader authoring catalog and may contain
legacy external GitHub source entries. OpenAI repo marketplace sync consumes
.agents/plugins/marketplace.json and portable Agent Plugin packages under
plugins/<name>/plugin.json.

External capabilities are not copied into this repository. They remain held
until their owning repository exposes a portable package or a deliberate Git
marketplace projection is added.
"""

from __future__ import annotations

import json
import pathlib
import sys


AGENT_PLUGIN_SCHEMA = "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json"


def title_category(value: str) -> str:
    return value.replace("-", " ").replace("_", " ").title()


def portable_manifest(entry: dict) -> dict:
    """Project only fields supported by the portable Agent Plugins schema."""
    return {
        "$schema": AGENT_PLUGIN_SCHEMA,
        "name": entry["name"],
        "version": entry["version"],
        "description": entry["description"],
        "keywords": entry.get("keywords", []),
    }


def main() -> int:
    root = pathlib.Path(__file__).resolve().parents[1]
    source_path = root / ".claude-plugin" / "marketplace.json"
    output_path = root / ".agents" / "plugins" / "marketplace.json"

    source = json.loads(source_path.read_text())
    plugins = []
    held = []
    portable_count = 0

    for entry in source.get("plugins", []):
        source_value = entry.get("source")
        if isinstance(source_value, str) and source_value.startswith("./plugins/"):
            rel = pathlib.PurePosixPath(source_value)
            if len(rel.parts) != 2 or rel.parts[0] != "plugins":
                print(
                    f"ERROR: refusing non-direct plugin path in OpenAI projection: {source_value}",
                    file=sys.stderr,
                )
                return 1

            plugin_dir = root.joinpath(*rel.parts)
            if not plugin_dir.is_dir():
                print(
                    f"ERROR: local plugin directory does not exist: {source_value}",
                    file=sys.stderr,
                )
                return 1
            if plugin_dir.name != entry.get("name"):
                print(
                    f"ERROR: plugin directory/name mismatch: {source_value} != {entry.get('name')}",
                    file=sys.stderr,
                )
                return 1

            manifest_path = plugin_dir / "plugin.json"
            manifest_path.write_text(
                json.dumps(portable_manifest(entry), indent=2, ensure_ascii=False) + "\n"
            )
            portable_count += 1

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

    print(
        f"[openai-marketplace] wrote {output_path.relative_to(root)} "
        f"({len(plugins)} plugins; {portable_count} portable manifests)"
    )
    if held:
        print(
            "[openai-marketplace] held non-local entries from OpenAI projection: "
            + ", ".join(held)
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
