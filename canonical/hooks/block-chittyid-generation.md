---
name: block-chittyid-generation
kind: hook
canonical_capability_ref: chittycanon://capability/govern/block-chittyid-generation
plugin: chittyos-governance
runtimes: [claude-code]
description: |
  Refuse any write that generates a ChittyID locally. Canon states the rule four
  times and nothing enforced it: the declarative hookify rule of this name was
  never written, and the nine rules that were written are unreachable by
  hookify's cwd-relative loader. Implemented as a native PreToolUse command hook
  so it loads for every session regardless of working directory.
hook:
  event: PreToolUse
  matcher: "Write|Edit|MultiEdit|NotebookEdit"
  entries:
    - type: command
      command: python3 "${CLAUDE_PLUGIN_ROOT}/hooks/block_chittyid_generation.py"
      timeout: 10
---

# block-chittyid-generation

## The rule

ChittyIDs are minted by the Foundation service and never constructed by a
caller. Canon says so four times:

| source | text |
|---|---|
| `chittyid/CHARTER.md:23` | "All other services MUST request ChittyIDs from this Foundation service—no local generation is permitted." |
| `chittyid/CHARTER.md:119` | "**STRICT NO LOCAL GENERATION**: ChittyIDs are NEVER generated locally" |
| `chittyid/CLAUDE.md:146` | "…under ANY circumstances" |
| `chittyid/HYBRID_SYSTEM.md:105` | "Server-only generation - NO local fallbacks allowed" |

## Why this exists as a native hook rather than a hookify rule

`chittyos-governance` declared ten hookify rules in `hooks/hooks.json` and
shipped none of them. Nine existed only as hand-maintained files in
`~/.claude/hooks/` on one host; this one existed nowhere.

Measured 2026-11-12: hookify 0.1.1 `core/config_loader.py:210-211` runs

```python
pattern = os.path.join('.claude', 'hookify.*.local.md')
files = glob.glob(pattern)
```

a **relative, non-recursive** glob against the hook process's working
directory. Running hookify's own `load_rules()` from the chittyfinance repo,
from `$HOME`, and from `~/.claude` returned `rules loaded: 0` every time. So a
cwd-relative loader cannot host host-global governance: rules would have to be
copied into every repository's `.claude/`, which guarantees drift.

A native command hook in a plugin's `hooks.json` loads for every session
regardless of cwd, and `plugins/chittyagent-dispatch/scripts/adapters/claude-code-hook.sh`
already projects exactly this shape.

## What it catches

Each pattern is drawn from a site found in the 2026-11-11 fleet sweep:

- a mod-97 checksum computed locally, with or without BigInt — `98n - (x % 97n)` and `98 - (x % 97)`
- eight segments assembled by template or f-string
- six or more segments joined from an array (5+ commas, so ordinary joins pass)
- an entity-type segment reassigned and the ID re-joined — the forgery in `chittycan hook-handlers.ts:588`, which rewrote segment 4 and recomputed the checksum on every SessionStart
- a local generator being defined: `generate|mint|create|make|new|build` + `(Local)?ChittyId`

## What it deliberately allows

- **Validators.** A mod-97 result that is *compared* (`===`, `assert`, `expect`, `isValid`) reads an ID; it does not issue one.
- **The minting services** themselves, by path: `chittyfoundation/chittyid/`, `chittymint/`.
- **Tests, fixtures and documentation** — a hardcoded sample ID is not a generator.
- Ordinary dash joins such as `[org, repo].join("-")`.

A guard that blocks legitimate writes gets switched off, and a switched-off
guard is the failure this hook exists to end. The allow cases are tested as
hard as the block cases.

## Failure mode

Fails **open** on malformed input or an internal error — a broken guard must not
wedge every write — but prints the reason to stderr. It never fails silently.

## Mutation test

`hooks/test_block_chittyid_generation.py` runs the guard as a subprocess over 18
cases, 9 block and 9 allow, each block case a real string from the sweep. Both
of the guard's original regexes were wrong and the tests caught them: the
segment-rewrite pattern used `[^;]` as its gap when `;` is exactly what
separates those statements, and the array-join pattern matched any dash-joined
array. Run it on every change:

```
python3 plugins/chittyos-governance/hooks/test_block_chittyid_generation.py
```

## Related

- `chittyos/chittycan#231` — removed the forgery this hook now blocks
- `chittyfoundation/chittyid#36` — the mint's own breaker and its three defects
- `@canon: chittycanon://gov/governance#core-types` — entity types are P/L/T/E/A
