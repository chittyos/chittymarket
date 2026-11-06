#!/usr/bin/env bash
# stamp-canon.sh — release step: content_hash = canon-hash-v3 of the WHOLE artifact
# (scripts/lib/canon-hash.sh); emit the UNSIGNED manifest. The pipeline signs
# `jq -cS 'del(.signature)'` of the FINAL object (after signed_by is filled) with a
# service key (Secrets Store, brokered). No operator key. Requires jq + coreutils.
# canon: chittycanon://core/contracts/canon-versioning
# Usage: stamp-canon.sh <artifact-file> <uri> <version> [supersedes]
set -euo pipefail
BODY="${1:?body file}"; URI="${2:?canon uri}"; VER="${3:?version}"; PREV="${4:-}"
[ -f "$BODY" ] && [ -r "$BODY" ] || { echo "stamp: artifact not readable: $BODY" >&2; exit 1; }
. "$(dirname "$0")/lib/canon-hash.sh"
[[ $URI =~ ^chittycanon://[^[:space:][:cntrl:]]+$ ]] || { echo "stamp: malformed uri: $URI" >&2; exit 1; }
[[ $VER =~ $CANON_VER_RE ]] || { echo "stamp: malformed version: $VER" >&2; exit 1; }
canon_body_nonempty "$BODY" || { echo "stamp: empty-body artifact refused: $BODY" >&2; exit 1; }
HASH="$(canon_hash "$BODY")" || { echo "stamp: hash failed: $BODY" >&2; exit 1; }
DIST="https://canon.chitty.cc/canon/$(printf '%s' "$URI" | sed 's#chittycanon://##')/manifest.json"
jq -n --arg uri "$URI" --arg v "$VER" --arg h "$HASH" --arg t "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" --arg p "$PREV" --arg d "$DIST" \
  '{uri:$uri, version:$v, content_hash:$h, released:$t, signed_by:"<service ChittyID>", supersedes:(if $p=="" then null else $p end), distribution:$d, runtimes:["claude-code","codex","openclaw","gemini"], signature:"<UNSIGNED: pipeline signs jq -cS del(.signature) with service key>"}'
