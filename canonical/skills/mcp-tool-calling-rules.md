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
* **Ontology Role:** Tool / Ingestion (`webmaster_t_harvest`)
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
* **Ontology Role:** Tool / Verification (`webmaster_t_check`)
* **Input Schema:**
  - `source_url` (string, required): Must be `http://` or `https://`.
  - `claim_text` (string, required, min length 5): The factual claim to check.
* **Contradiction Evaluation Rules:**
  - Stores claim in `wm_claims`.
  - Performs cross-reference evaluation against claims from different URLs.
  - Word boundary regexes (`\b... \b`) are enforced to prevent false-positive substring matches (e.g. `"must"` vs `"must not"`).
  - Matches write to `wm_contradictions` with default confidence `0.85`.

---

### Tool 3: `webmaster_flag`
* **Ontology Role:** Tool / User Reporting (`webmaster_t_flag`)
* **Input Schema:**
  - `url` (string, required): Target URL being reported.
  - `description` (string, required, min length 5): Details of contradiction or decay.
  - `flagged_by` (string, required, min length 1): Reporting user ID or handle.
* **Transaction Integrity Rules:**
  - D1 `batch()` transaction is strictly required for atomic writes:
    - Insert into `wm_flags` (`reward_status = 'awarded'`, `points_awarded = 100`)
    - Insert into `wm_rewards` (`source = 'wm_flag'`, `points = 100`)
