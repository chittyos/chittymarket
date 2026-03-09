# ChittyOS Health Check Skill

## Overview
Check health status of ChittyOS services across the ecosystem.

## Usage
```
/health [service-name|all]
```

## Parameters
| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| service-name | No | all | Specific service or "all" for full check |

## Service Registry

### Tier 0-1: Foundation Services
| Service | Domain | Expected Response |
|---------|--------|-------------------|
| chittyid | id.chitty.cc | `{"status":"ok","service":"chittyid"}` |
| chittyauth | auth.chitty.cc | `{"status":"ok","service":"chittyauth"}` |
| chittyschema | schema.chitty.cc | `{"status":"ok","service":"chittyschema"}` |
| chittyregistry | registry.chitty.cc | `{"status":"ok","service":"chittyregistry"}` |

### Tier 2-3: Core Services
| Service | Domain | Expected Response |
|---------|--------|-------------------|
| chittyconnect | connect.chitty.cc | `{"status":"ok","service":"chittyconnect"}` |
| chittyapi | api.chitty.cc | `{"status":"ok","service":"chittyapi"}` |
| chittymcp | mcp.chitty.cc | `{"status":"ok","service":"chittymcp"}` |

## Workflow

### Single Service Check
```bash
curl -s https://{service}.chitty.cc/health | jq .
```

### Full Ecosystem Check
```bash
for service in id auth connect api registry schema mcp; do
  echo -n "$service: "
  curl -s "https://$service.chitty.cc/health" --max-time 5 | jq -r '.status // "DOWN"'
done
```

### Detailed Check
```bash
# Check response time
time curl -s https://{service}.chitty.cc/health

# Check SSL certificate
curl -vI https://{service}.chitty.cc 2>&1 | grep -A2 "Server certificate"

# Check Cloudflare headers
curl -sI https://{service}.chitty.cc | grep -i "cf-"
```

## Status Interpretation

| Status | Meaning | Action |
|--------|---------|--------|
| `{"status":"ok"}` | Healthy | None needed |
| Connection refused | Not deployed | Run /deploy |
| DNS error | No DNS record | Configure in Cloudflare |
| 502/503 | Worker error | Check wrangler logs |
| Timeout | Performance issue | Check worker metrics |

## Troubleshooting
```bash
# View worker logs
wrangler tail {worker-name} --env production

# Check deployment status
wrangler deployments list
```
