# Bootstrap projections — `legal-operating-defaults`

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

**Generated — do not edit.** Run `scripts/generate-legal-bootstrap.sh` after changing the
canonical document. Generated from `canonical/skills/legal-operating-defaults.md` @ `204de3de697c7f1a5d3018dfbe551f0c8942e827`.

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
