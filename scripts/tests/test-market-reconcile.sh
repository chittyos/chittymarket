#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/scripts" "$TMP/canonical/skills"
cp "$ROOT/scripts/market-reconcile.py" "$TMP/scripts/market-reconcile.py"

cat > "$TMP/marketplace.json" <<'JSON'
{"version":"1.0.0","artifacts":[{"id":"skill-foo","name":"Foo","description":"old","type":"skill","category":"ecosystem","access":"read","enabled":true,"installMode":"standalone"},{"id":"external","name":"External","description":"preserve me","type":"mcp-server","category":"ecosystem","access":"read","enabled":true,"installMode":"ch1tty"}]}
JSON

cat > "$TMP/capabilities.generated.json" <<'JSON'
{"version":"1.1.0","total":2,"capabilities":[{"capability_id":"chittycanon://capability/workspace/foo","legacy_id":"skill-foo","name":"Foo","description":"CORRUPTED GENERATED VALUE","capability_group":"workspace","group_assignment_source":"override","execution_class":"@chitty/connectors","canonical_version":"1.0.0","projection_version_policy":"inherit-canonical","ontology":{"primary":["T"],"secondary":[]},"authority":{"requires_chittyid":true},"execution":{"default_surface":"local","local_allowed":true,"context_cost":"low","mutation_risk":"low"},"discovery":{"indexable":true,"session_index":"hidden","ambient_by_intent":false,"verbs":["foo"],"fallback_search":true},"auth_flow":{"mode":"local-only","stores_credentials_in":"n/a","fail_closed_if_unavailable":false},"runtime_exclusions":{},"compatible_channels":["codex"],"source_links":["local://canonical/skills/foo.md"],"phase0_audit":{"job_to_be_done":"route","environmental_footprint":"local","evidentiary_risk":"none","advisory_disposition":"skill"},"legacy_type":"skill","legacy_category":"ecosystem","deprecated_aliases":["skill-foo"],"visibility":"advanced","provenance":{"content_hash":"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","canonicalization":"json-sorted-compact","hash_covers":"record-excluding-provenance","schema_ref":"x","signature":null,"signer_chittyid":null,"anchored_in_ledger":null}},{"capability_id":"chittycanon://capability/connect/external","legacy_id":"external","name":"External","description":"preserve me exactly","capability_group":"connect","opaque_external":{"keep":[1,2,3]},"provenance":{"signature":"external-signature"}}]}
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

if CHITTYMARKET_ROOT="$TMP" python3 "$TMP/scripts/market-reconcile.py" audit > "$TMP/audit.out" 2>&1; then
  echo "expected corrupted generated record to fail audit"
  exit 1
fi
grep -q "foo: materialized overlay drift" "$TMP/audit.out"
grep -q "bar: capability field is not a chittycanon://capability/" "$TMP/audit.out"

if CHITTYMARKET_ROOT="$TMP" python3 "$TMP/scripts/market-reconcile.py" sync --name bar >/dev/null 2>&1; then
  echo "expected invalid identity sync to fail"
  exit 1
fi

python3 - "$TMP" <<'PY2'
import json, sys
from pathlib import Path
root=Path(sys.argv[1])
ov=json.loads((root/'capabilities.generated.json').read_text())
ext=[x for x in ov['capabilities'] if x.get('legacy_id')=='external'][0]
(root/'external-before.json').write_text(json.dumps(ext, sort_keys=True))
PY2

CHITTYMARKET_ROOT="$TMP" python3 "$TMP/scripts/market-reconcile.py" sync >/dev/null
CHITTYMARKET_ROOT="$TMP" python3 "$TMP/scripts/market-reconcile.py" audit >/dev/null
sha256sum "$TMP/marketplace.json" "$TMP/capabilities.generated.json" > "$TMP/after-first.sha"
CHITTYMARKET_ROOT="$TMP" python3 "$TMP/scripts/market-reconcile.py" sync >/dev/null
sha256sum "$TMP/marketplace.json" "$TMP/capabilities.generated.json" > "$TMP/after-second.sha"
diff -u "$TMP/after-first.sha" "$TMP/after-second.sha"

python3 - "$TMP" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
manifest = json.loads((root / "marketplace.json").read_text())
overlay = json.loads((root / "capabilities.generated.json").read_text())

assert not [x for x in manifest["artifacts"] if x.get("id") == "skill-bar"]
foo = [x for x in overlay["capabilities"] if x.get("legacy_id") == "skill-foo"][0]
assert foo["description"] == "old"
assert foo["provenance"]["content_hash"] != "sha256:" + "a" * 64
external = [x for x in overlay["capabilities"] if x.get("legacy_id") == "external"][0]
assert json.dumps(external, sort_keys=True) == (root / "external-before.json").read_text()
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
