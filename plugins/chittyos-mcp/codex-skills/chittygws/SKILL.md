---
name: chittygws
description: Instructs agents on how to utilize the ChittyGWS surface (Google Workspace MCP). Covers connecting to ChittyGWS securely via Cloudflare Access JWT validation, dealing with MCP portal errors, and handling OAuth for external testing apps. Use when agents need to interact with Google Workspace APIs via the MCP server or troubleshoot 404/421/503 errors on the MCP portal.
canon_uri: chittycanon://core/services/chittymarket#skills/chittygws
---

# ChittyGWS (Google Workspace MCP)

This skill provides instructions for interacting with the ChittyGWS (Google Workspace) MCP surface, particularly regarding authentication, Cloudflare Access, and troubleshooting connection issues from ChatGPT or Claude via the MCP Portal.

## Architecture & Authentication

ChittyGWS is protected by Cloudflare Access. External clients (like ChatGPT or Claude) connecting through the MCP Portal (`https://chatgpt.com/connector/oauth/...`) do not bypass this protection.

### Cloudflare Access JWT Validation

When the MCP Portal makes a request to the ChittyGWS MCP endpoints (e.g., `/mcp`), it MUST include a valid Cloudflare Access JWT in the `Cf-Access-Jwt-Assertion` header. 

1. **Middleware (`verifyAccessJwt`)**: The ChittyGWS worker checks for the `Cf-Access-Jwt-Assertion` header.
2. **Validation**: It validates the token using the JWKS endpoint associated with your Cloudflare Zero Trust `TEAM_DOMAIN`.
3. **Audience Check**: The token's audience (`aud`) MUST match the `POLICY_AUD` configured in the worker's environment.

**Reference**: [Validating JSON Web Tokens](https://developers.cloudflare.com/cloudflare-one/access-controls/applications/http-apps/authorization-cookie/validating-json/index.md)

### Required Environment Variables

For the ChittyGWS worker to successfully authenticate requests, the following environment variables MUST be correctly configured in `wrangler.jsonc` (or via Cloudflare Secrets):

- `TEAM_DOMAIN`: The Cloudflare Zero Trust team domain (e.g., `https://your-team.cloudflareaccess.com`).
- `POLICY_AUD`: The Audience tag of the Cloudflare Access application protecting the MCP endpoint.

*If either of these are empty or incorrect, the worker will fail to validate the JWT, resulting in `503 Service Unavailable` or `401 Unauthorized` errors.*

## Troubleshooting MCP Portal Errors

When users report errors like `HTTP 404`, `HTTP 421`, or `HTTP 503` in the MCP Portal:

1. **HTTP 503 (Service Unavailable)**:
   - **Cause**: Often caused by missing or misconfigured `TEAM_DOMAIN` or `POLICY_AUD` environment variables in the worker, causing the `verifyAccessJwt` middleware to fail.
   - **Action**: Check `wrangler.jsonc` and ensure these variables are populated with the correct values from the Cloudflare Zero Trust dashboard.

2. **HTTP 401 (Unauthorized)**:
   - **Cause**: The `Cf-Access-Jwt-Assertion` header is missing, expired, or invalid. The MCP Portal (or proxy, like `chittyconnect`) might not be passing the header correctly.
   - **Action**: Verify that the MCP Portal is correctly linked as an application in Cloudflare Access and that the service token or user session is valid.

3. **HTTP 404 / 421**:
   - **Cause**: Incorrect routing, the MCP server is down, or the endpoint URL is misconfigured in the MCP Portal.
   - **Action**: Verify the MCP Server URL configured in the ChatGPT/Claude connector settings.

## Google OAuth & Allow Lists

ChittyGWS integrates with Google Workspace APIs via OAuth 2.0.

- **External Testing Apps**: When the Google Cloud Project's OAuth consent screen is set to "External" and "Testing", ONLY users explicitly added to the "Test users" list in the GCP Console can authorize the app.
- **No Additional Allow Lists Needed**: Because Google enforces the "Test users" list at the OAuth consent screen level, building an *additional* allow list within ChittyGWS is redundant and unnecessary. If a user can successfully complete the Google OAuth flow (e.g., receiving `{"success":true,"message":"Google OAuth completed"}`), they are already authorized.

## Sensitive Information Guardrails

**CRITICAL**: NEVER reveal API keys, Client IDs, Client Secrets, or other sensitive tokens in conversation history. Treat all values in `wrangler.jsonc`, `.dev.vars`, and Cloudflare Secrets as highly sensitive. Do not echo them back in plain text during debugging.
