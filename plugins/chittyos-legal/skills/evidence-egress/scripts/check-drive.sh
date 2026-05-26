#!/usr/bin/env bash
# Annotate a manifest with Drive presence for a given case.
# Reads TSV on stdin:  path<TAB>sha256<TAB>size<TAB>mtime<TAB>in_neon
# Writes TSV stdout:   path<TAB>sha256<TAB>size<TAB>mtime<TAB>in_neon<TAB>in_drive
#
# in_drive ∈ {yes, no, no_remote}
# Matching is by (basename, size) — best we can do without per-object hash on Drive.
# This is intentionally a HINT, not proof. Authoritative dedup is by sha256 against Neon.

set -euo pipefail
. "$(dirname "$0")/lib.sh"

CASE_ID="${1:-}"
[ -n "$CASE_ID" ] || { echo "usage: check-drive.sh <case_id>" >&2; exit 2; }

REMOTE="$(ee_drive_remote_for "$CASE_ID")"
REMOTES="$(rclone listremotes 2>/dev/null || true)"
if ! echo "$REMOTES" | grep -qx "$REMOTE"; then
  ee_log "no drive remote $REMOTE — marking in_drive=no_remote"
  awk -F'\t' 'BEGIN{OFS="\t"} {print $0, "no_remote"}'
  exit 0
fi

TMP_DRIVE="$(mktemp -t ee-drive.XXXXXX)"
trap 'rm -f "$TMP_DRIVE"' EXIT

ee_log "walking $REMOTE (one-time per case) — this may take a few minutes"
# Format: <name>\t<size>
rclone lsf "$REMOTE" -R --format "ps" --separator $'\t' --files-only 2>/dev/null \
  | awk -F'\t' 'BEGIN{OFS="\t"} {n=split($1,a,"/"); print a[n], $2}' \
  | sort -u > "$TMP_DRIVE"
DC=$(wc -l < "$TMP_DRIVE" | tr -d ' ')
ee_log "indexed $DC files on $REMOTE"

# Annotate input
awk -F'\t' -v DRV="$TMP_DRIVE" '
  BEGIN {
    OFS="\t"
    while ((getline line < DRV) > 0) {
      split(line, a, "\t")
      key = a[1] "|" a[2]
      drive[key] = 1
    }
    close(DRV)
  }
  {
    n = split($1, p, "/")
    name = p[n]
    key = name "|" $3
    print $0, (key in drive ? "yes" : "no")
  }
'
