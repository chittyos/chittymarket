#!/usr/bin/env bash
# market.sh — ChittyMarket artifact toggle actuator
# Usage: market.sh <command> [args...]
#   list [--type=X] [--category=X] [--enabled] [--disabled]
#   enable <id>
#   disable <id>
#   info <id>
#   sync

set -euo pipefail

MANIFEST="$HOME/.claude/marketplace.json"
# Capability Overlay (provenance/content_hash source). Resolves next to the
# real manifest, then falls back to ~/.claude. Override with MARKET_OVERLAY.
if [ -n "${MARKET_OVERLAY:-}" ]; then
  OVERLAY="$MARKET_OVERLAY"
else
  _mreal="$(readlink -f "$MANIFEST" 2>/dev/null || echo "$MANIFEST")"
  OVERLAY="$(dirname "$_mreal")/capabilities.generated.json"
  [ -f "$OVERLAY" ] || OVERLAY="$HOME/.claude/capabilities.generated.json"
fi
# Allow env override; fall back to known workstation/legacy paths.
# Workstations (Mac /Users/nb/Workspace) use the first hit; Linux dev VMs use the last.
CH1TTY_SERVERS="${CH1TTY_SERVERS:-}"
if [ -z "$CH1TTY_SERVERS" ]; then
  for cand in \
    "$HOME/Workspace/ch1tty/servers.json" \
    "$HOME/Workspace/CHITTYOS/ch1tty/servers.json" \
    "$HOME/Desktop/Projects/github.com/CHITTYOS/ch1tty/servers.json" \
    "$HOME/projects/github.com/CHITTYOS/ch1tty/servers.json"; do
    [ -f "$cand" ] && CH1TTY_SERVERS="$cand" && break
  done
fi
SETTINGS="$HOME/.claude/settings.json"
BLOCKLIST="$HOME/.claude/plugins/blocklist.json"
SKILLS_DIR="$HOME/.claude/skills"
AGENTS_DIR="$HOME/.claude/agents"
HOOKS_DIR="$HOME/.claude/hooks"

# ─── Helpers ─────────────────────────────────────────────────────────────────

die() { echo "ERROR: $*" >&2; exit 1; }

require_manifest() {
  [[ -f "$MANIFEST" ]] || die "marketplace.json not found at $MANIFEST"
}

# Get artifact JSON by id
get_artifact() {
  python3 -c "
import json, sys
with open('$MANIFEST') as f:
    data = json.load(f)
for a in data['artifacts']:
    if a.get('id') == '$1':
        json.dump(a, sys.stdout)
        sys.exit(0)
sys.exit(1)
" 2>/dev/null || die "Artifact '$1' not found"
}

# ─── PROVENANCE ──────────────────────────────────────────────────────────────
# Verify an artifact's Capability Overlay record against its content_hash.
# Prints a status line. Exit: 0 = verified/unsigned/unknown (non-blocking),
# 2 = content_hash MISMATCH (tampered → callers fail closed).
verify_provenance() {
  local artifact_id="$1"
  [[ -f "$OVERLAY" ]] || { echo "  provenance: overlay not found — skipped"; return 0; }
  OVERLAY_FILE="$OVERLAY" ARTIFACT_ID="$artifact_id" python3 -c '
import json, hashlib, os, sys

with open(os.environ["OVERLAY_FILE"]) as f:
    data = json.load(f)

aid = os.environ["ARTIFACT_ID"]
rec = next((c for c in data.get("capabilities", []) if c.get("legacy_id") == aid), None)
if rec is None:
    print(f"  provenance: no overlay record for {aid} — unverified")
    sys.exit(0)

prov = rec.get("provenance") or {}
stored = prov.get("content_hash")
if not stored:
    print(f"  provenance: record has no content_hash — unverified")
    sys.exit(0)

# Canonicalization MUST match scripts/overlay-provenance.py exactly.
body = {k: v for k, v in rec.items() if k != "provenance"}
canon = json.dumps(body, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
computed = "sha256:" + hashlib.sha256(canon).hexdigest()

if computed != stored:
    print(f"  provenance: \033[0;31mCONTENT HASH MISMATCH — record tampered/stale\033[0m")
    print(f"    stored:   {stored}")
    print(f"    computed: {computed}")
    sys.exit(2)

sig = prov.get("signature")
signer = prov.get("signer_chittyid")
if sig and signer:
    print(f"  provenance: \033[0;32m✓ content verified + signed by {signer}\033[0m")
else:
    print(f"  provenance: \033[0;32m✓ content verified\033[0m (unsigned — signature pending L2)")
sys.exit(0)
'
}

# ─── LIST ────────────────────────────────────────────────────────────────────

cmd_list() {
  local type_filter="" cat_filter="" enabled_filter=""
  for arg in "$@"; do
    case "$arg" in
      --type=*)     type_filter="${arg#--type=}" ;;
      --category=*) cat_filter="${arg#--category=}" ;;
      --enabled)    enabled_filter="true" ;;
      --disabled)   enabled_filter="false" ;;
    esac
  done

  python3 -c "
import json

with open('$MANIFEST') as f:
    data = json.load(f)

arts = [a for a in data['artifacts'] if 'id' in a]

type_filter = '$type_filter' or None
cat_filter = '$cat_filter' or None
enabled_filter = '$enabled_filter' or None

if type_filter:
    arts = [a for a in arts if a['type'] == type_filter]
if cat_filter:
    arts = [a for a in arts if a['category'] == cat_filter]
if enabled_filter == 'true':
    arts = [a for a in arts if a['enabled']]
elif enabled_filter == 'false':
    arts = [a for a in arts if not a['enabled']]

groups = {}
for a in arts:
    groups.setdefault(a['type'], []).append(a)

order = ['mcp-server', 'skill', 'plugin', 'agent', 'hook', 'extension']
total = enabled = 0
for t in order:
    items = groups.get(t, [])
    if not items: continue
    print(f'\n  {t.upper()} ({len(items)})')
    print(f'  {chr(9472) * 90}')
    for a in items:
        s = '[ON] ' if a['enabled'] else '[OFF]'
        print(f'  {s} {a[\"id\"]:<36} {a[\"name\"]:<34} {a[\"category\"]:<15} {a[\"installMode\"]}')
        total += 1
        if a['enabled']: enabled += 1

disabled = total - enabled
print(f'\n  TOTAL: {total} artifacts  |  {enabled} enabled  |  {disabled} disabled')
"
}

# ─── ENABLE / DISABLE ───────────────────────────────────────────────────────

toggle_mcp_server() {
  local server_id="$1" state="$2"
  python3 -c "
import json
with open('$CH1TTY_SERVERS') as f:
    data = json.load(f)
found = False
for s in data['servers']:
    if s.get('id') == '$server_id':
        s['enabled'] = $state
        found = True
        break
if not found:
    raise SystemExit('Server $server_id not found in servers.json')
with open('$CH1TTY_SERVERS', 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
"
}

toggle_skill() {
  local skill_path="$1" state="$2"
  local skill_dir
  skill_dir=$(echo "$skill_path" | sed "s|~|$HOME|")
  if [[ "$state" == "True" ]]; then
    [[ -f "$skill_dir/SKILL.md.disabled" ]] && mv "$skill_dir/SKILL.md.disabled" "$skill_dir/SKILL.md"
  else
    [[ -f "$skill_dir/SKILL.md" ]] && mv "$skill_dir/SKILL.md" "$skill_dir/SKILL.md.disabled"
  fi
}

toggle_official_plugin() {
  local ref="$1" state="$2"
  python3 -c "
import json
with open('$SETTINGS') as f:
    data = json.load(f)
data.setdefault('enabledPlugins', {})['$ref'] = $state
with open('$SETTINGS', 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
"
}

toggle_local_plugin() {
  local plugin_id="$1" state="$2"
  if [[ "$state" == "True" ]]; then
    # Remove from blocklist
    python3 -c "
import json
with open('$BLOCKLIST') as f:
    data = json.load(f)
data['plugins'] = [p for p in data['plugins'] if not p.get('plugin','').startswith('$plugin_id')]
with open('$BLOCKLIST', 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
"
  else
    # Add to blocklist
    python3 -c "
import json, datetime
with open('$BLOCKLIST') as f:
    data = json.load(f)
data['plugins'].append({
    'plugin': '$plugin_id',
    'added_at': datetime.datetime.now(datetime.UTC).isoformat().replace('+00:00','') + 'Z',
    'reason': 'disabled-via-market',
    'text': 'Disabled via /market'
})
with open('$BLOCKLIST', 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
"
  fi
}

toggle_agent() {
  local agent_path="$1" state="$2"
  agent_path=$(echo "$agent_path" | sed "s|~|$HOME|")
  if [[ "$state" == "True" ]]; then
    [[ -f "${agent_path}.disabled" ]] && mv "${agent_path}.disabled" "$agent_path"
  else
    [[ -f "$agent_path" ]] && mv "$agent_path" "${agent_path}.disabled"
  fi
}

update_manifest() {
  local artifact_id="$1" state="$2"
  python3 -c "
import json
with open('$MANIFEST') as f:
    data = json.load(f)
for a in data['artifacts']:
    if a.get('id') == '$artifact_id':
        a['enabled'] = $state
        break
with open('$MANIFEST', 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
"
}

cmd_toggle() {
  local artifact_id="$1" enable="$2"
  local state
  [[ "$enable" == "enable" ]] && state="True" || state="False"

  local art_json
  art_json=$(get_artifact "$artifact_id")

  local art_type art_enabled
  art_type=$(echo "$art_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['type'])")
  art_enabled=$(echo "$art_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['enabled'])")

  # Fail-closed provenance check on enable: a tampered overlay record blocks
  # activation unless explicitly overridden (MARKET_SKIP_VERIFY=1).
  if [[ "$enable" == "enable" ]]; then
    local vrc=0
    verify_provenance "$artifact_id" || vrc=$?
    if [[ "$vrc" -eq 2 ]]; then
      if [[ "${MARKET_SKIP_VERIFY:-}" == "1" ]]; then
        echo "  WARNING: provenance check failed — proceeding (MARKET_SKIP_VERIFY=1)" >&2
      else
        die "BLOCKED: provenance verification failed for '$artifact_id' (content_hash mismatch). Re-stamp the overlay or investigate tampering. Override with MARKET_SKIP_VERIFY=1."
      fi
    fi
  fi

  if [[ "$enable" == "enable" && "$art_enabled" == "True" ]]; then
    echo "Already enabled: $artifact_id"
    return 0
  fi
  if [[ "$enable" == "disable" && "$art_enabled" == "False" ]]; then
    echo "Already disabled: $artifact_id"
    return 0
  fi

  case "$art_type" in
    mcp-server)
      local server_id
      server_id=$(echo "$art_json" | python3 -c "import json,sys; print(json.load(sys.stdin).get('ch1tty',{}).get('serverId',''))")
      [[ -n "$server_id" ]] && toggle_mcp_server "$server_id" "$state"
      ;;
    skill)
      local skill_path
      skill_path=$(echo "$art_json" | python3 -c "import json,sys; print(json.load(sys.stdin).get('standalone',{}).get('path',''))")
      [[ -n "$skill_path" ]] && toggle_skill "$skill_path" "$state"
      ;;
    plugin)
      local ref
      ref=$(echo "$art_json" | python3 -c "import json,sys; print(json.load(sys.stdin).get('standalone',{}).get('ref',''))")
      if [[ -n "$ref" && "$ref" == *"@claude-plugins-official"* ]]; then
        toggle_official_plugin "$ref" "$state"
      else
        local path
        path=$(echo "$art_json" | python3 -c "import json,sys; print(json.load(sys.stdin).get('standalone',{}).get('path',''))")
        [[ -n "$path" ]] && toggle_local_plugin "$artifact_id" "$state"
      fi
      ;;
    agent)
      local agent_path
      agent_path=$(echo "$art_json" | python3 -c "import json,sys; print(json.load(sys.stdin).get('standalone',{}).get('path',''))")
      [[ -n "$agent_path" ]] && toggle_agent "$agent_path" "$state"
      ;;
    hook)
      echo "Hook toggle requires YAML frontmatter edit — use Claude to modify"
      ;;
    *)
      die "Unknown artifact type: $art_type"
      ;;
  esac

  update_manifest "$artifact_id" "$state"

  local action
  [[ "$enable" == "enable" ]] && action="Enabled" || action="Disabled"
  echo "$action: $artifact_id ($art_type)"
}

# ─── INFO ────────────────────────────────────────────────────────────────────

cmd_info() {
  local artifact_id="$1"
  python3 -c "
import json
with open('$MANIFEST') as f:
    data = json.load(f)
for a in data['artifacts']:
    if a.get('id') == '$artifact_id':
        print(f'  ID:          {a[\"id\"]}')
        print(f'  Name:        {a[\"name\"]}')
        print(f'  Description: {a[\"description\"]}')
        print(f'  Type:        {a[\"type\"]}')
        print(f'  Category:    {a[\"category\"]}')
        print(f'  Access:      {a[\"access\"]}')
        print(f'  Enabled:     {a[\"enabled\"]}')
        print(f'  Install:     {a[\"installMode\"]}')
        print(f'  Tags:        {\", \".join(a.get(\"tags\",[]))}')
        sa = a.get('standalone', {})
        if sa.get('available'):
            print(f'  Standalone:  {sa.get(\"type\",\"\")} — {sa.get(\"ref\", sa.get(\"path\",\"\"))}')
        ch = a.get('ch1tty', {})
        if ch.get('serverId'):
            print(f'  Ch1tty:      serverId={ch[\"serverId\"]}')
        break
else:
    print(f'Artifact not found: $artifact_id')
"
  echo "  ─ Provenance ─"
  verify_provenance "$artifact_id"
}

# ─── VERIFY ──────────────────────────────────────────────────────────────────
# Verify provenance for one artifact or all. Exits non-zero if any record is
# tampered (content_hash mismatch).
cmd_verify() {
  local target="${1:-}"
  if [[ -z "$target" || "$target" == "--all" ]]; then
    [[ -f "$OVERLAY" ]] || die "overlay not found at $OVERLAY"
    local ids rc=0
    ids=$(python3 -c "import json,os; d=json.load(open('$OVERLAY')); print('\n'.join(c['legacy_id'] for c in d.get('capabilities',[])))")
    local n_ok=0 n_bad=0
    while IFS= read -r id; do
      [[ -z "$id" ]] && continue
      if verify_provenance "$id" >/dev/null 2>&1; then
        n_ok=$((n_ok+1))
      else
        n_bad=$((n_bad+1)); echo "TAMPERED: $id"; rc=1
      fi
    done <<< "$ids"
    echo "Provenance: $n_ok verified, $n_bad tampered"
    return $rc
  else
    local rc=0
    verify_provenance "$target" || rc=$?
    [[ "$rc" -eq 2 ]] && return 1 || return 0
  fi
}

# ─── SYNC ────────────────────────────────────────────────────────────────────

cmd_sync() {
  python3 -c "
import json, os

manifest_path = '$MANIFEST'
ch1tty_path = '$CH1TTY_SERVERS'
settings_path = '$SETTINGS'
blocklist_path = '$BLOCKLIST'
home = os.path.expanduser('~')

with open(manifest_path) as f:
    manifest = json.load(f)

changes = []

# Load external state
with open(ch1tty_path) as f:
    ch1tty = json.load(f)
ch1tty_state = {s['id']: s.get('enabled', True) for s in ch1tty['servers'] if 'id' in s}

with open(settings_path) as f:
    settings = json.load(f)
plugin_state = settings.get('enabledPlugins', {})

blocklist_ids = set()
if os.path.exists(blocklist_path):
    with open(blocklist_path) as f:
        bl = json.load(f)
    blocklist_ids = {p.get('plugin','') for p in bl.get('plugins',[])}

for a in manifest['artifacts']:
    if 'id' not in a:
        continue
    art_id = a['id']
    art_type = a['type']
    old_enabled = a['enabled']
    new_enabled = old_enabled

    if art_type == 'mcp-server':
        sid = a.get('ch1tty',{}).get('serverId','')
        if sid in ch1tty_state:
            new_enabled = ch1tty_state[sid]

    elif art_type == 'skill':
        path = a.get('standalone',{}).get('path','').replace('~', home)
        if path:
            new_enabled = os.path.exists(os.path.join(path, 'SKILL.md'))

    elif art_type == 'plugin':
        ref = a.get('standalone',{}).get('ref','')
        if ref and '@claude-plugins-official' in ref:
            new_enabled = plugin_state.get(ref, old_enabled)
        else:
            lpath = a.get('standalone',{}).get('path','')
            if lpath:
                new_enabled = lpath not in blocklist_ids and art_id not in blocklist_ids

    elif art_type == 'agent':
        path = a.get('standalone',{}).get('path','').replace('~', home)
        if path:
            new_enabled = os.path.exists(path)

    if new_enabled != old_enabled:
        changes.append(f'  {art_id}: {old_enabled} -> {new_enabled}')
        a['enabled'] = new_enabled

import datetime
manifest['lastSync'] = datetime.datetime.now(datetime.UTC).isoformat().replace('+00:00','') + 'Z'

with open(manifest_path, 'w') as f:
    json.dump(manifest, f, indent=2)
    f.write('\n')

if changes:
    print('Sync complete. Changes:')
    for c in changes:
        print(c)
else:
    print('Sync complete. No changes detected.')
print(f'Last sync: {manifest[\"lastSync\"]}')
"
}

# ─── Main ────────────────────────────────────────────────────────────────────

require_manifest

case "${1:-list}" in
  list)    shift 2>/dev/null || true; cmd_list "$@" ;;
  enable)  [[ -n "${2:-}" ]] || die "Usage: market.sh enable <id>"; cmd_toggle "$2" "enable" ;;
  disable) [[ -n "${2:-}" ]] || die "Usage: market.sh disable <id>"; cmd_toggle "$2" "disable" ;;
  info)    [[ -n "${2:-}" ]] || die "Usage: market.sh info <id>"; cmd_info "$2" ;;
  verify)  cmd_verify "${2:-}" ;;
  sync)    cmd_sync ;;
  *)       die "Unknown command: $1" ;;
esac
