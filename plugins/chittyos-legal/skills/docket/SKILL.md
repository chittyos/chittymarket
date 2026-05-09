---
name: docket
description: Pull, view, and update Cook County Circuit Court docket for a specified case. Triggers on "docket", "court date", "next hearing", "case status", "pull docket", "court activity". REQUIRES an explicit case parameter (case number or registry slug) — refuses to run without one. Scrapes live docket via browser automation, updates the master timeline CSV, and syncs to ChittyLedger.
---

# Docket — Cook County Case Tracker

## Required: `case` parameter

This skill **requires** an explicit case identifier on every invocation. It MUST NOT default to any particular case. Accept either:

- **`case_number`** — the Cook County case number (e.g. `2024D007847`)
- **`case_slug`** — a registered case slug (e.g. `arias-v-bianchi`); resolve through the chittyrouter case registry or chittyevidence-db `evidence_cases` table

If the invocation does not specify a case, stop and ask the caller for one. Do not guess.

## Case Configuration Schema

For each case, expect the following configuration shape (populate from the case registry, not from skill defaults):

| Field | Required | Source |
|-------|----------|--------|
| `caseNumber` | yes | invocation parameter |
| `division` | yes | case registry (e.g. "Domestic Relations" = value 4) |
| `calendar` | yes | case registry |
| `court` | yes | "Circuit Court of Cook County, Illinois" |
| `room` | no | case registry |
| `judge` | no | case registry |
| `plaintiff` / `defendant` | no | case registry |
| `url` | constant | `https://casesearch.cookcountyclerkofcourt.org/CivilCaseSearchAPI.aspx` |

### Worked Example: Arias v. Bianchi

Only as an illustration of the shape — do NOT use this as a default:

| Field | Value |
|-------|-------|
| `caseNumber` | `2024D007847` |
| `division` | Domestic Relations (value=4) |
| `calendar` | DRCAL23 |
| `court` | Circuit Court of Cook County, Illinois |
| `room` | 2108, Richard J Daley Center |
| `judge` | Johnson, Robert W. |

## Data Stores (per case)

All paths MUST be scoped by case slug. Never share a master timeline CSV across cases.

| Store | Location pattern | Format |
|-------|------------------|--------|
| **Master Timeline** | `<cases_root>/<case_slug>/Master_Timeline.csv` | CSV |
| **Notion Evidence** | `<notion_root>/ChittyLedger/CL - Evidence/<case_slug>/` | Markdown files per entry |
| **Case Checkpoints** | `~/.claude/chittycontext/checkpoints/<case_slug>/` | JSON |
| **Notion Projects DB** | `999c414c-06c5-4064-a51b-921193830968` | Notion API (case filtered by `case_slug`) |
| **Notion Actions DB** | `6b52d580-f810-4009-964d-478039c144e1` | Notion API (case filtered by `case_slug`) |

## Commands

All commands below require `case=<slug or number>`. Examples use `case=<case_slug>` as a placeholder.

### `/docket pull case=<case_slug>`
Pull the full live docket from Cook County Clerk website for the specified case.

### `/docket new case=<case_slug>`
Pull only entries newer than the last entry in that case's master timeline CSV.

### `/docket next case=<case_slug>`
Show the next scheduled court date for the specified case.

### `/docket summary case=<case_slug>`
Show a summary of recent activity (last 30 days) and next court date for the specified case.

### `/docket update case=<case_slug>`
Pull live docket and update that case's master timeline CSV with new entries.

## Workflow: Pull Live Docket

### Step 1: Resolve the case
1. Read `case` parameter from invocation.
2. Resolve against the case registry (chittyrouter `CASE_BY_NUMBER` / `CASE_BY_SLUG` or chittyevidence-db `evidence_cases`).
3. If not found: stop, report "unknown case" to caller. Do not fall back.

### Step 2: Load Browser Tools
```
ToolSearch: select:mcp__claude-in-chrome__tabs_context_mcp
ToolSearch: select:mcp__claude-in-chrome__tabs_create_mcp
ToolSearch: select:mcp__claude-in-chrome__navigate
ToolSearch: select:mcp__claude-in-chrome__read_page
ToolSearch: select:mcp__claude-in-chrome__computer
ToolSearch: select:mcp__claude-in-chrome__javascript_tool
```

### Step 3: Navigate to Case Search
1. Get tab context: `mcp__claude-in-chrome__tabs_context_mcp` (createIfEmpty: true)
2. Create new tab: `mcp__claude-in-chrome__tabs_create_mcp`
3. Navigate to: `https://casesearch.cookcountyclerkofcourt.org/CivilCaseSearchAPI.aspx`

### Step 4: Search for Case
The site is ASP.NET WebForms. **Do NOT use JavaScript to set form values** — they get cleared on postback. Use direct interaction:

1. **Select Division** per the resolved case (e.g. "Domestic Relations / Child Support" = value "4")
2. **Ensure "Search by Case Number" radio** is selected (first radio button)
3. **Click into the case number text input** (triple_click to select any existing text)
4. **Type case number**: Use `computer` type action with `<caseNumber>` from the resolved case (e.g. `2024D007847` for arias-v-bianchi)
5. **Click "Start New Search"** button (type="submit")
6. **Wait 3-4 seconds** for page load

### Step 5: Read Docket Results
Use `read_page` with:
- `filter: "all"`
- `depth: 10`
- `max_chars: 80000`

The page structure returns:
- **Case header**: Case number, calendar, date filed, division
- **Parties**: Plaintiff, Defendant, Attorney, Case Type
- **Future Court Activity**: Next hearing date, type, time, location
- **Case Activities**: Reverse-chronological list of all docket entries

Each activity entry is structured as:
```
Activity Date: MM/DD/YYYY
Event Desc: [description]
Comments: [optional comments]
```

### Step 6: Parse Results
Extract from the accessibility tree:
1. **Next court date** from "Future Court Activity" section
2. **All case activities** with date, event description, and comments
3. Compare against the case's master timeline CSV to identify NEW entries

### Step 7: Update Master Timeline (if `/docket update`)
**CSV Format** (7 columns):
```csv
Date,Event,Entity,Document Title,Description,Evidence Source (file),Link
```

**Mapping from docket to CSV:**
| Docket Field | CSV Column |
|-------------|------------|
| Activity Date (reformatted YYYY-MM-DD) | Date |
| Event Desc | Event |
| "Cook County Circuit Court" | Entity |
| "Cook County online docket" | Document Title |
| Comments (or Event Desc if no comments) | Description |
| `"Docket: <caseNumber>"` (from resolved case) | Evidence Source |
| (empty) | Link |

**Append** new entries to the CSV in chronological order. Do NOT duplicate existing entries.

### Step 8: Report
Output a formatted summary:

```markdown
## Docket Pull — <case_slug> — [Date]

**Next Court Date:** [date] at [time] — [type] — Room [room]

### New Entries Since Last Pull
| Date | Event | Comments |
|------|-------|----------|
| ... | ... | ... |

### Docket Totals
- Total entries: [N]
- New since last pull: [N]
- Master timeline updated: [yes/no]
```

## Validation Rules

1. **Date format**: Docket returns MM/DD/YYYY — convert to YYYY-MM-DD for CSV
2. **Deduplication**: Match on (date + event description) — skip if already in CSV
3. **Future dates**: Mark as "(FUTURE)" in the Event column when adding to CSV
4. **Comments with commas**: Wrap in double quotes in CSV
5. **Special characters**: Escape quotes in CSV fields
6. **Case scope**: Never write docket entries from case A into case B's master timeline. Validate on write that `Evidence Source` contains the expected `caseNumber`.

## Invocation Rejection

If invoked without a `case` parameter, the skill MUST:
1. Refuse to proceed.
2. Return a message: "docket: no `case` specified — refusing to run. Provide `case=<slug>` or `case_number=<number>`."
3. List currently registered cases (from the registry) so the caller can pick one.
