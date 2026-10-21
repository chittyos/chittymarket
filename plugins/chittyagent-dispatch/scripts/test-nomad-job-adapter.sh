#!/usr/bin/env bash
# test-nomad-job-adapter.sh — exercises adapters/nomad-job.sh against the real
# canonical/jobs/cadvisor.md and variants of it. Exit non-zero on any failure.
#
# The cadvisor equivalence check compares against the live chittyserv spec
# (CHITTYSERV_CADVISOR_SPEC, default ../chittyserv/nomad/cadvisor.nomad.json
# next to this repo); it is skipped with a notice if that file is absent.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/../../.." && pwd)"
ADAPTER="$HERE/adapters/nomad-job.sh"
CANON="$REPO_ROOT/canonical/jobs/cadvisor.md"
SOURCE_SPEC="${CHITTYSERV_CADVISOR_SPEC:-$REPO_ROOT/../chittyserv/nomad/cadvisor.nomad.json}"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fails=0
pass() { echo "  ok: $1"; }
bad()  { echo "  FAIL: $1" >&2; fails=$((fails + 1)); }

# variant <name> <python-expr-on-text> — writes a mutated copy of the canonical.
variant() {
  python3 - "$CANON" "$TMP/$1.md" "$2" <<'PY'
import sys
src = open(sys.argv[1]).read()
text = eval(sys.argv[3], {"src": src})
open(sys.argv[2], "w").write(text)
PY
}

expect_reject() {  # <label> <variant-name> <stderr-substring>
  local rc=0
  "$ADAPTER" "$TMP/$2.md" "$TMP/$2.json" 2>"$TMP/$2.err" >/dev/null || rc=$?
  if [ "$rc" -eq 2 ] && grep -q "$3" "$TMP/$2.err"; then pass "$1"; else bad "$1 (rc=$rc, stderr: $(cat "$TMP/$2.err"))"; fi
}

echo "nomad-job adapter tests"

# 1. Renders cadvisor, deterministically.
"$ADAPTER" "$CANON" "$TMP/a.json" >/dev/null
"$ADAPTER" "$CANON" "$TMP/b.json" >/dev/null
if cmp -s "$TMP/a.json" "$TMP/b.json"; then pass "cadvisor renders deterministically"; else bad "cadvisor output differs between runs"; fi
if python3 - "$TMP/a.json" "$CANON" <<'PY'
import hashlib, json, sys
j = json.load(open(sys.argv[1]))["Job"]
assert j["ID"] == "cadvisor" and j["Type"] == "system", j
assert j["Meta"]["canon_uri"] == "chittycanon://core/services/chittyserv#jobs/cadvisor"
assert j["Meta"]["canonical_sha"] == hashlib.sha256(open(sys.argv[2], "rb").read()).hexdigest()
assert "Constraints" not in j, "placement any must emit no constraint"
PY
then pass "cadvisor Meta + no constraint"; else bad "cadvisor Meta/constraint"; fi

# 2. Equivalent to the live chittyserv spec on every non-null field.
if [ -f "$SOURCE_SPEC" ]; then
  if python3 - "$SOURCE_SPEC" "$TMP/a.json" <<'PY'
import json, sys
def strip(v):
    if isinstance(v, dict):
        return {k: strip(x) for k, x in v.items() if x is not None}
    if isinstance(v, list):
        return [strip(x) for x in v]
    return v
src = strip(json.load(open(sys.argv[1])))
proj = strip(json.load(open(sys.argv[2])))
# Job.Meta is the projection's own provenance stamp; the source has Meta: null.
proj["Job"].pop("Meta")
if src != proj:
    import difflib
    a = json.dumps(src, indent=2, sort_keys=True).splitlines()
    b = json.dumps(proj, indent=2, sort_keys=True).splitlines()
    sys.stderr.write("\n".join(difflib.unified_diff(a, b, "source", "projection", lineterm="")) + "\n")
    sys.exit(1)
PY
  then pass "cadvisor equals chittyserv spec (nulls stripped, Meta excepted)"; else bad "cadvisor differs from $SOURCE_SPEC"; fi
else
  echo "  skip: $SOURCE_SPEC not found (set CHITTYSERV_CADVISOR_SPEC)"
fi

# 3. Rejects image tag latest, and untagged images.
variant latest 'src.replace("cadvisor:v0.49.1", "cadvisor:latest")'
expect_reject "rejects image tag latest" latest "uses tag 'latest'"
variant untagged 'src.replace("gcr.io/cadvisor/cadvisor:v0.49.1", "gcr.io/cadvisor/cadvisor")'
expect_reject "rejects untagged image" untagged "is untagged"

# 4. Rejects secrets given as key: value mappings (both shapes).
variant secretmap 'src.replace("          resources:", "          secrets: {SERVICES_NEONDB_CONNECTION_STRING: postgres-dsn-value}\n          resources:")'
expect_reject "rejects secrets mapping" secretmap "never a key: value mapping"
variant secretitem 'src.replace("          resources:", "          secrets:\n            - SERVICES_NEONDB_CONNECTION_STRING: postgres-dsn-value\n          resources:")'
expect_reject "rejects secret list item with value" secretitem "never key: value mappings"

# 5. Secret names become ${NAME} env placeholders.
variant secretname 'src.replace("          resources:", "          secrets: [SERVICES_NEONDB_CONNECTION_STRING]\n          resources:")'
"$ADAPTER" "$TMP/secretname.md" "$TMP/secretname.json" >/dev/null
if python3 -c 'import json,sys; e=json.load(open(sys.argv[1]))["Job"]["TaskGroups"][0]["Tasks"][0]["Env"]; assert e=={"SERVICES_NEONDB_CONNECTION_STRING":"${SERVICES_NEONDB_CONNECTION_STRING}"}, e' "$TMP/secretname.json"
then pass "secret name emitted as env placeholder"; else bad "secret placeholder"; fi

# 6. placement micro emits the node-name constraint; unknown placement rejected.
variant micro 'src.replace("placement: any", "placement: micro")'
"$ADAPTER" "$TMP/micro.md" "$TMP/micro.json" >/dev/null
if python3 -c 'import json,sys; c=json.load(open(sys.argv[1]))["Job"]["Constraints"]; assert c==[{"LTarget":"${node.unique.name}","Operand":"regexp","RTarget":"^chittymicro-"}], c' "$TMP/micro.json"
then pass "placement micro emits constraint"; else bad "placement micro constraint"; fi
variant badplace 'src.replace("placement: any", "placement: tower")'
expect_reject "rejects unknown placement" badplace "unknown placement"

# 7. Missing job mapping rejected.
variant nojob 'src.split("job:\n")[0] + "---\n"'
expect_reject "rejects missing job" nojob "missing required .job. mapping"

if [ "$fails" -gt 0 ]; then echo "$fails failure(s)" >&2; exit 1; fi
echo "all passed"
