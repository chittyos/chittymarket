---
name: docket
description: Pull, view, and update Cook County Circuit Court docket for Arias v. Bianchi (2024D007847). Triggers on "docket", "court date", "next hearing", "case status", "pull docket", "court activity". Scrapes live docket via browser automation, updates master timeline CSV, and syncs to ChittyLedger.
---

# Docket — Cook County Case Tracker

## Case Configuration

| Field | Value |
|-------|-------|
| **Case Number** | 2024D007847 |
| **Division** | Domestic Relations (value=4) |
| **Calendar** | DRCAL23 |
| **Court** | Circuit Court of Cook County, Illinois |
| **Room** | 2108, Richard J Daley Center |
| **Judge** | Johnson, Robert W. |
| **Plaintiff** | Luisa Fernanda Arias Montealegre |
| **Defendant** | Nicholas Bianchi |
| **Attorney (Plaintiff)** | Rebecca Melzer |
| **URL** | `https://casesearch.cookcountyclerkofcourt.org/CivilCaseSearchAPI.aspx` |

## Data Stores

| Store | Location | Format |
|-------|----------|--------|
| **Master Timeline** | `/Users/nb/Desktop/Projects/development/dev/connections/notion/Master_Timeline_Aribia_Arias_v_Bianchi.csv` | CSV |
| **Notion Evidence** | `/Users/nb/Desktop/Projects/development/dev/connections/notion/Private & Shared/ChittyLedger/CL - Evidence/` | Markdown files per entry |
| **Case Checkpoints** | `/Users/nb/.claude/chittycontext/checkpoints/` | JSON |
| **Notion Projects DB** | `999c414c-06c5-4064-a51b-921193830968` | Notion API |
| **Notion Actions DB** | `6b52d580-f810-4009-964d-478039c144e1` | Notion API |

## Commands

### `/docket` or `/docket pull`
Pull the full live docket from Cook County Clerk website.

### `/docket new`
Pull only entries newer than the last entry in the master timeline CSV.

### `/docket next`
Show the next scheduled court date only.

### `/docket summary`
Show a summary of recent activity (last 30 days) and next court date.

### `/docket update`
Pull live docket and update the master timeline CSV with new entries.

## Workflow: Pull Live Docket

### Step 1: Load Browser Tools
```
ToolSearch: select:mcp__claude-in-chrome__tabs_context_mcp
ToolSearch: select:mcp__claude-in-chrome__tabs_create_mcp
ToolSearch: select:mcp__claude-in-chrome__navigate
ToolSearch: select:mcp__claude-in-chrome__read_page
ToolSearch: select:mcp__claude-in-chrome__computer
ToolSearch: select:mcp__claude-in-chrome__javascript_tool
```

### Step 2: Navigate to Case Search
1. Get tab context: `mcp__claude-in-chrome__tabs_context_mcp` (createIfEmpty: true)
2. Create new tab: `mcp__claude-in-chrome__tabs_create_mcp`
3. Navigate to: `https://casesearch.cookcountyclerkofcourt.org/CivilCaseSearchAPI.aspx`

### Step 3: Search for Case
The site is ASP.NET WebForms. **Do NOT use JavaScript to set form values** — they get cleared on postback. Use direct interaction:

1. **Select Division**: Use `computer` action to click the dropdown (ref for combobox), then select "Domestic Relations / Child Support" (value="4")
2. **Ensure "Search by Case Number" radio** is selected (first radio button)
3. **Click into the case number text input** (triple_click to select any existing text)
4. **Type case number**: Use `computer` type action: `2024D007847`
5. **Click "Start New Search"** button (type="submit")
6. **Wait 3-4 seconds** for page load

### Step 4: Read Docket Results
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

### Step 5: Parse Results
Extract from the accessibility tree:
1. **Next court date** from "Future Court Activity" section
2. **All case activities** with date, event description, and comments
3. Compare against master timeline CSV to identify NEW entries

### Step 6: Update Master Timeline (if `/docket update`)
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
| "Docket: 2024D007847" | Evidence Source |
| (empty) | Link |

**Append** new entries to the CSV in chronological order. Do NOT duplicate existing entries.

### Step 7: Report
Output a formatted summary:

```markdown
## Docket Pull — [Date]

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

## Quick Reference

**Last known state (Feb 6, 2026):**
- Next hearing: 03/31/2026, 11:00 AM, Room 2108 (Open Call)
- Last docket entry: 02/06/2026 — Quash Writ Allowed
- Total CSV entries: ~137
- Plaintiff attorney: Rebecca Melzer

**Critical pending items:**
- Petition to Disgorge Fees (filed 11/14/2025) — unruled
- TRO still technically active (filed 10/31/2024, 493+ days)
- Motion to Quash Body Attachment — GRANTED 02/06/2026
