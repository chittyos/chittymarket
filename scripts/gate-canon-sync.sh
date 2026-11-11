#!/usr/bin/env bash
# gate-canon-sync.sh — MANDATED, FAIL-CLOSED gate around check-canon-sync.sh.
# Only IN_SYNC (exit 0) passes. OUT_OF_SYNC / UNVERIFIED HALT.
# Wire at: SessionStart hook (every runtime) AND pre-commit-drift AND CI.
# canon: chittycanon://core/contracts/canon-versioning#gate
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
"$HERE/check-canon-sync.sh" "$@"; rc=$?
case "$rc" in
  0) exit 0 ;;
  3) echo "[canon-gate] BLOCKED — artifact OUT OF SYNC with canonical. Re-pull via dispatch before proceeding." >&2; exit 3 ;;
  *) echo "[canon-gate] BLOCKED — sync UNVERIFIED (offline / unsigned / bad signature). Not permitted to proceed as if current." >&2; exit 4 ;;
esac
