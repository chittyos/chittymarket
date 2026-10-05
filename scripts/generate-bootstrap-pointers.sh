#!/usr/bin/env bash
# generate-bootstrap-pointers.sh — generate thin bootstrap pointers + OpenAI
# skill metadata for canonical skills whose bootstrap surfaces are not modeled
# as dispatch (runtime, kind) targets.
#
# These are POINTERS / invocation metadata, not policy authorities. The canonical
# skill remains the only source of operating rules.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
requested="${1:-all}"

generate() {
  local name="$1"
  local plugin="$2"
  local display_name="$3"
  local short_description="$4"
  local trigger_text="$5"
  local generator_hint="$6"

  local canonical="$root/canonical/skills/$name.md"
  local out="$root/plugins/$plugin/bootstrap/$name"
  local skill_out="$root/plugins/$plugin/skills/$name"

  [ -f "$canonical" ] || { echo "missing canonical: $canonical" >&2; exit 1; }
  [ -f "$skill_out/SKILL.md" ] || { echo "missing skill projection: $skill_out/SKILL.md" >&2; exit 1; }

  local sha
  sha="$(git -C "$root" hash-object "$canonical")"
  local uri="chittycanon://core/services/chittymarket#skills/$name"
  mkdir -p "$out" "$skill_out/agents"

  body() {
    cat <<EOF
**Capability:** `$name` (ChittyMarket, plugin `$plugin`)
**Canonical:** `$uri`
**Canonical source:** `canonical/skills/$name.md` @ `$sha`

$trigger_text

This file is a pointer. It states no rules of its own. Where it and the canonical document
appear to differ, the canonical document governs and this file is drift.

Dependency routing, the distribution boundary, and every operating rule are defined in the
canonical document. This file restates none of them — read the canonical document.
EOF
  }

  { echo "# $display_name — ChatGPT skill entry"; echo; body; } > "$out/chatgpt-skill.md"
  { echo "# AGENTS.md — $display_name (Codex bootstrap)"; echo; body; } > "$out/AGENTS.md"
  { echo "# CLAUDE.md — $display_name (Claude bootstrap)"; echo; body; } > "$out/CLAUDE.md"
  { echo "# ChittyOS agent bootstrap policy — $display_name"; echo; body; } > "$out/chittyos-agent-bootstrap.md"

  cat > "$out/README.md" <<EOF
# Bootstrap projections — `$name`

Thin runtime pointers for bootstrap surfaces that have no dispatch adapter — a `CLAUDE.md`,
an `AGENTS.md`, and a ChatGPT skill entry are load-order hints, not skill packages, so
`resolve_output.py` has no `(runtime, kind)` row for them. The four runtimes that DO have
rows (`claude-code`, `codex`, `openclaw`, `universal`) receive full generated `SKILL.md`
projections instead, under `plugins/{plugin}/{skills,codex-skills,openclaw-skills,universal-skills}/`.

| File | Surface |
|---|---|
| `chatgpt-skill.md` | ChatGPT skill entry |
| `AGENTS.md` | Codex bootstrap |
| `CLAUDE.md` | Claude bootstrap |
| `chittyos-agent-bootstrap.md` | ChittyOS agent/bootstrap policy |

**Generated — do not edit.** Run `$generator_hint` after changing the
canonical document. Generated from `canonical/skills/$name.md` @ `$sha`.

## Why openclaw and universal reuse the claude-code adapter

Both lanes consume a skill as a directory containing `SKILL.md` with `name` /
`description` / `canon_uri` frontmatter followed by the full body — verified on this host
against `~/.openclaw/skills/capability-governor/SKILL.md` and
`~/.agents/skills/capability-governor/SKILL.md`, which carry exactly that shape. That is
what `claude-code-agent.sh` emits, so it is reused rather than cloned. The existing
`openclaw-agents/*.yaml` lane is a different kind (`agent`) with a different mold; the two
formats coexisting inside one plugin is expected, not drift. **This rests on host inspection,
not on a repo fixture — there is no runtime test asserting either lane's format.**

## Known delivery gap

The dispatch projections for the `openclaw` and `universal` lanes are written to
`plugins/{plugin}/openclaw-skills/` and `plugins/{plugin}/universal-skills/`. **This repo has
no installer that copies them onto a machine** (`~/.openclaw/skills/`, `~/.agents/skills/`).
Those directories are populated today by an out-of-repo fan-out that
`canonical/skills/drift-report.md` already records as uncontrolled drift. Projection here is
managed and reproducible; last-mile delivery is not, and is not solved by this capability.
EOF

  cat > "$skill_out/agents/openai.yaml" <<EOF
interface:
  display_name: $display_name
  short_description: $short_description
policy:
  allow_implicit_invocation: true
EOF

  echo "[bootstrap] regenerated $name pointers + OpenAI metadata from $canonical @ $sha"
}

generate_legal() {
  generate     "legal-operating-defaults"     "chittyos-legal"     "Legal Operating Defaults"     "Evidence-governed operating defaults for legal, litigation, court-record, privilege, and legal-analysis work."     $'Legal, litigation, evidentiary, dispute, court-record, or legal-governance work — including\nrequests that sound administrative — loads `legal-operating-defaults` BEFORE acting on the request. It governs\nevidence handling, the factual lifecycle, provenance, matter isolation, and privilege.'     "scripts/generate-legal-bootstrap.sh"
}

generate_finance() {
  generate     "finance-operating-defaults"     "chittyos-finance"     "Finance Operating Defaults"     "Books-method defaults for bookkeeping, chart-of-accounts, classification, reconciliation, tax derivation, and governed financial writes."     $'Bookkeeping, chart-of-accounts, classification, reconciliation, tax-form derivation, or\nfinancial-datastore work — including requests that sound trivial — loads `finance-operating-defaults` BEFORE acting on the request. It governs books method, financial-write controls, reconciliation discipline, and the handoff to legal when a figure becomes an assertion.'     "scripts/generate-bootstrap-pointers.sh finance-operating-defaults"
}

case "$requested" in
  all)
    generate_legal
    generate_finance
    ;;
  legal-operating-defaults)
    generate_legal
    ;;
  finance-operating-defaults)
    generate_finance
    ;;
  *)
    echo "unknown bootstrap capability: $requested" >&2
    echo "known: legal-operating-defaults, finance-operating-defaults, all" >&2
    exit 2
    ;;
esac
