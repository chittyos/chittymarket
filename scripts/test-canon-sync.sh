#!/usr/bin/env bash
# test-canon-sync.sh — real-crypto test corpus (hash = canon-hash-v1, scripts/lib/canon-hash.sh) for check-canon-sync.sh / gate-canon-sync.sh.
# No mocks: generates a throwaway ed25519 keypair (openssl) in a temp dir, stamps REAL
# canonical/ artifacts with stamp-canon.sh, signs the manifest the way the pipeline does
# (jq -cS del(.signature)), and asserts exit codes. Fail-closed cases must exit 3/4, never 0.
# The keypair is test-only and deleted on exit; no service key is touched.
# Usage: scripts/test-canon-sync.sh   (exit 0 = all pass; nonzero = failure count)
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(dirname "$HERE")"
CHECK="$HERE/check-canon-sync.sh"; GATE="$HERE/gate-canon-sync.sh"; STAMP="$HERE/stamp-canon.sh"
W="$(mktemp -d "${TMPDIR:-/tmp}/canontest.XXXXXX")"; trap 'rm -rf "$W"' EXIT
URI=chittycanon://test/canon-sync
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

t "valid artifact+manifest+sig -> IN_SYNC"        0 "$(run "$CHECK" "$W/a.md" "$W/m.json" "$W/pub.pem" "$URI")"
t "gate passes IN_SYNC"                            0 "$(run "$GATE"  "$W/a.md" "$W/m.json" "$W/pub.pem" "$URI")"
t "CANON env var alone must NOT supply the trust anchor" 4 "$(CANON_PUBKEY="$W/pub.pem" run "$CHECK" "$W/a.md" "$W/m.json" "" "$URI")"

# identity semantics (canon-hash-v1: allowlisted frontmatter keys + fm marker + body)
sed '1a projection_id: zzz-not-behaviour' "$W/a.md" > "$W/fm.md"
t "non-allowlisted frontmatter key added -> still IN_SYNC"   0 "$(run "$CHECK" "$W/fm.md" "$W/m.json" "$W/pub.pem" "$URI")"
sed 's/^description:/description: EVIL/' "$W/a.md" > "$W/fd.md"
t "description (allowlisted) edited -> OUT_OF_SYNC"          3 "$(run "$CHECK" "$W/fd.md" "$W/m.json" "$W/pub.pem" "$URI")"
sed '1a permissionMode: bypassPermissions' "$W/a.md" > "$W/fp.md"
t "permissionMode injected into frontmatter -> OUT_OF_SYNC"  3 "$(run "$CHECK" "$W/fp.md" "$W/m.json" "$W/pub.pem" "$URI")"
sed '1a tools: Bash, Write, Edit, Agent' "$W/a.md" > "$W/ft.md"
t "tools injected into frontmatter -> OUT_OF_SYNC"           3 "$(run "$CHECK" "$W/ft.md" "$W/m.json" "$W/pub.pem" "$URI")"
printf 'Plain doc, no frontmatter.\nSecond line.\n' > "$W/nofm.md"; "$STAMP" "$W/nofm.md" "$URI" 1.0.0 > "$W/nu.json"; sign "$W/nu.json" "$SK" "$W/nm.json"
t "no-frontmatter artifact -> IN_SYNC"                       0 "$(run "$CHECK" "$W/nofm.md" "$W/nm.json" "$W/pub.pem" "$URI")"
{ printf -- '---\nanything: deploy freely\n---\n'; cat "$W/nofm.md"; } > "$W/fake.md"
t "fake frontmatter prepended to bare artifact -> OUT_OF_SYNC" 3 "$(run "$CHECK" "$W/fake.md" "$W/nm.json" "$W/pub.pem" "$URI")"
# known-answer vector, computed independently in python (stamp and check share the lib, so a round trip alone proves nothing)
printf -- '---\nname: kat\nignored: z\ndescription: |\n  line1\n\n  line2\n---\nBody line\n\n\n' > "$W/kat.md"
EXPECT="sha256:$(python3 -I -c "import hashlib;print(hashlib.sha256(b'canon-hash-v1\nfm=1\ndescription: |\n  line1\n  line2\nname: kat\nbody\nBody line\n').hexdigest())")"
GOT="$("$STAMP" "$W/kat.md" "$URI" 1.0.0 2>/dev/null | jq -r .content_hash)"
t "known-answer vector matches independent python hash" "$EXPECT" "$GOT"
sed 's/$/\r/' "$W/a.md" > "$W/crlf.md"
t "CRLF line endings -> still IN_SYNC"             0 "$(run "$CHECK" "$W/crlf.md" "$W/m.json" "$W/pub.pem" "$URI")"
{ cat "$W/a.md"; printf '\n\n\n'; } > "$W/trail.md"
t "trailing blank lines -> still IN_SYNC"          0 "$(run "$CHECK" "$W/trail.md" "$W/m.json" "$W/pub.pem" "$URI")"
jq -c 'to_entries|reverse|from_entries' "$W/m.json" > "$W/reorder.json"
t "manifest key reorder -> still IN_SYNC"          0 "$(run "$CHECK" "$W/a.md" "$W/reorder.json" "$W/pub.pem" "$URI")"

# drift
{ cat "$W/a.md"; echo "tampered line"; } > "$W/body.md"
t "body tampered -> OUT_OF_SYNC"                   3 "$(run "$CHECK" "$W/body.md" "$W/m.json" "$W/pub.pem" "$URI")"
t "gate blocks OUT_OF_SYNC with rc 3"              3 "$(run "$GATE"  "$W/body.md" "$W/m.json" "$W/pub.pem" "$URI")"
: > "$W/empty.md"
t "empty artifact -> UNVERIFIED (empty-body hash refused)" 4 "$(run "$CHECK" "$W/empty.md" "$W/m.json" "$W/pub.pem" "$URI")"

# unverified (must never be 0 or 3)
jq '.version="9.9.9"' "$W/m.json" > "$W/mv.json"
t "manifest field edited after signing -> UNVERIFIED" 4 "$(run "$CHECK" "$W/a.md" "$W/mv.json" "$W/pub.pem" "$URI")"
ZERO="$(printf '0%.0s' $(seq 64))"
jq --arg h "sha256:$ZERO" '.content_hash=$h' "$W/m.json" > "$W/mh.json"
t "hash swapped, stale sig -> UNVERIFIED (not OUT_OF_SYNC)" 4 "$(run "$CHECK" "$W/body.md" "$W/mh.json" "$W/pub.pem" "$URI")"
t "wrong pinned pubkey -> UNVERIFIED"              4 "$(run "$CHECK" "$W/a.md" "$W/m.json" "$W/pub2.pem" "$URI")"
jq 'del(.signature)' "$W/m.json" > "$W/ns.json"
t "signature absent -> UNVERIFIED"                 4 "$(run "$CHECK" "$W/a.md" "$W/ns.json" "$W/pub.pem" "$URI")"
t "stamp placeholder signature -> UNVERIFIED"      4 "$(run "$CHECK" "$W/a.md" "$W/m.unsigned" "$W/pub.pem" "$URI")"
jq '.signature="!!!notbase64!!!"' "$W/m.json" > "$W/bs.json"
t "garbage signature -> UNVERIFIED"                4 "$(run "$CHECK" "$W/a.md" "$W/bs.json" "$W/pub.pem" "$URI")"
jq '.content_hash=""' "$W/m.json" > "$W/eh.json"
t "empty content_hash -> UNVERIFIED"               4 "$(run "$CHECK" "$W/a.md" "$W/eh.json" "$W/pub.pem" "$URI")"
echo 'not json' > "$W/nj.json"
t "manifest not JSON -> UNVERIFIED"                4 "$(run "$CHECK" "$W/a.md" "$W/nj.json" "$W/pub.pem" "$URI")"
t "manifest missing -> UNVERIFIED"                 4 "$(run "$CHECK" "$W/a.md" "$W/nope.json" "$W/pub.pem" "$URI")"
t "artifact missing -> UNVERIFIED"                 4 "$(run "$CHECK" "$W/nope.md" "$W/m.json" "$W/pub.pem" "$URI")"
t "no pubkey supplied -> UNVERIFIED"               4 "$(run "$CHECK" "$W/a.md" "$W/m.json" "" "$URI")"
t "pubkey unreadable -> UNVERIFIED"                4 "$(run "$CHECK" "$W/a.md" "$W/m.json" "$W/nopub.pem" "$URI")"
t "gate collapses UNVERIFIED to rc 4"              4 "$(run "$GATE"  "$W/a.md" "$W/m.json" "$W/pub2.pem" "$URI")"
t "unreachable URL -> UNVERIFIED"                  4 "$(run "$CHECK" "$W/a.md" "http://127.0.0.1:9/m.json" "$W/pub.pem" "$URI")"


# manifest binding / freshness (signed fields must actually be compared)
t "manifest for a different uri -> UNVERIFIED"      4 "$(run "$CHECK" "$W/a.md" "$W/m.json" "$W/pub.pem" chittycanon://test/OTHER)"
t "no expected uri supplied -> UNVERIFIED"          4 "$(run "$CHECK" "$W/a.md" "$W/m.json" "$W/pub.pem")"
t "version >= min-version -> IN_SYNC"               0 "$(run "$CHECK" "$W/a.md" "$W/m.json" "$W/pub.pem" "$URI" 1.0.0)"
t "stale manifest (1.0.0 < min 1.0.1) -> UNVERIFIED" 4 "$(run "$CHECK" "$W/a.md" "$W/m.json" "$W/pub.pem" "$URI" 1.0.1)"
mkdir -p "$W/adir"
t "directory as artifact -> UNVERIFIED"             4 "$(run "$CHECK" "$W/adir" "$W/m.json" "$W/pub.pem" "$URI")"
printf -- '---\nname: x\n---\n' > "$W/fmonly.md"; "$STAMP" "$W/fmonly.md" "$URI" 1.0.0 > "$W/fu.json"; sign "$W/fu.json" "$SK" "$W/fmo.json"
t "frontmatter-only artifact (empty-body hash) -> UNVERIFIED" 4 "$(run "$CHECK" "$W/fmonly.md" "$W/fmo.json" "$W/pub.pem" "$URI")"
# '---' rules inside the body must stay in the hash (kills the awk toggle mutation)
printf -- '---\nname: x\n---\nintro\n\n---\nsecret-rule A\n---\noutro\n' > "$W/rules.md"
"$STAMP" "$W/rules.md" "$URI" 1.0.0 > "$W/ru.json"; sign "$W/ru.json" "$SK" "$W/rm.json"
t "body with '---' rules -> IN_SYNC"                0 "$(run "$CHECK" "$W/rules.md" "$W/rm.json" "$W/pub.pem" "$URI")"
sed 's/secret-rule A/secret-rule B/' "$W/rules.md" > "$W/rules2.md"
t "edit between body '---' rules -> OUT_OF_SYNC"    3 "$(run "$CHECK" "$W/rules2.md" "$W/rm.json" "$W/pub.pem" "$URI")"
# reason codes: rc alone cannot tell causes apart
reason() { "$@" 2>&1 >/dev/null | grep -o 'sig=[^ ]*' | head -1; }
t "reason: wrong key -> sig=INVALID"                "sig=INVALID" "$(reason "$CHECK" "$W/a.md" "$W/m.json" "$W/pub2.pem" "$URI")"
t "reason: absent signature -> sig=no-signature"    "sig=no-signature" "$(reason "$CHECK" "$W/a.md" "$W/ns.json" "$W/pub.pem" "$URI")"
t "reason: unreadable key file -> sig=pubkey-unreadable" "sig=pubkey-unreadable" "$(reason "$CHECK" "$W/a.md" "$W/m.json" "$W/nopub.pem" "$URI")"

# stamp/check agreement on every real canonical artifact (hash computed in two places)
bad=0; n=0
for f in "$ROOT"/canonical/*/*.md; do
  [ -r "$f" ] || continue; n=$((n+1))
  "$STAMP" "$f" "$URI" 1.0.0 > "$W/u.json" 2>/dev/null || { bad=$((bad+1)); continue; }
  sign "$W/u.json" "$SK" "$W/sm.json"
  [ "$(run "$CHECK" "$f" "$W/sm.json" "$W/pub.pem" "$URI")" = 0 ] || { bad=$((bad+1)); echo "  stamp/check disagree: $f"; }
done
[ "$n" -gt 0 ] || { FAIL=$((FAIL+1)); echo "FAIL zero canonical artifacts found"; }
t "stamp->sign->check round-trip on $n real canonical artifacts (0 disagreements)" 0 "$bad"

# determinism: grep -q under pipefail SIGPIPEs the upstream sed on large files and silently
# falls through to hashing the WHOLE file (frontmatter included). Regression pin.
BIG="$(ls -S "$ROOT"/canonical/*/*.md | head -1)"
distinct="$(for _ in $(seq 150); do "$STAMP" "$BIG" chittycanon://test/x 1.0.0 2>/dev/null | jq -r .content_hash; done | sort -u | wc -l | tr -d ' ')"
t "stamp hash deterministic over 150 runs on largest artifact" 1 "$distinct"
cp "$BIG" "$W/big.md"; "$STAMP" "$W/big.md" "$URI" 1.0.0 > "$W/bu.json"; sign "$W/bu.json" "$SK" "$W/bm.json"
flaky=0; for _ in $(seq 150); do [ "$(run "$CHECK" "$W/big.md" "$W/bm.json" "$W/pub.pem" "$URI")" = 0 ] || flaky=$((flaky+1)); done
t "check verdict stable over 150 runs on largest artifact (0 flaky)" 0 "$flaky"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"; exit "$FAIL"
