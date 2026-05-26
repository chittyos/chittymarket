#!/usr/bin/env bash
# Index (sha256) all document-type files under a case dir, excluding code subtrees.
# Output: TSV to stdout with columns: path<TAB>sha256<TAB>size<TAB>mtime_epoch
#
# Usage:
#   index.sh <case_dir>
#   index.sh <case_dir> > manifest.tsv

set -euo pipefail
. "$(dirname "$0")/lib.sh"

CASE_DIR="${1:-}"
[ -n "$CASE_DIR" ] || { echo "usage: index.sh <case_dir>" >&2; exit 2; }
[ -d "$CASE_DIR" ] || { echo "not a dir: $CASE_DIR" >&2; exit 2; }

TOTAL=$(ee_count_docs "$CASE_DIR")
ee_log "indexing up to $TOTAL document files under $CASE_DIR"

i=0
ee_list_docs "$CASE_DIR" | while IFS= read -r f; do
  i=$((i+1))
  # Skip zero-byte
  size=$(stat -f%z "$f" 2>/dev/null || stat -c%s "$f" 2>/dev/null || echo 0)
  if [ "$size" = "0" ]; then
    continue
  fi
  mtime=$(stat -f%m "$f" 2>/dev/null || stat -c%Y "$f" 2>/dev/null || echo 0)
  hash=$(ee_sha256 "$f")
  printf '%s\t%s\t%s\t%s\n' "$f" "$hash" "$size" "$mtime"
  if [ $((i % 50)) = 0 ] || [ "$i" = "$TOTAL" ]; then
    ee_progress "$i" "$TOTAL" "$(basename "$f")"
  fi
done
