# Runtime Projection Matrix

| Runtime | Allowed footprint | Typical use | Restriction |
|---|---|---|---|
| ChatGPT Skill | context-only, read-only guidance | repeatable reasoning, templates, audit procedures | do not execute privileged operations |
| MCP gateway | read-only connector, network-service, controlled write | tool execution and search-and-execute dispatch | require route-level authorization |
| Local CLI/plugin | filesystem-local, metadata-sensitive, high-volume | machine-local cleanup, file inspection, bulk artifact work | do not expose broadly through cloud-only channels |
| Legal space | high evidentiary risk, legal-grade records | claims, evidence, custody, filings, disputes | require source IDs, hashes, timestamps, decision log |
| Evidence pipeline | forensic-legal-grade | ingestion, preservation, chain of custody | require immutable trail and no ad hoc file copying |
| Portal/web app | human review, dashboard, approvals | registry review, retirement approvals, migration queue | require role-based access |
| Worker/API service | network-service | stateless routing, registry API, gateway decisions | implement health and status endpoints |

## Projection principle

Expose the simplest safe projection. Do not leak adapter names, backend fragmentation, or duplicate platform entries into the user-facing marketplace.
