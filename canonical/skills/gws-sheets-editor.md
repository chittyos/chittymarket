---
name: gws-sheets-editor
canon_uri: chittycanon://core/services/chittymarket#skills/gws-sheets-editor
description: Write, append, or update cells in an existing Google Sheet from any Claude/Codex runtime. Use whenever the user says "populate / append to / update / fill in / write to this sheet", pastes a docs.google.com/spreadsheets URL as a destination, or asks to sync rows into a Google Sheet. Picks the first working write route (ChittyGWS google_sheets_update_values → Chrome-extension paste → Drive staging sheet), enforces schema-match + dedupe before any write, and always re-reads the target to verify. Do NOT use for reading-only tasks (the Drive connector handles reads) or for creating standalone .xlsx deliverables (use xlsx).
kind: skill
plugin: chittyos-mcp
runtimes:
  - claude-code
  - codex
classification:
  - integration
  - google-workspace
  - data-entry
---

# gws-sheets-editor — write rows into an existing Google Sheet

Read/metadata connectors (Google Drive MCP `read_file_content`, `get_file_metadata`) cannot write cells. This skill defines the only sanctioned write routes, in priority order, and the pre-write discipline that applies to every route.

## 1. Restate before writing

State, in one line: target spreadsheet ID, target tab, the row range that will be written, and the verification condition. Never write to a tab you have not read in this session.

## 2. Pre-write discipline (all routes)

1. **Read the target tab first** (`mcp__Google_Drive__read_file_content` on the sheet ID). Capture the header row verbatim and the current last data row.
2. **Schema-match.** Emit rows in the target's exact column order and count. Do not add columns; put annotations in an existing free-text column (e.g. `Brand/Model`, `Notes`) or ask.
3. **Dedupe** against existing rows on the natural key the sheet already uses (typically `Location + Item Description + Brand/Model`, or an ID column). Report which candidate rows were dropped as duplicates and why.
4. **Tag provenance.** Every written row carries a `Source` link (Gmail thread, Drive file, receipt) when the sheet has such a column. Mark inferred rows `[UNVERIFIED]` in the description; mark unknown fields `Unknown`, never blank-as-if-verified.
5. **Never destructive.** Append only. Do not clear, sort, or overwrite existing rows unless the user explicitly says "replace"; if so, capture-before-destroy: export the current tab (CSV via `download_file_content`) and attach it before writing.
6. **Build the payload as a local CSV/XLSX first** (12-column example: `Location, Item Category, Item Description, Quantity, Condition, Brand/Model, Purchase Date, Purchase Price, Protection Plan, Protection Coverage, Plan Price, Source`). This file is the artifact that every route consumes and the fallback deliverable if all routes fail.

## 3. Write routes — try in order, stop at the first that works

### Route A — ChittyGWS (canonical)
- Surface: ChittyGWS worker, MCP at `https://gws.chitty.cc/mcp`, flat tools `google_sheets_get`, `google_sheets_get_values`, `google_sheets_update_values` (also `google_mcp_proxy` for the raw Sheets surface). Protected by Cloudflare Access — see the `chittygws` skill for JWT/`TEAM_DOMAIN`/`POLICY_AUD` requirements.
- Call through the portal (`portal_codemode_search` for a name containing `google_sheets`), or through `ch1tty/cast` with the intent "append rows to sheet <id> tab <name>". Never call the Sheets API with raw credentials; credential/auth flow is governed by `chittycanon://core/contracts/credential-access` — cite it, do not restate it.
- Payload: `spreadsheetId`, `range` = `'<Tab>'!A<lastRow+1>:<lastCol><lastRow+n>`, `valueInputOption: USER_ENTERED`, `values` = the CSV rows.
- If `gws.chitty.cc` returns 000/5xx or the portal lists no `google_sheets_*` tool: record `ROUTE_A_UNAVAILABLE` with the observed status and fall through. (Observed 2026-09-04: host unreachable from both cloud and chittymini-00; registry has no `gws` entry — file as a finding, do not retry in-loop.)

### Route B — Chrome extension paste (user-attended)
- Requires `mcp__claude-in-chrome__tabs_context_mcp` to succeed. Open the sheet URL with `#gid=<tab gid>&range=A<lastRow+1>`, write the rows as TSV to the clipboard, paste with cmd/ctrl+V, then re-read via Drive to verify.
- Do not attempt GUI automation through remote-device AppleScript/Control_Chrome when calls hang — that is a macOS Automation permission prompt waiting on the device; tell the user and fall through.

### Route C — Drive staging sheet (always available)
- `mcp__Google_Drive__create_file` with `contentMimeType: text/csv`, `parentId` = the target sheet's parent folder, title `<Target title> — <scope> rows to append [staging]`. Drive converts it to a Google Sheet.
- Re-read the staging sheet to confirm row/column count, then give the user the exact paste instruction: "copy `A2:L<n>` from staging → paste at `<Tab>!A<lastRow+1>`".
- Also deliver the `.xlsx` via `SendUserFile` so the rows survive outside Drive.

## 4. Verify (mandatory, every route)

Re-read the target tab after the write (Routes A/B) or the staging sheet (Route C). Report: rows before, rows after, rows added, duplicates dropped, rows flagged `[UNVERIFIED]`, and any rows with an empty `Source`. If the count does not match the payload, say so — never claim a write that was not confirmed by a read.

## 5. Output format

One short block: route used (or blocker with the exact failing call), target range written, verification counts, excluded/conflicting items that need the operator's call, and the staging/xlsx links if Route C was used. Label facts Given / Derived / Unknown. No narration of intermediate steps.

## 6. Known gaps (file to Linear, do not work around)

- ChittyGWS is not registered in `registry.chitty.cc` and `gws.chitty.cc` does not answer; until it is deployed on its custom domain and exposed through the portal, Route A is dead and Route C is the default. Deploy/registry changes are PR-only and ratified by the operator.
- The Google Drive connector has no cell-write tool; do not expect `update_file` to write content (metadata only).
