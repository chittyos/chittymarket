---
name: manifest-forge-publisher
description: Publish or validate ChittyOS Development skills across Claude, Codex/OpenAI, Agent Plugin, ChatGPT, skills.sh and npx skills add using the existing ChittyMarket Manifest Forge engine. Use for skill marketplace publishing, manifest repair, package export, cross-runtime projection, or drift checks.
---

# Manifest Forge Publisher

## Authority and scope
- Treat `chittyos/chittymarket` `canonical/skills/manifest-forge.md` as the authoritative workflow and `scripts/manifest-forge.py` as the engine. Do not fork or reimplement the generator in this plugin.
- Treat existing `skills/<name>/SKILL.md` frontmatter as source data. Preserve existing authored metadata and marketplace identities. Consult `development-governance` and `capability-governor` before creating new canonical capabilities.
- ChittyOS Development is the consumer and packaging surface; ChittyMarket owns projection behavior.

## Execution
1. Obtain an authorized working checkout of ChittyMarket and a local unpacked copy of the current ChittyOS Development package. Check actual repository revisions and inspect `manifest-forge.py --help` before choosing options.
2. Run `python3 scripts/manifest-forge.py diff <package>` first for existing packages. Review proposed changes and preserve intentional native manifest fields.
3. Run `python3 scripts/manifest-forge.py repair <package>` only where drift is confirmed, or `generate <package>` for a new package. Optional marketplace upserts require a selected canonical marketplace JSON and explicit authorization.
4. Run `python3 scripts/manifest-forge.py validate <package>` and inspect diffs. Verify each of `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`, `.agent-plugin/plugin.json`, `agents/openai.yaml`, and `skills/<name>/SKILL.md` as applicable.
5. Run `npx skills add . --list` against the **published repository layout** to confirm skill discovery. Do not claim that this validates a ZIP or that it installs skills into ChatGPT.
6. Run relevant ChittyMarket tests and existing governance checks, then commit via a normal reviewed PR. Never overwrite credential fields or protected manifest metadata. Report generated, validated, merged and published states separately.

## Failure modes
- If ChittyMarket checkout or execution is unavailable, produce an inspectable package and mark projection/runtime validation pending; do not fabricate success.
- If the engine drops package-specific fields, stop and resolve compatibility in ChittyMarket rather than hand-maintaining divergent generators.
- Never create a separate manifest service, schema, registry, paid GitHub Actions workflow or background automation for this task.

Canonical reference: https://github.com/chittyos/chittymarket/blob/main/canonical/skills/manifest-forge.md (merged PR #219).
