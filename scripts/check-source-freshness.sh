#!/usr/bin/env bash
# check-source-freshness.sh
# Freshness/liveness audit of every source_link in the Capability Overlay.
#
# Default (CI-safe, deterministic — GATES):
#   marketplace://artifact/<id>  -> <id> must be a real artifact in marketplace.json
#   local://<repo-relative-path> -> path must exist in the repo
# Non-gating warnings (printed, exit unaffected):
#   local://~/...                -> user-home install path, unverifiable in CI
#   ch1tty://servers/<id>        -> deferred to --live (authoritative source is
#                                   ch1tty servers.json, not reachable here)
#
# --live  ALSO probes ch1tty://servers/<id> against mcp.chitty.cc/health and
#         reports any serverId not advertised there. REPORT-ONLY: /health's
#         service list is indicative, NOT the authoritative serverId registry
#         (ch1tty servers.json is), so --live never changes the exit code.
#
# Exit 0 = all gated links resolve. Exit 1 = dangling marketplace:// or local://
# repo link. Exit 2 = I/O.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
cd "$REPO_ROOT"

MANIFEST="marketplace.json"
OVERLAY="capabilities.generated.json"
LIVE=0
[ "${1:-}" = "--live" ] && LIVE=1

red()    { printf '\033[0;31m%s\033[0m\n' "$1"; }
green()  { printf '\033[0;32m%s\033[0m\n' "$1"; }
yellow() { printf '\033[0;33m%s\033[0m\n' "$1"; }
dim()    { printf '\033[0;90m%s\033[0m\n' "$1"; }

for f in "$MANIFEST" "$OVERLAY"; do
  [ -f "$f" ] && jq -e . "$f" >/dev/null 2>&1 || { red "ERROR: $f missing or invalid JSON"; exit 2; }
done

echo "=== source-link freshness ==="

artifact_ids="$(mktemp)"; trap 'rm -f "$artifact_ids"' EXIT
jq -r '.artifacts[] | select(has("id")) | .id' "$MANIFEST" | sort -u > "$artifact_ids"

# Collect "<legacy_id>\t<link>" rows.
mapfile -t ROWS < <(jq -r '.capabilities[] | .legacy_id as $id | .source_links[] | "\($id)\t\(.)"' "$OVERLAY")

fail=0 n_market=0 n_localrepo=0 n_localhome=0 n_ch1tty=0
DANGLING=(); WARN_HOME=(); CH1TTY_LINKS=()

for row in "${ROWS[@]}"; do
  id="${row%%$'\t'*}"; link="${row#*$'\t'}"
  case "$link" in
    marketplace://artifact/*)
      n_market=$((n_market+1))
      ref="${link#marketplace://artifact/}"
      grep -qxF "$ref" "$artifact_ids" || { DANGLING+=("$id -> $link (no such artifact)"); fail=1; }
      ;;
    local://~/*)
      n_localhome=$((n_localhome+1)); WARN_HOME+=("$id -> $link")
      ;;
    local://*)
      n_localrepo=$((n_localrepo+1))
      path="${link#local://}"
      [ -e "$path" ] || { DANGLING+=("$id -> $link (path not in repo)"); fail=1; }
      ;;
    ch1tty://servers/*)
      n_ch1tty=$((n_ch1tty+1)); CH1TTY_LINKS+=("$id|${link#ch1tty://servers/}")
      ;;
    *)
      DANGLING+=("$id -> $link (unrecognized scheme)"); fail=1
      ;;
  esac
done

echo "  links: marketplace=$n_market(gated)  local-repo=$n_localrepo(gated)  local-home=$n_localhome(warn)  ch1tty=$n_ch1tty(live-only)"
echo ""

if [ "${#DANGLING[@]}" -gt 0 ]; then
  red "  DANGLING gated links (${#DANGLING[@]}):"
  printf '    - %s\n' "${DANGLING[@]}"
fi

if [ "$n_localhome" -gt 0 ]; then
  dim "  $n_localhome local://~/ install-path link(s) — unverifiable in CI (skipped)."
fi

if [ "$LIVE" -eq 1 ] && [ "$n_ch1tty" -gt 0 ]; then
  echo ""
  yellow "  --live: probing $n_ch1tty ch1tty:// serverId(s) against mcp.chitty.cc/health (indicative only)..."
  live_services="$(curl -s --max-time 8 https://mcp.chitty.cc/health | jq -r '.services[]?' 2>/dev/null | sort -u || true)"
  if [ -z "$live_services" ]; then
    dim "    could not reach mcp.chitty.cc/health — skipping live probe."
  else
    not_advertised=()
    for cl in "${CH1TTY_LINKS[@]}"; do
      sid="${cl#*|}"
      grep -qxF "$sid" <<<"$live_services" || not_advertised+=("${cl%%|*} -> ch1tty://servers/$sid")
    done
    if [ "${#not_advertised[@]}" -gt 0 ]; then
      yellow "    ${#not_advertised[@]} serverId(s) not advertised in /health (verify vs authoritative servers.json):"
      printf '      - %s\n' "${not_advertised[@]}"
    else
      green "    all ch1tty serverIds advertised in /health."
    fi
  fi
fi

echo ""
if [ "$fail" -eq 0 ]; then
  green "  All clear — every gated source_link resolves."
  exit 0
fi
red "Source-link freshness check FAILED (dangling gated link)."
exit 1
