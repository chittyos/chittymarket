#!/usr/bin/env bash
# Orchestrator: index → check-neon → check-drive → write report CSV.
#
# Usage:
#   audit.sh --root <dir> --case <case_id>
#   audit.sh --root <dir> --all
#
# Produces /tmp/egress-<case_id>-<run_id>.csv with columns:
#   path,sha256,size,mtime,in_neon,in_drive,action
# Plus a summary printed to stdout.

set -euo pipefail
. "$(dirname "$0")/lib.sh"

ROOT=""
CASE=""
ALL=0
while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    --case) CASE="$2"; shift 2 ;;
    --all)  ALL=1; shift ;;
    -h|--help) sed -n '1,12p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[ -n "$ROOT" ] || { echo "--root is required" >&2; exit 2; }
[ -d "$ROOT" ] || { echo "not a dir: $ROOT" >&2; exit 2; }
if [ "$ALL" = 0 ] && [ -z "$CASE" ]; then
  echo "must pass --case <id> or --all" >&2; exit 2
fi

SCRIPT_DIR="$(dirname "$0")"
RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)"
REPORT_DIR="$(ee_report_dir)"
mkdir -p "$REPORT_DIR"

# action classifier
classify() {
  awk -F'\t' '
    BEGIN { OFS="," }
    {
      path=$1; sha=$2; sz=$3; mt=$4; nn=$5; dr=$6
      action="review"
      if (nn=="yes" && dr=="yes")           action="safe_to_delete"
      else if (nn=="yes" && dr=="no")       action="verify_drive"
      else if (nn=="yes" && dr=="no_remote") action="no_remote_review"
      else if (nn=="no"  && dr=="yes")      action="ingest_then_delete"
      else if (nn=="no"  && dr=="no")       action="ingest_then_delete"
      else if (nn=="skipped")               action="neon_skipped"
      # CSV-escape path
      gsub(/"/,"\"\"",path)
      printf "\"%s\",%s,%s,%s,%s,%s,%s\n", path, sha, sz, mt, nn, dr, action
    }
  '
}

audit_case() {
  local case_id="$1"
  local case_dir="${ROOT}/cases/${case_id}"
  local report="${REPORT_DIR}/egress-${case_id}-${RUN_ID}.csv"

  ee_log "=== auditing case: $case_id ==="
  ee_log "case dir: $case_dir"
  ee_log "report:   $report"

  echo "path,sha256,size,mtime,in_neon,in_drive,action" > "$report"

  "${SCRIPT_DIR}/index.sh" "$case_dir" \
    | "${SCRIPT_DIR}/check-neon.sh" \
    | "${SCRIPT_DIR}/check-drive.sh" "$case_id" \
    | classify \
    >> "$report"

  # Summary
  local total
  total=$(($(wc -l < "$report") - 1))
  echo ""
  echo "Summary for $case_id (run $RUN_ID):"
  echo "  Total document files indexed: $total"
  echo "  Report: $report"
  echo ""
  if [ "$total" -gt 0 ]; then
    echo "  By action:"
    tail -n +2 "$report" | awk -F',' '{print $NF}' | sort | uniq -c | sort -rn \
      | awk '{printf "    %-22s %d\n", $2, $1}'
  fi
}

if [ "$ALL" = 1 ]; then
  while IFS= read -r cid; do
    audit_case "$cid"
  done < <(ee_discover_cases "$ROOT")
else
  audit_case "$CASE"
fi
