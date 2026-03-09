# Remote Marketplace Spec — market.chitty.cc

A Cloudflare Worker that serves the ChittyMarket plugin catalog remotely, enabling multi-machine and cross-platform installation.

## Endpoints

### `GET /api/plugins`
List all available plugins.

```json
{
  "version": "2.0.0",
  "plugins": [
    {
      "name": "chittyos-core",
      "description": "...",
      "version": "1.0.0",
      "category": "ecosystem",
      "keywords": ["chittyos", "session", "context"],
      "requires": [],
      "source_type": "inline",
      "install_url": "https://github.com/CHITTYOS/chittymarket"
    }
  ],
  "total": 12,
  "profiles": ["minimal", "coding", "devops", "legal", "integrations", "full"]
}
```

### `GET /api/plugins/:name`
Get a specific plugin's metadata.

### `GET /api/profiles`
List all available profiles with their plugin sets.

### `GET /api/profiles/:name`
Get a specific profile's plugin configuration.

### `GET /api/manifest`
Return the full `.claude-plugin/marketplace.json` for direct consumption by Claude Code's plugin system.

### `GET /health`
Standard ChittyOS health check.

```json
{"status": "ok", "service": "chittymarket", "plugins": 12, "version": "2.0.0"}
```

## Architecture

```
market.chitty.cc
├── Worker (Hono)
│   ├── GET /api/plugins          — Plugin catalog
│   ├── GET /api/plugins/:name    — Single plugin details
│   ├── GET /api/profiles         — Profile catalog
│   ├── GET /api/profiles/:name   — Single profile
│   ├── GET /api/manifest         — Native Claude Code manifest
│   └── GET /health               — Health check
├── KV Namespace: MARKET_CATALOG
│   ├── manifest        — .claude-plugin/marketplace.json
│   ├── profiles        — profiles.json
│   └── telemetry:agg   — Aggregated anonymous usage stats (opt-in)
└── R2 Bucket: market-assets (future)
    └── Plugin tarballs for offline install
```

## Data Flow

1. **GitHub Action** on push to `main` in `CHITTYOS/chittymarket`:
   - Runs `generate-marketplace.sh`
   - Runs `test-plugins.sh` + `lint-plugins.sh`
   - Uploads `marketplace.json`, `profiles.json` to KV
2. **Worker** serves KV contents with caching headers
3. **Client** (`bootstrap.sh` or Claude Code) fetches from `market.chitty.cc`

## Client Integration

### bootstrap.sh remote mode
```bash
# Fetch latest manifest from remote
curl -s https://market.chitty.cc/api/manifest > /tmp/marketplace.json

# Or install with profile
curl -s "https://market.chitty.cc/api/profiles/devops" | \
  python3 -c "import json,sys; print('\n'.join(json.load(sys.stdin)['plugins']))" | \
  xargs -I{} echo "Installing: {}"
```

### Claude Code native
```bash
# Add as plugin source (future — when Claude Code supports remote marketplaces)
claude plugin add https://market.chitty.cc/api/manifest
```

## Deployment

```bash
# wrangler.toml
name = "chittymarket"
main = "src/index.ts"
compatibility_date = "2025-09-01"
route = { pattern = "market.chitty.cc/*", zone_name = "chitty.cc" }

[vars]
SERVICE_NAME = "chittymarket"

[[kv_namespaces]]
binding = "MARKET_CATALOG"
id = "..."

[[tail_consumers]]
service = "chittytrack"
```

## ChittyOS Registration

```json
{
  "name": "chittymarket",
  "domain": "market.chitty.cc",
  "tier": 3,
  "canonical_uri": "chittycanon://core/services/chittymarket",
  "endpoints": ["/health", "/api/plugins", "/api/profiles", "/api/manifest"]
}
```
