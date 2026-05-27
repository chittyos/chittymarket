#!/usr/bin/env bash
# test-plugins.sh — Validate all ChittyMarket plugins for structural correctness
# Runs: JSON validity, required files, skill content checks, agent headers, manifest consistency

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
PLUGINS_DIR="$REPO_DIR/plugins"
MARKETPLACE="$REPO_DIR/.claude-plugin/marketplace.json"
PASS=0
FAIL=0

red() { printf '\033[0;31mFAIL: %s\033[0m\n' "$1"; FAIL=$((FAIL + 1)); }
green() { printf '\033[0;32mPASS: %s\033[0m\n' "$1"; PASS=$((PASS + 1)); }

echo "=== ChittyMarket Plugin Tests ==="
echo ""

# --- Test 1: All plugin directories have plugin.json ---
echo "--- plugin.json presence ---"
for plugin_dir in "$PLUGINS_DIR"/*/; do
  name=$(basename "$plugin_dir")
  if [ -f "$plugin_dir/.claude-plugin/plugin.json" ]; then
    green "$name has plugin.json"
  else
    red "$name missing plugin.json"
  fi
done
echo ""

# --- Test 2: plugin.json schema validation ---
echo "--- plugin.json schema ---"
for plugin_dir in "$PLUGINS_DIR"/*/; do
  name=$(basename "$plugin_dir")
  pj="$plugin_dir/.claude-plugin/plugin.json"
  [ -f "$pj" ] || continue
  result=$(python3 -c "
import json, sys
try:
    d = json.load(open('$pj'))
    errors = []
    for f in ['name','version','description']:
        if f not in d:
            errors.append(f'missing {f}')
    if 'requires' in d and not isinstance(d['requires'], list):
        errors.append('requires must be array')
    if errors:
        print('FAIL:' + ','.join(errors))
    else:
        print('PASS')
except Exception as e:
    print(f'FAIL:{e}')
")
  if [ "$result" = "PASS" ]; then
    green "$name plugin.json schema valid"
  else
    red "$name plugin.json: ${result#FAIL:}"
  fi
done
echo ""

# --- Test 3: SKILL.md files are non-empty and have headers ---
echo "--- SKILL.md content ---"
for skill_file in "$PLUGINS_DIR"/*/skills/*/SKILL.md; do
  [ -f "$skill_file" ] || continue
  skill_name=$(basename "$(dirname "$skill_file")")
  plugin_name=$(basename "$(dirname "$(dirname "$(dirname "$skill_file")")")")

  # Check non-empty
  if [ ! -s "$skill_file" ]; then
    red "$plugin_name/$skill_name SKILL.md is empty"
    continue
  fi

  # Check has a markdown header or YAML frontmatter
  if head -5 "$skill_file" | grep -q "^#\|^---"; then
    green "$plugin_name/$skill_name SKILL.md has header"
  else
    red "$plugin_name/$skill_name SKILL.md missing markdown header or frontmatter"
  fi
done
echo ""

# --- Test 4: Agent .md files have content ---
echo "--- Agent files ---"
for agent_file in "$PLUGINS_DIR"/*/agents/*.md; do
  [ -f "$agent_file" ] || continue
  agent_name=$(basename "$agent_file" .md)
  plugin_name=$(basename "$(dirname "$(dirname "$agent_file")")")

  if [ ! -s "$agent_file" ]; then
    red "$plugin_name/$agent_name agent file is empty"
  else
    lines=$(wc -l < "$agent_file" | tr -d ' ')
    if [ "$lines" -lt 3 ]; then
      red "$plugin_name/$agent_name agent file too short ($lines lines)"
    else
      green "$plugin_name/$agent_name agent file OK ($lines lines)"
    fi
  fi
done
echo ""

# --- Test 5: MCP configs are valid and have mcpServers ---
echo "--- MCP configs ---"
for mcp_file in "$PLUGINS_DIR"/*/.mcp.json; do
  [ -f "$mcp_file" ] || continue
  plugin_name=$(basename "$(dirname "$mcp_file")")

  result=$(python3 -c "
import json
try:
    d = json.load(open('$mcp_file'))
    if 'mcpServers' not in d:
        print('FAIL:missing mcpServers key')
    elif not d['mcpServers']:
        print('FAIL:mcpServers is empty')
    else:
        print(f'PASS:{len(d[\"mcpServers\"])}')
except Exception as e:
    print(f'FAIL:{e}')
")
  if [[ "$result" == PASS:* ]]; then
    green "$plugin_name .mcp.json (${result#PASS:} servers)"
  else
    red "$plugin_name .mcp.json: ${result#FAIL:}"
  fi
done
echo ""

# --- Test 5b: Claude Skills tool descriptors (kind: tool projections) ---
echo "--- Claude Skills tool descriptors ---"
found_cs=false
for cs_file in "$PLUGINS_DIR"/*/claude-skills/*.json; do
  [ -f "$cs_file" ] || continue
  found_cs=true
  plugin_name=$(basename "$(dirname "$(dirname "$cs_file")")")
  tool_name=$(basename "$cs_file" .json)

  result=$(python3 -c "
import json, sys
try:
    d = json.load(open('$cs_file'))
except Exception as e:
    print(f'FAIL:invalid JSON: {e}')
    sys.exit(0)
errors = []
for f in ['name', 'description', 'inputSchema', 'outputSchema', 'annotations']:
    if f not in d:
        errors.append(f'missing {f}')
if 'annotations' in d:
    ann = d['annotations']
    if not isinstance(ann, dict):
        errors.append('annotations must be object')
    else:
        for f in ['readOnlyHint', 'openWorldHint']:
            if f not in ann:
                errors.append(f'annotations.{f} missing')
            elif not isinstance(ann[f], bool):
                errors.append(f'annotations.{f} must be bool')
for f in ['inputSchema', 'outputSchema']:
    if f in d:
        s = d[f]
        if not isinstance(s, dict) or s.get('type') != 'object':
            errors.append(f'{f} must be object schema (type: object)')
if errors:
    print('FAIL:' + '; '.join(errors))
else:
    print('PASS')
")
  if [ "$result" = "PASS" ]; then
    green "$plugin_name/claude-skills/$tool_name.json (tool descriptor valid)"
  else
    red "$plugin_name/claude-skills/$tool_name.json: ${result#FAIL:}"
  fi
done
if [ "$found_cs" = false ]; then
  echo "  (no claude-skills/*.json files found)"
fi
echo ""

# --- Test 5c: ChatGPT Apps SDK tool descriptors (kind: tool projections) ---
echo "--- ChatGPT Apps tool descriptors ---"
found_cg=false
for cg_file in "$PLUGINS_DIR"/*/chatgpt-apps/*.json; do
  [ -f "$cg_file" ] || continue
  found_cg=true
  plugin_name=$(basename "$(dirname "$(dirname "$cg_file")")")
  tool_name=$(basename "$cg_file" .json)

  result=$(python3 -c "
import json, sys
try:
    d = json.load(open('$cg_file'))
except Exception as e:
    print(f'FAIL:invalid JSON: {e}')
    sys.exit(0)
errors = []
for f in ['name', 'description', 'inputSchema', 'outputSchema', 'annotations']:
    if f not in d:
        errors.append(f'missing {f}')
if 'annotations' in d:
    ann = d['annotations']
    if not isinstance(ann, dict):
        errors.append('annotations must be object')
    else:
        for f in ['readOnlyHint', 'openWorldHint']:
            if f not in ann:
                errors.append(f'annotations.{f} missing')
            elif not isinstance(ann[f], bool):
                errors.append(f'annotations.{f} must be bool')
for f in ['inputSchema', 'outputSchema']:
    if f in d:
        s = d[f]
        if not isinstance(s, dict) or s.get('type') != 'object':
            errors.append(f'{f} must be object schema (type: object)')
meta = d.get('_meta') or {}
if 'openai/outputTemplate' in meta:
    v = meta['openai/outputTemplate']
    if not isinstance(v, str) or not v.strip():
        errors.append('_meta[openai/outputTemplate] must be non-empty string')
if 'openai/widgetCSP' in meta:
    csp = meta['openai/widgetCSP']
    if not isinstance(csp, dict):
        errors.append('_meta[openai/widgetCSP] must be object')
    else:
        for k in ('connectDomains', 'resourceDomains', 'frameDomains', 'redirect_domains'):
            if k in csp and (not isinstance(csp[k], list) or not all(isinstance(x, str) for x in csp[k])):
                errors.append(f'_meta[openai/widgetCSP].{k} must be list of strings')
if 'openai/fileParams' in meta:
    fp = meta['openai/fileParams']
    if not isinstance(fp, list) or not all(isinstance(x, str) for x in fp):
        errors.append('_meta[openai/fileParams] must be list of strings')
if errors:
    print('FAIL:' + '; '.join(errors))
else:
    print('PASS')
")
  if [ "$result" = "PASS" ]; then
    green "$plugin_name/chatgpt-apps/$tool_name.json (tool descriptor valid)"
  else
    red "$plugin_name/chatgpt-apps/$tool_name.json: ${result#FAIL:}"
  fi
done
if [ "$found_cg" = false ]; then
  echo "  (no chatgpt-apps/*.json files found)"
fi
echo ""

# --- Test 6: hooks.json validity ---
echo "--- Hooks configs ---"
found_hooks=false
for hooks_file in "$PLUGINS_DIR"/*/hooks/hooks.json; do
  [ -f "$hooks_file" ] || continue
  found_hooks=true
  plugin_name=$(basename "$(dirname "$(dirname "$hooks_file")")")

  if python3 -c "import json; json.load(open('$hooks_file'))" 2>/dev/null; then
    hooks_count=$(python3 -c "
import json
d = json.load(open('$hooks_file'))
count = sum(len(v) if isinstance(v, list) else 1 for v in d.values())
print(count)
")
    green "$plugin_name hooks.json ($hooks_count hooks)"
  else
    red "$plugin_name hooks.json invalid JSON"
  fi
done
if [ "$found_hooks" = false ]; then
  echo "  (no hooks.json files found)"
fi
echo ""

# --- Test 7: Marketplace manifest consistency ---
echo "--- Marketplace manifest ---"
if [ -f "$MARKETPLACE" ]; then
  result=$(python3 -c "
import json, os, glob

mp = json.load(open('$MARKETPLACE'))
plugins = mp.get('plugins', [])
plugin_dirs = set()
for d in glob.glob('$PLUGINS_DIR/*/'):
    if os.path.exists(os.path.join(d, '.claude-plugin', 'plugin.json')):
        name = json.load(open(os.path.join(d, '.claude-plugin', 'plugin.json')))['name']
        plugin_dirs.add(name)

mp_inline = set()
for p in plugins:
    if isinstance(p.get('source'), str) and p['source'].startswith('./plugins/'):
        mp_inline.add(p['name'])

missing_from_manifest = plugin_dirs - mp_inline
extra_in_manifest = mp_inline - plugin_dirs

if missing_from_manifest:
    print(f'MISSING:{\";\".join(missing_from_manifest)}')
elif extra_in_manifest:
    print(f'EXTRA:{\";\".join(extra_in_manifest)}')
else:
    print(f'PASS:{len(mp_inline)}')
")
  if [[ "$result" == PASS:* ]]; then
    green "Marketplace manifest matches plugins/ (${result#PASS:} inline plugins)"
  elif [[ "$result" == MISSING:* ]]; then
    red "Plugins in dir but not manifest: ${result#MISSING:}"
  elif [[ "$result" == EXTRA:* ]]; then
    red "Plugins in manifest but not dir: ${result#EXTRA:}"
  fi
else
  red "No .claude-plugin/marketplace.json found — run generate-marketplace.sh first"
fi
echo ""

# --- Summary ---
TOTAL=$((PASS + FAIL))
echo "=== Test Summary ==="
echo "  Passed: $PASS / $TOTAL"
echo "  Failed: $FAIL / $TOTAL"
[ $FAIL -eq 0 ] && printf '\033[0;32m  All tests passed!\033[0m\n' || printf '\033[0;31m  %d test(s) failed\033[0m\n' $FAIL

exit $FAIL
