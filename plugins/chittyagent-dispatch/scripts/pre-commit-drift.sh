#!/usr/bin/env bash
# pre-commit-drift.sh — block commits that leave canonical/projection drift.
#
# Logic:
#   1. Identify canonicals touched by the staged diff:
#        - canonical/<name>.md staged
#        - any projection path staged: plugins/<plugin>/agents/<name>.md,
#          plugins/<plugin>/codex-skills/<name>/SKILL.md,
#          plugins/<plugin>/openclaw-agents/<name>.yaml
#   2. Re-run `dispatch.sh sync <name>` for each touched canonical.
#   3. If sync produced any changes (modified projection, modified state, or new
#      untracked artifacts), the commit is incomplete or has direct-edit drift.
#      Fail with a message listing what needs to be staged or reverted.
#
# Install:  ln -s ../../plugins/chittyagent-dispatch/scripts/pre-commit-drift.sh .git/hooks/pre-commit
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
DISPATCH="$REPO_ROOT/plugins/chittyagent-dispatch/scripts/dispatch.sh"
[ -x "$DISPATCH" ] || exit 0   # plugin missing → no-op (other repos may share this hook)

cd "$REPO_ROOT"

mapfile -t staged < <(git diff --cached --name-only --diff-filter=ACMR)
# Note: we intentionally do NOT early-exit when staged is empty. The evidence-gate
# policy check at the bottom must run regardless (adversarial review #7).

declare -A names=()
for f in "${staged[@]}"; do
  case "$f" in
    canonical/*.md)
      # Strip any kind-subdir prefix so name is just the basename. Files like
      # canonical/agents/foo.md and canonical/skills/foo.md both yield name=foo.
      n="${f#canonical/}"
      n="${n##*/}"     # strip subdir(s) → basename
      n="${n%.md}"
      [ "$n" = "README" ] || names["$n"]=1 ;;
    plugins/*/agents/*.md)
      n="${f##*/}"; names["${n%.md}"]=1 ;;
    plugins/*/codex-skills/*/SKILL.md)
      tmp="${f%/SKILL.md}"; names["${tmp##*/}"]=1 ;;
    plugins/*/openclaw-agents/*.yaml)
      n="${f##*/}"; names["${n%.yaml}"]=1 ;;
    plugins/*/claude-skills/*.json)
      n="${f##*/}"; names["${n%.json}"]=1 ;;
    plugins/*/chatgpt-apps/*.json)
      n="${f##*/}"; names["${n%.json}"]=1 ;;
  esac
done

snapshot_before=$(git status --porcelain)

failed=0
# Skip drift sync when no canonical/projection paths are touched, but still fall
# through to the always-on evidence-gate check below.
if [ "${#names[@]}" -gt 0 ]; then
  for name in "${!names[@]}"; do
    # Search canonical/<kind>/<name>.md first, then flat canonical/<name>.md.
    can=""
    for sub in agents skills commands mcp hooks tools; do
      if [ -f "$REPO_ROOT/canonical/$sub/${name}.md" ]; then
        can="$REPO_ROOT/canonical/$sub/${name}.md"
        break
      fi
    done

    if [ -z "$can" ]; then
      # Pointer-file exception.
      proj=$(printf '%s\n' "${staged[@]}" | grep -E "plugins/[^/]+/agents/${name}\.md$" | head -1 || true)
      if [ -n "$proj" ] && grep -qE "^prompt_url:" "$REPO_ROOT/$proj" && grep -qE "^owner_repo:" "$REPO_ROOT/$proj"; then
        dim_msg="[pre-commit-drift] $name: pointer (owner_repo declared) — canonical/ not required"
        printf '\033[0;90m%s\033[0m\n' "$dim_msg" >&2
        continue
      fi
      # Skip leftover SKILL.md or similar that don't have a canonical name.
      if [ "$name" = "SKILL" ] || [ "$name" = "README" ]; then
        continue
      fi
      echo "[pre-commit-drift] $name: projection staged but canonical missing (searched canonical/{agents,skills,commands,mcp,hooks,tools}/${name}.md and canonical/${name}.md)" >&2
      failed=1
      continue
    fi
    "$DISPATCH" sync "$name" >/dev/null 2>&1 || {
      echo "[pre-commit-drift] $name: dispatch.sh sync failed" >&2
      failed=1
    }
  done

  snapshot_after=$(git status --porcelain)

  if [ "$snapshot_before" != "$snapshot_after" ]; then
    echo ""
    echo "[pre-commit-drift] BLOCKED — canonical/projection drift detected." >&2
    echo "" >&2
    echo "Re-running dispatch.sh produced changes that aren't in your commit." >&2
    echo "Either:" >&2
    echo "  (a) git add the regenerated files below, or" >&2
    echo "  (b) revert direct edits to projected files and edit the canonical instead." >&2
    echo "" >&2
    diff <(printf '%s\n' "$snapshot_before") <(printf '%s\n' "$snapshot_after") | grep '^>' | sed 's/^> /  /' >&2
    failed=1
  fi
fi

# Evidence-gate policy enforcement (adversarial review #7)
# Source: docs/overrides/evidence-gate-overrides.json
# Policy: any capability with authority.non_repudiation_required:true MUST carry
# authority.evidence_gate populated. Block on the combination
# (non_repudiation_required:true, evidence_gate:null|missing).
#
# ALWAYS-ON: this check runs whenever capabilities.generated.json exists,
# regardless of staging. Previously it only ran when the overlay was in the
# staged diff, which let pre-existing violations persist across unrelated
# commits indefinitely. Decoupling from staging closes that hole.
overlay="$REPO_ROOT/capabilities.generated.json"
if [ -f "$overlay" ]; then
  if command -v jq >/dev/null 2>&1; then
    violations=$(jq -r '
      .capabilities[]
      | select(.authority.non_repudiation_required == true)
      | select(.authority.evidence_gate == null or .authority.evidence_gate == "")
      | .capability_id
    ' "$overlay" 2>/dev/null || true)
    if [ -n "$violations" ]; then
      echo "" >&2
      echo "[pre-commit-drift] BLOCKED — evidence-gate policy violation." >&2
      echo "" >&2
      echo "These capabilities assert non_repudiation_required:true but evidence_gate is unset:" >&2
      printf '  - %s\n' $violations >&2
      echo "" >&2
      echo "Populate authority.evidence_gate (one of: pre-execute-middleware," >&2
      echo "projection-internal, legal-space-only). See docs/overrides/evidence-gate-overrides.json" >&2
      echo "and docs/decisions/capability-audit-log.md#2026-05-23." >&2
      failed=1
    fi
  else
    echo "[pre-commit-drift] WARN — jq not available; evidence-gate policy check skipped." >&2
  fi
fi

exit "$failed"
