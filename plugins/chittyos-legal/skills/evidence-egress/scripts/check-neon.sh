#!/usr/bin/env bash
# Annotate a manifest with Neon presence.
# Reads TSV on stdin: path<TAB>sha256<TAB>size<TAB>mtime
# Writes TSV to stdout: path<TAB>sha256<TAB>size<TAB>mtime<TAB>in_neon
#
# in_neon ∈ {yes, no, skipped}
# "skipped" means Neon was unreachable; downstream must treat as unknown.

set -euo pipefail
. "$(dirname "$0")/lib.sh"

if ! ee_neon_ready; then
  ee_log "Neon not ready (NEON_DATABASE_URL unset or psql failing) — marking all rows in_neon=skipped"
  awk -F'\t' 'BEGIN{OFS="\t"} {print $0, "skipped"}'
  exit 0
fi

TABLE="$(ee_neon_table)"
if [ -z "$TABLE" ]; then
  ee_log "no neon table matched .neon_tables_to_try — marking all rows in_neon=skipped"
  awk -F'\t' 'BEGIN{OFS="\t"} {print $0, "skipped"}'
  exit 0
fi
HASH_COL="$(ee_config '.neon_hash_column')"
ee_log "Neon table=${TABLE} hash_col=${HASH_COL}"

TMP_IN="$(mktemp -t ee-hashes.XXXXXX)"
TMP_OUT="$(mktemp -t ee-found.XXXXXX)"
trap 'rm -f "$TMP_IN" "$TMP_OUT"' EXIT

# Cache input to a tmpfile so we can stream twice
cat > "$TMP_IN"

# Extract unique hashes
awk -F'\t' '{print $2}' "$TMP_IN" | sort -u > "${TMP_IN}.hashes"
HASH_COUNT=$(wc -l < "${TMP_IN}.hashes" | tr -d ' ')
ee_log "querying $HASH_COUNT unique hashes against $TABLE"

# Batch query — use temp staging table for efficiency
psql "$NEON_DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL > "$TMP_OUT" 2>&1 || {
  ee_log "psql failed — falling back to in_neon=skipped"
  awk -F'\t' 'BEGIN{OFS="\t"} {print $0, "skipped"}' "$TMP_IN"
  exit 0
}
\set QUIET on
\pset format unaligned
\pset tuples_only on
\pset fieldsep '\t'
CREATE TEMP TABLE _ee_q (h text PRIMARY KEY) ON COMMIT DROP;
\copy _ee_q (h) FROM '${TMP_IN}.hashes'
SELECT q.h FROM _ee_q q WHERE EXISTS (SELECT 1 FROM ${TABLE} d WHERE d.${HASH_COL} = q.h);
SQL

# Build hash → yes lookup
awk -F'\t' 'NR==FNR{found[$1]=1; next} {print $0 "\t" (found[$2] ? "yes" : "no")}' \
  "$TMP_OUT" "$TMP_IN"
