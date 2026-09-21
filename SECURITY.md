---
uri: chittycanon://docs/ops/policy/chittymarket-security
namespace: chittycanon://docs/ops
type: policy
version: 1.0.0
status: DRAFT
registered_with: chittycanon://core/services/canon
title: "ChittyMarket Security Policy"
certifier: chittycanon://core/foundation/mychitty-vault
visibility: PUBLIC
---

# ChittyMarket Security Policy

> `chittycanon://core/services/chittymarket` | Tier 3 (Operational) | Local-only

## Threat model

ChittyMarket has **no runtime attack surface**. It exposes no HTTP endpoint,
holds no secret, issues no token, and runs no process — per `CHARTER.md`, it is
explicitly not responsible for network APIs, identity generation, or token
provisioning. Reasoning about it as a service is a category error, and a
security policy that describes an auth provider or JWT verification here is
describing something that does not exist.

The real exposure is **supply chain**. This repo is the manifest that Claude
Code reads via `/plugin add`. Every artifact it lists — skill, agent, hook, MCP
server — is installed into an operator session and executes with that
operator's full tool access. A change here is a change to what runs on
developer machines, with no sandbox between the manifest and the shell.

That inverts the usual severity ordering. A merge to `main` is closer to a
production deploy than to a docs change.

## Trust boundaries

| Boundary | What crosses it | Control |
|---|---|---|
| PR → `main` | Every artifact definition | Code review + CI validation |
| `main` → operator session | `/plugin add`, `/market enable` | Operator action |
| `marketplace.json` → `~/.claude/marketplace.json` | Live session config | Symlink — writes land immediately |
| `canonical/<name>.md` → projections | Runtime agent/skill behavior | `chittyagent-dispatch`, drift audit |
| External GitHub sources | Plugin code not in this repo | **Unpinned — see below** |

### Canonical is the only source of truth

`canonical/<name>.md` is authoritative; the files under `plugins/*/skills/`,
`plugins/*/codex-skills/`, and `plugins/*/openclaw-agents/` are **generated
projections**. Reviewing a projection is not reviewing the artifact — a
projection can drift from the canonical it claims to represent, and a reviewer
who reads only the projection has approved something other than what runs.

Edit canonical, re-project, and treat any hand-edit of a projected file as
drift to be reconciled through `chittyagent-dispatch` (`reconcile` mode), never
as the change itself.

`.claude-plugin/marketplace.json` is likewise generated. Per `CLAUDE.md`, never
edit it by hand — edit `plugin.json` and regenerate. The
`manifest idempotency` CI job exists to catch exactly this and fails the build
when the committed manifest does not match a fresh regeneration.

### External plugin sources are unpinned

Four entries in `.claude-plugin/marketplace.json` resolve outside this repo:

- `chittyhelper` → `CHITTYOS/chittyhelper`
- `chittyagent` → `CHITTYOS/chittyagent`
- `chittycommand` → `CHITTYOS/chittycommand`
- `legal-arsenal` → `CHITTYOS/legal-cases`

None declares a ref, tag, or commit, so each resolves to whatever that
repository's default branch holds at install time. Review of this repo does not
cover their contents, and a commit pushed to any of those four changes what
`/plugin add` installs without a change here. They are trusted because they are
org-owned, not because they are verified.

Treat the org boundary as the actual control. Anything that widens who can push
to those four repos widens this one.

### Hooks execute, but the enforcement is not in this repo

`plugins/chittyos-governance/hooks/hooks.json` registers a `PreToolUse` hook
with matcher `.*` and `"type": "command"` — a shell command that runs on
**every tool call** in the operator's session. A hook change is a privileged
change regardless of how small the diff reads.

The shipped command is only a pointer. The rules that actually gate —
`validate-entity-types`, `block-chittyid-generation`, `block-direct-deploy`,
`require-pr-workflow`, `block-governance-edits`, and five others — are named in
`hooks.json` but live in operator-local config at
`~/.claude/hooks/hookify.*.local.md`. They are referenced by filename, not
shipped or version-pinned here.

So reviewing this repo does not review the enforcement, and the plugin cannot
guarantee a rule it names is installed, current, or unmodified. Whether a given
governance rule is actually in force is a property of the operator's machine,
not of this manifest — verify it there before relying on it.

## Secrets

There are none in this repo, and none should ever be added. ChittyMarket
consumes no credential at runtime because it has no runtime.

For artifacts that *do* need credentials once installed, the canonical path is
ChittySecrets (`secrets.chitty.cc`, cold source of truth) fronting Cloudflare
Secrets Store, resolved at the call site. 1Password is retired and non-functional.
Route credential intent through ChittyConnect (`/chico`); never commit a secret
value, and never ask an operator to paste one into a session.

## CI as a control

`.github/workflows/validate-chittymarket.yml` gates:

- `lint + test + manifest idempotency` — schema validation, plugin lint, and
  proof that the committed native manifest matches a regeneration
- `codex runtime smoke` — every projected `codex-skills/*/SKILL.md` loads
- `openclaw runtime smoke` — every projected `openclaw-agents/*.yaml` loads

Both smoke jobs fall back to a schema-mimic loader when the real runtime is not
on PATH, and report the mode they ran in. A schema-only pass is weaker evidence
than a real-runtime pass; read the reported mode before treating a green check
as proof the artifact loads.

**A CI job only gates if branch protection requires it.** Job-level
configuration is not enforcement — verify required checks are configured on
`main`, not merely that the workflow exists and passes.

## Reporting

Security issues in this repo — a malicious or compromised artifact, an
unexpected projection drift, an unreviewed external source — go to
`chittymarket@chitty.cc` or a private advisory on `CHITTYOS/chittymarket`.

Because a merge here reaches operator machines directly, report before the
artifact is enabled anywhere, not after.

---
*Policy Version: 1.0.0 | Last Updated: 2026-09-03*
