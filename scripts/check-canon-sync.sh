#!/usr/bin/env bash
# check-canon-sync.sh — verify a local canonical artifact against the deployed manifest.
# Identity = sha256 of the body BELOW a complete YAML frontmatter block (CR-insensitive),
# reference = SIGNED manifest, verdict emitted here. A valid ed25519 signature against a
# pinned pubkey is REQUIRED for IN_SYNC. Requires OpenSSL >= 3.0 (-rawin), jq, coreutils.
# canon: chittycanon://core/contracts/canon-versioning
# Usage: check-canon-sync.sh <artifact-file> <manifest-url-or-path> [pubkey-file]
# Exit: 0 IN_SYNC · 3 OUT_OF_SYNC · 4 UNVERIFIED
set -uo pipefail
BODY="${1:?artifact file}"; MANIFEST_SRC="${2:?manifest url or path}"; PUBKEY="${3:-${CANON_PUBKEY:-}}"
NOW="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/canonsync.XXXXXX")" || { echo "UNVERIFIED: mktemp failed" >&2; exit 4; }
trap 'rm -rf "$TMP"' EXIT INT TERM
ARTIFACT="?"; CANON_HASH="?"; CANON_VER="?"; SIG_STATE="?"; LOCAL_HASH="?"
emit() { printf 'CANON-SYNC %s | artifact=%s | local=%s | canon=%s | ver=%s | sig=%s | checked=%s | by=check-canon-sync\n' "$1" "$ARTIFACT" "$LOCAL_HASH" "$CANON_HASH" "$CANON_VER" "$SIG_STATE" "$NOW" >&2; }
if command -v sha256sum >/dev/null 2>&1; then HASH_CMD="sha256sum"
elif command -v shasum >/dev/null 2>&1; then HASH_CMD="shasum -a 256"
else echo "UNVERIFIED: no sha256 tool" >&2; exit 4; fi
[ -r "$BODY" ] || { SIG_STATE="n/a"; emit "UNVERIFIED"; echo "UNVERIFIED: artifact not readable: $BODY" >&2; exit 4; }
strip_fm() {
  if [ "$(sed -n '1p' "$1" | sed 's/\r$//')" = "---" ] && sed -n '2,$p' "$1" | sed 's/\r$//' | grep -qxF -- '---'; then
    awk '{l=$0; sub(/\r$/,"",l)} NR==1&&l=="---"{fm=1;next} fm&&l=="---"{fm=0;next} fm{next} {print}' "$1"
  else cat "$1"; fi
}
LOCAL_HASH="sha256:$(strip_fm "$BODY" | sed -e 's/\r$//' | sed -e :a -e '/^\n*$/{$d;N;ba}' | $HASH_CMD | cut -d' ' -f1)"
fetch() { case "$1" in http*://*) curl -fsS --max-time 10 "$1";; *) [ -r "$1" ] && cat "$1";; esac; }
if ! MANIFEST="$(fetch "$MANIFEST_SRC")" || [ -z "$MANIFEST" ]; then
  SIG_STATE="unreachable"; emit "UNVERIFIED"; echo "UNVERIFIED: manifest unreachable/empty ($MANIFEST_SRC)" >&2; exit 4; fi
if ! printf '%s' "$MANIFEST" | jq -e '(.content_hash|type=="string") and (.content_hash|length>0)' >/dev/null 2>&1; then
  SIG_STATE="n/a"; emit "UNVERIFIED"; echo "UNVERIFIED: manifest unparseable or missing content_hash" >&2; exit 4; fi
ARTIFACT="$(printf '%s' "$MANIFEST" | jq -r '.uri // "?"')"
CANON_HASH="$(printf '%s' "$MANIFEST" | jq -r '.content_hash')"
CANON_VER="$(printf '%s' "$MANIFEST" | jq -r '.version // "?"')"
if [ -z "$PUBKEY" ]; then SIG_STATE="no-pubkey"; emit "UNVERIFIED"; echo "UNVERIFIED: no pinned pubkey" >&2; exit 4; fi
if [ ! -r "$PUBKEY" ]; then SIG_STATE="pubkey-unreadable"; emit "UNVERIFIED"; echo "UNVERIFIED: pubkey not readable: $PUBKEY" >&2; exit 4; fi
printf '%s' "$MANIFEST" | jq -cS 'del(.signature)' > "$TMP/signed"
SIG_B64="$(printf '%s' "$MANIFEST" | jq -r '.signature // empty')"
if [ -z "$SIG_B64" ] || ! printf '%s' "$SIG_B64" | openssl base64 -d -A > "$TMP/sig" 2>/dev/null || [ ! -s "$TMP/sig" ]; then
  SIG_STATE="no-signature"; emit "UNVERIFIED"; echo "UNVERIFIED: no decodable signature" >&2; exit 4; fi
if openssl pkeyutl -verify -pubin -inkey "$PUBKEY" -rawin -in "$TMP/signed" -sigfile "$TMP/sig" >/dev/null 2>&1; then
  SIG_STATE="valid"
else SIG_STATE="INVALID"; emit "UNVERIFIED"; echo "UNVERIFIED: signature INVALID" >&2; exit 4; fi
if [ "$LOCAL_HASH" = "$CANON_HASH" ]; then
  emit "IN_SYNC"; echo "IN SYNC ok $ARTIFACT @ $CANON_VER" >&2; exit 0
else emit "OUT_OF_SYNC"; echo "OUT OF SYNC $ARTIFACT local $LOCAL_HASH canon $CANON_HASH" >&2; exit 3; fi
