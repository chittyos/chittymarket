---
name: cli-surface-projection
description: |
  Runbook and CLI command projection for managing nowebmaster capabilities via chittycan (can wm & can surface).
canon_uri: chittycanon://core/services/chittymarket#skills/cli-surface-projection
---

# CLI Surface Projection — `chittycan` (`can`)

## 1. CLI Projection Overview

The **CLI Surface Projection** projects `nowebmaster` canonical atoms and lifecycle operations directly into terminal interfaces via **`chittycan`** (`can`).

---

## 2. Command Reference

### A. `can wm` Subcommands

```bash
# Harvest & atomize any URL
can wm harvest <url> [--content="<markdown>"]

# Cross-reference claim against canonical store
can wm check <source_url> "<claim_text>"

# Submit user flag & issue reward points
can wm flag <url> "<description>" --by=<user>

# Generate B2G / Enterprise contradiction priority report
can wm report [--format=markdown|json] [--out=<filepath>]
```

### B. `can surface` Subcommands

```bash
# Compile canonical atoms to provider surface molds
can surface compile <domain> --target=openai-mcp|openapi-3.1|claude-skill|cf-portal

# Hot-load assembled bundle into live gateway
can surface hotload <domain> --portal=mcp-portal.chitty.cc
```
