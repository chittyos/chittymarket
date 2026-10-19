#!/usr/bin/env bash
# stamp-canon.sh — release step: content_hash over the body below a complete YAML
# frontmatter block (CR-insensitive); emit the UNSIGNED manifest. The pipeline signs
# `jq -cS 'del(.signature)'` of the FINAL object (after signed_by is filled) with a
# service key (Secrets Store, brokered). No operator key. Requires jq + coreutils.
# canon: chittycanon://core/contracts/canon-versioning
# Usage: stamp-canon.sh <artifact-file> <uri> <version> [supersedes]
set -euo pipefail
BODY="${1:?body file}"; URI="${2:?canon uri}"; VER="${3:?version}"; PREV="${4:-}"
[ -r "$BODY" ] || { echo "stamp: artifact not readable: $BODY" >&2; exit 1; }
if command -v sha256sum >/dev/null 2>&1; then HASH_CMD="sha256sum"; else HASH_CMD="shasum -a 256"; fi
strip_fm() {
  if [ "$(sed -n '1p' "$1" | sed 's/\r$//')" = "---" ] && sed -n '2,$p' "$1" | sed 's/\r$//' | grep -qxF -- '---'; then
    awk '{l=$0; sub(/\r$/,"",l)} NR==1&&l=="---"{fm=1;next} fm&&l=="---"{fm=0;next} fm{next} {print}' "$1"
  else cat "$1"; fi
}
HASH="sha256:$(strip_fm "$BODY" | sed -e 's/\r$//' | sed -e :a -e '/^\n*$/{$d;N;ba}' | $HASH_CMD | cut -d' ' -f1)"
DIST="https://canon.chitty.cc/canon/$(printf '%s' "$URI" | sed 's#chittycanon://##')/manifest.json"
jq -n --arg uri "$URI" --arg v "$VER" --arg h "$HASH" --arg t "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" --arg p "$PREV" --arg d "$DIST" \
  '{uri:$uri, version:$v, content_hash:$h, released:$t, signed_by:"<service ChittyID>", supersedes:(if $p=="" then null else $p end), distribution:$d, runtimes:["claude-code","codex","openclaw","gemini"], signature:"<UNSIGNED: pipeline signs jq -cS del(.signature) with service key>"}'
