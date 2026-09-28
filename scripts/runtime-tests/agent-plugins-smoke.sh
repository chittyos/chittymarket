#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

python3 scripts/generate-agent-plugins.py audit

python3 - <<'PY'
import json
from pathlib import Path
root=Path('.')
market=json.load(open('.agents/plugins/marketplace.json'))
assert market.get('name') == 'chittymarket'
assert market.get('interface',{}).get('displayName') == 'ChittyMarket'
plugins=market.get('plugins')
assert isinstance(plugins,list) and plugins, 'marketplace plugins[] required'
for entry in plugins:
    name=entry['name']
    assert entry['source'] == {'source':'local','path':f'./plugins/{name}'}
    assert entry['policy']['installation'] == 'AVAILABLE'
    assert entry['policy']['authentication'] == 'ON_INSTALL'
    assert entry.get('category'), f'{name}: category required'
    manifest=json.load(open(root/'plugins'/name/'plugin.json'))
    assert manifest['$schema'] == 'https://agent-plugins.org/schemas/1.0.0/plugin.schema.json'
    assert manifest['name'] == name
    assert manifest.get('version') and manifest.get('description')
    assert (root/'plugins'/name/'skills').is_dir()
print(f'portable Agent Plugins structural validation: PASS ({len(plugins)})')
PY

if ! command -v codex >/dev/null 2>&1; then
  echo 'mode: structural-only (Codex CLI unavailable)'
  exit 0
fi

TMP_HOME="$(mktemp -d)"
trap 'rm -rf "$TMP_HOME"' EXIT
mkdir -p "$TMP_HOME/.codex"

HOME="$TMP_HOME" codex plugin marketplace add "$ROOT" --json >/tmp/chittymarket-codex-marketplace-add.json
HOME="$TMP_HOME" codex plugin list --available --json >/tmp/chittymarket-codex-plugins.json
python3 - <<'PY'
import json
market=json.load(open('.agents/plugins/marketplace.json'))
expected={x['name'] for x in market['plugins']}
data=json.load(open('/tmp/chittymarket-codex-plugins.json'))
items=data.get('available',[]) if isinstance(data,dict) else data
rows={row.get('name'):row for row in items if isinstance(row,dict)}
missing=sorted(expected-set(rows))
assert not missing, f'Codex missing marketplace plugins: {missing}'
for name in expected:
    row=rows[name]
    assert row.get('marketplaceName') == 'chittymarket', row
    assert row.get('installPolicy') == 'AVAILABLE', row
    assert row.get('authPolicy') == 'ON_INSTALL', row
    assert row.get('installed') is False, row
print(f'Codex native marketplace discovery: PASS ({len(expected)})')
PY

echo 'mode: native-codex-marketplace'
