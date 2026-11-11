# Chrome DevTools auto-connect: ChittyOS policy

Status: proposed standing policy, 2026-11-06. Owner: ChittyMarket maintainers. Review by 2027-02-06.
Scope: any agent runtime on any ChittyOS host that would attach `chrome-devtools-mcp` to a
running Chrome with `--autoConnect`. Nothing here enables it. It records the conditions
under which it may be enabled and the work that must never run against it.

Sources:
- Chrome DevTools, "Auto-connect" (https://developer.chrome.com/docs/devtools/agents/use-cases/auto-connect), read 2026-11-06.
- WebMCP explainer (https://googlechromelabs.github.io/webmcp-tools/demos/explainer/), read 2026-11-06.
- `canonical/skills/docket.md`, Step 2 ("WAF blocker").

## What the vendor documents

- Auto-connect is `--autoConnect` on the `chrome-devtools-mcp@latest` server args, plus
  enabling remote debugging at `chrome://inspect/#remote-debugging`, plus clicking **Allow**
  on Chrome's per-session permission prompt. Requires Chrome 144 or later.
- Reach: open tabs, cookies, and data exposed to JavaScript such as session and local
  storage. Vendor wording: "When auto-connect is active, your agent has access to all data
  in your browser profile." and "Use this mode only with agents you trust".
- Telemetry: usage statistics and performance-trace URLs go to Google by default,
  regardless of connection mode. `--no-usage-statistics` stops the statistics.
  `--no-performance-crux` stops trace URLs going to the CrUX API.
- The vendor page does not discuss `--user-data-dir` or profile selection.

## Policy

1. **Use a dedicated, empty-by-default Chrome profile.** Never attach to the operator's
   everyday profile. That profile holds signed-in sessions for mail, banking, court and
   registry portals, and whatever cookie jar the vendor warning refers to. This is a
   ChittyOS requirement derived from the vendor warning. The vendor does not document it,
   and attaching to a non-default profile has not been tested here.
2. **Set both opt-out flags** in the server args whenever auto-connect is enabled:
   `--no-usage-statistics` and `--no-performance-crux`. Check the effective args before the
   first session. The defaults send data to Google.
3. **Never run the following against an auto-connected browser**, because one attach exposes
   every tab and cookie across every matter or account in the profile:
   - evidence and legal skills: `docket`, `evidence-collect`, `evidence-egress`,
     `fact-governance`, `dispute`, `9-step-legal-audit`, `pipeline-submit`
     (`legal-operating-defaults`: matter isolation, privilege boundaries, provenance);
   - financial portals and any session that can write to a financial datastore
     (`finance-operating-defaults`: production writes are operator-gated).
4. **Definition lives in the backend, not local config.** Do not add `--autoConnect` to a
   local `.mcp.json` or plugin file. If adopted, register the server and its args through
   ch1tty `servers.json` so the flags in item 2 are set once. Whether `chrome-devtools-mcp`
   is registered in ch1tty today has not been verified.
5. **Per session, not standing.** Remote debugging stays off in Chrome between uses.

## `docket` is not helped by this

`docket` Step 2 records that the Cook County Clerk WAF rejects CDP-driven and headless
automation regardless of origin IP, and that only a real Safari GUI session
(`chittymini-01`) was verified working. Auto-connect still uses the DevTools Protocol, so it
is expected to hit the same class of block. That expectation is untested; the skill itself
says the Chrome path "has not been directly tested against this specific portal". Treat
docket scraping as brittle: portal markup and WAF behaviour change without notice, and a
silent partial read is the failure to guard against. Item 3 already excludes docket from
auto-connect, so this note does not change the current preferred method.

## WebMCP: watch-list, build nothing

WebMCP is a web-platform proposal in which a page declares tools
(`document.modelContext.registerTool({...})`, or `<form>` attributes `toolname`,
`tooldescription`, `toolautosubmit`) so agents call them instead of scraping. The explainer
calls it "under active discussion and subject to change". Discovery currently needs an
extension, and the page does not say whether a flag or origin trial is required.

Decision: no ChittyOS work now. Revisit when native browser support ships or when a portal
we depend on publishes WebMCP tools. If a portal does, that is the sanctioned replacement
for scraping it, and its tools register through ch1tty like any other capability, subject
to the same sensitive-intent routing.
