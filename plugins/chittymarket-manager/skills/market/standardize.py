#!/usr/bin/env python3
"""
/market standardize — resumable marketplace + plugin packaging standardization
across GitHub organizations.

Each repo moves through four checkpointed steps:

    audit   classify the repo and evaluate standard/gate.yaml (read-only)
    plan    map failed checks to standard/remediate.yaml
    apply   open ONE pull request carrying the auto remediations (needs --apply)
    verify  re-audit; stays `waiting` until the repo is actually clean

State is written after every step, so an interrupted or rate-limited run picks
up at the first incomplete step of the first incomplete repo. Nothing here
pushes to a default branch or merges: the only write is a pull request, and
only when --apply is passed.

What this does NOT establish: a clean gate says a repo's packaging matches the
standard. It says nothing about canonical capability identity, registration or
runtime readiness; those are separate facts owned elsewhere.

Exit: 0 every in-scope repo verified · 3 work remains (pending/waiting) ·
      1 at least one step errored · 2 usage/environment.
"""

from __future__ import annotations

import argparse
import base64
import copy
import datetime
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("ERROR: PyYAML required: pip install pyyaml")

HERE = Path(__file__).resolve().parent
STANDARD_DIR = Path(os.environ.get("MARKET_STANDARD_DIR", HERE / "standard"))
STEPS = ["audit", "plan", "apply", "verify"]
DONE = {"ok", "n/a"}
PROBE = [
    ".claude-plugin/plugin.json",
    ".claude-plugin/marketplace.json",
    ".claude/settings.json",
    ".mcp.json",
    "CLAUDE.md",
    "AGENTS.md",
]
# Reported by pattern name only. A matched value is never printed or stored.
SECRET_PATTERNS = {
    "anthropic-key": r"sk-ant-[A-Za-z0-9_-]{20,}",
    "github-token": r"(gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,})",
    "aws-access-key": r"AKIA[0-9A-Z]{16}",
    "slack-token": r"xox[baprs]-[A-Za-z0-9-]{10,}",
    "neon-api-key": r"napi_[a-z0-9]{30,}",
    "private-key": r"-----BEGIN [A-Z ]*PRIVATE KEY-----",
    "literal-credential-field": (
        r"(?i)\"[a-z_-]*(authorization|api[_-]?key|token|secret|password)[a-z_-]*\""
        r"\s*:\s*\"(?!\$\{)[^\"$]{16,}\""
    ),
}


class Unknown(Exception):
    """A check that could not be evaluated. Never counted as pass or fail."""


def now() -> str:
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


# --------------------------------------------------------------------------- #
# Sources: where repos and files come from, and where pull requests go.
# --------------------------------------------------------------------------- #


class FixtureSource:
    """Offline source for tests and dry rehearsal: <root>/<org>/<repo>/<files>."""

    def __init__(self, root: Path):
        self.root = Path(root)

    def list_repos(self, org):
        d = self.root / org
        if not d.is_dir():
            raise RuntimeError(f"fixture org not found: {org}")
        out = []
        for r in sorted(p for p in d.iterdir() if p.is_dir()):
            meta = {"name": r.name, "archived": False, "fork": False}
            mf = r / "_repo.json"
            if mf.exists():
                meta.update(json.loads(mf.read_text()))
            out.append(meta)
        return out

    def read(self, org, repo, path):
        f = self.root / org / repo / path
        return f.read_text() if f.is_file() else None

    def _pr_file(self, org, repo):
        return self.root / "_prs" / f"{org}__{repo}.json"

    def existing_pr(self, org, repo, branch):
        f = self._pr_file(org, repo)
        return json.loads(f.read_text())["url"] if f.exists() else None

    def open_pr(self, org, repo, branch, files, title, body):
        f = self._pr_file(org, repo)
        f.parent.mkdir(parents=True, exist_ok=True)
        url = f"fixture://{org}/{repo}/pull/1"
        f.write_text(json.dumps({"url": url, "branch": branch, "title": title, "files": files}, indent=2))
        return url


class GhSource:
    """Live source over the GitHub REST API via the `gh` CLI (its own auth)."""

    def _api(self, path, method="GET", fields=None, jq=None, paginate=False):
        cmd = ["gh", "api", "-X", method, path]
        if paginate:
            cmd.append("--paginate")
        if jq:
            cmd += ["--jq", jq]
        for k, v in (fields or {}).items():
            cmd += ["-f", f"{k}={v}"]
        p = subprocess.run(cmd, capture_output=True, text=True)
        if p.returncode != 0:
            if "HTTP 404" in p.stderr:
                return None
            raise RuntimeError(f"gh api {method} {path}: {p.stderr.strip()[:300]}")
        return p.stdout

    def list_repos(self, org):
        jq = ".[] | {name, archived, fork, default_branch}"
        out = self._api(f"orgs/{org}/repos?per_page=100&type=all", jq=jq, paginate=True)
        if out is None:  # a user account, not an organization
            out = self._api(f"users/{org}/repos?per_page=100", jq=jq, paginate=True)
        if out is None:
            raise RuntimeError(f"no such org or user: {org}")
        return [json.loads(line) for line in out.splitlines() if line.strip()]

    def read(self, org, repo, path):
        out = self._api(f"repos/{org}/{repo}/contents/{path}")
        if out is None:
            return None
        d = json.loads(out)
        if isinstance(d, list) or d.get("type") != "file":
            return None
        return base64.b64decode(d.get("content", "")).decode("utf-8", "replace")

    def existing_pr(self, org, repo, branch):
        out = self._api(f"repos/{org}/{repo}/pulls?state=open&head={org}:{branch}", jq=".[0].html_url // empty")
        return (out or "").strip() or None

    def open_pr(self, org, repo, branch, files, title, body):
        base = json.loads(self._api(f"repos/{org}/{repo}"))["default_branch"]
        if self._api(f"repos/{org}/{repo}/git/ref/heads/{branch}") is None:
            sha = json.loads(self._api(f"repos/{org}/{repo}/git/ref/heads/{base}"))["object"]["sha"]
            self._api(f"repos/{org}/{repo}/git/refs", "POST", {"ref": f"refs/heads/{branch}", "sha": sha})
        for path, content in files.items():
            fields = {
                "message": f"{title} ({path})",
                "content": base64.b64encode(content.encode()).decode(),
                "branch": branch,
            }
            cur = self._api(f"repos/{org}/{repo}/contents/{path}?ref={branch}")
            if cur is not None:
                fields["sha"] = json.loads(cur)["sha"]
            self._api(f"repos/{org}/{repo}/contents/{path}", "PUT", fields)
        out = self._api(
            f"repos/{org}/{repo}/pulls", "POST", {"title": title, "body": body, "head": branch, "base": base}
        )
        return json.loads(out)["html_url"]


# --------------------------------------------------------------------------- #
# Check evaluators. Return a list of failure messages; empty means pass.
# --------------------------------------------------------------------------- #


def _json(ctx, path):
    raw = ctx["files"].get(path)
    if raw is None:
        return None
    try:
        return json.loads(raw)
    except json.JSONDecodeError as e:
        raise ValueError(f"{path} is not valid JSON: {e.msg} (line {e.lineno})")


def _market(ctx):
    if ctx["market"] is None:
        raise Unknown("marketplace manifest of the market repo could not be read")
    return ctx["market"]


def _gh_source(entry):
    s = entry.get("source")
    return s if isinstance(s, dict) and s.get("source") == "github" else None


def ev_json_required_keys(ctx, c):
    d = _json(ctx, c["path"])
    if d is None:
        return [f"{c['path']} missing"]
    return [f"{c['path']} missing key: {k}" for k in c["keys"] if not d.get(k)]


def ev_json_regex(ctx, c):
    d = _json(ctx, c["path"])
    v = (d or {}).get(c["key"])
    if v is None:
        return []  # absence is the required-keys check's finding
    return [] if re.match(c["pattern"], str(v)) else [f"{c['path']} {c['key']}={v!r} does not match {c['pattern']}"]


def ev_file_absent(ctx, c):
    return [f"{c['path']} present"] if ctx["files"].get(c["path"]) is not None else []


def ev_no_inline_secrets(ctx, c):
    out = []
    for path in c["paths"]:
        raw = ctx["files"].get(path) or ""
        out += [f"{path}: matches {name}" for name, pat in SECRET_PATTERNS.items() if re.search(pat, raw)]
    return out


def ev_marketplace_registered(ctx, c):
    d = _json(ctx, c["path"])
    if d is None:
        return [f"{c['path']} missing"]
    entry = (d.get("extraKnownMarketplaces") or {}).get(ctx["cfg"]["marketplace_name"])
    repo = ((entry or {}).get("source") or {}).get("repo", "")
    if repo.lower() != ctx["cfg"]["market_repo"].lower():
        return [f"{c['path']} does not register {ctx['cfg']['marketplace_name']} from {ctx['cfg']['market_repo']}"]
    return []


def ev_enabled_plugins_resolve(ctx, c):
    d = _json(ctx, c["path"])
    suffix = "@" + ctx["cfg"]["marketplace_name"]
    refs = [k for k in ((d or {}).get("enabledPlugins") or {}) if k.endswith(suffix)]
    if not refs:
        return []
    names = {p.get("name") for p in _market(ctx).get("plugins", [])}
    return [f"enabledPlugins {r} is not in the marketplace" for r in refs if r[: -len(suffix)] not in names]


def _own_entry(ctx):
    me = f"{ctx['org']}/{ctx['repo']}".lower()
    for p in _market(ctx).get("plugins", []):
        s = _gh_source(p)
        if s and s.get("repo", "").lower() == me:
            return p
    return None


def ev_listed_in_marketplace(ctx, c):
    return [] if _own_entry(ctx) else [f"not listed in {ctx['cfg']['market_repo']}"]


def ev_version_matches_marketplace(ctx, c):
    entry, d = _own_entry(ctx), _json(ctx, ".claude-plugin/plugin.json")
    if not entry or not d or entry.get("version") == d.get("version"):
        return []
    return [f"plugin.json version {d.get('version')} != marketplace entry {entry.get('version')}"]


def ev_marketplace_entries_complete(ctx, c):
    d = _json(ctx, ".claude-plugin/marketplace.json") or {}
    return [
        f"plugin entry {p.get('name', '?')} missing {k}"
        for p in d.get("plugins", [])
        for k in c["keys"]
        if not p.get(k)
    ]


def ev_marketplace_sources_resolve(ctx, c):
    d = _json(ctx, ".claude-plugin/marketplace.json") or {}
    out = []
    for p in d.get("plugins", []):
        s = _gh_source(p)
        if not s:
            continue
        repo = s.get("repo", "").lower()
        if repo.split("/")[0] in ctx["orgs_seen"] and repo not in ctx["inventory"]:
            out.append(f"plugin entry {p.get('name')}: source repo {s.get('repo')} not found in its org")
    return out


def ev_marketplace_sources_pinned(ctx, c):
    d = _json(ctx, ".claude-plugin/marketplace.json") or {}
    return [
        f"plugin entry {p.get('name')}: source {s.get('repo')} has no ref or sha"
        for p in d.get("plugins", [])
        if (s := _gh_source(p)) and not (s.get("ref") or s.get("sha"))
    ]


EVALUATORS = {k[3:]: v for k, v in globals().items() if k.startswith("ev_")}


# --------------------------------------------------------------------------- #
# Run
# --------------------------------------------------------------------------- #


def load_standard():
    docs, h = {}, hashlib.sha256()
    for name in ("targets", "gate", "remediate"):
        raw = (STANDARD_DIR / f"{name}.yaml").read_bytes()
        h.update(raw)
        docs[name] = yaml.safe_load(raw)
    unknown = {c["kind"] for c in docs["gate"]["checks"]} - set(EVALUATORS)
    if unknown:
        sys.exit(f"ERROR: gate.yaml uses unknown check kinds: {sorted(unknown)}")
    missing = {c["remediation"] for c in docs["gate"]["checks"]} - set(docs["remediate"]["remediations"])
    if missing:
        sys.exit(f"ERROR: gate.yaml names remediations absent from remediate.yaml: {sorted(missing)}")
    return docs, "sha256:" + h.hexdigest()


def state_dir(run_id):
    base = os.environ.get("MARKET_STATE_DIR") or os.path.join(
        os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"), "chittymarket"
    )
    return Path(base) / "standardize" / run_id


def load_state(run_id):
    f = state_dir(run_id) / "state.json"
    return json.loads(f.read_text()) if f.exists() else None


def save_state(run_id, state):
    d = state_dir(run_id)
    d.mkdir(parents=True, exist_ok=True)
    state["updated_at"] = now()
    fd, tmp = tempfile.mkstemp(dir=d, prefix=".state-")
    with os.fdopen(fd, "w") as fh:
        json.dump(state, fh, indent=2, sort_keys=True)
    os.replace(tmp, d / "state.json")


def fill(value, cfg):
    """Substitute {market_repo}/{marketplace_name} through a nested value."""
    if isinstance(value, str):
        # Plain replacement, not str.format: summaries legitimately contain ${ENV}.
        return value.replace("{market_repo}", cfg["market_repo"]).replace("{marketplace_name}", cfg["marketplace_name"])
    if isinstance(value, dict):
        return {fill(k, cfg): fill(v, cfg) for k, v in value.items()}
    if isinstance(value, list):
        return [fill(v, cfg) for v in value]
    return value


def deep_merge(base, extra):
    out = copy.deepcopy(base)
    for k, v in extra.items():
        out[k] = deep_merge(out[k], v) if isinstance(v, dict) and isinstance(out.get(k), dict) else copy.deepcopy(v)
    return out


class Runner:
    def __init__(self, args, source):
        self.args, self.src = args, source
        self.std, self.std_hash = load_standard()
        self.cfg = self.std["targets"]
        self.remed = self.std["remediate"]["remediations"]
        self._market = "unread"

    # ---- context ---------------------------------------------------------- #

    def market(self):
        if self._market == "unread":
            org, repo = self.cfg["market_repo"].split("/")
            try:
                raw = self.src.read(org, repo, ".claude-plugin/marketplace.json")
                self._market = json.loads(raw) if raw else None
            except Exception:
                self._market = None
        return self._market

    def evaluate(self, org, repo):
        files = {p: self.src.read(org, repo, p) for p in PROBE}
        if f"{org}/{repo}".lower() == self.cfg["market_repo"].lower():
            cls = "market"
        elif files[".claude-plugin/plugin.json"] is not None:
            cls = "plugin"
        elif any(files[p] is not None for p in ("CLAUDE.md", "AGENTS.md", ".claude/settings.json")):
            cls = "consumer"
        else:
            cls = "none"
        st = self.state
        ctx = {
            "org": org,
            "repo": repo,
            "files": files,
            "cfg": self.cfg,
            "market": self.market(),
            "orgs_seen": {o.lower() for o, v in st["orgs"].items() if v.get("discover", {}).get("status") == "ok"},
            "inventory": {f"{o}/{r}".lower() for o, v in st["orgs"].items() for r in v.get("repos", {})},
        }
        findings = []
        for c in self.std["gate"]["checks"]:
            if cls not in c["applies_to"]:
                continue
            try:
                msgs, status = EVALUATORS[c["kind"]](ctx, c), "fail"
            except Unknown as e:
                msgs, status = [str(e)], "unknown"
            except ValueError as e:
                msgs, status = [str(e)], "fail"
            if msgs:
                findings.append(
                    {
                        "check": c["id"],
                        "severity": c["severity"],
                        "status": status,
                        "messages": msgs,
                        "remediation": c["remediation"],
                        "auto": bool(self.remed[c["remediation"]].get("auto")),
                    }
                )
        return cls, findings

    # ---- steps ------------------------------------------------------------ #

    def step_audit(self, org, repo, rs):
        rs["class"], rs["findings"] = self.evaluate(org, repo)
        fails = [f for f in rs["findings"] if f["status"] == "fail"]
        rs["gate"] = "fail" if any(f["severity"] == "error" for f in fails) else "pass"
        return "ok", f"class={rs['class']} gate={rs['gate']} findings={len(fails)}"

    def step_plan(self, org, repo, rs):
        fails = [f for f in rs["findings"] if f["status"] == "fail"]
        if not fails:
            return "n/a", "nothing to remediate"
        lines = [f"# Remediation plan: {org}/{repo}", "", f"Class: {rs['class']} · Gate: {rs['gate']}", ""]
        for f in fails:
            r = self.remed[f["remediation"]]
            lines += [
                f"## {f['check']} ({f['severity']})",
                *[f"- {m}" for m in f["messages"]],
                f"- Remediation `{f['remediation']}` ({'auto: pull request' if f['auto'] else 'manual'}): "
                + fill(r["summary"], self.cfg),
                "",
            ]
        d = state_dir(self.args.run_id) / "plans"
        d.mkdir(parents=True, exist_ok=True)
        (d / f"{org}__{repo}.md").write_text("\n".join(lines))
        return "ok", f"{len(fails)} item(s), {sum(f['auto'] for f in fails)} auto"

    def step_apply(self, org, repo, rs):
        auto = [f for f in rs["findings"] if f["status"] == "fail" and f["auto"]]
        if not auto:
            return "n/a", "no auto remediation"
        if not self.args.apply:
            return "pending", "dry-run: re-run with --apply to open the pull request"
        branch = self.std["remediate"]["branch"]
        url = self.src.existing_pr(org, repo, branch)
        if not url:
            files = {}
            for f in auto:
                r = self.remed[f["remediation"]]
                if r["action"] != "merge_json":
                    raise RuntimeError(f"unsupported auto action: {r['action']}")
                raw = files.get(r["path"]) or self.src.read(org, repo, r["path"])
                cur = json.loads(raw) if raw else {}
                files[r["path"]] = json.dumps(deep_merge(cur, fill(r["value"], self.cfg)), indent=2) + "\n"
            body = "Opened by `/market standardize` (gate.yaml {}).\n\n{}".format(
                self.std_hash[:19],
                "\n".join(f"- `{f['check']}`: {fill(self.remed[f['remediation']]['summary'], self.cfg)}" for f in auto),
            )
            url = self.src.open_pr(org, repo, branch, files, "chore: standardize ChittyMarket packaging", body)
        rs["pr"] = url
        return "ok", url

    def step_verify(self, org, repo, rs):
        _, findings = self.evaluate(org, repo)
        rs["findings"] = findings  # the report must show the repo as it is now
        errs = [f for f in findings if f["status"] == "fail" and f["severity"] == "error"]
        rs["gate"] = "fail" if errs else "pass"
        left = [f for f in findings if f["status"] == "fail" and (f["severity"] == "error" or f["auto"])]
        rs["remaining"] = [f["check"] for f in left]
        if not left:
            return "ok", "clean"
        why = "pull request not merged yet" if rs.get("pr") else "manual remediation outstanding"
        return "waiting", f"{why}: {', '.join(rs['remaining'])}"

    # ---- driver ----------------------------------------------------------- #

    def run(self):
        a = self.args
        st = load_state(a.run_id) or {"schema": 1, "run_id": a.run_id, "created_at": now(), "orgs": {}}
        self.state = st
        if st.get("standard_hash") not in (None, self.std_hash):
            # The standard changed: earlier verdicts are about a different bar.
            # `apply` is kept so an already-opened pull request is not duplicated.
            for org in st["orgs"].values():
                for rs in org.get("repos", {}).values():
                    for s in ("audit", "plan", "verify"):
                        rs.get("steps", {}).pop(s, None)
            print("standard changed since last run: re-auditing")
        st["standard_hash"] = self.std_hash
        orgs = a.orgs.split(",") if a.orgs else self.cfg["orgs"]

        for org in orgs:
            o = st["orgs"].setdefault(org, {"repos": {}})
            if o.get("discover", {}).get("status") == "ok" and not a.rediscover:
                continue
            try:
                for meta in self.src.list_repos(org):
                    rs = o["repos"].setdefault(meta["name"], {"steps": {}})
                    skip = self.cfg.get("skip", {})
                    rs["skipped"] = (
                        "archived" if meta.get("archived") and skip.get("archived")
                        else "fork" if meta.get("fork") and skip.get("forks") else None
                    )
                o["discover"] = {"status": "ok", "at": now(), "count": len(o["repos"])}
                print(f"discover {org}: {len(o['repos'])} repo(s)")
            except Exception as e:
                o["discover"] = {"status": "error", "at": now(), "error": str(e)[:300]}
                print(f"discover {org}: ERROR {e}", file=sys.stderr)
            save_state(a.run_id, st)

        worked = 0
        for org in orgs:
            for repo, rs in sorted(st["orgs"][org]["repos"].items()):
                if a.only and a.only.lower() != f"{org}/{repo}".lower():
                    continue
                if rs.get("skipped"):
                    continue
                steps = rs.setdefault("steps", {})
                if all(steps.get(s, {}).get("status") in DONE for s in STEPS):
                    continue
                if a.max and worked >= a.max:
                    continue
                worked += 1
                for s in STEPS:
                    if steps.get(s, {}).get("status") in DONE:
                        continue
                    try:
                        status, note = getattr(self, f"step_{s}")(org, repo, rs)
                    except Exception as e:
                        status, note = "error", str(e)[:300]
                    steps[s] = {"status": status, "at": now(), "note": note}
                    save_state(a.run_id, st)
                    print(f"{org}/{repo} {s}: {status} — {note}")
                    if status not in DONE:
                        break
                    if s == "audit" and rs["class"] == "none":
                        for rest in STEPS[1:]:
                            steps[rest] = {"status": "n/a", "at": now(), "note": "not Claude-facing"}
                        save_state(a.run_id, st)
                        break
        return summarize(st)


def summarize(st, quiet=False):
    counts, errors, open_work = {}, 0, 0
    for org, o in st["orgs"].items():
        if o.get("discover", {}).get("status") != "ok":
            errors += 1
        for rs in o.get("repos", {}).values():
            if rs.get("skipped"):
                key = "skipped"
            else:
                steps = rs.get("steps", {})
                statuses = [steps.get(s, {}).get("status", "pending") for s in STEPS]
                if "error" in statuses:
                    key, errors = "error", errors + 1
                elif all(s in DONE for s in statuses):
                    key = "verified"
                else:
                    first = next(s for s, v in zip(STEPS, statuses) if v not in DONE)
                    key, open_work = f"{first}:{steps.get(first, {}).get('status', 'pending')}", open_work + 1
            counts.setdefault(org, {}).setdefault(key, 0)
            counts[org][key] += 1
    if not quiet:
        print(f"\nrun {st['run_id']} · standard {st.get('standard_hash', '?')[:19]} · updated {st.get('updated_at', '-')}")
        for org, c in counts.items():
            print(f"  {org}: " + ", ".join(f"{k}={v}" for k, v in sorted(c.items())))
    return 1 if errors else 3 if open_work else 0


def cmd_report(st):
    print(f"# ChittyMarket packaging standardization — run {st['run_id']}\n")
    for org, o in sorted(st["orgs"].items()):
        rows = []
        for repo, rs in sorted(o.get("repos", {}).items()):
            fails = [f for f in rs.get("findings", []) if f["status"] == "fail"]
            if not fails and not rs.get("pr"):
                continue
            v = rs.get("steps", {}).get("verify", {}).get("status", "-")
            rows.append(f"### {org}/{repo} — {rs.get('class')} · gate {rs.get('gate')} · verify {v}")
            if rs.get("pr"):
                rows.append(f"- PR: {rs['pr']}")
            rows += [f"- `{f['check']}` ({f['severity']}, {'auto' if f['auto'] else 'manual'}): {'; '.join(f['messages'])}" for f in fails]
            rows.append("")
        print(f"## {org} ({o.get('discover', {}).get('status', 'not discovered')})\n")
        print("\n".join(rows) if rows else "No findings.\n")


def cmd_reset(args, st):
    n = 0
    for org, o in st["orgs"].items():
        for repo, rs in o.get("repos", {}).items():
            if args.only and args.only.lower() != f"{org}/{repo}".lower():
                continue
            for s in [args.step] if args.step else STEPS:
                n += rs.get("steps", {}).pop(s, None) is not None
        if not args.only and not args.step:
            o.pop("discover", None)
    save_state(args.run_id, st)
    print(f"reset {n} step record(s)")


def main():
    ap = argparse.ArgumentParser(prog="market standardize", description=__doc__.split("\n\n")[0])
    ap.add_argument("command", nargs="?", default="run", choices=["run", "status", "report", "reset"])
    ap.add_argument("--run-id", default="default", help="state namespace; the same id resumes the same run")
    ap.add_argument("--orgs", help="comma-separated override of targets.yaml orgs")
    ap.add_argument("--only", metavar="ORG/REPO", help="limit to one repo")
    ap.add_argument("--max", type=int, default=0, help="process at most N repos this invocation")
    ap.add_argument("--apply", action="store_true", help="open pull requests for auto remediations")
    ap.add_argument("--rediscover", action="store_true", help="re-list repos for already-discovered orgs")
    ap.add_argument("--step", choices=STEPS, help="reset: only this step")
    ap.add_argument("--fixtures", help="read repos from a directory instead of GitHub")
    args = ap.parse_args()

    if args.command == "run":
        src = FixtureSource(args.fixtures) if args.fixtures else GhSource()
        sys.exit(Runner(args, src).run())
    st = load_state(args.run_id)
    if st is None:
        sys.exit(f"ERROR: no state for run '{args.run_id}' at {state_dir(args.run_id)}")
    if args.command == "status":
        sys.exit(summarize(st))
    if args.command == "report":
        cmd_report(st)
    else:
        cmd_reset(args, st)


if __name__ == "__main__":
    main()
