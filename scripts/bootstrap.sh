#!/usr/bin/env bash
# bootstrap.sh — One-command ChittyMarket setup
# Installs all inline plugins: symlinks skills, agents, hooks, MCP configs
# Usage: ./scripts/bootstrap.sh [--profile=<name>] [--dry-run]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
PLUGINS_DIR="$REPO_DIR/plugins"
CLAUDE_DIR="${HOME}/.claude"
SKILLS_DIR="$CLAUDE_DIR/skills"
AGENTS_DIR="$CLAUDE_DIR/agents"
HOOKS_DIR="$CLAUDE_DIR/hooks"

PROFILE=""
DRY_RUN=false

# Parse args
for arg in "$@"; do
  case "$arg" in
    --profile=*) PROFILE="${arg#--profile=}" ;;
    --dry-run) DRY_RUN=true ;;
    --help|-h)
      echo "Usage: $0 [--profile=<name>] [--dry-run]"
      echo ""
      echo "Profiles: minimal, coding, devops, legal, integrations, full"
      echo "Default: full (installs everything)"
      exit 0
      ;;
  esac
done

green() { printf '\033[0;32m%s\033[0m\n' "$1"; }
yellow() { printf '\033[0;33m%s\033[0m\n' "$1"; }
dim() { printf '\033[0;90m%s\033[0m\n' "$1"; }

echo "=== ChittyMarket Bootstrap ==="
echo "Repo: $REPO_DIR"
[ -n "$PROFILE" ] && echo "Profile: $PROFILE" || echo "Profile: full (default)"
$DRY_RUN && echo "Mode: DRY RUN"
echo ""

# Determine which plugins to install
if [ -n "$PROFILE" ]; then
  PROFILES_FILE="$REPO_DIR/profiles.json"
  if [ ! -f "$PROFILES_FILE" ]; then
    echo "ERROR: profiles.json not found"
    exit 1
  fi
  ENABLED_PLUGINS=$(python3 -c "
import json
data = json.load(open('$PROFILES_FILE'))
profile = data.get('profiles', {}).get('$PROFILE')
if not profile:
    print('ERROR')
else:
    plugins = profile.get('plugins', []) + profile.get('mcp', [])
    print(' '.join(plugins))
")
  if [ "$ENABLED_PLUGINS" = "ERROR" ]; then
    echo "ERROR: Profile '$PROFILE' not found in profiles.json"
    exit 1
  fi
else
  # Full — all inline plugins
  ENABLED_PLUGINS=$(find "$PLUGINS_DIR" -name plugin.json -exec python3 -c "import json; print(json.load(open('{}'))['name'])" \;)
fi

echo "Plugins to install: $ENABLED_PLUGINS"
echo ""

# Ensure directories exist
for dir in "$SKILLS_DIR" "$AGENTS_DIR" "$HOOKS_DIR"; do
  if [ ! -d "$dir" ]; then
    if $DRY_RUN; then
      dim "  would create: $dir"
    else
      mkdir -p "$dir"
      green "  Created: $dir"
    fi
  fi
done

# --- Step 1: Symlink marketplace.json ---
echo ""
echo "--- Marketplace manifest ---"
MANIFEST_LINK="$CLAUDE_DIR/marketplace.json"
if [ -L "$MANIFEST_LINK" ] || [ -f "$MANIFEST_LINK" ]; then
  dim "  marketplace.json already linked"
else
  if $DRY_RUN; then
    dim "  would link: $MANIFEST_LINK -> $REPO_DIR/marketplace.json"
  else
    ln -s "$REPO_DIR/marketplace.json" "$MANIFEST_LINK"
    green "  Linked: marketplace.json"
  fi
fi

# --- Step 2: Install skills ---
echo ""
echo "--- Installing skills ---"
SKILL_COUNT=0
for plugin_name in $ENABLED_PLUGINS; do
  plugin_dir="$PLUGINS_DIR/$plugin_name"
  [ -d "$plugin_dir/skills" ] || continue

  for skill_dir in "$plugin_dir"/skills/*/; do
    [ -d "$skill_dir" ] || continue
    skill_name=$(basename "$skill_dir")
    target="$SKILLS_DIR/$skill_name"

    if [ -L "$target" ]; then
      dim "  skip: $skill_name (already linked)"
    elif [ -d "$target" ]; then
      yellow "  skip: $skill_name (exists as directory, not symlink)"
    else
      if $DRY_RUN; then
        dim "  would link: $target -> $skill_dir"
      else
        ln -s "$skill_dir" "$target"
        green "  Linked: $skill_name"
      fi
    fi
    SKILL_COUNT=$((SKILL_COUNT + 1))
  done
done
echo "  Skills processed: $SKILL_COUNT"

# --- Step 3: Install agents ---
echo ""
echo "--- Installing agents ---"
AGENT_COUNT=0
for plugin_name in $ENABLED_PLUGINS; do
  plugin_dir="$PLUGINS_DIR/$plugin_name"
  [ -d "$plugin_dir/agents" ] || continue

  for agent_file in "$plugin_dir"/agents/*.md; do
    [ -f "$agent_file" ] || continue
    agent_name=$(basename "$agent_file")
    target="$AGENTS_DIR/$agent_name"

    if [ -L "$target" ]; then
      dim "  skip: $agent_name (already linked)"
    elif [ -f "$target" ]; then
      yellow "  skip: $agent_name (exists as file, not symlink)"
    else
      if $DRY_RUN; then
        dim "  would link: $target -> $agent_file"
      else
        ln -s "$agent_file" "$target"
        green "  Linked: $agent_name"
      fi
    fi
    AGENT_COUNT=$((AGENT_COUNT + 1))
  done
done
echo "  Agents processed: $AGENT_COUNT"

# --- Step 4: Install hooks ---
echo ""
echo "--- Installing hooks ---"
HOOK_COUNT=0
for plugin_name in $ENABLED_PLUGINS; do
  plugin_dir="$PLUGINS_DIR/$plugin_name"
  hooks_file="$plugin_dir/hooks/hooks.json"
  [ -f "$hooks_file" ] || continue

  hook_count=$(python3 -c "import json; d=json.load(open('$hooks_file')); print(sum(len(v) if isinstance(v, list) else 1 for v in d.values()))")
  dim "  $plugin_name: $hook_count hooks defined in hooks.json"
  yellow "  Note: hooks.json must be merged into ~/.claude/settings.json manually or via /market"
  HOOK_COUNT=$((HOOK_COUNT + hook_count))
done
echo "  Hooks found: $HOOK_COUNT"

# --- Step 5: Install MCP configs ---
echo ""
echo "--- MCP configurations ---"
for plugin_name in $ENABLED_PLUGINS; do
  plugin_dir="$PLUGINS_DIR/$plugin_name"
  mcp_file="$plugin_dir/.mcp.json"
  [ -f "$mcp_file" ] || continue

  servers=$(python3 -c "import json; d=json.load(open('$mcp_file')); print(', '.join(d.get('mcpServers',{}).keys()))")
  yellow "  $plugin_name: MCP servers [$servers]"
  yellow "  Note: merge $mcp_file into project .mcp.json or use Ch1tty"
done

# --- Step 6: Generate native marketplace ---
echo ""
echo "--- Native marketplace ---"
if [ -f "$REPO_DIR/scripts/generate-marketplace.sh" ]; then
  if $DRY_RUN; then
    dim "  would run: generate-marketplace.sh"
  else
    bash "$REPO_DIR/scripts/generate-marketplace.sh"
  fi
fi

# --- Summary ---
echo ""
echo "=== Bootstrap Complete ==="
echo "  Skills: $SKILL_COUNT"
echo "  Agents: $AGENT_COUNT"
echo "  Hooks: $HOOK_COUNT (manual merge required)"
echo ""
echo "Next steps:"
echo "  1. Run: /market sync     — reconcile manifest with filesystem"
echo "  2. Run: /market list     — verify all artifacts are visible"
echo "  3. Merge hooks.json into ~/.claude/settings.json if needed"
$DRY_RUN && echo "" && yellow "  (This was a dry run — no changes were made)"
