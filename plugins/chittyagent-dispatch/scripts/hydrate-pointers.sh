#!/usr/bin/env bash
# hydrate-pointers.sh — Fetch the canonical body content for every pointer-style
# agent in plugins/, replacing the stub body while preserving the pointer frontmatter.
#
# A "pointer agent" is any plugins/<plug>/agents/<name>.md whose frontmatter
# declares `prompt_source:` and/or `prompt_url:` and `owner_repo:`. The body
# below the frontmatter is replaced with the content fetched from prompt_url.
# Anything between the frontmatter closing `---` and the body's first markdown
# heading (`#`) — typically the warning comment — is preserved as a banner.
#
# Exit codes:
#   0 — pointers were already current (nothing fetched-and-changed)
#   1 — one or more pointers were refreshed; review `git diff` and commit
#   2 — fetch failure (network, 404, etc.)
#
# Designed to be safe to re-run; can be wired into CI as a scheduled freshness check.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
cd "$REPO_ROOT"

red()    { printf '\033[0;31m%s\033[0m\n' "$1"; }
yellow() { printf '\033[0;33m%s\033[0m\n' "$1"; }
green()  { printf '\033[0;32m%s\033[0m\n' "$1"; }
dim()    { printf '\033[0;90m%s\033[0m\n' "$1"; }

CHANGED=0
FETCH_FAIL=0

# Discover every pointer agent (frontmatter has both owner_repo and prompt_url).
mapfile -t POINTERS < <(grep -lrE '^prompt_url:' plugins/*/agents/*.md 2>/dev/null || true)

if [ "${#POINTERS[@]}" -eq 0 ]; then
  dim "No pointer agents found."
  exit 0
fi

echo "=== hydrate-pointers ==="
echo "Found ${#POINTERS[@]} pointer agent(s)."
echo ""

for f in "${POINTERS[@]}"; do
  name=$(basename "$f" .md)

  # Extract prompt_url from frontmatter
  prompt_url=$(awk '/^---$/{c++; next} c==1 && /^prompt_url:/{sub(/^prompt_url:[[:space:]]*/, ""); print; exit}' "$f")
  owner_repo=$(awk '/^---$/{c++; next} c==1 && /^owner_repo:/{sub(/^owner_repo:[[:space:]]*/, ""); print; exit}' "$f")

  if [ -z "$prompt_url" ]; then
    yellow "  SKIP $f: missing prompt_url"
    continue
  fi

  echo "  hydrating $name from $owner_repo ..."

  # Fetch the canonical body (5s timeout, follow redirects, fail on HTTP errors)
  fetched=$(curl -fsSL --max-time 5 "$prompt_url" 2>/dev/null || echo "__FETCH_FAILED__")
  if [ "$fetched" = "__FETCH_FAILED__" ]; then
    red "    FETCH FAILED: $prompt_url"
    FETCH_FAIL=$((FETCH_FAIL + 1))
    continue
  fi

  # The fetched content typically includes its own frontmatter. Strip it
  # (between first two `---` lines) so we only inject the body.
  fetched_body=$(printf '%s' "$fetched" | awk '
    BEGIN { in_fm=0; saw_fm_end=0 }
    /^---$/ {
      if (!in_fm && NR==1) { in_fm=1; next }
      else if (in_fm && !saw_fm_end) { saw_fm_end=1; next }
    }
    { if (!in_fm || saw_fm_end) print }
  ')

  # Build the new file: keep frontmatter as-is, keep the warning comment block,
  # replace everything below the first `# ` heading with the canonical body.
  /usr/bin/python3 - <<PY
import pathlib, re, sys
p = pathlib.Path("$f")
text = p.read_text()
# Split frontmatter
m = re.match(r"^---\n(.*?)\n---\n(.*)$", text, re.DOTALL)
if not m:
    sys.exit("frontmatter not parseable")
frontmatter = m.group(1)
rest = m.group(2)
# Find HTML comment block (the warning) — keep it
comment_match = re.match(r"^\s*(<!--.*?-->)", rest, re.DOTALL)
comment = comment_match.group(1).rstrip() if comment_match else ""
# Build new content (normalize whitespace to prevent diff drift on idempotent re-runs)
new_body = """$fetched_body""".strip()
sep = "\n\n" if comment else ""
new_text = f"---\n{frontmatter}\n---\n\n{comment}{sep}{new_body}\n"
# Only write if changed
if new_text != text:
    p.write_text(new_text)
    print(f"    refreshed: {p}")
else:
    print(f"    unchanged: {p}")
PY

  # Track whether the file is now modified relative to git index
  if ! git diff --quiet -- "$f"; then
    CHANGED=$((CHANGED + 1))
  fi
done

echo ""
echo "=== Summary ==="
if [ "$FETCH_FAIL" -gt 0 ]; then
  red "Fetch failures: $FETCH_FAIL"
fi
if [ "$CHANGED" -gt 0 ]; then
  yellow "Hydrated: $CHANGED file(s). Review with 'git diff' and commit."
elif [ "$FETCH_FAIL" -eq 0 ]; then
  green "All pointer agents are current."
fi

[ "$FETCH_FAIL" -gt 0 ] && exit 2
[ "$CHANGED" -gt 0 ] && exit 1
exit 0
