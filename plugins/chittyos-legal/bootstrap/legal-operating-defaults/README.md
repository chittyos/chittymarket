# Bootstrap projections — `legal-operating-defaults`

Thin runtime pointers for surfaces the dispatch adapters do not cover for `kind: skill`
(`resolve_output.py` maps skills to claude-code and codex only).

| File | Surface |
|---|---|
| `chatgpt-skill.md` | ChatGPT skill entry |
| `AGENTS.md` | Codex bootstrap |
| `CLAUDE.md` | Claude bootstrap |
| `chittyos-agent-bootstrap.md` | ChittyOS agent/bootstrap policy |

**Generated — do not edit.** Run `scripts/generate-legal-bootstrap.sh` after changing the
canonical document. Generated from `canonical/skills/legal-operating-defaults.md` @ `2acf282b28989d6ece53f8733db9530a62f7dce6`.

## Known delivery gap

The dispatch projections for the `openclaw` and `universal` lanes are written to
`plugins/{plugin}/openclaw-skills/` and `plugins/{plugin}/universal-skills/`. **This repo has
no installer that copies them onto a machine** (`~/.openclaw/skills/`, `~/.agents/skills/`).
Those directories are populated today by an out-of-repo fan-out that
`canonical/skills/drift-report.md` already records as uncontrolled drift. Projection here is
managed and reproducible; last-mile delivery is not, and is not solved by this capability.
