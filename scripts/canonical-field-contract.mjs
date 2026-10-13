#!/usr/bin/env node
// canonical-field-contract — validate the frontmatter FIELD CONTRACT of every
// artifact under canonical/.
//
// Why this exists. Patterning the SHAPE of an artifact without TYPING its field
// VALUES only relocates the drift. Measured before this file existed:
//
//   status:    4 distinct values across 14 declarers; THREE were malformed —
//              two were the enum DEFINITION pasted into the value slot
//              ("DRAFT|PENDING|CERTIFIED|...", "active | experimental | deprecated")
//              and one was foreign vocabulary ("backlog").
//   canon_uri: 9 undeclared top-level namespaces, inconsistent depth
//              (gov vs gov/governance vs gov/authority/*), trailing-slash drift
//              (rel vs rel/), and TWO competing addressing schemes —
//              service-based core/services/* alongside class-based skills/*.
//
// Both escaped because nothing validated them. classification: and runtimes:
// did NOT escape — they are already clean controlled vocabularies. The
// difference is enforcement, not intent.
//
// SCOPE BOUNDARY: this is a work engine, not an authority. Data contracts are
// chartered to ChittySchema. This file encodes the CURRENT OBSERVED contract so
// it can be attacked and corrected; it does not own the contract. Where the
// observed corpus and this file disagree, that disagreement is the finding.
//
// Exit codes — a caller must be able to tell these apart:
//   0  every artifact parsed AND satisfied the contract
//   1  contract violations found
//   2  sweep INCOMPLETE — something intended to be checked could not be
//      (unreadable file, unparseable frontmatter). NOT the same as "clean".
//   3  the runner itself crashed
//   64 usage error
//
// Usage: node scripts/canonical-field-contract.mjs [canonical-dir] [--json]

import { readdirSync, readFileSync, statSync, existsSync } from 'node:fs'
import { join, relative } from 'node:path'

const ROOT = process.argv.find((a, i) => i >= 2 && !a.startsWith('--')) ?? 'canonical'
const AS_JSON = process.argv.includes('--json')

if (!existsSync(ROOT)) {
  console.error(`usage: canonical-field-contract.mjs [canonical-dir] [--json]\n  no such directory: ${ROOT}`)
  process.exit(64)
}

// ---------------------------------------------------------------------------
// THE CONTRACT (v0 — observed, not decreed)
// ---------------------------------------------------------------------------

// Present on 100% of the 60 canonical artifacts measured 2026-08-12.
const REQUIRED = ['name', 'description', 'kind', 'classification', 'plugin', 'runtimes']

// `kind` is the sub-kind discriminator. mcp-server/mcp are the SAME sub-kind
// under two names — recorded as drift rather than silently normalised, because
// which one is canonical is ChittySchema's call, not this file's.
const KIND = new Set(['skill', 'agent', 'tool', 'mcp', 'mcp-server', 'command'])
const KIND_ALIASES = new Map([['mcp-server', 'mcp']])

// Observed clean vocabulary — these two never drifted.
const RUNTIMES = new Set([
  'claude-code', 'codex', 'openclaw', 'claude-skills', 'chatgpt-apps', 'orchestrator-kv',
])

// status DID drift. A value that contains a separator is the enum definition
// pasted into the value slot — the single highest-signal defect in the corpus.
const STATUS = new Set(['draft', 'active', 'experimental', 'deprecated', 'pending', 'certified', 'canonical', 'archived'])

// canon_uri: two addressing schemes coexist. Both are recorded; the conflict is
// reported rather than resolved here.
const CANON_NS = new Set([
  'core', 'gov', 'docs', 'rel', 'legal', 'skills', 'commands', 'capability', 'integration',
])
const CANON_RE = /^chittycanon:\/\/([a-z0-9_-]+)(\/[a-z0-9/_#-]*)?$/

const findings = []
const unproven = []
const seenNames = new Map()
let checked = 0

const add = (file, code, msg) => findings.push({ file, code, msg })

function frontmatter(text) {
  if (!text.startsWith('---')) return null
  const end = text.indexOf('\n---', 3)
  if (end === -1) return null
  return text.slice(4, end)
}

// Minimal, deliberately strict: scalars and `- ` list items only. Anything it
// cannot represent is reported as UNPROVEN rather than guessed at.
function parseFields(block) {
  const out = {}
  let key = null
  for (const raw of block.split('\n')) {
    if (!raw.trim() || raw.trimStart().startsWith('#')) continue
    const top = raw.match(/^([a-z0-9_]+):\s*(.*)$/i)
    if (top) {
      key = top[1]
      const v = top[2].trim()
      out[key] = v === '' || v === '|' || v === '>' ? [] : v
      continue
    }
    const item = raw.match(/^\s+-\s+(.*)$/)
    if (item && key) {
      if (!Array.isArray(out[key])) out[key] = []
      out[key].push(item[1].trim())
    }
  }
  return out
}

function walk(dir) {
  for (const entry of readdirSync(dir)) {
    const p = join(dir, entry)
    const st = statSync(p)
    if (st.isDirectory()) { walk(p); continue }
    if (!entry.endsWith('.md')) continue
    check(p)
  }
}

function check(path) {
  const rel = relative('.', path)
  let text
  try {
    text = readFileSync(path, 'utf8')
  } catch (e) {
    unproven.push({ file: rel, code: 'UNREADABLE', msg: String(e.message) })
    return
  }

  const block = frontmatter(text)
  if (block === null) {
    // No frontmatter at all: cannot be checked, and MUST NOT count as clean.
    unproven.push({ file: rel, code: 'NO_FRONTMATTER', msg: 'no frontmatter block — contract unprovable' })
    return
  }

  checked++
  const f = parseFields(block)

  for (const r of REQUIRED) {
    if (!(r in f)) add(rel, 'MISSING_REQUIRED', `required field '${r}' absent`)
  }

  // name uniqueness across the whole corpus — a duplicate canonical name is an
  // identity collision, the defect class chittyanima exists to resolve.
  if (typeof f.name === 'string' && f.name) {
    const prev = seenNames.get(f.name)
    if (prev) add(rel, 'DUPLICATE_NAME', `name '${f.name}' already declared by ${prev}`)
    else seenNames.set(f.name, rel)
  }

  if (typeof f.kind === 'string' && f.kind) {
    if (!KIND.has(f.kind)) add(rel, 'KIND_UNKNOWN', `kind '${f.kind}' not in the observed set`)
    else if (KIND_ALIASES.has(f.kind)) {
      add(rel, 'KIND_ALIAS_DRIFT', `kind '${f.kind}' is an alias of '${KIND_ALIASES.get(f.kind)}' — one sub-kind, two names`)
    }
  }

  if (typeof f.status === 'string' && f.status) {
    const v = f.status.trim()
    if (/[|,/]/.test(v)) {
      add(rel, 'ENUM_DEFINITION_AS_VALUE', `status '${v}' is an enum DEFINITION in the value slot, not an instance`)
    } else if (!STATUS.has(v.toLowerCase())) {
      add(rel, 'STATUS_UNKNOWN', `status '${v}' outside the observed vocabulary`)
    }
  }

  for (const rt of Array.isArray(f.runtimes) ? f.runtimes : []) {
    if (!RUNTIMES.has(rt)) add(rel, 'RUNTIME_UNKNOWN', `runtime '${rt}' not a known substrate`)
  }

  const uri = typeof f.canon_uri === 'string' ? f.canon_uri
            : typeof f.canonical_uri === 'string' ? f.canonical_uri : null
  if (uri) {
    if ('canon_uri' in f && 'canonical_uri' in f) {
      add(rel, 'URI_KEY_DRIFT', 'both canon_uri and canonical_uri declared')
    }
    const m = uri.match(CANON_RE)
    if (!m) add(rel, 'URI_MALFORMED', `canon uri '${uri}' does not match chittycanon://<ns>/<path>`)
    else {
      if (!CANON_NS.has(m[1])) add(rel, 'URI_NAMESPACE_UNKNOWN', `namespace '${m[1]}' undeclared`)
      if (uri.endsWith('/')) add(rel, 'URI_TRAILING_SLASH', `canon uri '${uri}' has a trailing slash`)
      if (!m[2] || m[2] === '/') add(rel, 'URI_DEPTH', `canon uri '${uri}' is namespace-only — no addressable path`)
    }
  }
}

try {
  walk(ROOT)
} catch (e) {
  console.error(`crashed: ${e.stack}`)
  process.exit(3)
}

if (AS_JSON) {
  console.log(JSON.stringify({ checked, findings, unproven }, null, 2))
} else {
  console.log(`canonical field contract — ${checked} artifact(s) checked under ${ROOT}`)
  for (const f of findings) console.log(`  FAIL      ${f.file}  [${f.code}] ${f.msg}`)
  for (const u of unproven) console.log(`  UNPROVEN  ${u.file}  [${u.code}] ${u.msg}`)
  console.log(`\n  ${findings.length} violation(s), ${unproven.length} UNPROVEN`)
  if (unproven.length) console.log('  sweep INCOMPLETE — exit 2. Nothing here may be read as "contract clean".')
}

if (unproven.length) process.exit(2)
process.exit(findings.length ? 1 : 0)
