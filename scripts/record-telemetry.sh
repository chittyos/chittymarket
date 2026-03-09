#!/usr/bin/env bash
# record-telemetry.sh — Record plugin usage telemetry
# Usage:
#   record-telemetry.sh skill <plugin> <skill-name>
#   record-telemetry.sh agent <plugin> <agent-name>
#   record-telemetry.sh hook <plugin> <hook-event>
#   record-telemetry.sh summary

set -euo pipefail

TELEMETRY_FILE="${HOME}/.claude/chittymarket-telemetry.json"

init_telemetry() {
  if [ ! -f "$TELEMETRY_FILE" ]; then
    python3 -c "
import json
from datetime import datetime, timezone
data = {
    'version': '1.0.0',
    'firstRecorded': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
    'lastUpdated': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
    'plugins': {},
    'sessions': {'total': 0, 'withPluginActivity': 0}
}
json.dump(data, open('$TELEMETRY_FILE', 'w'), indent=2)
"
  fi
}

record_event() {
  local event_type="$1"  # skill, agent, hook
  local plugin="$2"
  local name="$3"

  init_telemetry

  python3 -c "
import json
from datetime import datetime, timezone

f = '$TELEMETRY_FILE'
data = json.load(open(f))
now = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
data['lastUpdated'] = now

plugin = '$plugin'
event_type = '${event_type}s'  # skills, agents, hooks
name = '$name'

if plugin not in data['plugins']:
    data['plugins'][plugin] = {
        'installed': now[:10],
        'skills': {},
        'agents': {},
        'hooks': {}
    }

p = data['plugins'][plugin]
if event_type not in p:
    p[event_type] = {}
if name not in p[event_type]:
    p[event_type][name] = {'invocations': 0, 'lastUsed': now}

p[event_type][name]['invocations'] += 1
p[event_type][name]['lastUsed'] = now

json.dump(data, open(f, 'w'), indent=2)
print(f'Recorded: {plugin}/{name} ({event_type}) — {p[event_type][name][\"invocations\"]} total')
"
}

show_summary() {
  init_telemetry

  python3 -c "
import json

f = '$TELEMETRY_FILE'
data = json.load(open(f))

print('=== Plugin Usage Summary ===')
print(f'Tracking since: {data[\"firstRecorded\"]}')
print(f'Last updated:   {data[\"lastUpdated\"]}')
print()

if not data['plugins']:
    print('No usage recorded yet.')
    exit()

# Sort by total invocations
totals = []
for plugin, info in data['plugins'].items():
    total = 0
    for category in ['skills', 'agents', 'hooks']:
        for name, stats in info.get(category, {}).items():
            total += stats['invocations']
    totals.append((plugin, total, info))

totals.sort(key=lambda x: -x[1])

for plugin, total, info in totals:
    print(f'{plugin} ({total} total invocations)')
    for category in ['skills', 'agents', 'hooks']:
        items = info.get(category, {})
        if items:
            for name, stats in sorted(items.items(), key=lambda x: -x[1]['invocations']):
                print(f'  {category[:-1]:>5}: {name:<30} {stats[\"invocations\"]:>4}x  (last: {stats[\"lastUsed\"][:10]})')
    print()
"
}

case "${1:-summary}" in
  skill|agent|hook)
    if [ $# -lt 3 ]; then
      echo "Usage: $0 $1 <plugin-name> <item-name>"
      exit 1
    fi
    record_event "$1" "$2" "$3"
    ;;
  summary)
    show_summary
    ;;
  *)
    echo "Usage: $0 {skill|agent|hook|summary} [args...]"
    exit 1
    ;;
esac
