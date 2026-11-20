#!/usr/bin/env bash
# Offline regression test for `/market standardize` (fixture source, no network).
# Pins: classification, gate verdicts, checkpoint/resume, dry-run never writes,
# one PR per repo with no duplicate on re-run, verify waits for the merge,
# secret values never reach state, a changed standard forces re-audit.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SKILL="$ROOT/plugins/chittymarket-manager/skills/market"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FX="$TMP/fx"
export MARKET_STATE_DIR="$TMP/state"
STATE="$MARKET_STATE_DIR/standardize/default/state.json"
PASS=0
ok()   { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { echo "FAIL: $1" >&2; exit 1; }
std()  { bash "$SKILL/market.sh" standardize "$@" --fixtures "$FX"; }
# jq-free state probe: q <python expr over `s`>
q()    { python3 -c "import json,sys; s=json.load(open('$STATE')); print($1)"; }
step() { q "s['orgs']['$1']['repos']['$2']['steps']['$3']['status']"; }

mk() { mkdir -p "$FX/$1/$(dirname "$2")"; cat > "$FX/$1/$2"; }
mk chittyos/chittymarket .claude-plugin/marketplace.json <<'JSON'
{"name":"chittymarket","owner":{"name":"ChittyOS"},"plugins":[
 {"name":"inline","source":"./plugins/inline","version":"1.0.0","description":"d"},
 {"name":"goodplugin","source":{"source":"github","repo":"CHITTYOS/goodplugin"},"version":"1.0.0","description":"d"},
 {"name":"ghost","source":{"source":"github","repo":"CHITTYOS/ghost","ref":"v1"},"version":"1.0.0","description":"d"}]}
JSON
mk chittyos/goodplugin .claude-plugin/plugin.json <<'JSON'
{"name":"goodplugin","version":"1.1.0","description":"d"}
JSON
mk chittyos/app CLAUDE.md <<<"# app"
mk chittyos/app .claude/settings.json <<'JSON'
{"permissions":{"allow":["Bash(ls:*)"]}}
JSON
mkdir -p "$FX/chittyos/plain"
mk chittyos/old CLAUDE.md <<<"# old"
mk chittyos/old _repo.json <<<'{"archived":true}'
SECRET="gh""p_$(printf 'A%.0s' $(seq 36))"   # assembled at runtime; never a literal in the repo
mk orgb/secretapp CLAUDE.md <<<"# s"
mk orgb/secretapp .mcp.json <<<"{\"mcpServers\":{\"x\":{\"env\":{\"T\":\"$SECRET\"}}}}"
mk orgb/badref AGENTS.md <<<"# b"
mk orgb/badref .claude/settings.json <<'JSON'
{"extraKnownMarketplaces":{"chittymarket":{"source":{"source":"github","repo":"chittyos/chittymarket"}}},
 "enabledPlugins":{"nope@chittymarket":true,"inline@chittymarket":true}}
JSON
mk orgb/rogue .claude-plugin/plugin.json <<<'{"name":"Rogue_Plugin","version":"1","description":"d"}'
mk orgb/rogue .claude-plugin/marketplace.json <<<'{"name":"other","plugins":[]}'

# 1. A bounded first pass stops early; the second pass resumes, it does not redo.
set +e; OUT1="$(std run --orgs chittyos,orgb --max 2)"; RC=$?; set -e
[ "$RC" = 3 ] || fail "bounded run should exit 3 (work remains), got $RC"
[ "$(grep -c ' audit: ' <<<"$OUT1")" = 2 ] || fail "--max 2 should audit exactly 2 repos"
set +e; OUT2="$(std run --orgs chittyos,orgb)"; RC=$?; set -e
[ "$RC" = 3 ] || fail "dry run with open work should exit 3, got $RC"
grep -q 'chittyos/app audit:' <<<"$OUT1" && ! grep -q 'chittyos/app audit:' <<<"$OUT2" \
  || fail "resume re-audited a repo already checkpointed"
grep -q 'discover' <<<"$OUT2" && fail "resume re-discovered an org"
ok "bounded run checkpoints; second run resumes without redoing audit or discovery"

# 2. Classification and gate verdicts.
[ "$(q "s['orgs']['chittyos']['repos']['plain']['class']")" = none ] || fail "plain should be class none"
[ "$(q "s['orgs']['chittyos']['repos']['old']['skipped']")" = archived ] || fail "archived repo not skipped"
chk() { q "sorted(f['check'] for f in s['orgs']['$1']['repos']['$2']['findings'])"; }
[ "$(chk chittyos chittymarket)" = "['M3-external-sources-resolve', 'M4-external-sources-pinned']" ] || fail "market findings: $(chk chittyos chittymarket)"
[ "$(chk chittyos goodplugin)" = "['P5-version-matches-marketplace']" ] || fail "goodplugin findings: $(chk chittyos goodplugin)"
[ "$(chk chittyos app)" = "['C1-marketplace-registered']" ] || fail "app findings: $(chk chittyos app)"
[ "$(chk orgb secretapp)" = "['C1-marketplace-registered', 'S2-no-inline-secrets']" ] || fail "secretapp findings: $(chk orgb secretapp)"
[ "$(chk orgb badref)" = "['C2-enabled-plugins-resolve']" ] || fail "badref findings: $(chk orgb badref)"
[ "$(chk orgb rogue)" = "['P2-name-kebab-case', 'P3-version-semver', 'P4-listed-in-marketplace', 'S1-single-marketplace']" ] || fail "rogue findings: $(chk orgb rogue)"
ok "classification and gate verdicts"

# 3. Dry run writes nothing and parks at apply.
[ ! -e "$FX/_prs" ] || fail "dry run opened a pull request"
[ "$(step chittyos app apply)" = pending ] || fail "app apply should be pending in dry run"
ok "dry run opens no pull request; apply stays pending"

# 4. The secret value is in neither state nor report.
! grep -rq "$SECRET" "$MARKET_STATE_DIR" || fail "secret value written to state"
! std report | grep -q "$SECRET" || fail "secret value printed in report"
ok "secret values never reach state, plans or report"

# 5. --apply opens one PR, merges into existing settings, and does not duplicate.
set +e; std run --orgs chittyos,orgb --apply >/dev/null; set -e
PR="$FX/_prs/chittyos__app.json"
[ -f "$PR" ] || fail "--apply did not open the pull request"
python3 - "$PR" <<'PY' || fail "PR content wrong"
import json, sys
pr = json.load(open(sys.argv[1]))
s = json.loads(pr["files"][".claude/settings.json"])
assert s["permissions"] == {"allow": ["Bash(ls:*)"]}, "existing settings keys were not preserved"
assert s["extraKnownMarketplaces"]["chittymarket"]["source"] == {"source": "github", "repo": "chittyos/chittymarket"}
assert pr["branch"] == "chore/market-standardize"
PY
[ "$(step chittyos app verify)" = waiting ] || fail "verify should wait for the merge"
BEFORE="$(sha256sum "$PR")"
set +e; std run --orgs chittyos,orgb --apply >/dev/null; set -e
[ "$(sha256sum "$PR")" = "$BEFORE" ] || fail "re-run rewrote the pull request"
[ "$(ls "$FX/_prs" | wc -l)" = 2 ] || fail "unexpected PR set: $(ls "$FX/_prs")"   # app + secretapp
ok "--apply opens one PR per repo, preserves settings, and is idempotent"

# 6. verify turns ok only once the change is actually on the repo.
python3 -c "import json;print(json.load(open('$PR'))['files']['.claude/settings.json'],end='')" > "$FX/chittyos/app/.claude/settings.json"
set +e; std run --orgs chittyos,orgb >/dev/null; set -e
[ "$(step chittyos app verify)" = ok ] || fail "verify did not pass after the merge"
[ "$(q "s['orgs']['chittyos']['repos']['app']['findings']")" = "[]" ] || fail "findings not refreshed after verify"
ok "verify passes only after the merge lands"

# 7. An unreachable org is recorded, does not block the rest, and is retried.
set +e; std run --orgs chittyos,orgc >/dev/null 2>&1; RC=$?; set -e
[ "$RC" = 1 ] || fail "unreachable org should exit 1, got $RC"
mk orgc/late CLAUDE.md <<<"# late"
set +e; std run --orgs chittyos,orgc >/dev/null; set -e
[ "$(step orgc late audit)" = ok ] || fail "failed discovery was not retried on resume"
ok "discovery failure is isolated and retried on resume"

# 8. Changing the standard invalidates earlier verdicts.
cp -r "$SKILL/standard" "$TMP/std2"; echo "# changed" >> "$TMP/std2/gate.yaml"
set +e; OUT="$(MARKET_STANDARD_DIR="$TMP/std2" std run --orgs chittyos)"; set -e
grep -q 'standard changed' <<<"$OUT" && grep -q 'chittyos/goodplugin audit:' <<<"$OUT" || fail "changed standard did not force re-audit"
ok "a changed standard forces re-audit"

echo "test-market-standardize: $PASS passed"
