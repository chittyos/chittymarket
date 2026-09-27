# Furnished Housing Operator

Role-focused ChittyMarket package for furnished and mid-term residential operations.

## Bundled

- `furnished-housing-operator`
- `prioritize-property-leads`

## Required shared capabilities

- `chittyos-core`
- `chittyos-legal`
- `chittyos-mcp`

Shared dependencies remain in their canonical owning plugins. This package does not fork them.

## Upstream vertical service

ChiCo is canonical service `chittycanon://core/services/concierge-properties` and exposes lead-processing MCP tools in its source repo. The current MCP transport is repo-local stdio; do not package it as a portable standalone until it is registered through Ch1tty.
