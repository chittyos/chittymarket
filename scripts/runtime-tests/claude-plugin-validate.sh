#!/usr/bin/env bash
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

if command -v claude >/dev/null 2>&1; then
  claude plugin validate .claude-plugin/marketplace.json
  echo 'mode: native-claude-plugin-validator'
  exit 0
fi

# CI fallback when Claude Code is not installed. This does not claim native
# validation; the repository lint + generated-manifest equality are the weaker
# structural evidence available on that runner.
python3 - <<'PY'
import json
m=json.load(open('.claude-plugin/marketplace.json'))
assert m.get('name')
assert isinstance(m.get('plugins'),list) and m['plugins']
for entry in m['plugins']:
    assert entry.get('name') and entry.get('source')
print(f'Claude marketplace structural fallback: PASS ({len(m["plugins"])})')
PY
bash scripts/lint-plugins.sh >/dev/null

echo 'mode: structural-only (Claude Code unavailable)'
