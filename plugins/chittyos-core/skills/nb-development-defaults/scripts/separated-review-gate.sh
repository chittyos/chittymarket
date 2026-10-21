#!/usr/bin/env bash
# separated-review-gate.sh — makes the separated-review gate EXECUTABLE.
#
# `chitty-autonomy`'s `separated_review` phase specifies a receipt and four
# conditions Ship must check. Until something writes and verifies that receipt,
# the phase is prose: a driver whose transition logic does not consult it advances
# regardless, and an automated loop then ships unreviewed work while every
# document says it cannot. This script is the control the document describes.
#
#   run    <diff-file> [-p "focus"]   dispatch the separated reviewer, write the receipt
#   verify <receipt-file>             exit 0 only if Ship may proceed
#
# `run` writes the receipt to stdout and the review BODY to $REVIEW_BODY (default
# ./separated_review.md). The body is never discarded: the first version of this
# script captured the reviewer's output only to parse its model line and dropped
# the rest, which makes triage impossible and loses every finding -- the same
# defect as a test gate running its suite under `>/dev/null 2>&1`. A control that
# throws away the evidence it was built to collect is decoration.
#
# The split matters: `run` CANNOT be the gate. A reviewer that returns nothing is
# the dangerous case, and it exits 0 like a clean pass. Only `verify`, reading the
# receipt, can tell those apart.
#
# Exit: 0 ok · 1 gate CLOSED (verify) / review failed (run) · 2 usage/env
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REVIEWER="$HERE/adversarial-review.sh"

usage() { echo "usage: separated-review-gate.sh run <diff-file> [-p focus] | verify <receipt>" >&2; exit 2; }

# --- run -------------------------------------------------------------------
cmd_run() {
  local diff="${1:-}"; shift || true
  [ -n "$diff" ] && [ -f "$diff" ] || { echo "ERROR: diff file required" >&2; exit 2; }
  [ -x "$REVIEWER" ] || { echo "ERROR: reviewer not found at $REVIEWER" >&2; exit 2; }

  local out rc=0
  out="$("$REVIEWER" "$diff" "$@" 2>&1)" || rc=$?

  # Persist the body BEFORE deciding anything, so it survives even a failed run --
  # a failed review's output is how you find out why it failed.
  local body="${REVIEW_BODY:-separated_review.md}"
  printf '%s\n' "$out" > "$body"

  local lines bytes model status
  lines=$(wc -l < "$diff" | tr -d ' ')
  bytes=$(wc -c < "$diff" | tr -d ' ')
  # The reviewer prints its model on the verdict line; absence of that line is
  # itself evidence the review did not complete.
  model="$(printf '%s' "$out" | sed -n 's/.*reviewed by \([^ ]*\).*/\1/p' | tail -1)"

  if [ "$rc" -ne 0 ]; then
    # 2 = reviewer host unreachable, 3 = model call failed. Both are "did not
    # run", never "no findings".
    status="did_not_run"
  elif [ -z "$model" ]; then
    # Exit 0 with no verdict line: ran, but produced nothing attributable. This
    # is the confident-empty shape, and it must NOT read as a pass.
    status="ran_inconclusive"
  elif [ "$bytes" -eq 0 ]; then
    status="did_not_run"
  else
    status="ran_adequate"
  fi

  # Findings are NOT parsed from prose. A regex over a review's text would invent
  # severities and miss them, and the gate would then be deciding on fiction. The
  # triaging agent fills `findings` deliberately; an empty array with
  # ran_adequate means "triage not yet recorded", which verify treats as closed.
  python3 - "$status" "$model" "$lines" "$bytes" "$rc" <<'PY'
import json,os,subprocess,sys,socket
status,model,lines,byts,rc = sys.argv[1:6]
def sh(c):
    try: return subprocess.run(c,shell=True,capture_output=True,text=True,timeout=10).stdout.strip()
    except Exception: return ""
print(json.dumps({
  "run_status": status,
  "reviewer":    {"model": model or None, "host": "separated"},
  "implementer": {"model": os.environ.get("CLAUDE_MODEL") or os.environ.get("IMPLEMENTER_MODEL") or None,
                  "host": socket.gethostname()},
  "coverage":    {"diff_lines_sent": int(lines), "prompt_bytes": int(byts)},
  "reviewer_exit": int(rc),
  "review_body": os.environ.get("REVIEW_BODY","separated_review.md"),
  "findings": [],
  "findings_triaged": False
}, indent=2))
PY
  [ "$status" = "ran_adequate" ] || return 1
  return 0
}

# --- verify ----------------------------------------------------------------
cmd_verify() {
  local r="${1:-}"
  [ -n "$r" ] && [ -f "$r" ] || { echo "GATE CLOSED: no receipt at '${r:-<none>}'" >&2; exit 1; }
  python3 - "$r" <<'PY'
import json,os,sys
p=sys.argv[1]
try: d=json.load(open(p))
except Exception as e:
    print(f"GATE CLOSED: receipt unreadable ({e})",file=sys.stderr); sys.exit(1)

fail=[]
st=d.get("run_status")
if st!="ran_adequate":
    fail.append(f"run_status={st!r} — only 'ran_adequate' may pass; a review that "
                "could not run is NOT 'no findings'")

rv,im = d.get("reviewer") or {}, d.get("implementer") or {}
if not rv.get("model"):
    fail.append("reviewer.model missing — separation cannot be attested")
elif rv.get("model")==im.get("model") and rv.get("host")==im.get("host"):
    fail.append("reviewer identical to implementer — an agent may not review its own diff")

cov=d.get("coverage") or {}
if not (cov.get("diff_lines_sent") or 0) > 0 or not (cov.get("prompt_bytes") or 0) > 0:
    fail.append("coverage is zero — adequacy claimed over nothing is 'ran_inconclusive'")

body=d.get("review_body")
if not body or not os.path.isfile(body) or os.path.getsize(body)==0:
    fail.append(f"review body missing or empty ({body!r}) — findings cannot be "
                "triaged against evidence that was not kept")

if not d.get("findings_triaged"):
    fail.append("findings_triaged is false — an untriaged review is not a pass")

blocking=[f for f in (d.get("findings") or [])
          if f.get("severity") in ("critical","high") and f.get("state")=="confirmed"]
for f in blocking:
    fail.append(f"confirmed {f.get('severity')}: {f.get('id') or f.get('summary','<unnamed>')} "
                "— must be fixed or explicitly risk_accepted")

if fail:
    print("GATE CLOSED — Ship must not proceed:",file=sys.stderr)
    for f in fail: print(f"  - {f}",file=sys.stderr)
    sys.exit(1)
print(f"gate open — reviewed by {rv.get('model')}, "
      f"{cov.get('diff_lines_sent')} diff lines, "
      f"{len(d.get('findings') or [])} finding(s) triaged")
PY
}

case "${1:-}" in
  run)    shift; cmd_run "$@" ;;
  verify) shift; cmd_verify "$@" ;;
  *)      usage ;;
esac
