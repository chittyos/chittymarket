---
name: chitty-pipelines
canon_uri: chittycanon://core/services/chittymarket#skills/chitty-pipelines
description: Inspect and operate ChittyOS data pipelines — Mercury sync, Notion mirrors, Drive ingestion, evidence ingress. Status, retry, drain failed jobs.
kind: skill
plugin: chittyos-devops
runtimes:
  - claude-code
  - codex
classification:
  - operations
  - deployment
---

# ChittyOS Pipelines Skill

## Overview
Manage Cloudflare Pipelines for ChittyOS services. Pipelines consist of three components:
- **Stream**: Data ingestion endpoint (HTTP or Worker binding)
- **Sink**: Data output destination (R2 bucket)
- **Pipeline**: SQL transformation connecting stream to sink

## Usage
```
/pipelines [action] [name]
```

## Actions

| Action | Description |
|--------|-------------|
| `list` | List all pipelines, streams, and sinks |
| `create <name>` | Create a new pipeline with all components |
| `delete <name>` | Delete pipeline and associated resources |
| `recreate <name>` | Delete and recreate a pipeline |

## Non-Interactive Pipeline Creation

### Step 1: Create Stream
```bash
wrangler pipelines streams create <name>_stream --http-enabled --http-auth
```

Options:
- `--http-enabled` - Enable HTTP ingestion endpoint
- `--http-auth` - Require authentication (recommended)
- `--schema-file <path>` - JSON schema for structured data

### Step 2: Create Sink
```bash
wrangler pipelines sinks create <name>_sink \
  --type r2 \
  --bucket <bucket-name> \
  --format json \
  --path "<prefix>/"
```

Options:
- `--type r2` - R2 bucket sink (required)
- `--bucket` - Target R2 bucket name (required)
- `--format json|parquet` - Output format (default: parquet)
- `--path` - Prefix path in bucket
- `--compression` - For parquet: snappy, gzip, zstd, lz4
- `--roll-interval` - File rotation interval in seconds (default: 300)

### Step 3: Create Pipeline
```bash
wrangler pipelines create <name> \
  --sql "INSERT INTO <name>_sink SELECT * FROM <name>_stream"
```

The SQL must include `INSERT INTO <sink>` - plain SELECT will fail.

## Delete Pipeline Resources

Delete requires the resource ID (32-char hex), not the name:

```bash
# List to get IDs
wrangler pipelines list
wrangler pipelines streams list
wrangler pipelines sinks list

# Delete by ID with --force to skip confirmation
wrangler pipelines delete <pipeline-id> --force
wrangler pipelines streams delete <stream-id> --force
wrangler pipelines sinks delete <sink-id> --force
```

## wrangler.toml Configuration

After creating a pipeline, add to wrangler.toml using the **Stream ID** (not Pipeline ID):

```toml
[[pipelines]]
pipeline = "<stream-id>"  # 32-char hex from streams list
binding = "MY_PIPELINE"
```

Worker usage:
```typescript
await env.MY_PIPELINE.send([{
  value: { example: "json_value" }
}]);
```

## CLI Command

The `chitty pipelines` CLI provides an interactive wrapper:

```bash
# Interactive menu
chitty pipelines

# List all resources
chitty pipelines --list

# Create pipeline
chitty pipelines --create --name myservice --bucket mybucket

# Delete pipeline
chitty pipelines --delete --name myservice --force
```

## Common Patterns

### EDRM Evidence Pipelines
For legal evidence processing, use EDRM-aligned naming:

```bash
# Collection stage - gathering documents
wrangler pipelines streams create chittyevidence_collection_stream --http-enabled --http-auth
wrangler pipelines sinks create chittyevidence_collection_sink --type r2 --bucket chittyevidence-pipeline --format json --path "collection/"
wrangler pipelines create chittyevidence_collection --sql "INSERT INTO chittyevidence_collection_sink SELECT * FROM chittyevidence_collection_stream"

# Preservation stage - securing with chain of custody
wrangler pipelines streams create chittyevidence_preservation_stream --http-enabled --http-auth
wrangler pipelines sinks create chittyevidence_preservation_sink --type r2 --bucket chittyevidence-pipeline --format json --path "preservation/"
wrangler pipelines create chittyevidence_preservation --sql "INSERT INTO chittyevidence_preservation_sink SELECT * FROM chittyevidence_preservation_stream"
```

## Troubleshooting

### "String must contain exactly 32 characters"
Use the pipeline/stream/sink ID, not the name:
```bash
# Wrong
wrangler pipelines delete my-pipeline

# Right
wrangler pipelines delete 0b08219189274957ad21bc1e8d5891a4
```

### "all queries must be written into a sink"
SQL must use INSERT INTO:
```bash
# Wrong
--sql "SELECT * FROM mystream"

# Right
--sql "INSERT INTO mysink SELECT * FROM mystream"
```

### 504 Gateway Timeout
Retry after a few seconds - Cloudflare Pipelines API can be slow:
```bash
sleep 3 && wrangler pipelines create ...
```

### Internal Server Error on sink creation
Wait a few seconds between creating multiple sinks to the same bucket.
