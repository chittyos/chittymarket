#!/usr/bin/env bash
# hydrate-pointers.sh — Fetch the canonical body content for every pointer-style
# agent in plugins/, replacing the stub body while preserving the pointer frontmatter.
#
# SECURITY HARDENING (adversarial review findings #2 + #5):
#   1. Allowlist of source hosts (prevents pointing prompt_url at attacker-controlled origins).
#   2. prompt_sha required on every pointer for content-integrity pinning. Fetched content
#      hash MUST match the pinned SHA-256 before being written.
#   3. Fetched content is passed to Python via stdin (NOT shell heredoc), so embedded
#      """ or python source in the fetched body cannot escape into the script context.
#
# A "pointer agent" is any plugins/<plug>/agents/<name>.md whose frontmatter declares
# `prompt_url:`, `owner_repo:`, and `prompt_sha:` (sha256 hex).
#
# Exit codes:
#   0 — pointers were already current (nothing fetched-and-changed)
#   1 — pointers were refreshed; review `git diff` and commit
#   2 — fetch failure or SHA mismatch
#   3 — disallowed source host
#   4 — pointer missing required prompt_sha

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
cd "$REPO_ROOT"

# Allowlist: pointer-source hosts we trust.
ALLOWED_HOSTS=(
  "raw.githubusercontent.com"
)

red()    { printf '\033[0;31m%s\033[0m\n' "$1"; }
yellow() { printf '\033[0;33m%s\033[0m\n' "$1"; }
green()  { printf '\033[0;32m%s\033[0m\n' "$1"; }
dim()    { printf '\033[0;90m%s\033[0m\n' "$1"; }

host_allowed() {
  local host="$1"
  for ah in "${ALLOWED_HOSTS[@]}"; do
    [ "$host" = "$ah" ] && return 0
  done
  return 1
}

CHANGED=0
FETCH_FAIL=0
DISALLOWED=0
NO_SHA=0

mapfile -t POINTERS < <(grep -lrE '^prompt_url:' plugins/*/agents/*.md 2>/dev/null || true)

if [ "${#POINTERS[@]}" -eq 0 ]; then
  dim "No pointer agents found."
  exit 0
fi

echo "=== hydrate-pointers (hardened) ==="
echo "Found ${#POINTERS[@]} pointer agent(s)."
echo "Allowed hosts: ${ALLOWED_HOSTS[*]}"
echo ""

for f in "${POINTERS[@]}"; do
  name=$(basename "$f" .md)
  prompt_url=$(awk '/^---$/{c++; next} c==1 && /^prompt_url:/{sub(/^prompt_url:[[:space:]]*/, ""); print; exit}' "$f")
  owner_repo=$(awk '/^---$/{c++; next} c==1 && /^owner_repo:/{sub(/^owner_repo:[[:space:]]*/, ""); print; exit}' "$f")
  prompt_sha=$(awk '/^---$/{c++; next} c==1 && /^prompt_sha:/{sub(/^prompt_sha:[[:space:]]*/, ""); print; exit}' "$f")

  if [ -z "$prompt_url" ]; then
    yellow "  SKIP $name: missing prompt_url"
    continue
  fi

  # Require prompt_sha (content-integrity pin).
  if [ -z "$prompt_sha" ]; then
    red "  REJECT $name: missing prompt_sha (content-integrity pin required)"
    red "         Add to frontmatter:  prompt_sha: <sha256 hex of expected content>"
    NO_SHA=$((NO_SHA + 1))
    continue
  fi

  # Validate host against allowlist.
  host=$(printf '%s\n' "$prompt_url" | awk -F/ '{print $3}')
  if ! host_allowed "$host"; then
    red "  REJECT $name: disallowed host '$host'"
    red "         Allowed: ${ALLOWED_HOSTS[*]}"
    DISALLOWED=$((DISALLOWED + 1))
    continue
  fi

  echo "  hydrating $name from $owner_repo (host=$host, sha=${prompt_sha:0:12}…)"

  # Fetch into a temp file (NOT shell variable) to prevent injection.
  tmp=$(mktemp)
  if ! curl -fsSL --max-time 5 --max-filesize 1048576 "$prompt_url" -o "$tmp" 2>/dev/null; then
    red "    FETCH FAILED: $prompt_url"
    rm -f "$tmp"
    FETCH_FAIL=$((FETCH_FAIL + 1))
    continue
  fi

  # Verify SHA-256.
  actual_sha=$(shasum -a 256 "$tmp" | awk '{print $1}')
  if [ "$actual_sha" != "$prompt_sha" ]; then
    red "    SHA MISMATCH: expected $prompt_sha, got $actual_sha"
    red "                  If upstream changed intentionally, update prompt_sha in frontmatter."
    rm -f "$tmp"
    FETCH_FAIL=$((FETCH_FAIL + 1))
    continue
  fi

  # Hand off to Python via env var (NOT heredoc interpolation).
  POINTER_PATH="$f" FETCHED_FILE="$tmp" python3 - <<'PY'
import os, pathlib, re, sys
pointer_path = pathlib.Path(os.environ["POINTER_PATH"])
fetched = pathlib.Path(os.environ["FETCHED_FILE"]).read_text(encoding="utf-8")

# Strip any frontmatter from fetched content (we keep the local pointer's frontmatter).
m = re.match(r"^---\n.*?\n---\n(.*)$", fetched, re.DOTALL)
fetched_body = (m.group(1) if m else fetched).strip()

text = pointer_path.read_text(encoding="utf-8")
fm_m = re.match(r"^---\n(.*?)\n---\n(.*)$", text, re.DOTALL)
if not fm_m:
    sys.exit("frontmatter not parseable")
frontmatter = fm_m.group(1)
rest = fm_m.group(2)

# Preserve the warning HTML comment block (no trailing whitespace capture).
comment_m = re.match(r"^\s*(<!--.*?-->)", rest, re.DOTALL)
comment = comment_m.group(1).rstrip() if comment_m else ""
sep = "\n\n" if comment else ""
new_text = f"---\n{frontmatter}\n---\n\n{comment}{sep}{fetched_body}\n"

if new_text != text:
    pointer_path.write_text(new_text, encoding="utf-8")
    print(f"    refreshed: {pointer_path}")
else:
    print(f"    unchanged: {pointer_path}")
PY

  rm -f "$tmp"

  if ! git diff --quiet -- "$f"; then
    CHANGED=$((CHANGED + 1))
  fi
done

echo ""
echo "=== Summary ==="
[ "$DISALLOWED" -gt 0 ] && red "Disallowed hosts: $DISALLOWED"
[ "$NO_SHA" -gt 0 ] && red "Missing prompt_sha: $NO_SHA"
[ "$FETCH_FAIL" -gt 0 ] && red "Fetch/SHA failures: $FETCH_FAIL"
if [ "$CHANGED" -gt 0 ]; then
  yellow "Hydrated: $CHANGED file(s). Review with 'git diff' and commit."
elif [ "$FETCH_FAIL" -eq 0 ] && [ "$DISALLOWED" -eq 0 ] && [ "$NO_SHA" -eq 0 ]; then
  green "All pointer agents are current."
fi

[ "$NO_SHA" -gt 0 ] && exit 4
[ "$DISALLOWED" -gt 0 ] && exit 3
[ "$FETCH_FAIL" -gt 0 ] && exit 2
[ "$CHANGED" -gt 0 ] && exit 1
exit 0
