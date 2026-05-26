#!/usr/bin/env bash
# Summarize the most recent egress report(s).
#
# Usage:
#   report.sh --summary               — summary of latest report per case
#   report.sh --case <id>             — summary of latest report for one case
#   report.sh --file <path>           — summary of a specific report

set -euo pipefail
. "$(dirname "$0")/lib.sh"

REPORT_DIR="$(ee_report_dir)"

summarize_file() {
  local f="$1"
  local total
  total=$(($(wc -l < "$f") - 1))
  echo "── $f ──"
  echo "  Total rows: $total"
  if [ "$total" -gt 0 ]; then
    echo "  By action:"
    tail -n +2 "$f" | awk -F',' '{print $NF}' | sort | uniq -c | sort -rn \
      | awk '{printf "    %-22s %d\n", $2, $1}'
    echo "  By (in_neon, in_drive):"
    tail -n +2 "$f" | awk -F',' '{print $5","$6}' | sort | uniq -c | sort -rn \
      | awk '{printf "    %-30s %d\n", $2, $1}'
    # Top 10 'no_remote' or 'ingest_then_delete' samples
    local samples
    samples=$(tail -n +2 "$f" | awk -F',' '$NF == "ingest_then_delete" || $NF == "verify_drive"' | head -5)
    if [ -n "$samples" ]; then
      echo "  Sample action items (≤5):"
      echo "$samples" | awk -F',' '{printf "    [%s] %s\n", $NF, $1}'
    fi
  fi
  echo ""
}

case "${1:-}" in
  --summary)
    # Latest report per case
    for cid in $(ls "$REPORT_DIR" 2>/dev/null | grep -oE '^egress-[^-]+-' | sort -u | sed 's/^egress-//;s/-$//'); do
      f=$(ls -t "$REPORT_DIR"/egress-${cid}-*.csv 2>/dev/null | head -1)
      [ -n "$f" ] && summarize_file "$f"
    done
    ;;
  --case)
    cid="$2"
    f=$(ls -t "$REPORT_DIR"/egress-${cid}-*.csv 2>/dev/null | head -1)
    [ -n "$f" ] || { echo "no report for case $cid" >&2; exit 1; }
    summarize_file "$f"
    ;;
  --file)
    summarize_file "$2"
    ;;
  *)
    sed -n '1,9p' "$0"
    exit 2
    ;;
esac
