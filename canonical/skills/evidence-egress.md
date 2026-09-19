---
name: evidence-egress
canon_uri: chittycanon://core/services/chittymarket#skills/evidence-egress
description: "Migrate evidence/document files out of scattered local source directories (Desktop, iCloud, Downloads, external) into the canonical pipeline (R2 + Drive mirror + local working copy). Read-only audit by default — produces per-case CSV reports of {in_neon, in_drive, action_needed} before any move or delete. Case-agnostic: discovers cases from <root>/cases/* and resolves Drive remotes by convention (sd_<case_id>:). Triggers on: 'egress', 'evidence egress', 'migrate evidence', 'free up desktop', 'iCloud evidence sprawl', 'audit before move', '/evidence-egress', 'where are the duplicates'."
kind: skill
plugin: chittyos-legal
runtimes:
  - claude-code
  - codex
classification:
  - legal
  - evidence
---

# Evidence Egress — Audit Before You Move

## Principle (BINDING)

**Three-state rule.** Every evidence byte must exist in at least 2 of:

1. **Canonical** — `chittyevidence-documents/sha256/<hash>` in R2 (source of truth)
2. **Mirror** — `sd_<case_id>:` Google Drive (human-browsable, shareable)
3. **Working copy** — local case dir (or stick when chittymemory-00 exists)

**No source file is ever deleted before its canonical (1) AND one of (2/3) are verified.**

**Identity is content hash.** Never collapse documents by title, date, filename, or path — see [[feedback_version_authority]]. Two PDFs with the same name are not the same document; two PDFs with the same sha256 are.

## What This Skill Does

INDEX → CHECK → DRIVE → REPORT. Read-only.

- **INDEX**: walks `<root>/cases/<case_id>/`, sha256s every document-type file (configurable), excludes code subtrees (`node_modules/`, `bin/`, `.git/`, presence of `package.json` or `pyproject.toml` at subtree root).
- **CHECK**: batches hashes against Neon `storage.documents` (or `evidence_documents` — schema-discovered). Each file annotated `in_neon=yes|no`.
- **DRIVE**: resolves Drive remote per case using convention `sd_<case_id>:`. If remote exists, walks it once, builds a name+size index, matches local files. Each file annotated `in_drive=yes|no|no_remote`.
- **REPORT**: emits `/tmp/egress-<case_id>-<run_id>.csv` with columns: `path, sha256, size, mtime, in_neon, in_drive, action`. Plus a summary report.

`action` values:
| Value | Meaning |
|---|---|
| `safe_to_delete` | in_neon=yes AND (in_drive=yes OR working_copy_planned) |
| `ingest_then_delete` | in_neon=no — must run pipeline-submit before delete |
| `verify_drive` | in_neon=yes but in_drive=no AND no working copy planned — push to Drive first |
| `no_remote_review` | drive remote missing for this case — manual decision |
| `skip_code` | file is in code subtree, not document |
| `skip_empty` | zero-byte file |
| `skip_dotfile` | hidden file (.DS_Store, .git/*, etc.) |

INGEST, MOVE, DELETE are **separate explicit subcommands** — not run by the audit.

## Triggers

Use this skill BEFORE moving, deleting, or reorganizing any directory containing legal/evidence/case material — even if "just freeing up space." Specifically:
- "Move ~/Desktop/organized/Legal somewhere"
- "Clean up iCloud — evidence is everywhere"
- "Free up the Downloads folder"
- "Migrate cases to the stick / external drive"
- "Find dups across local + Drive + R2"

## Usage

```bash
# 1. Discover cases under a root
~/.claude/skills/evidence-egress/scripts/discover.sh ~/Desktop/organized/Legal

# 2. Audit one case (produces /tmp/egress-<case>-<run>.csv)
~/.claude/skills/evidence-egress/scripts/audit.sh \
  --root ~/Desktop/organized/Legal \
  --case arias_v_bianchi

# 3. Audit all discovered cases under a root
~/.claude/skills/evidence-egress/scripts/audit.sh \
  --root ~/Desktop/organized/Legal --all

# 4. Show summary of last run
~/.claude/skills/evidence-egress/scripts/report.sh --summary
```

## Dependencies

Verified by `discover.sh --check`:
- `sha256sum` or `shasum`
- `rclone` with case-specific remotes (`sd_<case_id>:`)
- A reachable evidence store. **Check which one before assuming** — this differs per deployment:
  - **Cloudflare D1** `chittyevidence-db` (`f486fed7-cba9-47d2-93fb-ca11d90ca084`, account `0bc21e3a5a9de1a4cc843be9c3e98121`) is the live store for `case_2024d007847` as of 2026-09-19. Query it with the Cloudflare MCP `d1_database_query` tool — `psql`/`NEON_DATABASE_URL` will not reach it.
  - `psql` + `NEON_DATABASE_URL` (brokered via ChittyConnect / ChittySecrets, `assets/neon-source.sh`) where the store is Neon.
- Optional: `chitty_evidence_search` MCP tool as a fallback read path.

**If `NEON_DATABASE_URL` is unset, `discover.sh --check` reports "Neon checks will be skipped" and the audit still runs — producing a report where every file reads `in_neon=no`.** That is a false negative across the board, not a finding. Confirm the store is actually reachable before trusting any `ingest_then_delete` count.

## Configuration

`assets/config.json`:
- `document_extensions` — list (default below)
- `code_marker_files` — files whose presence flags a subtree as code (`package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`)
- `code_marker_dirs` — `node_modules`, `.git`, `__pycache__`, `dist`, `build`, `.next`
- `drive_remote_pattern` — default `sd_<case_id>` (template)
- `neon_table` — default tries `storage.documents` then `evidence_documents`
- `neon_hash_column` — default `content_hash`

Default document extensions: `pdf eml docx doc txt csv zip jpg jpeg png heic tiff mp3 m4a caf wav xlsx xls pptx rtf html htm`

## Reverse Reconciliation — when the store has it but cannot find it

The audit above answers *"is this local file in the store?"*. The opposite failure is more common and more damaging: **the document is in the store, correctly content-addressed, and still unusable** because its metadata was never populated.

Observed on `case_2024d007847` (2026-09-19): file-stamped court orders sat in the store with real bytes at `sha256/<digest>` in R2, and:

- `file_name` = `<first 12 hex of the digest>.bin` — e.g. `d92b6e66e52c.bin`
- `case_id` = `NULL`

They were therefore invisible to every case-scoped query, while facts that depended on them pointed at zero-byte placeholders instead. 17,282 of 17,999 rows in that store carry `case_id IS NULL`.

**Recovery is a hash join, and only a hash join.** Given a human-organized mirror (a Drive tree with real filenames):

```bash
# stream the bytes — Drive exposes md5 only, so sha256 requires the content
for f in $(rclone lsf -R --files-only "sd_<drive>:<case tree>"); do
  printf '%s  %s\n' "$(rclone cat "sd_<drive>:<case tree>/$f" | sha256sum | cut -d' ' -f1)" "$f"
done
```

Then, for each digest matching a row with `case_id IS NULL`: set `case_id`, restore `file_name` from the mirror path, set `mime_type`, and write an `evidence_correction_audit_log` row citing the sha256 match as the basis.

The `.bin` name is self-verifying — it is the digest's own prefix, so a correct match is provable rather than plausible.

**Scope note.** At 1,000+ objects this is `chittystorage-sasquatch`'s job, not something to hand-run. It owns content addressing and entity-document relationships. Hand-run it only to establish the technique on a handful of files first.

## What This Skill Does NOT Do

- Does NOT move files (use `scripts/move.sh` separately after review)
- Does NOT delete files (use `scripts/cleanup.sh` separately after review)
- Does NOT push to Drive (use `pipeline-submit` skill for ingestion)
- Does NOT classify documents (that's the pipeline worker's job)
- Does NOT touch code subtrees — they're skipped, you handle them separately

## Anti-Patterns

- **Never** combine audit + move + delete in one run. Audit is read-only by design.
- **Never** delete source based on filename/path match. Hash match only.
- **Never** assume a Drive mirror is complete. Verify with `rclone size` + sample reads.
- **Never** skip the store check because "we ingested it last week." Hash is truth.
- **Never create a document row for bytes that are not yet in R2.** A row with `file_size = 0` and a `content_hash` like `sha256:pending-<something>` is a placeholder that reads as a real exhibit to every downstream consumer. Two such rows in `case_2024d007847` were cited by facts for months and were unretrievable the whole time; one underpinned a withdrawn fraud allegation. An un-ingested file is a **finding**, not a row to write.
- **Never match by size, name, or date — even "just to get a rough count."** A size-only pass over the same corpus produced a materially different picture than the hash pass, in both directions: same-size distinct files collided, and revisions of one document read as unrelated. If you report a size-based number, label it as an estimate in the same sentence.
- **Never conclude "the document does not exist" from one store.** Evidence for a single case has been found spread across four locations — the D1/R2 store, a per-case Drive remote, a `chittyos-data` VAULT tree, and a separate shared drive holding the most recent filings. Checking one and generalizing produced a confident, wrong "this cannot be sourced."

## State

Run state at `~/.claude/skills/evidence-egress/assets/state.json`. Reports at `/tmp/egress-<case>-<run>.csv`. Old reports cleaned after 30 days.

## Related

- [[evidence-collect]] — canonical ingestion pipeline (the IN side of this skill's egress)
- [[pipeline-submit]] — actual ingestion command for `ingest_then_delete` action items
- [[fact-governance]] — fact lifecycle (versioning, locking) — egress preserves all versions, never collapses
- [[machine-management]] — the broader storage lifecycle this fits into
