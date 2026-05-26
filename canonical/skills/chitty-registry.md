---
name: chitty-registry
description: Query ChittyRegistry (registry.chitty.cc) for service catalog, tiers, domains, dependencies, and certification badges. Discovery before integration.
kind: skill
plugin: chittyos-devops
runtimes:
  - claude-code
classification:
  - operations
  - deployment
---

# ChittyOS Registry Skill

## Overview
Query and manage the ChittyOS service registry for service discovery and metadata.

## Usage
```
/registry [command] [args]
```

## Commands

| Command | Description |
|---------|-------------|
| `list` | List all registered services |
| `get [service]` | Get service details |
| `search [query]` | Search services by name/description |
| `tiers` | Show services grouped by tier |
| `status` | Show registration status of all services |

## Registry API

Base URL: `https://registry.chitty.cc`

### List Services
```bash
curl -s https://registry.chitty.cc/api/services | jq .
```

### Get Service Details
```bash
curl -s https://registry.chitty.cc/api/services/{service-id} | jq .
```

### Search Services
```bash
curl -s "https://registry.chitty.cc/api/services?q={query}" | jq .
```

## Local Registry CSV

Fallback registry data at:
`/Volumes/chitty/temp/systems-registry-import-v3.csv`

### Parse Local Registry
```bash
# List all services
cat /Volumes/chitty/temp/systems-registry-import-v3.csv | head -20

# Find specific service
grep -i "chittyid" /Volumes/chitty/temp/systems-registry-import-v3.csv
```

## Service Tiers

| Tier | Purpose | Services |
|------|---------|----------|
| 0 | Trust Anchors | ChittyID, ChittyTrust, ChittySchema |
| 1 | Core Identity | ChittyAuth, ChittyCert, ChittyRegister |
| 2 | Platform | ChittyConnect, ChittyRouter, ChittyAPI |
| 3 | Operational | ChittyMonitor, ChittyDiscovery, ChittyBeacon |
| 4 | Domain | ChittyEvidence, ChittyIntel, ChittyScore |
| 5 | Application | ChittyCases, ChittyPortal, ChittyDashboard |

## Service Metadata Schema

```json
{
  "id": "chittyid",
  "name": "ChittyID",
  "tier": 0,
  "domain": "id.chitty.cc",
  "repo": "CHITTYFOUNDATION/chittyid",
  "status": "live",
  "endpoints": {
    "health": "/health",
    "api": "/api/v1",
    "mcp": "/mcp"
  },
  "dependencies": []
}
```

## Cross-Reference

Use with other skills:
- `/health {service}` - Check if registered service is running
- `/deploy {service}` - Deploy registered service
