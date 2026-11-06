#!/usr/bin/env bash
# test-canon-sync.sh — real-crypto test corpus for check-canon-sync.sh / gate-canon-sync.sh.
# No mocks: generates a throwaway ed25519 keypair (openssl) in a temp dir, stamps REAL
# canonical/ artifacts with stamp-canon.sh, signs the manifest the way the pipeline does
# (jq -cS del(.signature)), and asserts exit codes. Fail-closed cases must exit 3/4, never 0.
# The keypair is test-only and deleted on exit; no service key is touched.
# Usage: scripts/test-canon-sync.sh   (exit 0 = all pass; nonzero = failure count)
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(dirname "$HERE")"
CHECK="$HERE/check-canon-sync.sh"; GATE="$HERE/gate-canon-sync.sh"; STAMP="$HERE/stamp-canon.sh"
W="$(mktemp -d "${TMPDIR:-/tmp}/canontest.XXXXXX")"; trap 'rm -rf "$W"' EXIT
PASS=0; FAIL=0
t() { # name expected_rc actual_rc
  if [ "$2" = "$3" ]; then PASS=$((PASS+1)); printf 'ok   %s\n' "$1"
  else FAIL=$((FAIL+1)); printf 'FAIL %s (expected rc=%s got rc=%s)\n' "$1" "$2" "$3"; fi; }
run() { "$@" >/dev/null 2>&1; echo $?; }

SK="$W/signer.pem"; SK2="$W/other.pem"
openssl genpkey -algorithm ed25519 -out "$SK" 2>/dev/null
openssl pkey -in "$SK" -pubout -out "$W/pub.pem" 2>/dev/null
openssl genpkey -algorithm ed25519 -out "$SK2" 2>/dev/null
openssl pkey -in "$SK2" -pubout -out "$W/pub2.pem" 2>/dev/null

sign() { # unsigned-manifest-json signer-pem out
  jq -c '.signed_by="did:chitty:test-service"|del(.signature)' "$1" | jq -cS . > "$W/s.in"
  openssl pkeyutl -sign -inkey "$2" -rawin -in "$W/s.in" -out "$W/s.sig" 2>/dev/null
  jq --arg s "$(openssl base64 -A -in "$W/s.sig")" '.signed_by="did:chitty:test-service"|.signature=$s' "$1" > "$3"; }

ART="$(ls "$ROOT"/canonical/agents/*.md | head -1)"
[ -r "$ART" ] || { echo "no real canonical artifact found"; exit 99; }
cp "$ART" "$W/a.md"
"$STAMP" "$W/a.md" chittycanon://test/canon-sync 1.0.0 > "$W/m.unsigned" 2>/dev/null || { echo "stamp failed"; exit 99; }
sign "$W/m.unsigned" "$SK" "$W/m.json"

t "valid artifact+manifest+sig -> IN_SYNC"        0 "$(run "$CHECK" "$W/a.md" "$W/m.json" "$W/pub.pem")"
t "gate passes IN_SYNC"                            0 "$(run "$GATE"  "$W/a.md" "$W/m.json" "$W/pub.pem")"
t "pubkey via CANON_PUBKEY env"                    0 "$(CANON_PUBKEY="$W/pub.pem" run "$CHECK" "$W/a.md" "$W/m.json")"

# identity semantics
{ printf -- '---\nname: changed\nextra: x\n---\n'; awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{f=0;next} !f{print}' "$ART"; } > "$W/fm.md"
t "frontmatter-only change -> still IN_SYNC"       0 "$(run "$CHECK" "$W/fm.md" "$W/m.json" "$W/pub.pem")"
sed 's/$/\r/' "$W/a.md" > "$W/crlf.md"
t "CRLF line endings -> still IN_SYNC"             0 "$(run "$CHECK" "$W/crlf.md" "$W/m.json" "$W/pub.pem")"
{ cat "$W/a.md"; printf '\n\n\n'; } > "$W/trail.md"
t "trailing blank lines -> still IN_SYNC"          0 "$(run "$CHECK" "$W/trail.md" "$W/m.json" "$W/pub.pem")"
jq -c 'to_entries|reverse|from_entries' "$W/m.json" > "$W/reorder.json"
t "manifest key reorder -> still IN_SYNC"          0 "$(run "$CHECK" "$W/a.md" "$W/reorder.json" "$W/pub.pem")"

# drift
{ cat "$W/a.md"; echo "tampered line"; } > "$W/body.md"
t "body tampered -> OUT_OF_SYNC"                   3 "$(run "$CHECK" "$W/body.md" "$W/m.json" "$W/pub.pem")"
t "gate blocks OUT_OF_SYNC with rc 3"              3 "$(run "$GATE"  "$W/body.md" "$W/m.json" "$W/pub.pem")"
: > "$W/empty.md"
t "empty artifact -> OUT_OF_SYNC"                  3 "$(run "$CHECK" "$W/empty.md" "$W/m.json" "$W/pub.pem")"

# unverified (must never be 0 or 3)
jq '.version="9.9.9"' "$W/m.json" > "$W/mv.json"
t "manifest field edited after signing -> UNVERIFIED" 4 "$(run "$CHECK" "$W/a.md" "$W/mv.json" "$W/pub.pem")"
ZERO="$(printf '0%.0s' $(seq 64))"
jq --arg h "sha256:$ZERO" '.content_hash=$h' "$W/m.json" > "$W/mh.json"
t "hash swapped, stale sig -> UNVERIFIED (not OUT_OF_SYNC)" 4 "$(run "$CHECK" "$W/body.md" "$W/mh.json" "$W/pub.pem")"
t "wrong pinned pubkey -> UNVERIFIED"              4 "$(run "$CHECK" "$W/a.md" "$W/m.json" "$W/pub2.pem")"
jq 'del(.signature)' "$W/m.json" > "$W/ns.json"
t "signature absent -> UNVERIFIED"                 4 "$(run "$CHECK" "$W/a.md" "$W/ns.json" "$W/pub.pem")"
t "stamp placeholder signature -> UNVERIFIED"      4 "$(run "$CHECK" "$W/a.md" "$W/m.unsigned" "$W/pub.pem")"
jq '.signature="!!!notbase64!!!"' "$W/m.json" > "$W/bs.json"
t "garbage signature -> UNVERIFIED"                4 "$(run "$CHECK" "$W/a.md" "$W/bs.json" "$W/pub.pem")"
jq '.content_hash=""' "$W/m.json" > "$W/eh.json"
t "empty content_hash -> UNVERIFIED"               4 "$(run "$CHECK" "$W/a.md" "$W/eh.json" "$W/pub.pem")"
echo 'not json' > "$W/nj.json"
t "manifest not JSON -> UNVERIFIED"                4 "$(run "$CHECK" "$W/a.md" "$W/nj.json" "$W/pub.pem")"
t "manifest missing -> UNVERIFIED"                 4 "$(run "$CHECK" "$W/a.md" "$W/nope.json" "$W/pub.pem")"
t "artifact missing -> UNVERIFIED"                 4 "$(run "$CHECK" "$W/nope.md" "$W/m.json" "$W/pub.pem")"
t "no pubkey supplied -> UNVERIFIED"               4 "$(env -u CANON_PUBKEY bash -c '"$0" "$1" "$2" >/dev/null 2>&1; echo $?' "$CHECK" "$W/a.md" "$W/m.json")"
t "pubkey unreadable -> UNVERIFIED"                4 "$(run "$CHECK" "$W/a.md" "$W/m.json" "$W/nopub.pem")"
t "gate collapses UNVERIFIED to rc 4"              4 "$(run "$GATE"  "$W/a.md" "$W/m.json" "$W/pub2.pem")"
t "unreachable URL -> UNVERIFIED"                  4 "$(run "$CHECK" "$W/a.md" "http://127.0.0.1:9/m.json" "$W/pub.pem")"

# stamp/check agreement on every real canonical artifact (hash computed in two places)
bad=0; n=0
for f in "$ROOT"/canonical/*/*.md; do
  [ -r "$f" ] || continue; n=$((n+1))
  "$STAMP" "$f" chittycanon://test/x 1.0.0 > "$W/u.json" 2>/dev/null || { bad=$((bad+1)); continue; }
  sign "$W/u.json" "$SK" "$W/sm.json"
  [ "$(run "$CHECK" "$f" "$W/sm.json" "$W/pub.pem")" = 0 ] || { bad=$((bad+1)); echo "  stamp/check disagree: $f"; }
done
[ "$n" -gt 0 ] || { FAIL=$((FAIL+1)); echo "FAIL zero canonical artifacts found"; }
t "stamp->sign->check round-trip on $n real canonical artifacts (0 disagreements)" 0 "$bad"

# determinism: grep -q under pipefail SIGPIPEs the upstream sed on large files and silently
# falls through to hashing the WHOLE file (frontmatter included). Regression pin.
BIG="$(ls -S "$ROOT"/canonical/*/*.md | head -1)"
distinct="$(for _ in $(seq 150); do "$STAMP" "$BIG" chittycanon://test/x 1.0.0 2>/dev/null | jq -r .content_hash; done | sort -u | wc -l | tr -d ' ')"
t "stamp hash deterministic over 150 runs on largest artifact" 1 "$distinct"
cp "$BIG" "$W/big.md"; "$STAMP" "$W/big.md" chittycanon://test/x 1.0.0 > "$W/bu.json"; sign "$W/bu.json" "$SK" "$W/bm.json"
flaky=0; for _ in $(seq 150); do [ "$(run "$CHECK" "$W/big.md" "$W/bm.json" "$W/pub.pem")" = 0 ] || flaky=$((flaky+1)); done
t "check verdict stable over 150 runs on largest artifact (0 flaky)" 0 "$flaky"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"; exit "$FAIL"
