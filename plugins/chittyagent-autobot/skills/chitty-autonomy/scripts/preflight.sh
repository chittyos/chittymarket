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
#      ChittyCert refuses that for synthetic agents by design:
#        "Direct synthetic agent access prohibited. Route through the front
#         door (mychitty Phase 0 continuity substrate)."
#      A 403 here means WRONG DOOR, not "you lack authority" — see below.
#
#   2. chitty-autonomy-affirm resolved the cert token via `op run`
#      (1Password). 1Password is RETIRED; credential resolution belongs to the
#      ChittySecrets / ChittyConnect broker and must never be done inline.
#
#   3. The front door itself was degraded — `can chitty authenticate-context`
#      reported "ChittyCanon DB unavailable - cannot create context" and fell
#      back to a local manifest.
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
CID="$(timeout 45 can chitty whoami 2>&1 | grep -oE '[0-9]{2}-[0-9]-[A-Z]{3}-[0-9]{4}-[PLTEA]-[0-9]{4}-[0-9]-[0-9]{2}' | head -1)"
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
# This is the "front door" ChittyCert requires. The CLI's own error text here
# ("ChittyCanon DB unavailable") is misleading — confirmed via chittyfoundation/
# chittycanon#43 (filed 2026-07-31, still open/unowned as of 2026-08-23) that
# canon.chitty.cc has been 522ing at the Cloudflare edge, i.e. no worker is
# bound to the hostname at all. The request never reaches a database, so it
# cannot be a DB outage — the CLI message is stale/wrong, not this skill's.
SUB="$(timeout 45 can chitty authenticate-context 2>&1)"
if printf '%s' "$SUB" | grep -qi 'ChittyCanon DB unavailable'; then
  say "  SUBSTRATE  DEGRADED — front door reports 'ChittyCanon DB unavailable'."
  say "             That message is misdiagnosed: canon.chitty.cc is 522ing at"
  say "             the Cloudflare edge (no worker bound to the hostname), not a"
  say "             DB failure. Tracked: github.com/chittyfoundation/chittycanon#43"
  say "             Identity resolved from local manifest only."
  FAIL=10
else
  say "  SUBSTRATE  ok"
fi

# 3. ChittyCert reachability ------------------------------------------------
CERT_HEALTH="$(curl -s --max-time 10 https://cert.chitty.cc/health || true)"
if ! printf '%s' "$CERT_HEALTH" | grep -q '"status":"ok"'; then
  say "  CERT       unreachable — $CERT_HEALTH"
  exit 11
fi
say "  CERT       reachable"

# 4. Confirm the direct door is still closed --------------------------------
# Not a probe for a way in — a check that our understanding is current. If this
# ever returns something other than the front-door refusal, the contract moved
# and this skill must be re-read against the live service before trusting it.
DIRECT="$(curl -s --max-time 10 -X POST https://cert.chitty.cc/api/v1/issue \
          -H 'content-type: application/json' -d '{"type":"TRUST_CHAIN"}' || true)"
if printf '%s' "$DIRECT" | grep -qi 'Direct synthetic agent access prohibited'; then
  say "  CERT DOOR  front-door-only (as documented) — direct POST correctly refused"
else
  say "  CERT DOOR  CONTRACT CHANGED — direct POST no longer returns the known refusal."
  say "             Response: $(printf '%s' "$DIRECT" | head -c 200)"
  say "             Re-read cert.chitty.cc's contract before relying on this skill."
  FAIL=${FAIL:-10}
fi

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
  say "Remedy: restore canon.chitty.cc (worker-binding fix, not a DB fix — see"
  say "github.com/chittyfoundation/chittycanon#43), then re-run."
  say "For the credential path, delegate to chittyconnect-concierge (/chico)."
  exit $FAIL
fi

say ""
say "READY — Phase 0 may proceed."
exit 0
