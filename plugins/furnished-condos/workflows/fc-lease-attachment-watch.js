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
