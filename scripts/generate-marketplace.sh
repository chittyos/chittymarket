#!/usr/bin/env bash
# generate-marketplace.sh v2 — Generate .claude-plugin/marketplace.json from plugins/ + external repos
# Includes categories, keywords, dependencies, and GitHub-sourced plugins.
# Run after adding/removing plugins to keep the native manifest in sync.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
PLUGINS_DIR="$REPO_DIR/plugins"
OUTPUT="$REPO_DIR/.claude-plugin/marketplace.json"

echo "=== generate-marketplace.sh v2 ==="
echo "Scanning plugins in $PLUGINS_DIR..."

# GitHub-sourced plugins (not in plugins/ directory)
# Format: name|description|version|repo|category|keywords
GITHUB_PLUGINS=(
  'chittyhelper|Architectural navigation — ask which service handles X? queries against the ChittyOS ecosystem|1.0.0|CHITTYOS/chittyhelper|ecosystem|chittyos,architecture,navigation,services'
  'chittyagent|ChittyOS session lifecycle — authenticated bootstrap, ecosystem routing, session identity, and Mercury finance|0.1.0|CHITTYOS/chittyagent|ecosystem|chittyos,session,bootstrap,identity'
  'chittycommand|Life management dashboard — query finances, manage disputes, monitor syncs, get AI-powered recommendations|0.1.0|CHITTYOS/chittycommand|productivity|dashboard,finance,disputes,obligations,cashflow'
  'legal-arsenal|Legal case management — evidence standards, chain of custody, adversarial analysis with ChittyStorage integration|1.0.0|CHITTYOS/legal-cases|legal|legal,evidence,cases,disputes,custody'
)

# Category map for inline plugins (read from marketplace.json native manifest)
declare -A CATEGORY_MAP
CATEGORY_MAP[chittyos-core]="ecosystem"
CATEGORY_MAP[chittyos-devops]="operations"
CATEGORY_MAP[chittyos-legal]="legal"
CATEGORY_MAP[chittyos-governance]="security"
CATEGORY_MAP[chittyos-proxy-agents]="integrations"
CATEGORY_MAP[chittymarket-manager]="ecosystem"
CATEGORY_MAP[chittyos-mcp]="ecosystem"
CATEGORY_MAP[neon-mcp]="database"

# Keywords map
declare -A KEYWORDS_MAP
KEYWORDS_MAP[chittyos-core]="chittyos,session,context,agents,schema,canon"
KEYWORDS_MAP[chittyos-devops]="deploy,health,registry,pipelines,wrangler,compliance"
KEYWORDS_MAP[chittyos-legal]="legal,evidence,disputes,docket,cases,custody"
KEYWORDS_MAP[chittyos-governance]="governance,hooks,entity-types,chittyid,deploy-gate,schema"
KEYWORDS_MAP[chittyos-proxy-agents]="notion,chatgpt,cloudflare,proxy,agent"
KEYWORDS_MAP[chittymarket-manager]="marketplace,market,artifacts,toggle,manage"
KEYWORDS_MAP[chittyos-mcp]="mcp,chittyos,gateway,standalone"
KEYWORDS_MAP[neon-mcp]="neon,postgres,database,sql,standalone"

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
  desc=$(python3 -c "import json; d=json.load(open('$plugin_json'))['description']; print(d.replace('\"', '\\\\\"'))")
  version=$(python3 -c "import json; print(json.load(open('$plugin_json')).get('version','1.0.0'))")
  requires=$(python3 -c "import json; r=json.load(open('$plugin_json')).get('requires',[]); print(','.join(r) if r else '')")

  category="${CATEGORY_MAP[$name]:-ecosystem}"
  keywords="${KEYWORDS_MAP[$name]:-}"

  if [ "$first" = true ]; then
    first=false
  else
    echo "," >> "$OUTPUT"
  fi

  # Build keywords JSON array
  kw_json="[]"
  if [ -n "$keywords" ]; then
    kw_json=$(python3 -c "print('[' + ', '.join('\"' + k.strip() + '\"' for k in '$keywords'.split(',')) + ']')")
  fi

  # Write plugin entry
  cat >> "$OUTPUT" <<ENTRY
    {
      "name": "$name",
      "description": "$desc",
      "version": "$version",
      "source": "./plugins/$(basename "$plugin_dir")",
      "strict": false,
      "category": "$category",
      "keywords": $kw_json
    }
ENTRY

  echo "  OK: $name (category=$category, $(echo "$keywords" | tr ',' ' ' | wc -w | tr -d ' ') keywords)"
done

# Add GitHub-sourced plugins
for entry in "${GITHUB_PLUGINS[@]}"; do
  IFS='|' read -r name desc version repo category keywords <<< "$entry"

  echo "," >> "$OUTPUT"

  kw_json=$(python3 -c "print('[' + ', '.join('\"' + k.strip() + '\"' for k in '$keywords'.split(',')) + ']')")

  cat >> "$OUTPUT" <<ENTRY
    {
      "name": "$name",
      "description": "$desc",
      "version": "$version",
      "source": {
        "source": "github",
        "repo": "$repo"
      },
      "strict": false,
      "category": "$category",
      "keywords": $kw_json
    }
ENTRY

  echo "  OK: $name (github:$repo, category=$category)"
done

# Close the JSON
cat >> "$OUTPUT" <<'FOOTER'
  ]
}
FOOTER

inline_count=$(find "$PLUGINS_DIR" -name plugin.json | wc -l | tr -d ' ')
github_count=${#GITHUB_PLUGINS[@]}
total=$((inline_count + github_count))

echo ""
echo "Generated: $OUTPUT"
echo "  Inline plugins: $inline_count"
echo "  GitHub plugins: $github_count"
echo "  Total: $total entries"
