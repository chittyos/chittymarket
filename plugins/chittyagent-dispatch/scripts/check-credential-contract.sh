#!/usr/bin/env bash
# ChittyGuardian check — Credential Access Contract conformance.
# canon: chittycanon://core/contracts/credential-access
#
# Usage: check-credential-contract.sh [PATH]     (PATH defaults to ".")
# Exit 0 = pass, 1 = violations found. Intended as a non-bypassable CI gate.
set -uo pipefail

ROOT="${1:-.}"
CONTRACT_URI="chittycanon://core/contracts/credential-access"
CODE_GLOBS=(--include='*.gs' --include='*.js' --include='*.ts' --include='*.py')
DOC_GLOBS=(--include='*.md' --include='*.json' --include='*.toml' --include='*.yaml' --include='*.yml')
fail=0
note() { printf '%s\n' "$*" >&2; }

# 1) Retired secret manager must not be named as a SOURCE. Allow explicit
#    retirement/deprecation notes (so canon docs that say "1Password is RETIRED" pass).
onep=$(grep -rIniE '1password|op run|op read|op item get' "$ROOT" "${CODE_GLOBS[@]}" "${DOC_GLOBS[@]}" 2>/dev/null \
        | grep -viE 'retir|deprecat|legacy|stale|do not (use|follow)|no longer')
if [ -n "$onep" ]; then note "FAIL (1Password as source of truth):"; printf '%s\n' "$onep" >&2; fail=1; fi

# 2) Consumer surfaces must not carry CF Access client secrets (broker-only identity).
cfa=$(grep -rInE 'CF_ACCESS_CLIENT_(ID|SECRET)' "$ROOT" "${CODE_GLOBS[@]}" 2>/dev/null)
if [ -n "$cfa" ]; then note "FAIL (consumer holds CF_ACCESS_CLIENT_* — broker identity):"; printf '%s\n' "$cfa" >&2; fail=1; fi

# 3) No raw secret-value reads from a consumer (Apps Script surfaces).
# Skip comment lines (doc references to the canonical mechanism are not calls).
rawread=$(grep -rInE 'wrangler secret get|secrets_resolve|SECRETS_STORE\.get|printenv[^|]*\|[^|]*TOKEN|echo[[:space:]]+\$[A-Z_]*(TOKEN|SECRET|KEY)' "$ROOT" --include='*.gs' 2>/dev/null \
          | grep -vE ':[0-9]+:[[:space:]]*([*]|//|#)')
if [ -n "$rawread" ]; then note "FAIL (secret-value read in a consumer surface):"; printf '%s\n' "$rawread" >&2; fail=1; fi

# 4) Every SECURITY.md must cite the contract URI.
while IFS= read -r f; do
  [ -z "$f" ] && continue
  if ! grep -qF "$CONTRACT_URI" "$f"; then note "FAIL ($f does not cite $CONTRACT_URI)"; fail=1; fi
done < <(find "$ROOT" -iname 'SECURITY.md' 2>/dev/null)

if [ "$fail" -eq 0 ]; then note "PASS: credential-access contract conformance ($ROOT)"; fi
exit "$fail"
