#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/scripts" "$TMP/canonical/skills"
cp "$ROOT/scripts/market-reconcile.py" "$TMP/scripts/market-reconcile.py"

cat > "$TMP/marketplace.json" <<'JSON'
{"version":"1.0.0","artifacts":[{"id":"skill-foo","name":"Foo","description":"old","type":"skill","category":"ecosystem","access":"read","enabled":true,"installMode":"standalone"}]}
JSON

cat > "$TMP/capabilities.generated.json" <<'JSON'
{"version":"1.1.0","total":1,"capabilities":[{"capability_id":"chittycanon://capability/workspace/foo","legacy_id":"skill-foo","name":"Foo","description":"old","capability_group":"workspace","group_assignment_source":"override","execution_class":"@chitty/connectors","canonical_version":"1.0.0","projection_version_policy":"inherit-canonical","ontology":{"primary":["T"],"secondary":[]},"authority":{"requires_chittyid":true},"execution":{"default_surface":"local","local_allowed":true,"context_cost":"low","mutation_risk":"low"},"discovery":{"indexable":true,"session_index":"hidden","ambient_by_intent":false,"verbs":["foo"],"fallback_search":true},"auth_flow":{"mode":"local-only","stores_credentials_in":"n/a","fail_closed_if_unavailable":false},"runtime_exclusions":{},"compatible_channels":["codex"],"source_links":["local://canonical/skills/foo.md"],"phase0_audit":{"job_to_be_done":"route","environmental_footprint":"local","evidentiary_risk":"none","advisory_disposition":"skill"},"legacy_type":"skill","legacy_category":"ecosystem","deprecated_aliases":["skill-foo"],"visibility":"advanced","provenance":{"content_hash":"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","canonicalization":"json-sorted-compact","hash_covers":"record-excluding-provenance","schema_ref":"x","signature":null,"signer_chittyid":null,"anchored_in_ledger":null}}]}
JSON

cat > "$TMP/canonical/skills/foo.md" <<'MD'
---
name: foo
canon_uri: chittycanon://core/services/chittymarket#skills/foo
description: updated foo
kind: skill
runtimes: [codex]
canonical_capability_ref: chittycanon://capability/workspace/foo
overlay:
  title: Foo
  capability_group: workspace
  group_assignment_source: override
  execution_class: "@chitty/connectors"
  canonical_version: 1.0.0
  projection_version_policy: inherit-canonical
  ontology: {primary: [T], secondary: []}
  authority: {requires_chittyid: true}
  execution: {default_surface: local, local_allowed: true, context_cost: low, mutation_risk: low}
  discovery: {indexable: true, session_index: hidden, ambient_by_intent: false, verbs: [foo], fallback_search: true}
  auth_flow: {mode: local-only, stores_credentials_in: n/a, fail_closed_if_unavailable: false}
  runtime_exclusions: {}
  phase0_audit: {job_to_be_done: route, environmental_footprint: local, evidentiary_risk: none, advisory_disposition: skill}
  legacy_category: ecosystem
  deprecated_aliases: [skill-foo]
  visibility: advanced
  access: read
---
# Foo
MD

cat > "$TMP/canonical/skills/bar.md" <<'MD'
---
name: bar
canonical_capability_ref: chittycanon://core/services/chittymarket#skills/bar
description: bad identity
kind: skill
---
# Bar
MD

cat > "$TMP/canonical/skills/baz.md" <<'MD'
---
name: baz
capability: chittycanon://capability/build/baz
canon_uri: chittycanon://core/services/chittymarket#skills/baz
description: new baz
kind: skill
runtimes: [codex]
overlay:
  capability_group: build
  access: readwrite
  execution_class: "@chitty/connectors"
  canonical_version: 1.0.0
  ontology: {primary: [T], secondary: [A]}
  authority: {requires_chittyid: true}
  execution: {default_surface: local, local_allowed: true, context_cost: low, mutation_risk: medium}
  discovery: {indexable: true, session_index: hidden, ambient_by_intent: false, verbs: [build], fallback_search: true}
  auth_flow: {mode: local-only, stores_credentials_in: n/a, fail_closed_if_unavailable: false}
  phase0_audit: {job_to_be_done: build, environmental_footprint: local, evidentiary_risk: none, advisory_disposition: skill}
  visibility: advanced
  legacy_category: code
---
# Baz
MD

CHITTYMARKET_ROOT="$TMP" python3 "$TMP/scripts/market-reconcile.py" audit > "$TMP/audit.out"
grep -q "bar: capability field is not a chittycanon://capability/" "$TMP/audit.out"

if CHITTYMARKET_ROOT="$TMP" python3 "$TMP/scripts/market-reconcile.py" sync --name bar >/dev/null 2>&1; then
  echo "expected invalid identity sync to fail"
  exit 1
fi

CHITTYMARKET_ROOT="$TMP" python3 "$TMP/scripts/market-reconcile.py" sync --name baz >/dev/null

python3 - "$TMP" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
manifest = json.loads((root / "marketplace.json").read_text())
overlay = json.loads((root / "capabilities.generated.json").read_text())

assert not [x for x in manifest["artifacts"] if x.get("id") == "skill-bar"]
baz = [x for x in manifest["artifacts"] if x.get("id") == "skill-baz"][0]
assert baz["enabled"] is False
assert baz["capability"] == "chittycanon://capability/build/baz"
assert any(
    x["legacy_id"] == "skill-baz"
    and x["capability_id"] == "chittycanon://capability/build/baz"
    for x in overlay["capabilities"]
)
print("market-reconcile regression tests: PASS")
PY
