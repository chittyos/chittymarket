#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

CAN="$TMP/test-agent.md"
OUT="$TMP/test-agent.json"

cat >"$CAN" <<'EOF'
---
name: ChittyTest
canon_uri: chittycanon://core/agents/chittytest
description: |
  Test managed projection.
model: claude-opus-5-5
kind: agent
plugin: test
runtimes:
  - anthropic-managed
runtime_overrides:
  anthropic-managed:
    tools:
      - type: agent_toolset_20260401
    mcp_servers:
      - type: url
        name: chittymcp
        url: https://mcp.chitty.cc/mcp
    metadata:
      owner: test
---
You are ChittyTest.
EOF

"$ROOT/plugins/chittyagent-dispatch/scripts/adapters/anthropic-managed-agent.sh" "$CAN" "$OUT"

python3 - "$OUT" <<'PY'
import json, sys
doc = json.load(open(sys.argv[1]))
assert doc["runtime"] == "anthropic-managed"
spec = doc["spec"]
assert spec["canonicalAgentId"] == "chittycanon://core/agents/chittytest"
assert spec["name"] == "ChittyTest"
assert spec["model"] == "claude-opus-5-5"
assert spec["system"] == "You are ChittyTest.\n"
assert spec["tools"][0]["type"] == "agent_toolset_20260401"
assert spec["mcpServers"][0]["url"] == "https://mcp.chitty.cc/mcp"
assert spec["metadata"]["chittyos_source"].endswith("/test-agent.md")
assert not spec["metadata"]["chittyos_source"].startswith("/")
assert "deploymentRef" not in spec
assert "agent_id" not in spec
PY

echo "anthropic-managed projection adapter: ok"
