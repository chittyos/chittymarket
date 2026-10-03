#!/usr/bin/env bash
# Route-id lookup over a Cloudflare AI Gateway LIST-routes response.
# Sourced by apply-gateway-route.sh and by scripts/tests/test-gateway-route-lookup.sh,
# so the test exercises the exact filter the script runs.
#
# route_id_from_list <list-json> <route-name>
#   prints the route id and returns 0          -> route present
#   prints nothing and returns 0               -> route absent (known shape, no match)
#   prints the top-level keys to stderr, rc 2  -> UNKNOWN response shape
#
# Verified live 2026-10-03: GET .../gateways/{g}/routes returns the list at
# .data.routes (there is no .result). .result.routes is kept only as a fallback.
# An unknown shape must never read as "absent": absent drives the create path,
# which would make a duplicate route.
route_id_from_list() {
  local list="$1" name="$2"
  if ! printf '%s' "$list" | jq -e '(.data.routes // .result.routes) | type == "array"' >/dev/null 2>&1; then
    echo "unrecognised route-list response shape; top-level keys:" >&2
    printf '%s' "$list" | jq -c 'keys?' >&2 2>/dev/null || echo "(not JSON)" >&2
    return 2
  fi
  printf '%s' "$list" | jq -r --arg n "$name" \
    '[(.data.routes // .result.routes)[] | select(.name == $n) | .id][0] // empty'
}
