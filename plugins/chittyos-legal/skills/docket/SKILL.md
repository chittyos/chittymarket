---
name: docket
description: Pull, view, and update Cook County Circuit Court docket for a specified case. Triggers on "docket", "court date", "next hearing", "case status", "pull docket", "court activity". REQUIRES an explicit case parameter (case number or registry slug) — refuses to run without one. Scrapes live docket via browser automation, updates the master timeline CSV, and syncs to ChittyLedger.
canon_uri: chittycanon://core/services/chittymarket#skills/docket
---

# Docket — Cook County Case Tracker

## Required: `case` parameter

This skill **requires** an explicit case identifier on every invocation. It MUST NOT default to any particular case. Accept either:

- **`case_number`** — the Cook County case number, shape `YYYY D NNNNNN` (division letter varies)
- **`case_slug`** — a registered case slug, shape `<case_slug>`; resolve through the chittyrouter case registry or the chittyevidence-db scope tables. Do not hardcode one here. **Read §"Case resolution is currently unavailable" before relying on this** — the table this step named for months does not exist, and the store it points at is empty.

If the invocation does not specify a case, stop and ask the caller for one. Do not guess.

### Case-number formats by division

The division letter in a case number determines both the number's shape and which Court Type
the portal's search form needs. Both columns are format tokens — substitute the resolved case.

| Division | Number shape | Portal Court Type |
|----------|--------------|-------------------|
| Domestic Relations | `YYYY D NNNNNN` | Domestic Relations / Child Support |
| Law | `YYYY L NNNNNN` | Civil / Law |
| Chancery | `YYYY CH NNNNNN` | Civil / Chancery |
| Municipal | `YYYY M<n> NNNNNN` | Municipal District `<n>` |
| Criminal | `YYYY CR NNNNNN` | Criminal |

Spacing is not significant to the clerk's system but is to the search form: if a spaced number
returns nothing, retry it unspaced before concluding the case does not exist.

## Case resolution is currently unavailable (verified 2026-10-19)

Step 1 below says to resolve `case_slug` against the case registry. **Via chittyevidence-db that
cannot currently succeed, and the failure is silent-shaped** — a session follows the step, finds
nothing, and has no way to tell "this case is not registered" from "the registry named here does
not exist".

What was actually checked, with real `COUNT(*)` rather than `pg_stat_user_tables.n_live_tup`
(which is a planner estimate and would have reported the same numbers without being evidence of
them), against the ChittyEvidence Neon project:

- **There is no `evidence_cases` table.** This document named it for months. The schema holds
  `scopes`, `scope_parties`, `scope_artifacts`, `scope_events`, `evidence_registry`,
  `evidence_events`, `source_canonical`.
- **`scopes` holds 0 rows**, as do `scope_parties`, `scope_artifacts`, `scope_events`,
  `evidence_events` and `source_canonical`. `evidence_registry` holds exactly 1 row, and it is
  not case material — an operator self-assessment artifact, `chittyverify_status: self-attested`.

So there is no registered case to resolve, and no ingested evidence for any matter. Until that
changes, a caller must pass `case_number` directly, and the chittyrouter path (`CASE_BY_NUMBER` /
`CASE_BY_SLUG`) is the only registry lane that might answer.

**Do not treat this as license to default to a case.** The Invocation Rejection rule below still
binds: no `case` parameter means refuse. An unresolvable registry makes the parameter *more*
load-bearing, not less — it is now the only thing scoping the run.

## The portal case-number format is NOT derivable for every division

The actor's input is digits only — no dashes, no division letter. Its worked example (in the
actor's own `CLAUDE.md` on the host, where a concrete matter is permitted and here is not)
**inserts a digit where the division letter was**. So the portal string is **not** a mechanical
strip of the printed case number, and the inserted digit is **not** the `divisionValue` — in that
example the division's table value and the inserted digit disagree.

Written as shapes, for a printed number `YYYY <L> NNNNNN`:

| Candidate derivation | Shape | Result for a live Domestic Relations matter |
|---|---|---|
| strip the division letter | `YYYYNNNNNN` (10 digits) | empty |
| strip the letter, insert a district digit | `YYYY<d>NNNNNN` (11 digits) | empty |

**Confirmed 2026-10-19:** both returned all header fields `null`, `case_activities: []`, exit 0.

Two readings of that, and the skill must not silently pick one: the numbers are wrong, or the
page did not render in time. Note the actor's `open_first_result_tables()` docstring describes an
all-null result as the signature of a *past* bug (an unconditional `.click()` on a null selector
plus a fixed 5s wait), now fixed by a conditional click and `_wait_for_stable()` — so from current
code all-null reads as no-match, but the two outcomes remain indistinguishable from the output
alone. **An all-null return is therefore a `UNVERIFIED` result, not a "case not found" finding.**

**Party-name search does not substitute here.** `search_by_company_name()` writes
`MainContent_txtCompName` — the by-name form's *company* field. A dissolution's parties are
natural persons, so that field will not reach them, and the actor implements no individual
last/first-name search. For Domestic Relations, case-number is the only path this actor offers.

**Get the string from a source, do not derive it.** Ask the operator, or take it from a case whose
portal string is already known to work in that division. Guessing further risks returning a
*different* case's docket, which the Stop Conditions below and matter isolation both forbid — and
a wrong caption that happens to look plausible is worse than an empty result.

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

### Shape of a resolved case

Token-only. Every value below is supplied by the case registry at invocation time; none of it
belongs in this document. A concrete matter here would be a §15 violation even when captioned
as an illustration — see `scripts/check-matter-leak.py`.

| Field | Shape |
|-------|-------|
| `caseNumber` | `YYYY D NNNNNN` |
| `division` | division name + its portal value, e.g. a two-digit code |
| `calendar` | `<calendar_code>` |
| `court` | Circuit Court of Cook County, Illinois |
| `room` | `<room>`, `<courthouse>` |
| `judge` | `<judge>` |

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
2. Resolve against the case registry (chittyrouter `CASE_BY_NUMBER` / `CASE_BY_SLUG`, or the chittyevidence-db scope tables). **This step cannot currently succeed via chittyevidence-db — see §"Case resolution is currently unavailable".**
3. If not found: stop, report "unknown case" to caller. Do not fall back.

### Step 2: WAF blocker — read this before choosing a method

Cook County Clerk's F5/Shape WAF is confirmed (2026-08-31, CFDXN-176/CFDXN-178) to reject
CDP-driven and headless browser automation, and plain HTTP requests, regardless of origin IP:
Cloudflare Browser Rendering (chittyscrape), Apify datacenter Playwright, Apify residential-IP
Playwright, and plain `curl` with a realistic browser User-Agent (even against the bare
homepage) were all blocked identically — from both a cloud datacenter VM and a home-network IP.
The block fingerprints the automation channel itself (CDP artifacts / TLS handshake), not IP
reputation. `mcp__claude-in-chrome__*` drives Chrome via the same DevTools Protocol class of
automation that's confirmed blocked in every other tested form — it has not been directly
tested against this specific portal, but treat it as likely blocked given the pattern, and
prefer the method below unless/until it's confirmed otherwise.

**Preferred method — real Safari GUI, verified working:** use the Cook County docket actor,
which lives at **`/Users/claude/chittyactors/cook-county-docket` on `chittymini-01`** (verified
2026-10-19). This document previously said `chittyentity/actors/chittyactor-cook-county-docket`;
no such path exists on that host, which costs a session a search every time. This drives a
genuine, logged-in Safari session via AppleScript (`osascript`/`do JavaScript`) on
`chittymini-01` — the only method confirmed to load the actual search results instead of an F5
"Request Rejected" page. It requires one-time, console-only permission grants on that specific
Mac (see the actor's `CLAUDE.md`) and cannot run in Docker, on Apify's cloud, or on any headless
Linux node. Invoke it via `python3 main.py <input.json> <output.json>` on `chittymini-01`
directly, or `python3 src/safari_docket.py case-number <digits> <divisionValue>` for a one-shot
read without the JSON file dance, or dispatch the Nomad job (`cook-county-docket.nomad.hcl`,
parameterized, node-pinned) from a calling `chittyagent-*` worker. Note `timeout(1)` is not on
that host's PATH (it is a GNU coreutils binary, absent from stock macOS) — wrap the ssh call
instead of the remote command. Case-number format for this portal has no dashes
(digits only, no dashes or division letter) — confirm the exact format against a case you already know
the answer for before trusting a new one.

The remaining steps below (claude-in-chrome-based) are kept as a documented fallback only, for
use if the real-Safari actor is unavailable and you want to attempt the CDP path anyway — expect
it to likely hit the same WAF block based on the pattern above.

### Step 3: Load Browser Tools (fallback path only — see Step 2)
```
ToolSearch: select:mcp__claude-in-chrome__tabs_context_mcp
ToolSearch: select:mcp__claude-in-chrome__tabs_create_mcp
ToolSearch: select:mcp__claude-in-chrome__navigate
ToolSearch: select:mcp__claude-in-chrome__read_page
ToolSearch: select:mcp__claude-in-chrome__computer
ToolSearch: select:mcp__claude-in-chrome__javascript_tool
```

### Step 4: Navigate to Case Search (fallback path only)
1. Get tab context: `mcp__claude-in-chrome__tabs_context_mcp` (createIfEmpty: true)
2. Create new tab: `mcp__claude-in-chrome__tabs_create_mcp`
3. Navigate to: `https://casesearch.cookcountyclerkofcourt.org/CivilCaseSearchAPI.aspx`

### Step 5: Search for Case (fallback path only)
The site is ASP.NET WebForms. **Do NOT use JavaScript to set form values across a postback
boundary** — they get cleared. (The real-Safari actor works around this by setting every field
and clicking submit inside a single `do JavaScript` call, which does not cross a postback.) Use
direct interaction:

1. **Select Division** per the resolved case (e.g. "Domestic Relations / Child Support" = value "4")
2. **Ensure "Search by Case Number" radio** is selected (first radio button)
3. **Click into the case number text input** (triple_click to select any existing text)
4. **Type case number**: Use `computer` type action with `<caseNumber>` from the resolved case — digits only, no dashes and no division letter
5. **Click "Start New Search"** button (type="submit")
6. **Wait 3-4 seconds** for page load

### Step 6: Read Docket Results (fallback path only)
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

(The real-Safari actor extracts the same fields more reliably via structured DOM table queries
instead of flattened accessibility-tree text — see its `TABLES_JS` — because multi-line cells,
e.g. a defendant name that wraps across lines, collapse ambiguously in flattened text but stay
unambiguous per-cell in the DOM.)

### Step 7: Parse Results (fallback path only)
Extract from the accessibility tree:
1. **Next court date** from "Future Court Activity" section
2. **All case activities** with date, event description, and comments
3. Compare against the case's master timeline CSV to identify NEW entries

### Step 7b: Capture the docket as a filed artifact

Parsing gives you entries; it does not give you something citable. Capture the rendered docket
before leaving the page, whichever path reached it:

1. Print to PDF with background graphics enabled — the clerk's status styling is meaningful and
   is lost without it.
2. Name it `CookCounty_<caseNumber>_Docket_<YYYY-MM-DD>.pdf`, dated for the day of retrieval,
   not the day of the last entry.
3. Hand it to the canonical ingestion path — `evidence-collect` for a specified case — rather
   than writing to R2, D1 or Notion from here. This skill reads a docket; it does not own
   evidence storage, and a second ingestion path is how chain of custody diverges.

### Step 8: Update Master Timeline (if `/docket update`)
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

### Step 9: Report
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

## Stop Conditions

Each of these ends the run. Report what was hit; do not work around it, and do not substitute a
different case or a cached result.

| Condition | Action |
|-----------|--------|
| CAPTCHA presented | Stop. Screenshot and report — solving it is not in scope |
| Login or paywall required | Stop. Report the auth barrier |
| Case not found | Retry the alternate number spacing once, then stop and report |
| Portal or API error | Stop. Report the status and the response body |
| Returned caption does not match the resolved case | Stop. Report the mismatch — never reconcile it silently |

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
