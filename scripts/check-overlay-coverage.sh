#!/usr/bin/env bash
# check-overlay-coverage.sh
# Asserts capabilities.generated.json (the Capability Overlay) projects EVERY real
# artifact in marketplace.json — and contains no orphan records pointing at
# artifacts that no longer exist.
#
# Invariant (CLAUDE.md: the overlay "projects every artifact"):
#   { artifact.id  | artifact in marketplace.json, not a _comment divider }
#     ==  { capability.legacy_id | capability in capabilities.generated.json }
#
# Exit 0 = sets match. Exit 1 = uncovered artifacts and/or orphan records.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
cd "$REPO_ROOT"

MANIFEST="marketplace.json"
OVERLAY="capabilities.generated.json"

red()   { printf '\033[0;31m%s\033[0m\n' "$1"; }
green() { printf '\033[0;32m%s\033[0m\n' "$1"; }
dim()   { printf '\033[0;90m%s\033[0m\n' "$1"; }

for f in "$MANIFEST" "$OVERLAY"; do
  [ -f "$f" ] || { red "ERROR: $f not found"; exit 2; }
  jq -e . "$f" >/dev/null 2>&1 || { red "ERROR: $f is not valid JSON"; exit 2; }
done

echo "=== overlay coverage check ==="

# Real artifacts = entries that carry an "id" (the _comment dividers have none).
mapfile -t ARTIFACT_IDS < <(jq -r '.artifacts[] | select(has("id")) | .id' "$MANIFEST" | sort -u)
mapfile -t OVERLAY_IDS  < <(jq -r '.capabilities[] | .legacy_id' "$OVERLAY" | sort -u)

artifacts_file="$(mktemp)"; overlay_file="$(mktemp)"
trap 'rm -f "$artifacts_file" "$overlay_file"' EXIT
printf '%s\n' "${ARTIFACT_IDS[@]}" > "$artifacts_file"
printf '%s\n' "${OVERLAY_IDS[@]}"  > "$overlay_file"

# In manifest, not projected into overlay.
mapfile -t UNCOVERED < <(comm -23 "$artifacts_file" "$overlay_file")
# In overlay, no matching artifact (stale/orphan record).
mapfile -t ORPHANS   < <(comm -13 "$artifacts_file" "$overlay_file")

declared_total="$(jq -r '.total // empty' "$OVERLAY")"
actual_count="$(jq -r '.capabilities | length' "$OVERLAY")"

echo "  artifacts (real): ${#ARTIFACT_IDS[@]}"
echo "  overlay records:  ${#OVERLAY_IDS[@]}  (total field: ${declared_total:-unset}, array len: $actual_count)"
echo ""

fail=0

if [ "${#UNCOVERED[@]}" -gt 0 ]; then
  red "  UNCOVERED — artifacts missing an overlay record (${#UNCOVERED[@]}):"
  printf '    - %s\n' "${UNCOVERED[@]}"
  fail=1
fi

if [ "${#ORPHANS[@]}" -gt 0 ]; then
  red "  ORPHAN — overlay records with no matching artifact (${#ORPHANS[@]}):"
  printf '    - %s\n' "${ORPHANS[@]}"
  fail=1
fi

if [ -n "$declared_total" ] && [ "$declared_total" != "$actual_count" ]; then
  red "  TOTAL MISMATCH — .total=$declared_total but array length=$actual_count"
  fail=1
fi

if [ "$fail" -eq 0 ]; then
  green "  All clear — overlay covers every artifact (${#ARTIFACT_IDS[@]}/${#ARTIFACT_IDS[@]}); no orphans; total consistent."
  exit 0
fi

echo ""
red "Overlay coverage check FAILED."
dim "Fix: add the missing §16 record(s) to $OVERLAY (see an existing record as a template),"
dim "bump .total to match the array length, or remove the orphan record(s)."
exit 1
