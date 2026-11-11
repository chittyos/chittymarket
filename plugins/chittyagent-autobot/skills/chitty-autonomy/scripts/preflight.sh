#!/usr/bin/env bash
# Phase 0 preflight for chitty-autonomy. Run BEFORE starting the pipeline.
#
# WHY THIS EXISTS
# ---------------
# On 2026-07-30 a /chitty-autonomy invocation reached Phase 0 and died on an
# opaque 403 from ChittyCert. Three separate drifts were behind it, none
# detectable from the skill text:
#
#   1. The skill instructed a DIRECT `POST cert.chitty.cc/api/v1/issue`.
#      Doctrine forbids that for synthetic agents: issuance goes through the
#      front door (mychitty Phase 0 continuity substrate). ChittyCert used to
#      refuse it with "Direct synthetic agent access prohibited"; that refusal
#      is gone from source and the route is ungated pending chittycert#12, so
#      the prohibition is now doctrine-only — the script never probes it.
#
#   2. chitty-autonomy-affirm resolved the cert token via `op run`
#      (1Password). 1Password is RETIRED; credential resolution belongs to the
#      ChittySecrets / ChittyConnect broker and must never be done inline.
#
#   3. The front door itself was degraded — `can chitty authenticate-context`
#      reported "ChittyCanon DB unavailable - cannot create context" and fell
#      back to a local manifest. (2026-11-11: that CLI message is a chittycan
#      artefact — it wants a ChittyCanon Neon DSN that stopped existing when
#      chittycanon moved to D1 (chittycanon#54). It says nothing about the
#      service, so this script probes canon over HTTP instead of grepping it.)
#
# Discovering that mid-pipeline wastes a run and, worse, tempts an agent into
# inventing a way around a governance gate. Fail here instead, with a canonical
# code and a named remedy.
#
# Usage:  preflight.sh            # check everything
#         preflight.sh --quiet    # exit code only
#
# Exit: 0 ready | 10 substrate degraded | 11 cert unreachable | 12 no identity

set -uo pipefail
QUIET=0; [[ "${1:-}" == "--quiet" ]] && QUIET=1
say() { [[ $QUIET -eq 0 ]] && echo "$@"; return 0; }

FAIL=0

say "── chitty-autonomy Phase 0 preflight ─────────────────"

# 1. Identity ---------------------------------------------------------------
CID="$(timeout -k 5 45 can chitty whoami 2>&1 | grep -oE '[0-9]{2}-[0-9]-[A-Z]{3}-[0-9]{4}-[PLTEA]-[0-9]{4}-[0-9]-[0-9]{2}' | head -1)"
if [[ -z "$CID" ]]; then
  say "  IDENTITY   none — run 'can chitty authenticate-context'"
  exit 12
fi
# Canonical: Claude contexts are Person (P), never Thing.
# @canon: chittycanon://gov/governance#core-types  (P/L/T/E/A — all five)
TYPE="$(printf '%s' "$CID" | cut -d- -f5)"
if [[ "$TYPE" != "P" ]]; then
  say "  IDENTITY   $CID has entity type '$TYPE' — a synthetic agent MUST be P (Person)."
  say "             Thing (T) is wrong: actors with agency are always Person."
  exit 12
fi
say "  IDENTITY   $CID (P-Synthetic) ok"

# 2. Continuity substrate ---------------------------------------------------
# Probe the service, not the CLI's opinion of it. canon.chitty.cc 308s to
# canon.chittyfoundation.org (ChittyFoundation account, D1-backed); follow it.
# chittycan's "ChittyCanon DB unavailable" line is a legacy direct-DSN path and
# is reported as an advisory only.
SUB="$(timeout -k 5 45 can chitty authenticate-context 2>&1)"
CANON_OUT="$(curl -fsSL --max-time 15 --max-redirs 2 --proto-redir =https \
             -w '\n%{url_effective}' https://canon.chitty.cc/health 2>/dev/null || true)"
CANON="$(printf '%s' "$CANON_OUT" | sed '$d')"
CANON_URL="$(printf '%s' "$CANON_OUT" | tail -n1)"
if printf '%s' "$CANON" | jq -e '.status=="ok"' >/dev/null 2>&1 \
   && printf '%s' "$CANON_URL" | grep -qE '^https://canon\.(chitty\.cc|chittyfoundation\.org)/'; then
  say "  SUBSTRATE  canon ok (v$(printf '%s' "$CANON" | jq -r .version) at $CANON_URL)"
  if printf '%s' "$SUB" | grep -qi 'ChittyCanon DB unavailable'; then
    say "             advisory: chittycan still looks for a ChittyCanon Neon DSN"
    say "             (gone since the D1 move, chittycanon#54); identity came"
    say "             from the local manifest. Not a substrate failure."
  fi
else
  say "  SUBSTRATE  DEGRADED — canon.chitty.cc/health did not report ok"
  say "             (final URL: ${CANON_URL:-none}; body: $(printf '%s' "$CANON" | head -c 160))"
  FAIL=10
fi

# 3. ChittyCert reachability ------------------------------------------------
CERT_HEALTH="$(curl -fs --max-time 10 https://cert.chitty.cc/health || true)"
if ! printf '%s' "$CERT_HEALTH" | jq -e '.status=="ok"' >/dev/null 2>&1; then
  say "  CERT       unreachable — $CERT_HEALTH"
  exit 11
fi
say "  CERT       reachable"

# 4. Front door reachability ------------------------------------------------
# chitty-autonomy-affirm issues through the front door
#   POST https://mychitty.com/api/v1/identity/api/v1/issue
# (delivered by the orchestrator), never by a direct POST to cert.chitty.cc.
# Note: as of 2026-11-11 cert.chitty.cc/api/v1/issue is NOT gated (chittycert#12
# — the old "Direct synthetic agent access prohibited" refusal is gone from
# source). That makes the direct door *more* open, not less; the doctrine still
# forbids using it, so this script does not probe it and the affirm skill must
# not fall back to it.
FD="$(curl -s --max-time 10 -o /dev/null -w '%{http_code}' https://mychitty.com/api/v1/identity/health)"
FD="${FD:-000}"
case "$FD" in
  2*) say "  FRONT DOOR reachable (mychitty.com identity $FD)" ;;
  *)  say "  FRONT DOOR UNREACHABLE — mychitty.com/api/v1/identity/health → HTTP $FD."
      say "             Owner: CHITTYAPPS/mychitty. No legitimate issuance path exists"
      say "             until the owner restores the front door — do not try another"
      say "             host and do not POST cert.chitty.cc directly."
      FAIL=10 ;;
esac

say "──────────────────────────────────────────────────────"

if [[ $FAIL -ne 0 ]]; then
  say ""
  say "POLICY_BLOCKED_CHITTYCERT_FRONT_DOOR_UNAVAILABLE"
  say ""
  say "Phase 0 cannot complete. Per chitty-autonomy: the agent does NOT act"
  say "without affirmation. Do not skip the gate, do not self-sign, and do not"
  say "resolve a cert token inline — a fabricated sovereignty cert defeats the"
  say "entire purpose of the phase."
  say ""
  say "Remedy: whichever line above is not ok names the owner — canon.chitty.cc"
  say "(CHITTYFOUNDATION/chittycanon), cert.chitty.cc (CHITTYFOUNDATION/chittycert),"
  say "the identity front door (CHITTYAPPS/mychitty). Fix there, then re-run."
  say "For the credential path, delegate to chittyconnect-concierge (/chico)."
  exit $FAIL
fi

say ""
say "READY — Phase 0 may proceed."
exit 0
