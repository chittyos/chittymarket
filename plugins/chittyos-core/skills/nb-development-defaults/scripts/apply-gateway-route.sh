#!/usr/bin/env bash
# Apply (or drift-check) a Cloudflare AI Gateway dynamic route from a JSON file.
#
# Usage:
#   apply-gateway-route.sh <route-json> [--gateway central] [--check]
#
# Route JSON: {"name": "...", "gateway": "central", "elements": [...]}
# See ai-gateway-routes/README.md (three-wise-men = the separated adversarial
# reviewer route; judgment work, never downgrade to a cheap model).
#
# Behaviour (idempotent):
#   route absent            -> create route, create version {elements}, deploy it
#   present, elements equal -> no-op
#   present, elements differ-> create new version, deploy it
#   --check                 -> report only; changes nothing
#
# Exit codes: 0 in sync / applied | 1 drift (--check) | 2 API/usage/auth error
#
# Auth: CLOUDFLARE_API_TOKEN must be supplied by the caller from the ChittySecrets /
# ChittyConnect broker (route credential intent through /chico). This script never
# obtains, prints, or logs the token; it is passed to curl via stdin config so it
# is not visible in the process list.
#
# NOTE: response shapes are parsed tolerantly; if the live shape is not recognised
# the script exits 2 rather than reporting a false "in sync".
set -euo pipefail
set +x

ACCOUNT="0bc21e3a5a9de1a4cc843be9c3e98121"
GATEWAY=""
CHECK=0
SMOKE=0
FILE=""

die() { echo "$*" >&2; exit 2; }

finish() {
  # --smoke: in-sync JSON is not proof the route answers. Call it for real through
  # the sibling reviewer script (chittyclaw path) with a tiny diff; non-zero = broken.
  if [[ $SMOKE -eq 1 ]]; then
    local review; review="$(dirname "$0")/adversarial-review.sh"
    [[ -r "$review" ]] || die "--smoke needs $review"
    printf -- '--- a/x.js\n+++ b/x.js\n@@ -1 +1 @@\n-return t > 0\n+return t >= 0 || t\n' \
      | REVIEW_MODEL="cloudflare-ai-gateway/dynamic/$NAME" bash "$review" - >/dev/null 2>&1 \
      || { echo "SMOKE FAILED: dynamic/$NAME did not return a review" >&2; exit 3; }
    echo "smoke ok: dynamic/$NAME returned a review"
  fi
  exit 0
}


while [[ $# -gt 0 ]]; do
  case "$1" in
    --gateway) GATEWAY="${2:-}"; [[ -n "$GATEWAY" ]] || die "--gateway needs a value"; shift 2 ;;
    --check)   CHECK=1; shift ;;
    --smoke)   SMOKE=1; shift ;;
    -h|--help) sed -n '2,24p' "$0"; exit 0 ;;
    -*)        die "unknown arg: $1" ;;
    *)         [[ -z "$FILE" ]] || die "unexpected extra arg: $1"; FILE="$1"; shift ;;
  esac
done

[[ -n "$FILE" && -r "$FILE" ]] || die "usage: $(basename "$0") <route-json> [--gateway central] [--check] [--smoke]"
command -v jq >/dev/null   || die "jq is required"
command -v curl >/dev/null || die "curl is required"

if [[ -z "${CLOUDFLARE_API_TOKEN:-}" ]]; then
  echo "POLICY_BLOCKED_CHITTYCONNECT_UNAVAILABLE: CLOUDFLARE_API_TOKEN is not set." >&2
  echo "  The token must come from the ChittySecrets/ChittyConnect broker (/chico). Nothing was changed." >&2
  exit 2
fi

NAME="$(jq -er '.name' "$FILE")" || die "route JSON missing .name"
jq -e '.elements | type == "array" and length > 0' "$FILE" >/dev/null || die "route JSON missing non-empty .elements array"
[[ -n "$GATEWAY" ]] || GATEWAY="$(jq -r '.gateway // "central"' "$FILE")"
DESIRED="$(jq -S -c '.elements' "$FILE")"

BASE="https://api.cloudflare.com/client/v4/accounts/$ACCOUNT/ai-gateway/gateways/$GATEWAY/routes"

# api METHOD URL [JSON-BODY]  -> prints response body; exits 2 on transport/HTTP/success=false
api() {
  local method="$1" url="$2" body="${3:-}" resp code
  local out; out="$(mktemp)"
  local args=(-sS -o "$out" -w '%{http_code}' -X "$method" -K - -H 'Content-Type: application/json')
  [[ -n "$body" ]] && args+=(--data-binary "$body")
  code="$(printf 'header = "Authorization: Bearer %s"\n' "$CLOUDFLARE_API_TOKEN" | curl "${args[@]}" "$url")" \
    || { rm -f "$out"; die "API transport error: $method $url"; }
  resp="$(cat "$out")"; rm -f "$out"
  if [[ "$code" != 2* ]] || ! printf '%s' "$resp" | jq -e '.success == true' >/dev/null 2>&1; then
    echo "API error: $method ${url#https://api.cloudflare.com/client/v4} -> HTTP $code" >&2
    printf '%s' "$resp" | jq -c '.errors // .' 2>/dev/null >&2 || true
    exit 2
  fi
  printf '%s' "$resp"
}

LIST="$(api GET "$BASE")"
ROUTE_ID="$(printf '%s' "$LIST" | jq -r --arg n "$NAME" \
  '[(.result.routes? // .result? // [])[]? | select(.name == $n) | .id][0] // empty')"

if [[ -z "$ROUTE_ID" ]]; then
  if [[ $CHECK -eq 1 ]]; then
    echo "DRIFT: route '$NAME' is absent on gateway '$GATEWAY'" >&2
    exit 1
  fi
  echo "route '$NAME' absent on '$GATEWAY' — creating" >&2
  # Create takes {name, elements} and deploys that first version itself
  # (verified live 2026-10-02: response carries .result.version and .result.deployment).
  CREATED="$(api POST "$BASE" "$(jq -c '{name: .name, elements: .elements}' "$FILE")")"
  ROUTE_ID="$(printf '%s' "$CREATED" | jq -er '.result.id')" || die "create returned no route id"
  printf '%s' "$CREATED" | jq -e '.result.deployment.version_id' >/dev/null \
    || die "route created but no deployment reported; run --check and inspect"
  echo "applied: route '$NAME' ($ROUTE_ID) created and deployed on '$GATEWAY'"
  finish
else
  DETAIL="$(api GET "$BASE/$ROUTE_ID")"
  # Active version's elements; shape probed in order. Unknown shape => exit 2, never "in sync".
  LIVE="$(printf '%s' "$DETAIL" | jq -S -c '
    # Verified live 2026-10-02: GET returns .result.version {version_id,data,active}
    # and .result.deployment {version_id}. Only trust .version.data when it IS the
    # deployed version; anything else is an unknown shape => exit 2.
    if (.result.version.version_id != null
        and .result.version.version_id == .result.deployment.version_id)
    then .result.version.data else empty end')"
  if [[ -z "$LIVE" ]]; then
    echo "cannot locate active version elements in route response; top-level result keys:" >&2
    printf '%s' "$DETAIL" | jq -c '.result | keys?' >&2 || true
    exit 2
  fi
  if [[ "$LIVE" == "$DESIRED" ]]; then
    echo "in sync: route '$NAME' ($ROUTE_ID) on '$GATEWAY'"
    finish
  fi
  if [[ $CHECK -eq 1 ]]; then
    echo "DRIFT: live active version of '$NAME' ($ROUTE_ID) differs from $FILE" >&2
    exit 1
  fi
  echo "drift on '$NAME' ($ROUTE_ID) — creating new version" >&2
  NEED_VERSION=1
fi

if [[ "${NEED_VERSION:-0}" -eq 1 ]]; then
  api POST "$BASE/$ROUTE_ID/versions" "$(jq -c '{elements: .elements}' "$FILE")" >/dev/null
  # The create response does not reliably carry the version id (its .result.id is
  # the route's). Find the version by CONTENT instead: verified live 2026-10-02,
  # GET .../versions returns .data.versions[] {version_id, data, created_at}.
  # NOTE: CF reports is_valid:false on a working active version; do not gate on it.
  VERSIONS="$(api GET "$BASE/$ROUTE_ID/versions")"
  VERSION_ID="$(printf '%s' "$VERSIONS" | jq -r --argjson want "$DESIRED" '
    [(.data.versions // .result.versions // [])[]
     | select((.data | tojson | fromjson) as $d | ($d | walk(if type=="object" then to_entries|sort_by(.key)|from_entries else . end)) == ($want | walk(if type=="object" then to_entries|sort_by(.key)|from_entries else . end)))]
    | sort_by(.created_at) | last | .version_id // empty')"
  [[ -n "$VERSION_ID" ]] || die "created a version but cannot find one whose elements match $FILE; nothing deployed"
  api POST "$BASE/$ROUTE_ID/deployments" "$(jq -c -n --arg v "$VERSION_ID" '{version_id:$v}')" >/dev/null
  # Read back: the deployed version must now carry exactly the desired elements.
  AFTER="$(api GET "$BASE/$ROUTE_ID" | jq -S -c 'if (.result.version.version_id == .result.deployment.version_id) then .result.version.data else empty end')"
  [[ "$AFTER" == "$DESIRED" ]] || die "deploy of $VERSION_ID did not take: live deployed elements differ from $FILE"
  echo "applied: route '$NAME' ($ROUTE_ID) version $VERSION_ID deployed and read back on '$GATEWAY'"
fi

finish
