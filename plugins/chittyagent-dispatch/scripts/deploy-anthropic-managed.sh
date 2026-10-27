#!/usr/bin/env bash
# deploy-anthropic-managed.sh — apply one projected intent through ChittyAgent.
#
# Requires a ChittyAuth service bearer injected by the normal broker/runtime
# path. It never accepts or resolves the Anthropic provider credential.
set -euo pipefail

projection="${1:-}"
endpoint="${CHITTY_DISPATCH_ANTHROPIC_ENDPOINT:-https://agent.chitty.cc/dispatch/api/v1/runtime/anthropic/project}"

[ -n "$projection" ] || { echo "usage: $0 <projection.json>" >&2; exit 2; }
[ -f "$projection" ] || { echo "projection not found: $projection" >&2; exit 2; }
[ -n "${CHITTY_AUTH_SERVICE_TOKEN:-}" ] || {
  echo "CHITTY_AUTH_SERVICE_TOKEN is required from the broker/runtime injection path" >&2
  exit 3
}

python3 - "$projection" <<'PY' >/dev/null
import json, sys
doc = json.load(open(sys.argv[1], encoding="utf-8"))
if doc.get("runtime") != "anthropic-managed" or not isinstance(doc.get("spec"), dict):
    raise SystemExit("invalid anthropic-managed projection document")
for key in ("canonicalAgentId", "name", "model"):
    if not doc["spec"].get(key):
        raise SystemExit(f"projection spec missing {key}")
PY

curl --fail-with-body --silent --show-error   -X POST "$endpoint"   -H "Authorization: Bearer $CHITTY_AUTH_SERVICE_TOKEN"   -H "Content-Type: application/json"   --data-binary @"$projection"
echo
