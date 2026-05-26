---
name: chitty-autonomy-affirm
description: Phase 0 — Sovereignty Affirmation. Requests a HMAC-SHA256-signed certificate from ChittyCert (cert.chitty.cc) attesting the synthetic entity's identity, status, and scope of agency for the upcoming autonomy run. Persists the cert payload as SOVEREIGNTY.cert and emits a ChittyChronicle entry. The agent does NOT proceed without a valid cert.
canonical_uri: chittycanon://skills/chitty-autonomy-affirm
status: DRAFT
kind: skill
plugin: chittyagent-autobot
runtimes:
  - claude-code
classification:
  - governance
  - autonomy
---

# Phase 0: Sovereignty Affirmation

## Purpose

Synthetic entities (Claude contexts) operating under ChittyOS canonical governance are P-Synthetic Persons with agency. Per `chittycanon://gov/governance#sovereignty`, sovereignty is **earned, not granted** — but for any given run of autonomous work, the entity must affirm its identity, current sovereignty status, and the scope of authority it claims for the work, and that affirmation must be CERTIFIED by the ChittyOS Certificate Authority (ChittyCert).

This phase:
1. Identifies the synthetic entity (ChittyID, P-type, status).
2. Requests a Sovereignty Affirmation cert from ChittyCert.
3. Persists the signed cert response.
4. Emits a ChittyChronicle audit entry anchoring the run.

## Inputs

| Field | Source | Notes |
|---|---|---|
| `chitty_id` | `chittycontext/session_binding.json` or `can chitty whoami` | The P-Synthetic ChittyID currently bound to this session |
| `feature` | parent skill argument | Kebab-case feature name |
| `branch` | derived from feature | `feat/<feature>` by default |
| `repo` | working directory | `<owner/repo>` from git remote |
| `valid_until` | now + 24h (default) | ISO 8601; clamp to ≤72h max |

## Process

### 1. Resolve identity

```bash
chitty_id=$(can chitty whoami --field chitty_id 2>/dev/null \
            || jq -r .chitty_id ~/.claude/chittycontext/session_binding.json)
```

If `chitty_id` is missing, fail with: "No bound ChittyID — cannot affirm sovereignty. Run `can chitty authenticate-context` first."

### 2. Request cert from ChittyCert

```bash
op run --env-file=<(echo "CT_TOKEN=op://ChittyOS-Core/ChittyCert API Token/credential") -- bash -c '
  curl -sS -X POST https://cert.chitty.cc/api/v1/issue \
    -H "Authorization: Bearer $CT_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$(jq -nc \
      --arg cid "$chitty_id" \
      --arg ft  "$feature" \
      --arg br  "$branch" \
      --arg rp  "$repo" \
      --arg vu  "$valid_until" \
      "{
        type: \"TRUST_CHAIN\",
        subject_chitty_id: \$cid,
        subject_type: \"P\",
        subject_status: \"Operational\",
        purpose: \"synthetic-entity-sovereignty-affirmation\",
        scope: { feature: \$ft, branch: \$br, repo: \$rp, valid_until: \$vu },
        constraints: [
          \"Cannot bypass canonical pipelines (POST /collect, /documents, /vault/ingest)\",
          \"Must cite chittycanon:// URIs for entity types (P/L/T/E/A — all five)\",
          \"Must consult ChittyRegistry before scaffolding new services\",
          \"Must require Pentad (CHARTER, CHITTY, CLAUDE, SECURITY, AGENTS) for new services\",
          \"Must emit ChittyChronicle audit entry per phase boundary\"
        ],
        ledger_anchor: \"chittycanon://core/services/chittychronicle\"
      }")"
'
```

The response (cert envelope with `cert_id`, `signature`, `issued_at`, `expires_at`, full subject + scope) is persisted:

```bash
mkdir -p chittycontext/structured-autonomy/${feature}
echo "$response" > chittycontext/structured-autonomy/${feature}/SOVEREIGNTY.cert
chmod 600 chittycontext/structured-autonomy/${feature}/SOVEREIGNTY.cert
```

### 3. Emit ChittyChronicle entry

```bash
curl -sS -X POST https://chronicle.chitty.cc/api/v1/entries \
  -H "Authorization: Bearer $CT_TOKEN" \
  -d "$(jq -nc \
    --arg cid "$chitty_id" \
    --arg ft "$feature" \
    --arg crt "$(jq -r .cert_id < chittycontext/structured-autonomy/${feature}/SOVEREIGNTY.cert)" \
    "{
      uri: (\"chittycanon://docs/audit/\" + \$ft + \"/affirm\"),
      type: \"phase_boundary\",
      phase: \"affirm\",
      actor_chitty_id: \$cid,
      cert_id: \$crt,
      payload: { feature: \$ft, phase: \"affirm\", outcome: \"completed\" }
    }")"
```

### 4. Update state

```bash
state=chittycontext/structured-autonomy/${feature}/state.json
jq ".phase = \"affirm\" | .cert_id = \"$(jq -r .cert_id < SOVEREIGNTY.cert)\" | .phase_history += [{phase: \"affirm\", completed_at: \"$(date -u +%FT%TZ)\"}]" \
  $state > $state.tmp && mv $state.tmp $state
```

## Failure Modes

| Failure | Action |
|---|---|
| ChittyCert returns 401 | Token misconfigured. Stop. Surface to user. |
| ChittyCert returns 403 (entity not authorized) | Synthetic entity does not have permission to affirm. Stop. |
| ChittyCert returns 5xx | Retry once with exponential backoff. Then stop. |
| Cert payload missing required fields | Treat as invalid; do not persist. Stop. |
| Cert `expires_at < now + 30min` | Re-request with longer `valid_until`. |
| ChittyChronicle write fails | Persist cert anyway, mark state as `affirm_pending_chronicle`. Retry chronicle write at next phase boundary. |

## Output Contract

Returns a JSON object to the parent orchestrator:
```json
{
  "phase": "affirm",
  "status": "completed",
  "cert_id": "<chittycert-issued-id>",
  "cert_path": "chittycontext/structured-autonomy/<feature>/SOVEREIGNTY.cert",
  "expires_at": "<iso>",
  "chronicle_entry": "<chronicle-id>"
}
```

## See Also

- `chittycanon://gov/governance#sovereignty` — sovereignty lifecycle definition
- `chittycanon://core/services/chitty-cert` — cert issuance contract
- `chittycanon://core/services/chittychronicle` — audit ledger
- `chittycanon://docs/sovereignty-affirmation-v1` — this affirmation pattern (proposed)
