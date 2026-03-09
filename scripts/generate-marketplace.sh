#!/usr/bin/env bash
# generate-marketplace.sh — Generate .claude-plugin/marketplace.json from plugins/ directory
# This script scans the plugins/ directory and generates the native Claude Code marketplace manifest.
# Run after adding/removing plugins to keep the native manifest in sync.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
PLUGINS_DIR="$REPO_DIR/plugins"
OUTPUT="$REPO_DIR/.claude-plugin/marketplace.json"

echo "Scanning plugins in $PLUGINS_DIR..."

# Start building the JSON
cat > "$OUTPUT" <<'HEADER'
{
  "name": "chittymarket",
  "owner": {
    "name": "ChittyOS",
    "email": "dev@chitty.cc"
  },
  "metadata": {
    "description": "The ChittyOS ecosystem marketplace — skills, agents, hooks, and MCP servers for Claude Code. Install standalone or use with Ch1tty for orchestrated MCP management.",
    "version": "2.0.0"
  },
  "plugins": [
HEADER

# Collect inline plugins from plugins/ directory
first=true
for plugin_dir in "$PLUGINS_DIR"/*/; do
  plugin_json="$plugin_dir/.claude-plugin/plugin.json"
  if [ ! -f "$plugin_json" ]; then
    echo "  SKIP: $(basename "$plugin_dir") (no plugin.json)"
    continue
  fi

  name=$(python3 -c "import json; print(json.load(open('$plugin_json'))['name'])")
  desc=$(python3 -c "import json; print(json.load(open('$plugin_json'))['description'])")
  version=$(python3 -c "import json; print(json.load(open('$plugin_json')).get('version','1.0.0'))")

  if [ "$first" = true ]; then
    first=false
  else
    echo "," >> "$OUTPUT"
  fi

  # Write plugin entry
  printf '    {\n      "name": "%s",\n      "description": "%s",\n      "version": "%s",\n      "source": "./plugins/%s",\n      "strict": false\n    }' \
    "$name" "$desc" "$version" "$(basename "$plugin_dir")" >> "$OUTPUT"

  echo "  OK: $name"
done

# Close the JSON
cat >> "$OUTPUT" <<'FOOTER'

  ]
}
FOOTER

echo ""
echo "Generated: $OUTPUT"
echo "Plugins: $(grep -c '"name"' "$OUTPUT" | head -1) entries"
