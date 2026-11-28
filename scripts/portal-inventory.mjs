#!/usr/bin/env node
// Read-only inventory of the Cloudflare MCP portal estate (portals, MCP servers, Access apps).
//
// Gathers only: no design, no mutations. Only GET requests are ever issued.
// Portal membership, registration (server record), sync (status/last_successful_sync),
// auth readiness and Access coverage are kept as SEPARATE fields (see README.md / CHITTY.md):
// membership does not create a capability and says nothing about readiness.
//
// Usage:
//   CLOUDFLARE_API_TOKEN=... node scripts/portal-inventory.mjs [--account <id>] [--out inventory] [--date YYYY-MM-DD]
//   node scripts/portal-inventory.mjs --from-raw <dir> [--out inventory] [--date YYYY-MM-DD]
//
// --from-raw <dir> reads <dir>/portals.json, <dir>/servers.json, <dir>/access-apps.json: the
// Cloudflare list responses ({result:[...]}) for the three endpoints below, optionally field-projected
// (the normalizer reads only the fields it names, and accepts string or object forms for
// portal servers, destinations and policies). Token is read from env only and is never printed.
//
// Endpoints (GET only):
//   /accounts/{a}/access/ai-controls/mcp/portals
//   /accounts/{a}/access/ai-controls/mcp/servers?per_page=100
//   /accounts/{a}/access/apps?per_page=200

import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const DEFAULT_ACCOUNT = "0bc21e3a5a9de1a4cc843be9c3e98121";
const API = "https://api.cloudflare.com/client/v4";

// ---------- normalization (pure) ----------

const idOf = (x) => (typeof x === "string" ? x : x?.id ?? x?.server_id ?? null);
const nameOf = (x) => (typeof x === "string" ? x : x?.name ?? x?.id ?? null);
const uriOf = (d) => (typeof d === "string" ? d : d?.uri ?? d?.hostname ?? d?.cidr ?? null);
const isDeprecated = (t) => typeof t?.description === "string" && t.description.startsWith("DEPRECATED");

export function normalizePortals(rows) {
  return rows.map((p) => ({
    id: p.id,
    hostname: p.hostname ?? null,
    server_ids: (p.servers ?? []).map(idOf).filter(Boolean).sort(),
  }));
}

export function normalizeApps(rows) {
  return rows.map((a) => ({
    id: a.id,
    name: a.name ?? null,
    type: a.type ?? null,
    destinations: [
      ...new Set([
        ...(a.destinations ?? []).map(uriOf),
        ...(a.domain ? [a.domain] : []),
        ...(a.self_hosted_domains ?? []),
      ].filter(Boolean)),
    ].sort(),
    policy_names: (a.policies ?? []).map(nameOf).filter(Boolean),
  }));
}

// host+path of a server URL, e.g. "agent.chitty.cc/viewport/mcp"
export function hostPath(url) {
  try {
    const u = new URL(url);
    return (u.host + u.pathname).replace(/\/+$/, "");
  } catch {
    return String(url ?? "").replace(/^https?:\/\//, "").replace(/\/+$/, "");
  }
}

const globRe = (g) =>
  new RegExp("^" + g.replace(/[.+?^${}()|[\]\\]/g, "\\$&").replace(/\*/g, ".*") + "$", "i");

// A destination covers host+path when it equals it, matches as a glob, or is host-only
// (host-only destinations cover every path on that host). Mechanical; no prefix inference.
export function destinationCovers(dest, hp) {
  const d = dest.replace(/\/+$/, "");
  if (!d.includes("/")) return globRe(d).test(hp.split("/")[0]);
  return globRe(d).test(hp);
}

export function normalizeServers(rows, portals, apps) {
  const portalsByServer = new Map();
  for (const p of portals)
    for (const sid of p.server_ids) (portalsByServer.get(sid) ?? portalsByServer.set(sid, []).get(sid)).push(p.id);
  return rows.map((s) => {
    const hp = hostPath(s.hostname);
    const covering = apps
      .filter((a) => a.destinations.some((d) => destinationCovers(d, hp)))
      .map((a) => ({ id: a.id, name: a.name, type: a.type }));
    const tools = s.tools ?? [];
    return {
      id: s.id,
      name: s.name ?? null,
      hostname: s.hostname ?? null,
      auth_type: s.auth_type ?? null,
      authentication_status: s.authentication_status ?? null,
      status: s.status ?? null,
      error_code: s.error_details?.status_code ?? null,
      error_summary: s.error ? String(s.error).split(" | ")[0] : null,
      last_successful_sync: s.last_successful_sync ?? null,
      portals: (portalsByServer.get(s.id) ?? []).sort(),
      tool_names: tools.map((t) => t.name),
      deprecated_tool_names: tools.filter(isDeprecated).map((t) => t.name),
      prompt_names: (s.prompts ?? []).map(nameOf),
      resource_count: Array.isArray(s.resources) ? s.resources.length : typeof s.resources === "number" ? s.resources : null,
      access_covering_apps: covering,
    };
  });
}

export function buildInventory({ portalsRaw, serversRaw, appsRaw, account, date }) {
  const portals = normalizePortals(portalsRaw);
  const access_apps = normalizeApps(appsRaw);
  const servers = normalizeServers(serversRaw, portals, access_apps);
  return {
    generated: date,
    account,
    counts: { portals: portals.length, servers: servers.length, access_apps: access_apps.length },
    portals,
    servers,
    access_apps,
  };
}

// ---------- findings (pure) ----------

const SELF_OR_MCP = new Set(["self_hosted", "mcp"]);

export function findings(inv) {
  const { servers, access_apps: apps, portals } = inv;
  const group = (xs, key) => {
    const m = new Map();
    for (const x of xs) {
      const k = key(x);
      (m.get(k) ?? m.set(k, []).get(k)).push(x);
    }
    return m;
  };
  const byStatus = group(servers, (s) => `${s.status} / auth=${s.authentication_status} / ${s.auth_type}`);
  const byError = group(servers.filter((s) => s.error_code != null || s.error_summary), (s) => `${s.error_code ?? "-"} ${s.error_summary ?? ""}`.trim());
  const multiPortal = servers.filter((s) => s.portals.length > 1);
  const noPortal = servers.filter((s) => s.portals.length === 0);
  const toolOwners = new Map();
  for (const s of servers) for (const t of new Set(s.tool_names)) (toolOwners.get(t) ?? toolOwners.set(t, []).get(t)).push(s.id);
  const dupTools = [...toolOwners].filter(([, o]) => o.length > 1).sort(([a], [b]) => a.localeCompare(b));
  const doubled = [];
  const deprecated = [];
  for (const s of servers) {
    // Portals expose tools as <server id>_<tool>; a tool already named <server id>_* is exposed doubled.
    const pre = s.id.replace(/-/g, "_") + "_";
    for (const t of s.tool_names) if (t.startsWith(pre)) doubled.push([s.id, `${pre}${t}`]);
    for (const t of s.deprecated_tool_names) deprecated.push([s.id, t]);
  }
  const covered = servers.filter((s) => s.access_covering_apps.length);
  const uncovered = servers.filter((s) => !s.access_covering_apps.length);
  const otherTypeOnPaths = apps.filter(
    (a) => !SELF_OR_MCP.has(a.type) && a.destinations.some((d) => d.includes("/")),
  );
  return { byStatus, byError, multiPortal, noPortal, dupTools, doubled, deprecated, covered, uncovered, otherTypeOnPaths, portals };
}

export function renderMarkdown(inv) {
  const f = findings(inv);
  const L = [];
  const ids = (xs) => xs.map((s) => s.id).join(", ");
  L.push(`# MCP portal estate snapshot ${inv.generated}`, "");
  L.push(
    `Read-only inventory of Cloudflare account \`${inv.account}\`. Counts: ${inv.counts.portals} portals, ${inv.counts.servers} servers, ${inv.counts.access_apps} Access apps.`,
    "Portal membership, registration, sync status, auth readiness and Access coverage are separate facts and are reported as separate fields in the JSON. This file lists findings mechanically; it makes no design recommendation.",
    "",
  );
  L.push("## Portals", "", "| portal | hostname | servers |", "|---|---|---|");
  for (const p of f.portals) L.push(`| ${p.id} | ${p.hostname} | ${p.server_ids.length} |`);
  L.push("", "## Servers by status", "", "| status / auth | count | servers |", "|---|---|---|");
  for (const [k, xs] of [...f.byStatus].sort((a, b) => b[1].length - a[1].length)) L.push(`| ${k} | ${xs.length} | ${ids(xs)} |`);
  L.push("", "## Servers with an error", "", "| error code / summary | count | servers |", "|---|---|---|");
  for (const [k, xs] of [...f.byError].sort((a, b) => b[1].length - a[1].length)) L.push(`| ${k} | ${xs.length} | ${ids(xs)} |`);
  L.push("", `## Servers in multiple portals (${f.multiPortal.length})`, "");
  for (const s of f.multiPortal) L.push(`- ${s.id}: ${s.portals.join(", ")}`);
  L.push("", `## Servers in no portal (${f.noPortal.length})`, "", f.noPortal.length ? ids(f.noPortal) : "none");
  L.push("", `## Tool names duplicated across servers (${f.dupTools.length})`, "");
  for (const [t, o] of f.dupTools) L.push(`- \`${t}\`: ${o.join(", ")}`);
  L.push("", `## Doubled server prefix in exposed tool name (${f.doubled.length})`, "");
  for (const [s, t] of f.doubled) L.push(`- ${s}: \`${t}\``);
  L.push("", `## Deprecated alias tools, description starts with "DEPRECATED" (${f.deprecated.length})`, "");
  const depBy = new Map();
  for (const [s, t] of f.deprecated) (depBy.get(s) ?? depBy.set(s, []).get(s)).push(t);
  for (const [s, ts] of depBy) L.push(`- ${s} (${ts.length}): ${ts.map((t) => `\`${t}\``).join(", ")}`);
  L.push("", `## Access coverage of server hostname paths`, "", `Covered: ${f.covered.length}. Not covered: ${f.uncovered.length}. A destination covers a server when it equals or globs the server host+path, or is host-only.`, "");
  L.push("Not covered:", "");
  for (const s of f.uncovered) L.push(`- ${s.id}: ${hostPath(s.hostname)}`);
  L.push("", "Covered:", "");
  for (const s of f.covered) L.push(`- ${s.id}: ${hostPath(s.hostname)} <- ${s.access_covering_apps.map((a) => `${a.name} (${a.type})`).join("; ")}`);
  L.push("", `## Access apps of type other than self_hosted/mcp with HTTP-path destinations (${f.otherTypeOnPaths.length})`, "");
  for (const a of f.otherTypeOnPaths) L.push(`- ${a.name} [${a.type}] ${a.id}: ${a.destinations.filter((d) => d.includes("/")).join(", ")}`);
  L.push("", "## Access apps by type", "");
  const byType = new Map();
  for (const a of inv.access_apps) byType.set(a.type, (byType.get(a.type) ?? 0) + 1);
  for (const [t, n] of [...byType].sort((a, b) => b[1] - a[1])) L.push(`- ${t}: ${n}`);
  L.push("");
  return L.join("\n");
}

// ---------- IO ----------

async function apiGet(token, path, query) {
  const url = new URL(API + path);
  for (const [k, v] of Object.entries(query ?? {})) url.searchParams.set(k, v);
  const res = await fetch(url, { method: "GET", headers: { Authorization: `Bearer ${token}` } });
  const body = await res.json().catch(() => null);
  if (!res.ok || body?.success === false) throw new Error(`GET ${path} -> HTTP ${res.status} ${JSON.stringify(body?.errors ?? null)}`);
  const info = body.result_info;
  if (info && info.total_count != null && info.total_count > body.result.length)
    throw new Error(`GET ${path}: got ${body.result.length} of ${info.total_count}; pagination not handled`);
  return body.result;
}

const readJson = (p) => JSON.parse(readFileSync(p, "utf8"));
const rows = (j) => (Array.isArray(j) ? j : j.result);

function parseArgs(argv) {
  const o = { account: DEFAULT_ACCOUNT, out: null, date: new Date().toISOString().slice(0, 10), fromRaw: null };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--from-raw") o.fromRaw = argv[++i];
    else if (a === "--account") o.account = argv[++i];
    else if (a === "--out") o.out = argv[++i];
    else if (a === "--date") o.date = argv[++i];
    else throw new Error(`unknown argument: ${a}`);
  }
  return o;
}

async function main() {
  const o = parseArgs(process.argv.slice(2));
  const out = resolve(o.out ?? join(dirname(fileURLToPath(import.meta.url)), "..", "inventory"));
  let portalsRaw, serversRaw, appsRaw;
  if (o.fromRaw) {
    portalsRaw = rows(readJson(join(o.fromRaw, "portals.json")));
    serversRaw = rows(readJson(join(o.fromRaw, "servers.json")));
    appsRaw = rows(readJson(join(o.fromRaw, "access-apps.json")));
  } else {
    const token = process.env.CLOUDFLARE_API_TOKEN;
    if (!token) throw new Error("CLOUDFLARE_API_TOKEN is not set (use --from-raw <dir> for saved responses)");
    const a = `/accounts/${o.account}`;
    portalsRaw = await apiGet(token, `${a}/access/ai-controls/mcp/portals`);
    serversRaw = await apiGet(token, `${a}/access/ai-controls/mcp/servers`, { per_page: 100 });
    appsRaw = await apiGet(token, `${a}/access/apps`, { per_page: 200 });
  }
  const inv = buildInventory({ portalsRaw, serversRaw, appsRaw, account: o.account, date: o.date });
  mkdirSync(out, { recursive: true });
  writeFileSync(join(out, `portals-${o.date}.json`), JSON.stringify(inv, null, 2) + "\n");
  writeFileSync(join(out, `portals-${o.date}.md`), renderMarkdown(inv));
  console.log(`portals=${inv.counts.portals} servers=${inv.counts.servers} access_apps=${inv.counts.access_apps} -> ${out}/portals-${o.date}.{json,md}`);
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().catch((e) => {
    console.error(String(e.message ?? e));
    process.exit(1);
  });
}
