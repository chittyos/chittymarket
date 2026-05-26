#!/usr/bin/env bash
# lint-plugins.sh — Detect conflicts across ChittyMarket plugins
# Checks for: duplicate skill triggers, overlapping agent names, hook conflicts, missing deps

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
PLUGINS_DIR="$REPO_DIR/plugins"
PROFILES="$REPO_DIR/profiles.json"
ERRORS=0
WARNINGS=0

red() { printf '\033[0;31m%s\033[0m\n' "$1"; }
yellow() { printf '\033[0;33m%s\033[0m\n' "$1"; }
green() { printf '\033[0;32m%s\033[0m\n' "$1"; }
dim() { printf '\033[0;90m%s\033[0m\n' "$1"; }

echo "=== ChittyMarket Plugin Lint ==="
echo ""

# --- 1. Check for duplicate skill names across plugins ---
echo "Checking skill names..."
declare -A SKILL_OWNERS
for plugin_dir in "$PLUGINS_DIR"/*/; do
  plugin_name=$(basename "$plugin_dir")
  if [ -d "$plugin_dir/skills" ]; then
    for skill_dir in "$plugin_dir"/skills/*/; do
      [ -d "$skill_dir" ] || continue
      skill_name=$(basename "$skill_dir")
      if [ -n "${SKILL_OWNERS[$skill_name]+x}" ]; then
        red "  ERROR: Skill '$skill_name' defined in both '${SKILL_OWNERS[$skill_name]}' and '$plugin_name'"
        ERRORS=$((ERRORS + 1))
      else
        SKILL_OWNERS[$skill_name]="$plugin_name"
        dim "  ok: $skill_name ($plugin_name)"
      fi
    done
  fi
done
echo ""

# --- 2. Check for duplicate agent names ---
echo "Checking agent names..."
declare -A AGENT_OWNERS
for plugin_dir in "$PLUGINS_DIR"/*/; do
  plugin_name=$(basename "$plugin_dir")
  if [ -d "$plugin_dir/agents" ]; then
    for agent_file in "$plugin_dir"/agents/*.md; do
      [ -f "$agent_file" ] || continue
      agent_name=$(basename "$agent_file" .md)
      if [ -n "${AGENT_OWNERS[$agent_name]+x}" ]; then
        red "  ERROR: Agent '$agent_name' defined in both '${AGENT_OWNERS[$agent_name]}' and '$plugin_name'"
        ERRORS=$((ERRORS + 1))
      else
        AGENT_OWNERS[$agent_name]="$plugin_name"
        dim "  ok: $agent_name ($plugin_name)"
      fi
    done
  fi
done
echo ""

# --- 3. Check for missing SKILL.md in skill directories ---
echo "Checking skill files..."
for plugin_dir in "$PLUGINS_DIR"/*/; do
  if [ -d "$plugin_dir/skills" ]; then
    for skill_dir in "$plugin_dir"/skills/*/; do
      [ -d "$skill_dir" ] || continue
      skill_name=$(basename "$skill_dir")
      if [ ! -f "$skill_dir/SKILL.md" ] && [ ! -f "$skill_dir/SKILL.md.disabled" ]; then
        red "  ERROR: Skill '$skill_name' in $(basename "$plugin_dir") has no SKILL.md"
        ERRORS=$((ERRORS + 1))
      else
        dim "  ok: $skill_name/SKILL.md"
      fi
    done
  fi
done
echo ""

# --- 3b. Check SKILL.md frontmatter has name: and description: ---
echo "Checking SKILL.md frontmatter..."
for plugin_dir in "$PLUGINS_DIR"/*/; do
  plugin_name=$(basename "$plugin_dir")
  skills_dir="$plugin_dir/skills"
  [ -d "$skills_dir" ] || continue
  for sd in "$skills_dir"/*/; do
    [ -d "$sd" ] || continue
    skill_name=$(basename "$sd")
    sm="$sd/SKILL.md"
    [ -f "$sm" ] || continue
    # Must start with --- frontmatter delimiter
    if ! head -1 "$sm" | grep -qx -- "---"; then
      red "  ERROR: $plugin_name/$skill_name/SKILL.md missing YAML frontmatter (must start with ---)"
      ERRORS=$((ERRORS + 1))
      continue
    fi
    # Find frontmatter end (second --- within first 30 lines)
    fm_end=$(head -30 "$sm" | grep -n -x -- "---" | sed -n "2p" | cut -d: -f1)
    if [ -z "$fm_end" ]; then
      red "  ERROR: $plugin_name/$skill_name/SKILL.md frontmatter not closed within 30 lines"
      ERRORS=$((ERRORS + 1))
      continue
    fi
    # Extract frontmatter and check for required fields
    fm=$(head -n "$fm_end" "$sm")
    missing=""
    echo "$fm" | grep -qE "^name\s*:" || missing="$missing name"
    echo "$fm" | grep -qE "^description\s*:" || missing="$missing description"
    if [ -n "$missing" ]; then
      red "  ERROR: $plugin_name/$skill_name/SKILL.md frontmatter missing fields:$missing"
      ERRORS=$((ERRORS + 1))
    else
      dim "  ok: $plugin_name/$skill_name SKILL.md frontmatter"
    fi
  done
done
echo ""

# --- 4. Check plugin.json validity ---
echo "Checking plugin.json files..."
for plugin_dir in "$PLUGINS_DIR"/*/; do
  plugin_name=$(basename "$plugin_dir")
  pj="$plugin_dir/.claude-plugin/plugin.json"
  if [ ! -f "$pj" ]; then
    red "  ERROR: $plugin_name missing .claude-plugin/plugin.json"
    ERRORS=$((ERRORS + 1))
  else
    # Validate JSON
    if ! python3 -c "import json; json.load(open('$pj'))" 2>/dev/null; then
      red "  ERROR: $plugin_name/plugin.json is invalid JSON"
      ERRORS=$((ERRORS + 1))
    else
      # Check required fields
      missing=$(python3 -c "
import json
d = json.load(open('$pj'))
missing = [f for f in ['name','version','description'] if f not in d]
print(','.join(missing) if missing else '')
")
      if [ -n "$missing" ]; then
        red "  ERROR: $plugin_name/plugin.json missing fields: $missing"
        ERRORS=$((ERRORS + 1))
      else
        dim "  ok: $plugin_name/plugin.json"
      fi
    fi
  fi
done
echo ""

# --- 4b. Check for non-canonical plugin.json at plugin top-level ---
echo "Checking plugin.json location..."
for plugin_dir in "$PLUGINS_DIR"/*/; do
  plugin_name=$(basename "$plugin_dir")
  if [ -f "$plugin_dir/plugin.json" ]; then
    red "  ERROR: $plugin_name has plugin.json at top-level — canonical location is .claude-plugin/plugin.json"
    ERRORS=$((ERRORS + 1))
  fi
done
echo ""

# --- 5. Check dependency resolution ---
echo "Checking dependencies..."
declare -A AVAILABLE_PLUGINS
for plugin_dir in "$PLUGINS_DIR"/*/; do
  pj="$plugin_dir/.claude-plugin/plugin.json"
  [ -f "$pj" ] || continue
  name=$(python3 -c "import json; print(json.load(open('$pj'))['name'])")
  AVAILABLE_PLUGINS[$name]=1
done

for plugin_dir in "$PLUGINS_DIR"/*/; do
  pj="$plugin_dir/.claude-plugin/plugin.json"
  [ -f "$pj" ] || continue
  plugin_name=$(python3 -c "import json; print(json.load(open('$pj'))['name'])")
  deps=$(python3 -c "import json; r=json.load(open('$pj')).get('requires',[]); print(' '.join(r))")
  for dep in $deps; do
    if [ -z "${AVAILABLE_PLUGINS[$dep]+x}" ]; then
      red "  ERROR: $plugin_name requires '$dep' but it's not in plugins/"
      ERRORS=$((ERRORS + 1))
    else
      dim "  ok: $plugin_name -> $dep"
    fi
  done
done
echo ""

# --- 6. Check hooks.json validity ---
echo "Checking hooks files..."
for plugin_dir in "$PLUGINS_DIR"/*/; do
  plugin_name=$(basename "$plugin_dir")
  hooks_file="$plugin_dir/hooks/hooks.json"
  if [ -f "$hooks_file" ]; then
    if ! python3 -c "import json; json.load(open('$hooks_file'))" 2>/dev/null; then
      red "  ERROR: $plugin_name/hooks/hooks.json is invalid JSON"
      ERRORS=$((ERRORS + 1))
    else
      dim "  ok: $plugin_name/hooks/hooks.json"
    fi
  fi
done
echo ""

# --- 7. Check MCP configs ---
echo "Checking MCP configs..."
for plugin_dir in "$PLUGINS_DIR"/*/; do
  plugin_name=$(basename "$plugin_dir")
  mcp_file="$plugin_dir/.mcp.json"
  if [ -f "$mcp_file" ]; then
    if ! python3 -c "import json; json.load(open('$mcp_file'))" 2>/dev/null; then
      red "  ERROR: $plugin_name/.mcp.json is invalid JSON"
      ERRORS=$((ERRORS + 1))
    else
      servers=$(python3 -c "import json; print(len(json.load(open('$mcp_file')).get('mcpServers',{})))")
      dim "  ok: $plugin_name/.mcp.json ($servers servers)"
    fi
  fi
done
echo ""

# --- 8. Check profiles reference valid plugins ---
if [ -f "$PROFILES" ]; then
  echo "Checking profiles.json..."
  # Collect all known plugin names (inline + github)
  all_plugins=$(python3 -c "
import json, os, glob
names = set()
for pj in glob.glob('$PLUGINS_DIR/*/.claude-plugin/plugin.json'):
    names.add(json.load(open(pj))['name'])
# GitHub plugins from marketplace
mp = '$REPO_DIR/.claude-plugin/marketplace.json'
if os.path.exists(mp):
    for p in json.load(open(mp))['plugins']:
        names.add(p['name'])
print(' '.join(sorted(names)))
")

  profiles=$(python3 -c "
import json
data = json.load(open('$PROFILES'))
for name, profile in data.get('profiles', {}).items():
    for p in profile.get('plugins', []) + profile.get('mcp', []):
        print(f'{name}|{p}')
")

  for line in $profiles; do
    IFS='|' read -r profile_name plugin_ref <<< "$line"
    if ! echo "$all_plugins" | tr ' ' '\n' | grep -qx "$plugin_ref"; then
      yellow "  WARN: Profile '$profile_name' references unknown plugin '$plugin_ref'"
      WARNINGS=$((WARNINGS + 1))
    fi
  done
  dim "  ok: profiles.json validated"
fi
echo ""

# --- Summary ---
echo "=== Lint Summary ==="
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
  green "All clear — no conflicts or issues found."
else
  [ $ERRORS -gt 0 ] && red "Errors: $ERRORS"
  [ $WARNINGS -gt 0 ] && yellow "Warnings: $WARNINGS"
fi

exit $ERRORS
