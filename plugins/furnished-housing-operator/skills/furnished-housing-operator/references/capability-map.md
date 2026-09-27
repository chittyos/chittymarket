# Capability composition

This file is a routing map, not a second registry.

| Job | Owner |
|---|---|
| Lead ingest/categorization/response | ChiCo / `chittycanon://core/services/concierge-properties` when authorized |
| Competing lead decision | `prioritize-property-leads` (bundled here) |
| Session/context | `chittyos-core` dependency |
| Disputes/evidence/legal facts | `chittyos-legal` dependency |
| ChittyOS capability discovery/execution | `chittyos-mcp` dependency / Ch1tty |
| CRM pipeline | Connected CRM remains system of record |
| Messaging/contact history | Connected messaging/contact system |
| Calendar | Operationally real dates only |
| Finance | Existing finance authority; do not duplicate ledger/accounting logic |
| Files/policies | Existing document system |

## Distribution decision

Bundle only vertical method. Keep cross-cutting platform skills and MCPs canonical in their owning plugins and pull them through `requires`. Do not ship a second ChiCo stdio server: the current implementation is repo-local and is not yet registered as a portable Ch1tty MCP route.
