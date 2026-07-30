---
name: mcp-tool-calling-rules
canon_uri: chittycanon://core/services/chittymarket#skills/mcp-tool-calling-rules
description: |
  Invocation runbook and rules for calling webmaster_harvest, webmaster_check, and webmaster_flag.
kind: skill
plugin: nowebmaster
runtimes:
  - claude-code
  - codex
classification:
  - mcp
  - tool-invocation
---

# MCP Tool Invocation Rules for nowebmaster

## 0. Implementation Drift (read first)

This skill documents the **intended** contract. Two rules below are NOT yet implemented in `chittyagent-webmaster`:

- **`batch()` atomicity in `webmaster_flag` is REQUIRED but ABSENT.** `webmaster-service.ts:156-186` issues two independent `.prepare().bind().run()` calls; there is no `.batch(` in `src/`. Treat the rule as binding-and-violated, not as a description of current behavior.
- **The `wm_*` tables have no DDL** anywhere in the monorepo. The tool handlers INSERT against unprovisioned tables.

## 1. Tool Index & Signatures

```
CHITTYAGENT-WEBMASTER (chittycanon://core/services/chittyagent-webmaster)
  ├── webmaster_harvest(url, content?)
  ├── webmaster_check(source_url, claim_text)
  └── webmaster_flag(url, description, flagged_by)
```

---

## 2. Invocation Protocols & Rules

### Tool 1: `webmaster_harvest`
* **`tool_id`:** `webmaster_t_harvest` — `ontology_type: 'T'` (Thing) per `manifest.ts`
* **Input Schema:**
  - `url` (string, required): Must be a valid `http://` or `https://` URL.
  - `content` (string, optional): Raw markdown text if page is pre-harvested.
* **Database Behavior:**
  - Inserts/updates `wm_pages` in `chittyevidence-db`.
  - Uses `RETURNING id` on UPSERT (`ON CONFLICT(url)`) to prevent page ID desynchronization.
* **Return Shape:**
  ```json
  {
    "status": "success",
    "page_id": "page_12345678",
    "url": "https://example.gov/docs",
    "content_hash": "a1b2c3d4...",
    "scraped_at": "2026-07-29T21:40:00.000Z"
  }
  ```

---

### Tool 2: `webmaster_check`
* **`tool_id`:** `webmaster_t_check` — `ontology_type: 'T'` (Thing) per `manifest.ts`
* **Input Schema:**
  - `source_url` (string, required): Must be `http://` or `https://`.
  - `claim_text` (string, required, min length 5): The factual claim to check.
* **Contradiction Evaluation Rules:**
  - Stores claim in `wm_claims`.
  - Performs cross-reference evaluation against claims from different URLs.
  - Word boundary regexes (`\b... \b`) are enforced to prevent false-positive substring matches (e.g. `"must"` vs `"must not"`).
  - Matches write to `wm_contradictions` with confidence `0.85` — a hardcoded SQL literal (`webmaster-service.ts:116`), not a computed default.

---

### Tool 3: `webmaster_flag`
* **`tool_id`:** `webmaster_t_flag` — `ontology_type: 'T'` (Thing) per `manifest.ts`
* **Input Schema:**
  - `url` (string, required): Target URL being reported.
  - `description` (string, required, min length 5): Details of contradiction or decay.
  - `flagged_by` (string, required, min length 1): Reporting user ID or handle.
* **Transaction Integrity Rules:**
  - D1 `batch()` transaction is strictly required for atomic writes (**NOT YET IMPLEMENTED — see §0**):
    - Insert into `wm_flags` (`reward_status = 'awarded'`, `points_awarded = 100`)
    - Insert into `wm_rewards` (`source = 'wm_flag'`, `points = 100`)
