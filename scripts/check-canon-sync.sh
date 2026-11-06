#!/usr/bin/env bash
# check-canon-sync.sh — verify a local canonical artifact against the deployed manifest.
# Identity = canon-hash-v1 (scripts/lib/canon-hash.sh): behaviour-affecting frontmatter keys + fm marker + body,
# reference = SIGNED manifest, verdict emitted here. A valid ed25519 signature against a
# pinned pubkey is REQUIRED for IN_SYNC. Requires OpenSSL >= 3.0 (-rawin), jq, coreutils.
# canon: chittycanon://core/contracts/canon-versioning
# Usage: check-canon-sync.sh <artifact-file> <manifest-url-or-path> <pubkey-file> <expected-uri> [min-version]
# The pubkey is an explicit argument (no environment fallback: env must not choose the trust anchor).
# The signed manifest uri MUST equal <expected-uri>; version MUST be >= [min-version] (sort -V).
# Exit: 0 IN_SYNC · 3 OUT_OF_SYNC · 4 UNVERIFIED
set -uo pipefail
BODY="${1:?artifact file}"; MANIFEST_SRC="${2:?manifest url or path}"; PUBKEY="${3:-}"; EXPECT_URI="${4:-}"; MIN_VER="${5:-}"
NOW="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/canonsync.XXXXXX")" || { echo "UNVERIFIED: mktemp failed" >&2; exit 4; }
trap 'rm -rf "$TMP"' EXIT INT TERM
ARTIFACT="?"; CANON_HASH="?"; CANON_VER="?"; SIG_STATE="?"; LOCAL_HASH="?"
emit() { printf 'CANON-SYNC %s | artifact=%s | local=%s | canon=%s | ver=%s | sig=%s | checked=%s | by=check-canon-sync\n' "$1" "$ARTIFACT" "$LOCAL_HASH" "$CANON_HASH" "$CANON_VER" "$SIG_STATE" "$NOW" >&2; }
. "$(dirname "$0")/lib/canon-hash.sh" || { echo "UNVERIFIED: cannot load lib/canon-hash.sh" >&2; exit 4; }
[ -f "$BODY" ] && [ -r "$BODY" ] || { SIG_STATE="n/a"; emit "UNVERIFIED"; echo "UNVERIFIED: artifact not readable: $BODY" >&2; exit 4; }
LOCAL_HASH="$(canon_hash "$BODY")" || { LOCAL_HASH="?"; SIG_STATE="n/a"; emit "UNVERIFIED"; echo "UNVERIFIED: hash pipeline failed on $BODY" >&2; exit 4; }
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
# Bind the signed manifest to THIS artifact and to freshness (signed fields, now actually compared).
if [ -z "$EXPECT_URI" ]; then emit "UNVERIFIED"; echo "UNVERIFIED: no expected uri supplied" >&2; exit 4; fi
if [ "$ARTIFACT" != "$EXPECT_URI" ]; then emit "UNVERIFIED"; echo "UNVERIFIED: manifest uri '$ARTIFACT' != expected '$EXPECT_URI'" >&2; exit 4; fi
if [ -n "$MIN_VER" ] && [ "$(printf '%s\n%s\n' "$MIN_VER" "$CANON_VER" | sort -V | head -n1)" != "$MIN_VER" ]; then
  emit "UNVERIFIED"; echo "UNVERIFIED: manifest version $CANON_VER < required $MIN_VER (stale/replayed)" >&2; exit 4; fi
if ! canon_body_nonempty "$BODY"; then
  emit "UNVERIFIED"; echo "UNVERIFIED: empty-body artifact refused" >&2; exit 4; fi
if [ "$LOCAL_HASH" = "$CANON_HASH" ]; then
  emit "IN_SYNC"; echo "IN SYNC ok $ARTIFACT @ $CANON_VER" >&2; exit 0
else emit "OUT_OF_SYNC"; echo "OUT OF SYNC $ARTIFACT local $LOCAL_HASH canon $CANON_HASH" >&2; exit 3; fi
