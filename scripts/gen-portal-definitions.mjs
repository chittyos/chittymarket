#!/usr/bin/env node
// Generate canonical/mcp-portal/*.md (kinds mcp-portal-server and mcp-portal) from the
// PR #261 portal snapshot plus scripts/portal-classification.json.
// Design: proposals/MCP_PORTAL_ESTATE.md v0.1 (docs/architecture/mcp-portal-estate.md).
// Layout is FLAT (canonical/mcp-portal/<name>.md) because dispatch finds canonicals one level
// deep. Files are named server-<id> / portal-<id>: dispatch resolves canonicals by bare name across
// all kind dirs, and server ids neon/dispute/market/ship already exist as mcp/skills canonicals.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(here, "..");
const CANON = "chittycanon://core/services/chittymarket#mcp-portal";

const q = JSON.stringify;
function scalar(v) {
  return v === null || v === undefined ? "null" : typeof v === "string" ? q(v) : String(v);
}
// Minimal deterministic YAML emitter (strings are JSON-quoted, which is valid YAML).
function emit(v, ind = 0) {
  const pad = " ".repeat(ind);
  if (Array.isArray(v)) {
    if (v.every((x) => x === null || typeof x !== "object")) return v.length ? `[${v.map(scalar).join(", ")}]` : "[]";
    return v.map((x) => `${pad}- ${emit(x, ind + 2).trimStart()}`).join("\n");
  }
  if (v && typeof v === "object") {
    return Object.entries(v)
      .map(([k, x]) => {
        if (typeof x === "string" && k === "description") return `${pad}${k}: |-\n${pad}  ${x}`;
        const isBlock = x && typeof x === "object" && (Array.isArray(x) ? x.some((y) => y && typeof y === "object") : Object.keys(x).length);
        return isBlock ? `${pad}${k}:\n${emit(x, ind + 2)}` : `${pad}${k}: ${emit(x, ind)}`;
      })
      .join("\n");
  }
  return scalar(v);
}

export function expectedTools(s) {
  const dep = new Set(s.deprecated_tool_names || []);
  const pre = `${s.id}_`;
  const out = [];
  for (const t of s.tool_names || []) {
    if (dep.has(t)) continue;
    const bare = t.startsWith(pre) && t.length > pre.length ? t.slice(pre.length) : t;
    if (!out.includes(bare)) out.push(bare);
  }
  return out;
}

function upstreamOf(s) {
  const u = new URL(s.hostname);
  const m = u.hostname === "agent.chitty.cc" && u.pathname.match(/^\/([^/]+)\/mcp/);
  return m ? { route: m[1] } : { route: null };
}

export function buildDefinitions(snap, cls) {
  const ids = snap.servers.map((s) => s.id);
  const byId = new Map(snap.servers.map((s) => [s.id, s]));
  if (ids.length !== 65 || byId.size !== 65) throw new Error(`snapshot must hold 65 distinct servers, found ${ids.length}/${byId.size}`);

  // server -> [{id, reason}] from explicit groups
  const member = new Map();
  const unknown = [];
  for (const g of cls.groups) {
    for (const sid of g.servers) {
      if (!byId.has(sid)) { unknown.push(sid); continue; }
      if (!member.has(sid)) member.set(sid, []);
      member.get(sid).push({ id: g.portal, reason: g.reason });
    }
  }
  const unc = cls.unclassified;
  for (const sid of Object.keys(unc)) if (!byId.has(sid)) unknown.push(sid);
  if (unknown.length) throw new Error(`classification names ids absent from the snapshot: ${unknown.join(", ")}`);
  const both = ids.filter((i) => member.has(i) && unc[i]);
  if (both.length) throw new Error(`placed AND unclassified: ${both.join(", ")}`);
  const missing = ids.filter((i) => !member.has(i) && !unc[i]);
  if (missing.length) throw new Error(`servers neither placed nor unclassified: ${missing.join(", ")}`);
  const noReason = Object.entries(unc).filter(([, r]) => !r || !String(r).trim()).map(([i]) => i);
  if (noReason.length) throw new Error(`unclassified without a reason: ${noReason.join(", ")}`);

  const portalIds = new Set(snap.portals.map((p) => p.id));
  for (const id of Object.keys(cls.portals)) if (!portalIds.has(id)) throw new Error(`classification portal ${id} not in snapshot`);
  for (const id of portalIds) if (!cls.portals[id]) throw new Error(`snapshot portal ${id} has no classification`);

  // mirrors (code-mode / headless) added after explicit placement
  for (const [pid, pc] of Object.entries(cls.portals)) {
    const reason = cls.mirror_reasons[pid];
    if (pc.membership === "all-placed") for (const [sid, list] of member) list.push({ id: pid, reason });
    else if (pc.membership.startsWith("mirror:")) {
      const src = pc.membership.slice(7);
      for (const [sid, list] of member) if (list.some((e) => e.id === src)) list.push({ id: pid, reason });
    }
  }

  const accessFor = (host) => {
    const hit = snap.access_apps.filter((a) => a.type === "mcp_portal" && a.destinations.includes(host));
    if (hit.length !== 1) throw new Error(`portal host ${host} must match exactly one mcp_portal Access app, got ${hit.length}`);
    return hit[0].name;
  };

  const files = {};
  for (const s of snap.servers) {
    const { route } = upstreamOf(s);
    const placed = member.get(s.id);
    const third = route === null;
    const own = !third;
    const target = unc[s.id] || third ? s.auth_type : "oauth";
    const primary = placed ? placed[0].id : null;
    const fm = {
      name: `server-${s.id}`,
      server_id: s.id,
      canon_uri: `${CANON}/servers/${s.id}`,
      kind: "mcp-portal-server",
      plugin: cls.plugin,
      runtimes: ["cf-portal"],
      description: own
        ? `ChittyOS agent MCP server at agent.chitty.cc/${route}/mcp.`
        : `Third-party style MCP server at ${new URL(s.hostname).hostname}.`,
      upstream: { url: s.hostname, worker: own ? `chittyagent-${route}` : null, repo: own ? "chittyos/chittyentity" : null },
      auth: {
        target,
        current: s.auth_type,
        access_apps: s.access_covering_apps.map((a) => a.name),
        on_behalf: false,
      },
      classification: placed ? "placed" : "unclassified",
    };
    if (placed) fm.portals = placed;
    else { fm.portals = []; fm.unclassified_reason = unc[s.id]; }
    fm.current_portals = [...s.portals].sort();
    fm.tools = { naming: "no-self-prefix", expected: expectedTools(s) };
    fm.prompts = { expose: own && s.prompt_names.length ? s.prompt_names : "none" };
    fm.resources = "unavailable";
    fm.tags = placed && own
      ? { "chitty.repo": "chittyos/chittyentity", "chitty.env": "production", "chitty.portal": primary }
      : {};
    fm.status = "active";
    files[`server-${s.id}`] = renderMd(fm, `# server-${s.id} (mcp-portal-server)\n\nGenerated by scripts/gen-portal-definitions.mjs from inventory/portals-${snap.generated}.json. Edit scripts/portal-classification.json, not this file.\n`);
  }

  for (const p of snap.portals) {
    const pc = cls.portals[p.id];
    const fm = {
      name: `portal-${p.id}`,
      canon_uri: `${CANON}/portals/${p.id}`,
      kind: "mcp-portal",
      plugin: cls.plugin,
      runtimes: ["cf-portal"],
      description: pc.description || `MCP portal ${p.id}.`,
      portal_id: p.id,
      hostname: p.hostname,
      audience: pc.audience,
      display_name: pc.display_name,
      access_app: accessFor(p.hostname),
      code_mode: pc.code_mode,
      membership: pc.membership,
      evidence: cls.mirror_reasons[p.id] || null,
      status: "active",
    };
    files[`portal-${p.id}`] = renderMd(fm, `# portal-${p.id} (mcp-portal)\n\nGenerated by scripts/gen-portal-definitions.mjs. Membership is declared on the servers.\n`);
  }
  return files;
}

function renderMd(fm, body) {
  return `---\n${emit(fm)}\n---\n\n${body}`;
}

function main() {
  const a = process.argv.slice(2);
  const opt = (k, d) => (a.includes(k) ? a[a.indexOf(k) + 1] : d);
  const snapPath = path.resolve(opt("--snapshot", path.join(ROOT, "inventory/portals-2026-11-23.json")));
  const clsPath = path.resolve(opt("--classification", path.join(here, "portal-classification.json")));
  const out = path.resolve(opt("--out", path.join(ROOT, "canonical/mcp-portal")));
  const files = buildDefinitions(JSON.parse(fs.readFileSync(snapPath, "utf8")), JSON.parse(fs.readFileSync(clsPath, "utf8")));
  fs.mkdirSync(out, { recursive: true });
  for (const [n, md] of Object.entries(files)) fs.writeFileSync(path.join(out, `${n}.md`), md);
  const names = Object.keys(files);
  console.log(`wrote ${names.length} definitions (${names.filter((n) => n.startsWith("portal-")).length} portals) to ${out}`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try { main(); } catch (e) { console.error(`gen-portal-definitions: ${e.message}`); process.exit(1); }
}
