---
name: wrangler-audit
canon_uri: chittycanon://core/services/chittymarket#skills/wrangler-audit
description: Audit all wrangler.toml files across CHITTYOS projects for consistency, stale compatibility dates, observability drift from the ratified OFF standard, orphaned tail consumers, binding gaps, and route conflicts. Triggers on "wrangler audit", "audit workers", "check wrangler", "worker consistency", or /wrangler-audit.
kind: skill
plugin: chittyos-devops
runtimes:
  - claude-code
  - codex
classification:
  - operations
  - deployment
---

# Wrangler Audit

Audit all Cloudflare Worker configurations across the ChittyOS ecosystem for consistency and correctness.

## Procedure

### Step 1: Discovery

Find all wrangler.toml files in the workspace:

```bash
find /Users/nb/Desktop/Projects/github.com/CHITTYOS -name "wrangler.toml" -not -path "*/node_modules/*" 2>/dev/null
```

Also check for wrangler.toml files inside nested worker directories:

```bash
find /Users/nb/Desktop/Projects/github.com/CHITTYOS -name "wrangler.toml" -not -path "*/node_modules/*" -not -path "*/.wrangler/*" 2>/dev/null
```

### Step 2: Extract Config

For each wrangler config file (`.toml`, `.json`, `.jsonc`), extract and compare:

| Field | Check |
|-------|-------|
| `name` | Must match `chitty*` naming convention |
| `compatibility_date` | Flag if older than 6 months from today |
| `compatibility_flags` | Note any non-standard flags |
| `main` | Verify entry point file exists |
| `tail_consumers` | MUST be absent. The OFF standard removed tail consumers fleet-wide; #650 stripped them from 18 files. Any surviving entry is a finding — and one naming a service with no deployed target is a dead binding that fails at deploy time, not review time. |
| `observability` (block itself) | MUST be present. A worker with no `observability` block at all inherits the platform default, which captures — the same "absent is not off" trap one level up. Flag it and add an explicit disabled block. |
| `observability.enabled` | MUST be `false` (fleet standard is OFF — see Step 3) |
| `observability.head_sampling_rate` | MUST be present AND `0` wherever `enabled` is set. An absent key is NOT off — it inherits a capturing platform default. |
| `observability.logs.*` | If a nested `logs` block exists, it carries the same rule: `enabled: false`, explicit `head_sampling_rate: 0`, `invocation_logs: false`. `invocation_logs` is valid ONLY here, never as a sibling of the top-level `enabled`. |
| `placement.mode` | SHOULD be `"smart"` for workers hitting Hyperdrive/Neon |
| `vars` | Check for hardcoded secrets (flag anything that looks like a token/key) |
| `kv_namespaces` | Cross-reference for duplicate binding names |
| `d1_databases` | Cross-reference for shared database names |
| `r2_buckets` | Cross-reference for shared bucket names |
| `env.production` / `env.staging` | Verify production and staging environments exist |
| `routes` / `*.chitty.cc` | Flag route conflicts between workers |

### Step 3: Observability — the fleet standard is OFF

**Operator decision, 2026-08-16** (CHITTYOS/chittyentity PR #650, commit `f5485a8`,
merged as `8d490b6`): every worker runs with observability **disabled** and no tail
consumers. This inverted the standard set six days earlier by PR #631, which had
mandated 100% sampling. Log ingest at 100% across the fleet was costing roughly
$65/month.

Required in every Worker's wrangler config:

```jsonc
"observability": {
  "enabled": false,
  "head_sampling_rate": 0
}
```

`invocation_logs` is **not** valid at this level. Verified against wrangler
4.118.0 — adding it as a sibling of `enabled` produces:

```
▲ [WARNING] Processing wrangler.jsonc configuration:
    - Unexpected fields found in observability field: "invocation_logs"
```

It belongs under `logs`, which is where all 19 of the fleet's configs that set it
actually put it.

Nested-`logs` shape (both shapes occur in the wild — check for BOTH):

```jsonc
"observability": {
  "enabled": false,
  "head_sampling_rate": 0,
  "logs": {
    "enabled": false,
    "head_sampling_rate": 0,
    "invocation_logs": false
  }
}
```

Or TOML equivalent:
```toml
[observability]
enabled = false
head_sampling_rate = 0

# only if a nested logs table is used:
[observability.logs]
enabled = false
head_sampling_rate = 0
invocation_logs = false
```

#### ABSENT IS NOT OFF

A config declaring `observability` with **no** `head_sampling_rate` key is not off —
an omitted rate inherits a platform default that captures. The key must be present
and explicitly `0`. This is the same failure mode #631 caught in the other
direction: a config that reads as conformant to a grep while behaving as its
opposite. Audit for the key's *presence*, never only its value.

**Flag CRITICAL** for any worker that:
- Has `observability.enabled = true`
- Declares an `observability` block with `head_sampling_rate` absent at the level where `enabled` is set
- Has **no** `observability` block at all (inherits the capturing default)
- Has any non-zero `head_sampling_rate`
- Has `invocation_logs = true`, or `invocation_logs` placed outside a `logs` block
- Has any `tail_consumers` entry (the OFF standard removed them fleet-wide)

**Do NOT flag** `observability.enabled = false` or a missing `traces` block. Those
are the standard, not defects.

#### On ChittyTrack

Earlier revisions of this skill mandated OTLP destinations `chittytrack-logs` /
`chittytrack-traces` pointing at `track.chitty.cc`. **Do not enforce that.** As of
2026-08-23 the `CHITTYOS/chittytrack` repo exists but `track.chitty.cc` does not
resolve and the service is absent from ChittyRegistry. #650 removed
`tail_consumers` naming `chittytrack` from 18 files for exactly this reason. If
ChittyTrack is later deployed and re-ratified as a sink, that is a new operator
decision — until then, treat any `chittytrack` reference in a wrangler config as an
orphaned binding to report, not a requirement to add.

### Step 4: Compatibility Date Analysis

Today's date determines staleness. Report:
- **Current** (< 3 months old): No action needed
- **Aging** (3-6 months old): Recommend update at next deploy
- **Stale** (> 6 months old): Flag for immediate update
- **Ancient** (> 12 months old): Critical — may miss important runtime changes

### Step 5: Output Report

```markdown
## Wrangler Audit Report

### Summary
- Workers found: X
- Stale compatibility dates: X
- Observability not OFF (enabled, non-zero rate, or rate key absent): X
- Orphaned tail consumers: X
- Route conflicts: X
- Issues found: X

### Per-Worker Assessment

| Worker | Compat Date | Age | Observability | Rate Key | Issues |
|--------|------------|-----|---------------|----------|--------|
| ... | ... | ... | off / ON | present:0 / absent | ... |

### Issues

1. **[CRITICAL/WARNING/INFO]** description...

### Recommended Actions

1. ...
```

### Step 6: Optional Fix

If the user asks to fix issues, update the wrangler.toml files:
- Update `compatibility_date` to today's date (YYYY-MM-DD)
- Set `observability.enabled = false` and insert an explicit `head_sampling_rate = 0`
  where the key is absent (see "ABSENT IS NOT OFF")
- Remove `tail_consumers` entries naming a service with no deployed target
- Do NOT change routes, bindings, or environment configs without explicit confirmation

For a repo-wide sweep, prefer the idempotent text-preserving sweeper rather than
hand-editing: `scripts/observability-off.mjs` in CHITTYOS/chittyentity. Structural
JSONC reserialization drops every comment in these files — do not reparse-and-rewrite.
