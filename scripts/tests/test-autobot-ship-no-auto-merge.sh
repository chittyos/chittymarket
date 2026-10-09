#!/usr/bin/env bash
# Pins the autobot Ship phase against blind merges: no `gh pr merge --auto` in
# the canonical autonomy skills/agent or any chittyagent-autobot projection, and
# the gated pr-land path present in the canonical and every projection.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail=0
scope=(canonical/skills/chitty-autonomy*.md canonical/agents/chittyagent-autobot.md plugins/chittyagent-autobot)
if grep -rnE -- "gh pr merge[^\`]*--auto" "${scope[@]}"; then
  echo "FAIL: autobot Ship must not use gh pr merge --auto" >&2; fail=1
fi
for f in canonical/skills/chitty-autonomy-ship.md \
         plugins/chittyagent-autobot/skills/chitty-autonomy-ship/SKILL.md \
         plugins/chittyagent-autobot/codex-skills/chitty-autonomy-ship/SKILL.md; do
  for needle in "autoassist:pr_land_v1" "--match-head-commit" "gh run list --commit"; do
    grep -qF -- "$needle" "$f" || { echo "FAIL: $f missing '$needle'" >&2; fail=1; }
  done
done
[ "$fail" -eq 0 ] && echo "✓ autobot Ship is gated (no --auto merge; pr-land + pinned fallback present)"
exit "$fail"
