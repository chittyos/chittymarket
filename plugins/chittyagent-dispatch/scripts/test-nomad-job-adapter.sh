#!/usr/bin/env bash
# test-nomad-job-adapter.sh — exercises adapters/nomad-job.sh against the real
# canonical/jobs/cadvisor.md and variants of it. Exit non-zero on any failure.
#
# The cadvisor equivalence check compares against a vendored, pinned copy of the
# chittyserv spec (fixtures/chittyserv-cadvisor.nomad.json, copied from
# chittyserv nomad/cadvisor.nomad.json). It never skips.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/../../.." && pwd)"
ADAPTER="$HERE/adapters/nomad-job.sh"
CANON="$REPO_ROOT/canonical/jobs/cadvisor.md"
SOURCE_SPEC="$HERE/fixtures/chittyserv-cadvisor.nomad.json"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fails=0
pass() { echo "  ok: $1"; }
bad()  { echo "  FAIL: $1" >&2; fails=$((fails + 1)); }

# variant <name> <python-expr-on-text> — writes a mutated copy of the canonical.
variant() {
  mkdir -p "$TMP/$1"
  python3 - "$CANON" "$TMP/$1/cadvisor.md" "$2" <<'PY'
import sys
src = open(sys.argv[1]).read()
text = eval(sys.argv[3], {"src": src})
open(sys.argv[2], "w").write(text)
PY
}

expect_reject() {  # <label> <variant-name> <stderr-substring>
  local rc=0
  "$ADAPTER" "$TMP/$2/cadvisor.md" "$TMP/$2.json" 2>"$TMP/$2.err" >/dev/null || rc=$?
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
[ -f "$SOURCE_SPEC" ] || { echo "  FAIL: missing fixture $SOURCE_SPEC" >&2; exit 1; }
{
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
}

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
"$ADAPTER" "$TMP/secretname/cadvisor.md" "$TMP/secretname.json" >/dev/null
if python3 -c 'import json,sys; e=json.load(open(sys.argv[1]))["Job"]["TaskGroups"][0]["Tasks"][0]["Env"]; assert e=={"SERVICES_NEONDB_CONNECTION_STRING":"${SERVICES_NEONDB_CONNECTION_STRING}"}, e' "$TMP/secretname.json"
then pass "secret name emitted as env placeholder"; else bad "secret placeholder"; fi

# 6. placement micro emits the node-name constraint; unknown placement rejected.
variant micro 'src.replace("placement: any", "placement: micro")'
"$ADAPTER" "$TMP/micro/cadvisor.md" "$TMP/micro.json" >/dev/null
if python3 -c 'import json,sys; c=json.load(open(sys.argv[1]))["Job"]["Constraints"]; assert c==[{"LTarget":"${node.unique.name}","Operand":"regexp","RTarget":"^chittymicro-"}], c' "$TMP/micro.json"
then pass "placement micro emits constraint"; else bad "placement micro constraint"; fi
variant badplace 'src.replace("placement: any", "placement: tower")'
expect_reject "rejects unknown placement" badplace "unknown placement"

# 7. Missing job mapping rejected.
variant nojob 'src.split("job:\n")[0] + "---\n"'
expect_reject "rejects missing job" nojob "missing required .job. mapping"

# 8. env: credential-shaped keys / values are rejected (F1), one case per rule.
envvar() { variant "$1" 'src.replace("          resources:", "          env: {'"$2"'}\n          resources:")'; }
SEP='://'
envvar envtoken 'API_TOKEN: abc'
expect_reject "rejects env key TOKEN" envtoken "looks like a credential"
envvar envkeysfx 'STRIPE_KEY: abc'
expect_reject "rejects env key _KEY suffix" envkeysfx "looks like a credential"
envvar envkeypfx 'KEY_ID: abc'
expect_reject "rejects env key KEY_ prefix" envkeypfx "looks like a credential"
envvar envdsn 'neon_dsn: abc'
expect_reject "rejects env key DSN (case-insensitive)" envdsn "looks like a credential"
envvar envurl "UPSTREAM: \\\"postgres${SEP}svc:hunter2@host/db\\\""
expect_reject "rejects env value scheme-user-pass-at" envurl "embeds credentials"
variant envlong 'src.replace("          resources:", "          env: {NOTE: " + "x"*201 + "}\n          resources:")'
expect_reject "rejects env value over 200 chars" envlong "longer than 200"
envvar envok "LOG_LEVEL: debug, ENDPOINT: \\\"https${SEP}host:8080/path\\\""
if "$ADAPTER" "$TMP/envok/cadvisor.md" "$TMP/envok.json" >/dev/null 2>&1; then pass "accepts benign env"; else bad "benign env rejected"; fi

# 9. name and number validation (F5), image tag case (F6).
variant badname 'src.replace("name: cadvisor", "name: CadVisor", 1)'
expect_reject "rejects non [a-z0-9-] name" badname "must match"
variant othername 'src.replace("name: cadvisor", "name: cadvisor2", 1)'
expect_reject "rejects name != file basename" othername "file basename"
variant staticnull 'src.replace("static: 8081", "static: null")'
expect_reject "rejects static: null" staticnull "must be an integer"
variant negcount 'src.replace("count: 1", "count: -5")'
expect_reject "rejects negative count" negcount ">= 0"
variant strcpu 'src.replace("cpu: 200", "cpu: lots")'
expect_reject "rejects non-int cpu" strcpu "must be an integer"
variant upperlatest 'src.replace("cadvisor:v0.49.1", "cadvisor:LATEST")'
expect_reject "rejects image tag LATEST" upperlatest "uses tag 'latest'"

if [ "$fails" -gt 0 ]; then echo "$fails failure(s)" >&2; exit 1; fi
echo "all passed"
