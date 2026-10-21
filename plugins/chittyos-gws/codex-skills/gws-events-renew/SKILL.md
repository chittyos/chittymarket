---
name: gws-events-renew
description: |
  Google Workspace Events: Renew/reactivate Workspace Events subscriptions.
canon_uri: chittycanon://core/services/chittyagent-google#skills/gws-events-renew
---

# events +renew

> **PREREQUISITE:** Read `../gws-shared/SKILL.md` for auth, global flags, and security rules. It ships in the `chittyos-gws` plugin alongside this skill.

Renew/reactivate Workspace Events subscriptions

## Usage

```bash
gws events +renew
```

## Flags

| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--name` | — | — | Subscription name to reactivate (e.g., subscriptions/SUB_ID) |
| `--all` | — | — | Renew all subscriptions expiring within --within window |
| `--within` | — | 1h | Time window for --all (e.g., 1h, 30m, 2d) |

## Examples

```bash
gws events +renew --name subscriptions/SUB_ID
gws events +renew --all --within 2d
```

## Tips

- Subscriptions expire if not renewed periodically.
- Use --all with a cron job to keep subscriptions alive.

## See Also

- [gws-shared](../gws-shared/SKILL.md) — Global flags and auth
- `gws events --help` — all subscribe-to-Google-Workspace-events commands (CLI reference; not a bundled skill)
