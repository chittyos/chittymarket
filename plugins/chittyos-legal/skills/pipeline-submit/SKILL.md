---
name: pipeline-submit
description: |
  Ingest, store, and log documents into the ChittyEvidence pipeline. Not just evidence — anything could be evidence, but all documents need proper storage and chain of custody. Triggers on: 'ingest', 'submit to pipeline', 'upload documents', 'store documents', 'pipeline submit', '/pipeline-submit', 'batch ingest', 'log documents'. Handles: local files, Downloads folder, batch submission via the canonical drop-folder watcher, and verifying what actually landed.
canon_uri: chittycanon://core/services/chittymarket#skills/pipeline-submit
---

# Pipeline Submit — Ingest, Store, Log

## Principle

**Anything could be evidence, but not everything is.** This skill stores documents properly and logs chain of custody. Classification happens downstream — the AI pipeline decides what each document actually is.

## What This Does

1. **Hand off** — Put the document in the intake drop folder; the watcher owns storage and submission
2. **Verify** — Confirm it was accepted, from the watcher's own record, not from an exit code
3. **Don't classify** — That's the pipeline's job, not ours
4. **Don't build a second path** — if the pipeline is down, fix it; don't route around it

## Quick Reference

```
/pipeline-submit                    # Interactive — asks what to ingest
/pipeline-submit ~/Downloads/*.pdf  # Specific files
/pipeline-submit --batch 2026-03-09 # All files from a date-stamped batch
/pipeline-submit --status <id>      # Check submission status
```

## Workflow

### Step 1: Identify Source Files

Check what we're working with:
```bash
# List candidate files
ls -lh /path/to/files/

# Get page counts and sizes (helps identify document types without reading them)
for f in *.pdf; do
  pages=$(pdfinfo "$f" 2>/dev/null | grep Pages | awk '{print $2}')
  size=$(stat -f%z "$f")
  echo "$f | pages=$pages | size=$size"
done
```

### Step 2: Drop the files into the intake folder — this IS the pipeline

**The canonical route is the drop folder. Do not stage to R2 and POST yourself.**

`chittyevidence-drop-watcher.service` (systemd timer, every 5 minutes, on chittyserv-vm)
owns the whole path and does all four steps for you:

```
Drive workflows_ops:INTAKE/
  -> R2 chittyevidence-documents/chittyserv-dev-watcher/<YYYY/MM/DD>/<sha8>_<name>
  -> POST https://evidence.chitty.cc/collect   (HMAC service auth)
  -> Drive workflows_ops:INTAKE/_processed/<YYYY-MM-DD>/
```

So submitting is one move:

```bash
# One file
rclone --config /etc/chitty/rclone.conf copyto "file.pdf" "workflows_ops:INTAKE/file.pdf"

# A batch
for f in /path/to/files/*.pdf; do
  rclone --config /etc/chitty/rclone.conf copyto "$f" "workflows_ops:INTAKE/$(basename "$f")"
done
```

The watcher computes sha256, size and MIME itself, builds the `/collect` payload, signs it,
and moves the source into `_processed/<date>/` only after `/collect` returns 2xx. A file still
sitting at the top level of `INTAKE/` has NOT been accepted yet.

Files are picked up at `--max-depth 1` only — do not nest them in subfolders. `*CONTROL LEDGER*`
is excluded by design.

### Step 3: Confirm it actually landed

Do not treat "the copy succeeded" as ingestion. Check the watcher's own record:

```bash
# Did this run accept anything? Look for processed=N, not just absence of errors.
journalctl -u chittyevidence-drop-watcher.service -n 50 --no-pager | grep -E "done:|! "

# Accepted submissions, newest last: <timestamp>|<submission_id>|<filename>|<r2 key>
tail -5 /var/lib/chittyevidence-watcher/pending.tsv

# The file should have moved out of the top level
rclone --config /etc/chitty/rclone.conf lsf --max-depth 1 --files-only workflows_ops:INTAKE/
```

`done: processed=0 failed=N total=N` means the pipeline is DOWN, not that there was nothing to do.
Failures also fire `chittyevidence-alert.service` (ntfy), so a silent journal is not reassurance.

### Step 4: The `/collect` contract — reference only, do not hand-roll

Recorded here so the contract is known, not so you reproduce it. If the watcher is broken, FIX
THE WATCHER; building a second path around it is how the same document ends up in six places.

```
POST https://evidence.chitty.cc/collect
  X-Service-ID: <from /etc/chitty/evidence-service-id>
  X-Timestamp: <RFC3339 with milliseconds>
  X-Service-Signature: HMAC-SHA256("<service-id>:<timestamp>", <service-secret>) hex
  Content-Type: application/json

  {"source":"gdrive_sync","source_ref":"r2://chittyevidence-documents/<key>",
   "source_hash":"<sha256>","file_name":"...","file_size":N,"mime_type":"...",
   "hints":{"tags":[...]}}
```

Auth is **HMAC service auth, not Bearer.** `Authorization: Bearer <token>` does not work on this
endpoint and never did. Both `/etc/chitty/evidence-service-id` and the secret file are root-only —
if you need them, you are on the wrong path. Route credential work through `/chico`.

Response carries `submission_id` and `status`; poll `GET /collect/status/{submission_id}`.

## Search Cache First

Before searching R2 or running rclone queries, **check project memory first**:
- `memory/search-cache.md` — entity index, document type index, R2 bucket inventory, relationship graph
- If the entity or document type is already indexed, use cached results instead of re-querying
- After any NEW search, **update search-cache.md** with results (entities found, document counts, relationships discovered)
- This is cumulative — each session builds on prior knowledge

## What NOT To Do

1. **Don't read PDFs** to classify them — store first, let the pipeline OCR + classify
2. **Don't assign case_id** — use hints.entity_names if you know them, otherwise leave blank
3. **Don't stage to R2 yourself and POST /collect by hand** — that is a second path around the
   watcher and it is how one document ends up in six places. If the watcher is down, say so and fix
   it; leave the files in `INTAKE/` so they are picked up when it recovers. The drop folder is the floor.
4. **Don't assume document type from filename** — "Regular Mail" could be a Lowe's statement, insurance dec, or court filing. Filenames lie.
5. **Don't create duplicate copies** — check search-cache.md first, then R2:
   `rclone --config /etc/chitty/rclone.conf ls r2:chittyevidence-documents --include "*keyword*"`
6. **Don't search R2 without updating the cache** — if you do a new search, log the results to search-cache.md
7. **Don't report success from an exit code** — ingestion is proven by a new row in
   `/var/lib/chittyevidence-watcher/pending.tsv` and the file leaving the top level of `INTAKE/`.
   A successful `rclone copyto` proves only that the file reached Drive.
8. **Don't read an empty result as an empty world** — `0 files`, `0 rows`, `clean` can all mean a
   failed read, a dead credential, or a permission denial. Establish which before reporting it.

## Source Hints Reference

When you know something about the source, provide hints:

| Source | `source_hint` | `tags` |
|--------|--------------|--------|
| IL registered agent forwarded mail | `registered-agent-mail` | `il-registered-agent` |
| Google Drive case folder | `gdrive` | `gdrive-sync` |
| Email attachment | `email-attachment` | `email`, sender info |
| Court filing download | `court-download` | `court-filing`, case number |
| Bank/financial download | `financial-download` | `financial` |
| Scanned physical document | `physical-scan` | `scan`, location |
| Unknown / mixed batch | `unknown` | `needs-classification` |

## Integration with Other Skills

- After pipeline processes docs → `/fact-governance` registers extracted facts
- If a doc turns out to be a dispute → `/dispute` creates the dispute record
- If it's a court filing → `/docket` can update the case timeline
- Pipeline status → `GET /collect/stats` or `GET /collect/status/:id`
