#!/usr/bin/env bash
# generate-legal-bootstrap.sh — regenerate the thin bootstrap projections of
# `legal-operating-defaults` for runtime surfaces the dispatch adapters do not cover
# (ChatGPT skill entry, Codex AGENTS.md, Claude CLAUDE.md, ChittyOS agent bootstrap).
#
# These are POINTERS, not policy. They carry the capability name, canon_uri, and the
# canonical content sha they were generated from — never rule text. The canonical
# document at canonical/skills/legal-operating-defaults.md is the only authority.
#
# Idempotent: output changes only when the canonical sha changes.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
name="legal-operating-defaults"
canonical="$root/canonical/skills/$name.md"
out="$root/plugins/chittyos-legal/bootstrap/$name"

[ -f "$canonical" ] || { echo "missing canonical: $canonical" >&2; exit 1; }
sha="$(git -C "$root" hash-object "$canonical")"
uri="chittycanon://core/services/chittymarket#skills/$name"
mkdir -p "$out"

body() {
  cat <<EOF
**Capability:** \`$name\` (ChittyMarket, plugin \`chittyos-legal\`)
**Canonical:** \`$uri\`
**Canonical source:** \`canonical/skills/$name.md\` @ \`$sha\`

Legal, litigation, evidentiary, dispute, court-record, or legal-governance work — including
requests that sound administrative — loads \`$name\` BEFORE acting on the request. It governs
evidence handling, the factual lifecycle, provenance, matter isolation, and privilege.

This file is a pointer. It states no rules of its own. Where it and the canonical document
appear to differ, the canonical document governs and this file is drift.

Dependency routing, the distribution boundary, and every operating rule are defined in the
canonical document. This file restates none of them — read the canonical document.
EOF
}

{ echo "# Legal Operating Defaults — ChatGPT skill entry"; echo; body; } > "$out/chatgpt-skill.md"
{ echo "# AGENTS.md — Legal Operating Defaults (Codex bootstrap)"; echo; body; } > "$out/AGENTS.md"
{ echo "# CLAUDE.md — Legal Operating Defaults (Claude bootstrap)"; echo; body; } > "$out/CLAUDE.md"
{ echo "# ChittyOS agent bootstrap policy — Legal Operating Defaults"; echo; body; } \
  > "$out/chittyos-agent-bootstrap.md"

cat > "$out/README.md" <<EOF
# Bootstrap projections — \`$name\`

Thin runtime pointers for bootstrap surfaces that have no dispatch adapter — a \`CLAUDE.md\`,
an \`AGENTS.md\` and a ChatGPT bootstrap pointer are load-order hints, not native packages.
Native ChatGPT Skill packaging is owned by dispatch and lands under
\`plugins/{plugin}/chatgpt-skills/{name}/\`. Claude Code, Codex, OpenClaw, and universal
projections remain under their existing runtime directories.

| File | Surface |
|---|---|
| \`chatgpt-skill.md\` | ChatGPT bootstrap pointer (not the native Skill package) |
| \`AGENTS.md\` | Codex bootstrap |
| \`CLAUDE.md\` | Claude bootstrap |
| \`chittyos-agent-bootstrap.md\` | ChittyOS agent/bootstrap policy |

**Generated — do not edit.** Run \`scripts/generate-legal-bootstrap.sh\` after changing the
canonical document. Generated from \`canonical/skills/$name.md\` @ \`$sha\`.

## Why openclaw and universal reuse the claude-code adapter

Both lanes consume a skill as a directory containing \`SKILL.md\` with \`name\` /
\`description\` / \`canon_uri\` frontmatter followed by the full body — verified on this host
against \`~/.openclaw/skills/capability-governor/SKILL.md\` and
\`~/.agents/skills/capability-governor/SKILL.md\`, which carry exactly that shape. That is
what \`claude-code-agent.sh\` emits, so it is reused rather than cloned. The existing
\`openclaw-agents/*.yaml\` lane is a different kind (\`agent\`) with a different mold; the two
formats coexisting inside one plugin is expected, not drift. **This rests on host inspection,
not on a repo fixture — there is no runtime test asserting either lane's format.**

## Known delivery gap

The dispatch projections for the \`openclaw\` and \`universal\` lanes are written to
\`plugins/{plugin}/openclaw-skills/\` and \`plugins/{plugin}/universal-skills/\`. **This repo has
no installer that copies them onto a machine** (\`~/.openclaw/skills/\`, \`~/.agents/skills/\`).
Those directories are populated today by an out-of-repo fan-out that
\`canonical/skills/drift-report.md\` already records as uncontrolled drift. Projection here is
managed and reproducible; last-mile delivery is not, and is not solved by this capability.
EOF

echo "[legal-bootstrap] regenerated $out from $canonical @ $sha; native ChatGPT package is dispatch-managed"
