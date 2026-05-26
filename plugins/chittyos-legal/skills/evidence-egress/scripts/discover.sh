#!/usr/bin/env bash
# Discover cases under a root + check dependency status.
# Usage:
#   discover.sh <root>           — list cases + drive remote status
#   discover.sh --check          — verify dependencies (sha256, rclone, psql, jq)
#   discover.sh <root> --json    — machine-readable case list

set -euo pipefail
. "$(dirname "$0")/lib.sh"

check_deps() {
  local ok=0
  printf '%-20s %s\n' "dependency" "status"
  printf '%-20s %s\n' "----------" "------"
  for cmd in jq rclone psql; do
    if command -v "$cmd" >/dev/null 2>&1; then
      printf '%-20s ✓ %s\n' "$cmd" "$(command -v "$cmd")"
    else
      printf '%-20s ✗ MISSING\n' "$cmd"; ok=1
    fi
  done
  if command -v sha256sum >/dev/null 2>&1; then
    printf '%-20s ✓ %s\n' "sha256sum" "$(command -v sha256sum)"
  elif command -v shasum >/dev/null 2>&1; then
    printf '%-20s ✓ %s (shasum -a 256)\n' "shasum" "$(command -v shasum)"
  else
    printf '%-20s ✗ MISSING\n' "sha256sum/shasum"; ok=1
  fi
  echo ""
  printf '%-20s %s\n' "NEON_DATABASE_URL" "$([ -n "${NEON_DATABASE_URL:-}" ] && echo 'set' || echo 'NOT set — Neon checks will be skipped')"
  if ee_neon_ready; then
    local tbl; tbl="$(ee_neon_table)"
    printf '%-20s %s\n' "Neon connectivity" "✓ ok"
    printf '%-20s %s\n' "Neon table" "${tbl:-NONE matched .neon_tables_to_try}"
  else
    printf '%-20s %s\n' "Neon connectivity" "skipped"
  fi
  return $ok
}

if [ "${1:-}" = "--check" ]; then
  check_deps
  exit $?
fi

ROOT="${1:-}"
[ -n "$ROOT" ] || { echo "usage: discover.sh <root> [--json]" >&2; exit 2; }
[ -d "$ROOT" ] || { echo "not a dir: $ROOT" >&2; exit 2; }
JSON=0
[ "${2:-}" = "--json" ] && JSON=1

# Snapshot remotes once
REMOTES="$(rclone listremotes 2>/dev/null || true)"

remote_status() {
  local case_id="$1"
  local remote; remote="$(ee_drive_remote_for "$case_id")"
  if echo "$REMOTES" | grep -qx "$remote"; then
    echo "$remote"
  else
    echo "—"
  fi
}

# Document predicate populated lazily inside ee_count_docs

if [ "$JSON" = 1 ]; then
  ee_discover_cases "$ROOT" | jq -R -s --arg root "$ROOT" '
    split("\n") | map(select(length > 0)) |
    map({case_id: .})
  ' > /tmp/ee-cases.tmp
  # enrich
  jq -c '.[]' /tmp/ee-cases.tmp | while read -r row; do
    cid=$(echo "$row" | jq -r '.case_id')
    dir="${ROOT}/cases/${cid}"
    doc_count=$(ee_count_docs "$dir")
    size=$(du -sh "$dir" 2>/dev/null | awk '{print $1}')
    remote=$(remote_status "$cid")
    echo "$row" | jq --arg dc "$doc_count" --arg sz "$size" --arg rm "$remote" \
      '. + {doc_count: ($dc|tonumber), size: $sz, drive_remote: $rm}'
  done | jq -s .
  rm -f /tmp/ee-cases.tmp
else
  echo "Root: $ROOT"
  echo ""
  printf '%-30s %10s %10s   %s\n' "case_id" "docs" "size" "drive_remote"
  printf '%-30s %10s %10s   %s\n' "-------" "----" "----" "------------"
  while IFS= read -r cid; do
    dir="${ROOT}/cases/${cid}"
    doc_count=$(ee_count_docs "$dir")
    size=$(du -sh "$dir" 2>/dev/null | awk '{print $1}')
    remote=$(remote_status "$cid")
    printf '%-30s %10s %10s   %s\n' "$cid" "$doc_count" "$size" "$remote"
  done < <(ee_discover_cases "$ROOT")
fi
