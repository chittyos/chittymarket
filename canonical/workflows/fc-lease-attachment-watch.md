---
name: fc-lease-attachment-watch
kind: workflow
description: |
  Background loop for fc-lease-compile: weekly re-fetch and hash of every statutory lease attachment and
  watch page in the Illinois / Chicago registry (IDHR Safe Homes summary, Chicago RLTO summary,
  deposit-interest rider, CDPH bed-bug brochure, EPA lead pamphlet + lessor form, IEMA radon guide + form,
  Ch. 5-12 and 765 ILCS 705 sections, Domu model lease). Drift → Linear issue with the updated registry
  attached; fetch failures → warning. Read-only toward the repo; the operator ratifies by PR.
canon_uri: chittycanon://core/services/chittymarket#workflows/fc-lease-attachment-watch
canonical_capability_ref: chittycanon://capability/workspace/fc-lease-attachment-watch
plugin: furnished-condos
runtimes:
  - claude-code
classification:
  - leasing
  - compliance
  - watcher
  - furnished-condos
overlay:
  title: FC lease attachment watcher (weekly drift loop)
  capability_group: workspace
  group_assignment_source: override
  execution_class: "@chitty/ambient"
  canonical_version: 1.0.0
  projection_version_policy: inherit-canonical
  ontology:
    primary:
      - E
    secondary:
      - T
  authority:
    requires_chittyid: true
  execution:
    default_surface: local
    local_allowed: true
    context_cost: low
    mutation_risk: low
  discovery:
    indexable: true
    session_index: hidden
    ambient_by_intent: false
    verbs:
      - watch
      - drift
      - attachments
      - rlto
    fallback_search: true
  auth_flow:
    mode: local-only
    stores_credentials_in: n/a
    fail_closed_if_unavailable: true
  runtime_exclusions: {}
  phase0_audit:
    job_to_be_done: watch
    environmental_footprint: write-capable
    evidentiary_risk: low
    advisory_disposition: local-only
  legacy_category: workspace
  deprecated_aliases: []
  visibility: advanced
  access: read
  compatible_channels:
    - claude_code
  source_links:
    - https://github.com/furnished-condos/ChittyPro-Compile/blob/feat/il-chicago-lease-attachment-registry/scripts/check_attachments.py
    - local://plugins/furnished-condos/workflows/fc-lease-attachment-watch.js
---

# FC lease attachment watcher

Runs the deterministic checker in `furnished-condos/ChittyPro-Compile` and turns its exit code into the
right side effect. The cloud scheduled task "FC lease attachment watcher" (Mondays 08:50 America/Chicago)
is the current trigger; this workflow is the canonical definition of what a run does, so any runtime
(scheduled task, CI cron, operator `/fc-lease-attachment-watch`) behaves the same way.

| Checker exit | Meaning | Action |
|---|---|---|
| 0 | no drift | log "no drift" to the run record; nothing else |
| 2 | drift (sha256 / page count / watch-page fingerprint changed) | `--update` into a scratch copy, attach the diff + updated registry to a Linear issue (team IT CAN BE LLC, label `lease-attachments`), never commit to the repo |
| 3 | fetch failures only | warning in the run record; retry next week; escalate after 2 consecutive failures of the same source |

Annual certainties the loop expects: deposit-interest rider (January), Domu model lease (Jan/Feb), IDHR summary
revisions (`V.YYYY-MM.N`). Invoke as `Workflow({name: "furnished-condos:fc-lease-attachment-watch", args: {repo, scratch, dryRun}})`.
Projected script (verbatim):

````js
export const meta = {
  name: 'fc-lease-attachment-watch',
  description: 'Weekly drift loop for the Illinois / Chicago lease-attachment registry: re-fetch + hash every statutory source and watch page, file drift as a Linear issue, never write to the repo',
  whenToUse: 'On the weekly schedule, or on demand before any fc-lease-compile run when the registry has not been checked in the last 7 days. Pass dryRun: true to validate args without dispatching.',
  phases: [
    { title: 'Check', detail: 'runner executes scripts/check_attachments.py --json and returns exit code + per-source status' },
    { title: 'File', detail: 'on drift (exit 2) a worker files the Linear issue with the diff and the updated registry attached' },
  ],
}

// ── args ───────────────────────────────────────────────────────────────────────────────────────
//   repo:    absolute path of the ChittyPro-Compile checkout (contains scripts/check_attachments.py)
//   scratch: writable directory for the JSON report (default: <repo>/.scratch)
//   team:    Linear team name for drift issues (default: "IT CAN BE LLC")
//   dryRun:  validate + return the resolved config; dispatch nothing
const a = typeof args === 'string' ? JSON.parse(args) : (args || {})
const repo = typeof a.repo === 'string' && a.repo.startsWith('/') ? a.repo : null
if (!repo) return { started: false, reason: 'args.repo must be an absolute path to the ChittyPro-Compile checkout', next: 'Workflow({name:"furnished-condos:fc-lease-attachment-watch", args:{repo:"/path/to/ChittyPro-Compile"}})' }
const scratch = typeof a.scratch === 'string' ? a.scratch : `${repo}/.scratch`
const team = typeof a.team === 'string' ? a.team : 'IT CAN BE LLC'
const report = `${scratch}/attachment-drift.json`
if (a.dryRun) return { started: false, dryRun: true, config: { repo, scratch, team, report } }

const CHECK_SCHEMA = {
  type: 'object',
  required: ['exit', 'drift', 'fetch_errors', 'summary'],
  properties: {
    exit: { type: 'integer', description: '0 no drift · 2 drift · 3 fetch failures only · other = checker error' },
    drift: { type: 'array', items: { type: 'object', required: ['id', 'detail'], properties: { id: { type: 'string' }, detail: { type: 'string' } } } },
    fetch_errors: { type: 'array', items: { type: 'object', required: ['id', 'detail'], properties: { id: { type: 'string' }, detail: { type: 'string' } } } },
    summary: { type: 'string', description: 'the checker\'s markdown table, verbatim' },
  },
}

phase('Check')
const check = await agent(
  `Run exactly this command in ${repo} and report its result; do not edit any file and do not run anything else:\n` +
  `  mkdir -p ${scratch} && python3 scripts/check_attachments.py --json ${report}\n` +
  `Return the process exit code as "exit", the markdown table it printed as "summary", and from ${report} the entries ` +
  `whose status is "drift" or "changed" (as drift[]) and "fetch_error" (as fetch_errors[]). If the command cannot run, exit = -1 and summary = the error.`,
  { label: 'check-attachments', phase: 'Check', schema: CHECK_SCHEMA, model: 'haiku' },
)

const result = { started: true, exit: check.exit, drift: check.drift, fetch_errors: check.fetch_errors, report, summary: check.summary }
if (check.exit === 0) { log('no drift'); result.status = 'ok'; return result }
if (check.exit === 3) { log(`fetch errors only: ${check.fetch_errors.map(e => e.id).join(', ')}`); result.status = 'fetch-errors'; return result }
if (check.exit !== 2) { result.status = 'error'; return result }

phase('File')
const today = new Date().toISOString().slice(0, 10)
const filed = await agent(
  `A statutory lease-attachment source changed. File ONE Linear issue (team "${team}", label "lease-attachments") titled ` +
  `"Lease attachment drift — ${today}" whose body is this checker table followed by the drift list, and attach the file ${report}. ` +
  `Body must end with: "Operator ratifies by PR: read the new document, confirm the version string, run ` +
  `check_attachments.py --update, commit. Do not assemble a package until the registry is updated." ` +
  `Do not modify the repository. Return the issue identifier and URL.\n\n${check.summary}\n\nDrift:\n` +
  check.drift.map(d => `- ${d.id}: ${d.detail}`).join('\n'),
  { label: 'file-linear-issue', phase: 'File', model: 'sonnet',
    schema: { type: 'object', required: ['issue', 'url'], properties: { issue: { type: 'string' }, url: { type: 'string' } } } },
)
result.status = 'drift'; result.linear = filed
return result
````
