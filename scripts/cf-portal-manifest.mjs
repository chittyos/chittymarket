#!/usr/bin/env node
// Aggregate the projected plugins/chittyos-mcp/cf-portal/{servers,portals}/*.json into
// plugins/chittyos-mcp/cf-portal/manifest.json. Run after `dispatch.sh sync`; deterministic.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

export function buildManifest(dir) {
  const load = (sub, key) =>
    fs.existsSync(path.join(dir, sub))
      ? fs.readdirSync(path.join(dir, sub)).filter((f) => f.endsWith(".json")).sort()
          .map((f) => JSON.parse(fs.readFileSync(path.join(dir, sub, f), "utf8")))
          .sort((a, b) => (a[key] < b[key] ? -1 : a[key] > b[key] ? 1 : 0))
      : [];
  return { schema: "chittymarket/cf-portal-manifest/v1", servers: load("servers", "server_id"), portals: load("portals", "portal_id") };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const dir = path.resolve(process.argv[2] || path.join(ROOT, "plugins/chittyos-mcp/cf-portal"));
  const m = buildManifest(dir);
  fs.writeFileSync(path.join(dir, "manifest.json"), JSON.stringify(m, null, 2) + "\n");
  console.log(`manifest: ${m.servers.length} servers, ${m.portals.length} portals`);
}
