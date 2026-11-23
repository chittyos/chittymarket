// node --test scripts/tests/test-mcp-portal-defs.mjs
// Exercises the real snapshot + classification (no mocks): generator invariants and the plan diff.
import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import { spawnSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { buildDefinitions, expectedTools } from "../gen-portal-definitions.mjs";
import { buildPlan } from "../cf-portal-plan.mjs";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const rd = (p) => JSON.parse(fs.readFileSync(path.join(ROOT, p), "utf8"));
const snap = () => rd("inventory/portals-2026-11-23.json");
const cls = () => rd("scripts/portal-classification.json");
const manifest = () => rd("plugins/chittyos-mcp/cf-portal/manifest.json");

test("generates 65 servers + 10 portals, each server placed, parked or unclassified with a reason", () => {
  const files = buildDefinitions(snap(), cls());
  assert.equal(Object.keys(files).filter((n) => n.startsWith("server-")).length, 65);
  assert.equal(Object.keys(files).filter((n) => n.startsWith("portal-")).length, 10);
  const m = manifest();
  assert.equal(m.servers.length, 65);
  for (const s of m.servers) {
    if (s.classification === "placed") assert.ok(s.portals.length && s.portals.every((p) => p.reason));
    else if (s.classification === "parked") assert.ok(s.parked_reason && s.portals.length === 0 && s.status === "active");
    else assert.ok(s.unclassified_reason && s.portals.length === 0);
  }
  assert.equal(m.servers.filter((s) => s.classification === "unclassified").length, 0);
  assert.deepEqual(m.servers.filter((s) => s.classification === "parked").map((s) => s.server_id).sort(), ["availability", "bridge-consent", "buyflow", "ch1tty", "google", "secrets"]);
});

test("D7: agent servers target oauth with on_behalf on every membership; third-party keeps its auth", () => {
  for (const s of manifest().servers) {
    if (new URL(s.upstream.url).hostname === "agent.chitty.cc") {
      assert.equal(s.auth.target, "oauth", s.server_id);
      assert.ok(s.portals.every((p) => p.on_behalf === true), s.server_id);
    } else assert.equal(s.auth.target, s.auth.current, s.server_id);
  }
});

test("D8: legal and finance-portal are proposed domain portals; their servers leave chitty-mcp and chittymcp-vm, chode keeps them", () => {
  const m = manifest();
  const pid = (id) => m.portals.find((p) => p.portal_id === id);
  assert.deepEqual([pid("legal").hostname, pid("legal").status, pid("legal").access_app], ["legal.chitty.cc", "proposed", null]);
  assert.deepEqual([pid("finance-portal").hostname, pid("finance-portal").status], ["finance.chitty.cc", "proposed"]);
  const where = (id) => m.servers.find((s) => s.server_id === id).portals.map((p) => p.id).sort();
  for (const id of ["evidence", "dispute", "contextual"]) assert.deepEqual(where(id), ["chode", "legal"], id);
  assert.deepEqual(where("finance"), ["chode", "finance-portal"]);
  assert.deepEqual(where("gam"), ["chode", "gws-portal"]);
  assert.deepEqual(where("secrets"), []);
  assert.deepEqual(where("ch1tty"), []);
  const serverIds = new Set(m.servers.map((s) => s.server_id));
  assert.ok(m.portals.every((p) => /^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(p.portal_id) && !serverIds.has(p.portal_id)));
});

test("a proposed portal whose id collides with a server id fails", () => {
  const c = cls();
  c.portals.finance = c.portals["finance-portal"];
  assert.throws(() => buildDefinitions(snap(), c), /collides with a server id/);
});

test("committed canonicals are byte-identical to generator output", () => {
  for (const [n, md] of Object.entries(buildDefinitions(snap(), cls())))
    assert.equal(fs.readFileSync(path.join(ROOT, "canonical/mcp-portal", `${n}.md`), "utf8"), md, n);
});

test("a server id missing from the classification fails the 65-id assertion", () => {
  const c = cls();
  delete c.parked.google;
  assert.throws(() => buildDefinitions(snap(), c), /neither placed, parked nor unclassified: google/);
});

test("a server id missing from the snapshot fails (64 != 65)", () => {
  const s = snap();
  s.servers = s.servers.filter((x) => x.id !== "npm");
  assert.throws(() => buildDefinitions(s, cls()), /65 distinct servers/);
});

test("unclassified without a reason, and placed+unclassified, both fail", () => {
  const c = cls();
  c.parked.buyflow = " ";
  assert.throws(() => buildDefinitions(snap(), c), /without a reason: buyflow/);
  const d = cls();
  d.unclassified.tasks = "x";
  assert.throws(() => buildDefinitions(snap(), d), /placed AND unclassified\/parked: tasks/);
});

test("expected tools drop deprecated aliases and strip the own-server prefix once", () => {
  assert.deepEqual(expectedTools({ id: "viewport", tool_names: ["hydrate", "viewport_hydrate", "viewport_x"], deprecated_tool_names: ["viewport_hydrate"] }), ["hydrate", "x"]);
  assert.deepEqual(expectedTools({ id: "a", tool_names: ["a_b", "b"], deprecated_tool_names: [] }), ["b"]);
});

test("plan is deterministic and its counts add up", () => {
  const a = JSON.stringify(buildPlan(manifest(), snap()));
  assert.equal(a, JSON.stringify(buildPlan(manifest(), snap())));
  const p = JSON.parse(a);
  assert.equal(p.counts.unclassified, 0);
  assert.equal(p.counts.recreate + p.counts.create + p.counts.noop + p.counts.unclassified + p.counts.delete > 0, true);
  assert.equal(p.counts.client_visible_removals, p.counts.membership_remove);
  assert.ok(p.notes.some((n) => n.includes("ChittyIdentity Agents")));
});

test("plan emits create / recreate / retire rows from a perturbed snapshot", () => {
  const s = snap();
  s.servers = s.servers.filter((x) => x.id !== "ai"); // manifest has an extra server -> create
  const m = manifest();
  m.servers.find((x) => x.server_id === "git").status = "retire";
  const p = buildPlan(m, s);
  assert.ok(p.rows.some((r) => r.type === "create" && r.server === "ai"));
  assert.ok(p.rows.some((r) => r.type === "delete" && r.server === "git"));
  assert.ok(p.rows.filter((r) => r.type === "membership_remove" && r.server === "git").every((r) => r.client_visible));
  assert.ok(p.rows.some((r) => r.type === "recreate" && r.server === "viewport" && r.gated_on === "D3 probe"));
  assert.ok(!p.rows.some((r) => r.type === "recreate" && r.server === "tasks"), "tasks is already oauth");
});

test("a manifest with one extra server yields one server create row and exits 0", () => {
  const s = snap();
  s.servers = s.servers.filter((x) => x.id !== "ai");
  const p = buildPlan(manifest(), s);
  assert.equal(p.rows.filter((r) => r.type === "create" && r.kind === "server").length, 1);
  const dir = fs.mkdtempSync(path.join(ROOT, "scripts/tests/.tmp-plan-"));
  try {
    fs.writeFileSync(path.join(dir, "s.json"), JSON.stringify(s));
    const r = spawnSync(process.execPath, [path.join(ROOT, "scripts/cf-portal-plan.mjs"), "--manifest", path.join(ROOT, "plugins/chittyos-mcp/cf-portal/manifest.json"), "--snapshot", path.join(dir, "s.json"), "--out", path.join(dir, "out")], { encoding: "utf8" });
    assert.equal(r.status, 0, r.stderr);
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});

test("portal create rows: the two proposed portals, none for portals already in the snapshot", () => {
  const p = buildPlan(manifest(), snap());
  const rows = p.rows.filter((r) => r.type === "create" && r.kind === "portal");
  assert.deepEqual(rows.map((r) => r.portal).sort(), ["finance-portal", "legal"]);
  assert.equal(p.counts.create_portals, 2);
  assert.ok(rows.every((r) => r.status === "proposed"));
  assert.ok(!p.notes.some((n) => n.includes("portal creation is out of scope")));
});

test("on_behalf rows: unknown snapshot value is recorded and summarised; a known matching value emits none", () => {
  const p = buildPlan(manifest(), snap());
  const ob = p.rows.filter((r) => r.type === "on_behalf_set");
  assert.ok(ob.length > 0 && ob.every((r) => r.from === "unknown" && r.to === true));
  assert.ok(p.notes.some((n) => n.includes("no per-membership on_behalf") && n.includes(`${ob.length} membership`)));
  const s = snap();
  const m = manifest();
  const t = m.servers.find((x) => x.server_id === "tasks");
  const live = s.servers.find((x) => x.id === "tasks");
  live.on_behalf = Object.fromEntries(live.portals.map((x) => [x, true]));
  const q = buildPlan(m, s);
  assert.ok(!q.rows.some((r) => r.type === "on_behalf_set" && r.server === "tasks" && live.portals.includes(r.portal)));
  live.on_behalf = Object.fromEntries(live.portals.map((x) => [x, false]));
  assert.ok(buildPlan(m, s).rows.some((r) => r.type === "on_behalf_set" && r.server === "tasks" && r.from === false));
  assert.ok(t.portals.every((x) => x.on_behalf));
});

test("on_behalf rows: a known true -> false de-escalation emits a row; unknown -> false emits none", () => {
  const m = manifest();
  const s = snap();
  const t = m.servers.find((x) => x.classification === "placed" && x.portals.some((p) => p.on_behalf !== true));
  const live = s.servers.find((x) => x.id === t.server_id);
  const off = t.portals.filter((p) => p.on_behalf !== true).map((p) => p.id);
  assert.ok(!buildPlan(m, s).rows.some((r) => r.type === "on_behalf_set" && r.server === t.server_id && off.includes(r.portal)));
  live.on_behalf = Object.fromEntries(live.portals.map((x) => [x, true]));
  const rows = buildPlan(m, s).rows.filter((r) => r.type === "on_behalf_set" && r.server === t.server_id && off.includes(r.portal));
  assert.ok(rows.length > 0 && rows.every((r) => r.from === true && r.to === false));
});

test("recreate rows are client-visible and counted in client_impact_total", () => {
  const p = buildPlan(manifest(), snap());
  const rec = p.rows.filter((r) => r.type === "recreate");
  assert.ok(rec.length > 0);
  assert.ok(rec.every((r) => r.client_visible === true && r.drops));
  assert.equal(p.counts.client_visible_recreates, rec.length);
  assert.equal(p.counts.client_impact_total, p.counts.membership_remove + rec.length);
});

test("a server with a tag_set row is never also noop", () => {
  const p = buildPlan(manifest(), snap());
  const tagged = new Set(p.rows.filter((r) => r.type === "tag_set").map((r) => r.server));
  assert.ok(!p.rows.some((r) => r.type === "noop" && tagged.has(r.server)));
});

test("plan CLI exits non-zero when the manifest is missing a server", () => {
  const dir = fs.mkdtempSync(path.join(ROOT, "scripts/tests/.tmp-plan-"));
  try {
    const m = manifest();
    m.servers.pop();
    fs.writeFileSync(path.join(dir, "m.json"), JSON.stringify(m));
    const r = spawnSync(process.execPath, [path.join(ROOT, "scripts/cf-portal-plan.mjs"), "--manifest", path.join(dir, "m.json"), "--snapshot", path.join(ROOT, "inventory/portals-2026-11-23.json"), "--out", path.join(dir, "out")], { encoding: "utf8" });
    assert.notEqual(r.status, 0);
    assert.match(r.stderr, /snapshot server\(s\) without a definition/);
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});

test("generator rejects an id containing ../", () => {
  const s = snap();
  s.servers[0].id = "../evil";
  assert.throws(() => buildDefinitions(s, cls()), /invalid id/);
  const t = snap();
  t.portals[0].id = "a/b";
  assert.throws(() => buildDefinitions(t, cls()), /invalid id/);
});
