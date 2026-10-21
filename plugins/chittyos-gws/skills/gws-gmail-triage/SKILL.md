---
name: gws-gmail-triage
description: |
  Gmail: Show unread inbox summary (sender, subject, date).
canon_uri: chittycanon://core/services/chittyagent-google#skills/gws-gmail-triage
---

# gmail +triage

> **PREREQUISITE:** Read `../gws-shared/SKILL.md` for auth, global flags, and security rules. It ships in the `chittyos-gws` plugin alongside this skill.

Show unread inbox summary (sender, subject, date)

## Usage

```bash
gws gmail +triage
```

## Flags

| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--max` | — | 20 | Maximum messages to show (default: 20) |
| `--query` | — | — | Gmail search query (default: is:unread) |
| `--labels` | — | — | Include label names in output |

## Examples

```bash
gws gmail +triage
gws gmail +triage --max 5 --query 'from:boss'
gws gmail +triage --format json | jq '.[].subject'
gws gmail +triage --labels
```

## Tips

- Read-only — never modifies your mailbox.
- Defaults to table output format.

## See Also

- [gws-shared](../gws-shared/SKILL.md) — Global flags and auth
- `gws gmail --help` — all send, read, and manage email commands (CLI reference; not a bundled skill)
