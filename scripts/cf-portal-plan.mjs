#!/usr/bin/env node
// Dry-run plan: diff the cf-portal manifest (target) against a portal snapshot (current).
// No network, no writes to Cloudflare. Deterministic: same inputs give byte-identical output.
//   node scripts/cf-portal-plan.mjs --manifest plugins/chittyos-mcp/cf-portal/manifest.json \
//        --snapshot inventory/portals-2026-11-23.json [--out inventory/portal-plan-2026-11-23]
// Design: docs/architecture/mcp-portal-estate.md section 4.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const ORDER = ["create", "recreate", "delete", "membership_add", "membership_remove", "on_behalf_set", "tag_set", "blocked", "unclassified", "noop"];

const cmp = (a, b) => (a < b ? -1 : a > b ? 1 : 0);

export function buildPlan(manifest, snap) {
  if (!manifest.servers.length || !manifest.portals.length) throw new Error("manifest has zero servers or zero portals");
  const defined = new Set(manifest.servers.filter((s) => s.status === "active" || s.status === "retire").map((s) => s.server_id));
  const undef = snap.servers.map((s) => s.id).filter((id) => !defined.has(id));
  if (undef.length) throw new Error(`snapshot server(s) without a definition (status active|retire): ${undef.join(", ")}`);
  const cur = new Map(snap.servers.map((s) => [s.id, s]));
  const curPortals = new Map(snap.portals.map((p) => [p.id, p]));
  const rows = [];
  const notes = [];
  const push = (type, r) => rows.push({ type, ...r });

  for (const s of manifest.servers) {
    const id = s.server_id;
    const live = cur.get(id);
    const touched = [];
    const t = (type, r) => { touched.push(type); push(type, { server: id, ...r }); };
    if (s.classification === "unclassified") {
      push("unclassified", { server: id, reason: s.unclassified_reason, current_portals: live ? [...live.portals].sort() : [], current_auth: live ? live.auth_type : null });
      continue;
    }
    const want = s.portals.map((p) => p.id).sort();
    const wantOb = new Map(s.portals.map((p) => [p.id, p.on_behalf === true]));
    const host = new URL(s.upstream.url).hostname;
    if ((host === "chitty.cc" || host.endsWith(".chitty.cc")) && live && !live.access_covering_apps.length)
      push("blocked", { server: id, reason: `upstream ${s.upstream.url} has no covering Access app` });

    if (!live) {
      if (s.status === "retire") continue;
      t("create", { kind: "server", auth_type: s.auth.target, upstream: s.upstream.url, portals: want, on_behalf: Object.fromEntries(want.map((p) => [p, wantOb.get(p)])), access_apps: s.auth.access_apps });
    } else {
      const have = [...live.portals].sort();
      if (s.status === "retire") {
        for (const p of have) t("membership_remove", { portal: p, client_visible: true, reason: "retire: remove from every portal before delete" });
        t("delete", { reason: "status: retire", current_portals: have });
      } else {
        const recreate = s.auth.target !== live.auth_type;
        if (recreate)
          t("recreate", { auth_type_from: live.auth_type, auth_type_to: s.auth.target, readd_portals: want, gated_on: s.auth.target === "oauth" ? "D3 probe" : null, client_visible: true, drops: "portal membership and per-user OAuth connections" });
        for (const p of want.filter((x) => !have.includes(x))) t("membership_add", { portal: p, bundled_with_recreate: recreate });
        for (const p of have.filter((x) => !want.includes(x))) t("membership_remove", { portal: p, client_visible: true });
        // snapshot records no per-membership on_behalf: current is "unknown"; an unknown current with target false (third-party, unchanged) needs no row; a known true->false de-escalation does
        for (const p of want) {
          const now = live.on_behalf && p in live.on_behalf ? live.on_behalf[p] : "unknown";
          if (now !== wantOb.get(p) && (wantOb.get(p) || now === true)) t("on_behalf_set", { portal: p, from: now, to: wantOb.get(p) });
        }
      }
    }
    if (s.status !== "retire" && s.tags && Object.keys(s.tags).length)
      t("tag_set", { server: id, tags: s.tags, support: "unverified (CF Resource Tagging may not accept MCP servers)" });
    if (!touched.length) push("noop", { server: id });
  }

  // portals: manifest vs snapshot, and Access apps that match no portal
  for (const p of manifest.portals) {
    if (!curPortals.has(p.portal_id)) { if (p.status !== "retire") push("create", { kind: "portal", portal: p.portal_id, hostname: p.hostname, status: p.status, audience: p.audience, code_mode: p.code_mode }); }
    else if (curPortals.get(p.portal_id).hostname !== p.hostname) notes.push(`portal ${p.portal_id}: hostname ${p.hostname} differs from snapshot ${curPortals.get(p.portal_id).hostname}`);
  }
  const hosts = new Set(manifest.portals.map((p) => p.hostname));
  for (const a of snap.access_apps)
    if (a.type === "mcp_portal" && !a.destinations.some((d) => hosts.has(d)))
      notes.push(`mcp_portal Access app "${a.name}" (${a.destinations.join(", ")}) matches no portal`);
  const unk = rows.filter((r) => r.type === "on_behalf_set" && r.from === "unknown").length;
  if (unk) notes.push(`on_behalf: the snapshot records no per-membership on_behalf, so ${unk} membership(s) have current value unknown and are planned as on_behalf=true (D7)`);

  rows.sort((a, b) => ORDER.indexOf(a.type) - ORDER.indexOf(b.type) || cmp(a.server || "", b.server || "") || cmp(a.portal || "", b.portal || ""));
  const counts = Object.fromEntries(ORDER.map((k) => [k, rows.filter((r) => r.type === k).length]));
  counts.create_portals = rows.filter((r) => r.type === "create" && r.kind === "portal").length;
  counts.client_visible_removals = rows.filter((r) => r.client_visible && r.type === "membership_remove").length;
  counts.client_visible_recreates = rows.filter((r) => r.client_visible && r.type === "recreate").length;
  counts.client_impact_total = counts.client_visible_removals + counts.client_visible_recreates;
  notes.sort();
  return { schema: "chittymarket/cf-portal-plan/v1", snapshot: snap.generated, counts, notes, rows };
}

export function renderMd(plan) {
  const L = [`# MCP portal estate: dry-run plan (snapshot ${plan.snapshot})`, "", "Nothing here is applied. Generated by scripts/cf-portal-plan.mjs.", "", "| row type | count |", "|---|---|"];
  for (const [k, v] of Object.entries(plan.counts)) L.push(`| ${k} | ${v} |`);
  L.push("", `Client impact: ${plan.counts.client_impact_total} client-visible changes = ${plan.counts.client_visible_removals} membership removals + ${plan.counts.client_visible_recreates} recreates. A recreate drops the server's portal membership and per-user OAuth connections until re-added and re-authorized.`);
  if (plan.notes.length) L.push("", "## Notes", ...plan.notes.map((n) => `- ${n}`));
  const sec = (type, title, cols, f) => {
    const rs = plan.rows.filter((r) => r.type === type);
    if (!rs.length) return;
    L.push("", `## ${title} (${rs.length})`, "", `| ${cols.join(" | ")} |`, `|${cols.map(() => "---").join("|")}|`);
    for (const r of rs) L.push(`| ${f(r).join(" | ")} |`);
  };
  sec("create", "create", ["kind", "id", "auth / hostname", "portals / status"], (r) => r.kind === "portal" ? ["portal", r.portal, r.hostname, r.status] : ["server", r.server, r.auth_type, r.portals.join(", ")]);
  sec("recreate", "recreate(auth_type, client-visible)", ["server", "from", "to", "re-add portals", "gated on"], (r) => [r.server, r.auth_type_from, r.auth_type_to, r.readd_portals.join(", "), r.gated_on || ""]);
  sec("delete", "delete(retire)", ["server", "reason"], (r) => [r.server, r.reason]);
  sec("membership_add", "membership add", ["server", "portal", "bundled with recreate"], (r) => [r.server, r.portal, String(r.bundled_with_recreate)]);
  sec("membership_remove", "membership remove (client-visible)", ["server", "portal"], (r) => [r.server, r.portal]);
  sec("on_behalf_set", "on_behalf set (D7 caller pass-through)", ["server", "portal", "from", "to"], (r) => [r.server, r.portal, String(r.from), String(r.to)]);
  sec("tag_set", "tag set", ["server", "tags"], (r) => [r.server, Object.entries(r.tags).map(([k, v]) => `${k}=${v}`).join(" ")]);
  sec("blocked", "blocked", ["server", "reason"], (r) => [r.server, r.reason]);
  sec("unclassified", "unclassified", ["server", "current auth", "current portals", "reason"], (r) => [r.server, r.current_auth, r.current_portals.join(", "), r.reason]);
  const noop = plan.rows.filter((r) => r.type === "noop").map((r) => r.server);
  if (noop.length) L.push("", `## no-op (${noop.length})`, "", noop.join(", "));
  return L.join("\n") + "\n";
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const a = process.argv.slice(2);
  const opt = (k) => (a.includes(k) ? a[a.indexOf(k) + 1] : null);
  try {
    const mp = opt("--manifest"), sp = opt("--snapshot");
    if (!mp || !sp) throw new Error("usage: cf-portal-plan.mjs --manifest <manifest.json> --snapshot <snapshot.json> [--out <path-prefix>]");
    const plan = buildPlan(JSON.parse(fs.readFileSync(mp, "utf8")), JSON.parse(fs.readFileSync(sp, "utf8")));
    const out = path.resolve(opt("--out") || path.join(ROOT, `inventory/portal-plan-${plan.snapshot}`));
    fs.writeFileSync(`${out}.json`, JSON.stringify(plan, null, 2) + "\n");
    fs.writeFileSync(`${out}.md`, renderMd(plan));
    console.log(JSON.stringify(plan.counts));
  } catch (e) { console.error(`cf-portal-plan: ${e.message}`); process.exit(1); }
}
