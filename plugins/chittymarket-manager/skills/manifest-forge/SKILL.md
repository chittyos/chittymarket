---
name: manifest-forge
description: Generate, validate, diff, and repair cross-runtime plugin manifests from existing SKILL.md packages for Claude, Codex/OpenAI, Agent Plugins, and ChatGPT skill metadata. Use when a repository or skill package needs compatible manifests, marketplace import repair, or manifest drift detection.
canon_uri: chittycanon://core/services/chittymarket#skills/manifest-forge
---

# Manifest Forge

Use the repository's deterministic `scripts/manifest-forge.py` engine. Treat existing `SKILL.md` frontmatter as source data; do not invent a parallel registry or schema.

## Commands

```bash
python3 scripts/manifest-forge.py generate <package>
python3 scripts/manifest-forge.py validate <package>
python3 scripts/manifest-forge.py diff <package>
python3 scripts/manifest-forge.py repair <package>
```

Add `--marketplace <path>` to `generate` or `repair` to upsert the package into an existing marketplace JSON document. Limit manifest targets with `--targets claude,codex,agent`.

## Workflow

1. Inspect the package before writing. Accept either a root `SKILL.md` or `skills/*/SKILL.md` layout.
2. Run `diff` first when modifying an established package.
3. Run `generate` for new packages or `repair` when generated manifests drift.
4. Run `validate` after generation; non-zero means generated output and committed files differ.
5. Review the diff before committing. Never write secrets, credentials, or runtime tokens into manifests.
6. Preserve repository-native manifests that contain intentional fields not derivable from `SKILL.md`; in those cases, use Manifest Forge as a validator/diff aid rather than blindly overwriting them.

## Generated surfaces

- `.claude-plugin/plugin.json`
- `.codex-plugin/plugin.json`
- `.agent-plugin/plugin.json`
- `agents/openai.yaml` beside each discovered `SKILL.md`
- optional marketplace entry via `--marketplace`

The engine is deterministic: identical skill frontmatter produces identical generated output.
