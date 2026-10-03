#!/usr/bin/env bash
# Offline test for the AI Gateway route-id lookup used by
# plugins/chittyos-core/skills/nb-development-defaults/scripts/apply-gateway-route.sh.
#
# Sources the SAME lib the script sources, so reverting the filter to the old
# `.result.routes? // .result?` lookup turns this test red (mutation-proven in the
# PR that added it). Fixtures are real response shapes, not invented ones.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="$ROOT/plugins/chittyos-core/skills/nb-development-defaults/scripts/lib/gateway-route-lookup.sh"
command -v jq >/dev/null || { echo "jq is required" >&2; exit 1; }
# shellcheck source=/dev/null
. "$LIB"

FAILS=0
check() { # name expected_rc expected_out list route
  local name="$1" want_rc="$2" want_out="$3" list="$4" route="$5" out rc
  set +e; out="$(route_id_from_list "$list" "$route" 2>/dev/null)"; rc=$?; set -e
  if [[ "$rc" == "$want_rc" && "$out" == "$want_out" ]]; then
    echo "ok   - $name"
  else
    echo "FAIL - $name: got rc=$rc out='$out', want rc=$want_rc out='$want_out'"
    FAILS=$((FAILS + 1))
  fi
}

# Historical capture 2026-10-03, before the operator deleted this route the same day.
# The route NAME is fixture data only; three-wise-men is retired and must not be recreated.
R=three-wise-men
# GET /accounts/0bc21e3a5a9de1a4cc843be9c3e98121/ai-gateway/gateways/central/routes
LIVE_LIST='{"success":true,"data":{"routes":[{"id":"9f66f555-fa67-4479-b3df-c40528a43c77","name":"'"$R"'","gateway_id":"central","account_tag":"0bc21e3a5a9de1a4cc843be9c3e98121","created_at":"2026-10-02 23:52:40","modified_at":"2026-10-02 23:52:40","version":{"version_id":"beb33635-bd67-45f0-af42-3d738722cf06","active":true,"created_at":"2026-10-02 23:52:40"},"deployment":{"deployment_id":"ab131237-ac7b-455b-ac7c-2da60bd04212","created_at":"2026-10-02 23:52:40","version_id":"beb33635-bd67-45f0-af42-3d738722cf06"}}],"page":1,"per_page":20,"order_by":"created_at","order_by_direction":"desc"}}'
# Detail GET shape (.result + .result.version.data) — a list lookup must NOT treat it as a list.
DETAIL='{"success":true,"result":{"id":"9f66f555-fa67-4479-b3df-c40528a43c77","name":"'"$R"'","version":{"version_id":"beb33635-bd67-45f0-af42-3d738722cf06","active":true,"data":[]},"deployment":{"version_id":"beb33635-bd67-45f0-af42-3d738722cf06"}}}'

check "live .data.routes list: id found"            0 "9f66f555-fa67-4479-b3df-c40528a43c77" "$LIVE_LIST" "$R"
check "live list, other name: absent (not error)"   0 ""  "$LIVE_LIST" "no-such-route"
check "empty .data.routes: absent (not error)"      0 ""  '{"success":true,"data":{"routes":[],"page":1}}' "$R"
check "legacy .result.routes fallback: id found"    0 "r-1" '{"success":true,"result":{"routes":[{"id":"r-1","name":"'"$R"'"}]}}' "$R"
check "no list key at all: unknown shape, exit 2"   2 ""  '{"success":true}' "$R"
check "bare .result array: unknown shape, exit 2"   2 ""  '{"success":true,"result":[]}' "$R"
check "detail object is not a list: exit 2"         2 ""  "$DETAIL" "$R"
check "non-JSON body: exit 2"                       2 ""  'not json' "$R"

if (( FAILS > 0 )); then echo "$FAILS gateway-route lookup test(s) failed"; exit 1; fi
echo "all gateway-route lookup tests passed"
