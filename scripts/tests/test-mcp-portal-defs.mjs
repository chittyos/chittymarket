// node --test scripts/tests/test-mcp-portal-defs.mjs
// Exercises the real snapshot + classification (no mocks): generator invariants and the plan diff.
import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { buildDefinitions, expectedTools } from "../gen-portal-definitions.mjs";
import { buildPlan } from "../cf-portal-plan.mjs";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const rd = (p) => JSON.parse(fs.readFileSync(path.join(ROOT, p), "utf8"));
const snap = () => rd("inventory/portals-2026-11-23.json");
const cls = () => rd("scripts/portal-classification.json");
const manifest = () => rd("plugins/chittyos-mcp/cf-portal/manifest.json");

test("generates 65 servers + 8 portals, each server placed or unclassified with a reason", () => {
  const files = buildDefinitions(snap(), cls());
  assert.equal(Object.keys(files).filter((n) => n.startsWith("server-")).length, 65);
  assert.equal(Object.keys(files).filter((n) => n.startsWith("portal-")).length, 8);
  const m = manifest();
  assert.equal(m.servers.length, 65);
  for (const s of m.servers) {
    if (s.classification === "placed") assert.ok(s.portals.length && s.portals.every((p) => p.reason));
    else assert.ok(s.unclassified_reason && s.portals.length === 0);
  }
});

test("committed canonicals are byte-identical to generator output", () => {
  for (const [n, md] of Object.entries(buildDefinitions(snap(), cls())))
    assert.equal(fs.readFileSync(path.join(ROOT, "canonical/mcp-portal", `${n}.md`), "utf8"), md, n);
});

test("a server id missing from the classification fails the 65-id assertion", () => {
  const c = cls();
  delete c.unclassified.google;
  assert.throws(() => buildDefinitions(snap(), c), /neither placed nor unclassified: google/);
});

test("a server id missing from the snapshot fails (64 != 65)", () => {
  const s = snap();
  s.servers = s.servers.filter((x) => x.id !== "npm");
  assert.throws(() => buildDefinitions(s, cls()), /65 distinct servers/);
});

test("unclassified without a reason, and placed+unclassified, both fail", () => {
  const c = cls();
  c.unclassified.gam = " ";
  assert.throws(() => buildDefinitions(snap(), c), /without a reason: gam/);
  const d = cls();
  d.unclassified.tasks = "x";
  assert.throws(() => buildDefinitions(snap(), d), /placed AND unclassified: tasks/);
});

test("expected tools drop deprecated aliases and strip the own-server prefix once", () => {
  assert.deepEqual(expectedTools({ id: "viewport", tool_names: ["hydrate", "viewport_hydrate", "viewport_x"], deprecated_tool_names: ["viewport_hydrate"] }), ["hydrate", "x"]);
  assert.deepEqual(expectedTools({ id: "a", tool_names: ["a_b", "b"], deprecated_tool_names: [] }), ["b"]);
});

test("plan is deterministic and its counts add up", () => {
  const a = JSON.stringify(buildPlan(manifest(), snap()));
  assert.equal(a, JSON.stringify(buildPlan(manifest(), snap())));
  const p = JSON.parse(a);
  assert.equal(p.counts.unclassified, 9);
  assert.equal(p.counts.recreate + p.counts.create + p.counts.noop + p.counts.unclassified + p.counts.delete > 0, true);
  assert.equal(p.counts.client_visible_removals, p.counts.membership_remove);
  assert.ok(p.notes.some((n) => n.includes("ChittyIdentity Agents")));
});

test("plan emits create / recreate / retire rows from a perturbed snapshot", () => {
  const s = snap();
  s.servers = s.servers.filter((x) => x.id !== "ai");
  const m = manifest();
  m.servers.find((x) => x.server_id === "git").status = "retire";
  const p = buildPlan(m, s);
  assert.ok(p.rows.some((r) => r.type === "create" && r.server === "ai"));
  assert.ok(p.rows.some((r) => r.type === "delete" && r.server === "git"));
  assert.ok(p.rows.filter((r) => r.type === "membership_remove" && r.server === "git").every((r) => r.client_visible));
  assert.ok(p.rows.some((r) => r.type === "recreate" && r.server === "viewport" && r.gated_on === "D3 probe"));
  assert.ok(!p.rows.some((r) => r.type === "recreate" && r.server === "tasks"), "tasks is already oauth");
});
