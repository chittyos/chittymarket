#!/usr/bin/env bash
# test-xai-grok-bot-adapter.sh — the adapter renders a profile from the
# canonical it is given and refuses addresses, credential-shaped names,
# legal-only definitions, and a missing connector declaration.
# Fixtures are synthetic. This script does not copy a real agent definition.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ADAPTER="$HERE/adapters/xai-grok-bot.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fails=0
pass() { echo "  ok: $1"; }
bad()  { echo "  FAIL: $1" >&2; fails=$((fails + 1)); }

write_fix() {  # <name> <body>
  printf '%s\n' "$2" > "$TMP/$1.md"
}

BASE='---
name: example-agent
description: |
  Inventory one estate and propose one brief.

  Later paragraphs are not the job statement.
kind: agent
plugin: example
boundary_class: business
canon_uri: chittycanon://example/agents/example-agent
address: https://example.invalid/should-not-copy
tier: 3
projection_owner: chittycanon://example/owners/not-a-roster
connectors:
  resolve: at-use-time
  source: registry
  by: canon_role
---
Follow the canonical you were given.
Do not invent an address.
'

echo "xai-grok-bot adapter tests"

write_fix base "$BASE"
"$ADAPTER" "$TMP/base.md" "$TMP/a.json" >/dev/null
cp "$TMP/a.json" "$TMP/a.first.json"
cp "$TMP/a.instructions.md" "$TMP/a.first.instructions.md"
"$ADAPTER" "$TMP/base.md" "$TMP/a.json" >/dev/null
if cmp -s "$TMP/a.json" "$TMP/a.first.json" && cmp -s "$TMP/a.instructions.md" "$TMP/a.first.instructions.md"; then pass "renders deterministically"; else bad "output differs between runs"; fi

if python3 - "$TMP/a.json" "$TMP/a.instructions.md" <<'PY'
import json, sys
doc = json.load(open(sys.argv[1]))
instructions = open(sys.argv[2], encoding="utf-8").read()
assert doc["runtime"] == "xai-grok-bot"
assert set(doc["profile"]) == {"name", "description", "title"}
assert doc["profile"]["name"] == "example-agent"
assert doc["profile"]["title"] == "example-agent"
assert doc["profile"]["description"] == "Inventory one estate and propose one brief."
assert "instructions" not in doc["profile"]
assert doc["instructions"] == {"artifact": "a.instructions.md"}
assert instructions.startswith("Follow the canonical")
assert doc["connectors"] == {"by": "canon_role", "resolve": "at-use-time", "source": "registry"}
assert "connectors" not in doc["profile"]
blob = json.dumps(doc)
assert "example.invalid" not in blob
assert "tier" not in doc and "tier" not in blob
assert "projection_owner" not in blob
assert "address" not in doc["profile"] and "address" not in doc
assert "://" not in doc["profile"]["description"]
assert doc["provenance"]["canon_uri"] == "chittycanon://example/agents/example-agent"
assert doc["provenance"]["boundary_class"] == "business"
assert doc["provenance"]["source"] == "base.md" or doc["provenance"]["source"].endswith("/base.md")
PY
then pass "profile is name, description, and title; instructions and connectors are separate"; else bad "profile shape"; fi

write_fix titled '---
name: example-agent
title: Example Display
display_name: Ignored When Title Is Set
description: One job.
kind: agent
connectors:
  resolve: at-use-time
  source: registry
  by: canon_role
---
Body.
'
"$ADAPTER" "$TMP/titled.md" "$TMP/titled.json" >/dev/null
if python3 -c 'import json,sys; p=json.load(open(sys.argv[1]))["profile"]; assert p["title"]=="Example Display" and p["name"]=="example-agent", p' "$TMP/titled.json"
then pass "title comes from the canonical title field"; else bad "title field"; fi

write_fix display '---
name: example-agent
display_name: Display From Canonical
description: One job.
kind: agent
connectors:
  resolve: at-use-time
  source: registry
  by: canon_role
---
Body.
'
"$ADAPTER" "$TMP/display.md" "$TMP/display.json" >/dev/null
if python3 -c 'import json,sys; assert json.load(open(sys.argv[1]))["profile"]["title"]=="Display From Canonical"' "$TMP/display.json"
then pass "title falls back to display_name"; else bad "display_name"; fi

write_fix overlay '---
name: example-agent
description: One job.
kind: agent
overlay:
  title: Overlay Display
connectors:
  resolve: at-use-time
  source: registry
  by: canon_role
---
Body.
'
"$ADAPTER" "$TMP/overlay.md" "$TMP/overlay.json" >/dev/null
if python3 -c 'import json,sys; assert json.load(open(sys.argv[1]))["profile"]["title"]=="Overlay Display"' "$TMP/overlay.json"
then pass "title falls back to overlay.title"; else bad "overlay title"; fi

write_fix override '---
name: example-agent
title: Canonical Title
description: One job.
kind: agent
runtime_overrides:
  xai-grok-bot:
    title: Projection Title
connectors:
  resolve: at-use-time
  source: registry
  by: canon_role
---
Body.
'
"$ADAPTER" "$TMP/override.md" "$TMP/override.json" >/dev/null
if python3 -c 'import json,sys; assert json.load(open(sys.argv[1]))["profile"]["title"]=="Projection Title"' "$TMP/override.json"
then pass "runtime title overrides the canonical title"; else bad "override title"; fi

write_fix names '---
name: example-agent
description: One job.
kind: agent
connectors:
  - registry-read
  - tasks-role
---
Body.
'
"$ADAPTER" "$TMP/names.md" "$TMP/names.json" >/dev/null
if python3 -c 'import json,sys; c=json.load(open(sys.argv[1]))["connectors"]; assert c==["registry-read","tasks-role"], c' "$TMP/names.json"
then pass "declared connector names pass through"; else bad "connector names"; fi

expect_reject() {  # <label> <file> <stderr-substring>
  local rc=0
  "$ADAPTER" "$TMP/$2.md" "$TMP/$2.json" 2>"$TMP/$2.err" >/dev/null || rc=$?
  if [ "$rc" -eq 2 ] && grep -q "$3" "$TMP/$2.err"; then pass "$1"; else bad "$1 (rc=$rc, stderr: $(cat "$TMP/$2.err"))"; fi
}

write_fix url '---
name: example-agent
description: One job.
kind: agent
connectors:
  - https://mcp.example.invalid/mcp
---
Body.
'
expect_reject "rejects a connector address" url "must be a name"

write_fix cred '---
name: example-agent
description: One job.
kind: agent
connectors:
  - API_TOKEN
---
Body.
'
expect_reject "rejects a credential-shaped connector name" cred "looks like a credential"

write_fix legal '---
name: example-agent
description: One job.
kind: agent
boundary_class: legal-only
connectors:
  resolve: at-use-time
  source: registry
  by: canon_role
---
Body.
'
expect_reject "rejects legal-only" legal "not eligible"

write_fix none '---
name: example-agent
description: One job.
kind: agent
---
Body.
'
expect_reject "rejects missing connectors" none "does not invent"

write_fix empty '---
name: example-agent
description: One job.
kind: agent
connectors: []
---
Body.
'
expect_reject "rejects an empty connector list" empty "empty"

write_fix skill '---
name: example-skill
description: One job.
kind: skill
connectors:
  - registry-read
---
Body.
'
expect_reject "rejects non-agent kind" skill "kind=agent"

if [ "$fails" -gt 0 ]; then echo "$fails failure(s)" >&2; exit 1; fi
echo "all passed"
