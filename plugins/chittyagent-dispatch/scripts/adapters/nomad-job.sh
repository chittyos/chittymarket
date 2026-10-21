#!/usr/bin/env bash
# nomad-job.sh — project a canonical `kind: job` definition into a Nomad JSON
# job spec (the {"Job": {...}} shape `nomad job run -json` accepts).
#
# Usage:
#   nomad-job.sh <canonical-path> <output-path>
#
# Canonical frontmatter shape (kind: job) — see canonical/jobs/README.md
# (first concrete entry: canonical/jobs/cadvisor.md).
#
# The output mirrors what `nomad job inspect` returns for the same job: the
# server-filled defaults (Region, Namespace, NodePool, Update, Identity,
# LogConfig, KillTimeout, the task-level copy of the group RestartPolicy, ...)
# are emitted explicitly so a projection can be compared field-for-field
# against a live job. Job.Meta carries canon_uri and canonical_sha (sha256 of
# the canonical file) so a reconciler can tell projections apart.
#
# Secrets are NAMES only and are emitted as Env placeholders `${NAME}`; a
# secret given as a `key: value` mapping is rejected, so a value can never
# reach the projection.
#
# Strict: invalid input => exit 2. Output is deterministic (sorted keys,
# 2-space indent, trailing newline, no timestamps).
set -euo pipefail

canonical="${1:-}"
out="${2:-}"
[ -n "$canonical" ] && [ -n "$out" ] || { echo "usage: $0 <canonical-path> <output-path>" >&2; exit 2; }
[ -f "$canonical" ] || { echo "canonical not found: $canonical" >&2; exit 2; }

mkdir -p "$(dirname "$out")"

python3 - "$canonical" "$out" <<'PY'
import copy, hashlib, json, re, sys
import yaml

canonical_path, out_path = sys.argv[1], sys.argv[2]


def fail(msg):
    sys.stderr.write(f"[nomad-job] {canonical_path}: {msg}\n")
    sys.exit(2)


raw = open(canonical_path, "rb").read()
src = raw.decode("utf-8")
m = re.match(r"^---\n(.*?\n)---\n", src, re.DOTALL)
if not m:
    fail("no frontmatter")
try:
    fm = yaml.safe_load(m.group(1)) or {}
except yaml.YAMLError as e:
    fail(f"frontmatter is not valid YAML: {e}")

for req in ("name", "canon_uri", "kind"):
    if not fm.get(req):
        fail(f"missing required field: {req}")
if fm["kind"] != "job":
    fail(f"nomad-job adapter requires kind=job, got kind={fm['kind']!r}")
job = fm.get("job")
if not isinstance(job, dict):
    fail("missing required `job` mapping")

JOB_TYPES = ("system", "service", "batch")
jtype = job.get("type")
if jtype not in JOB_TYPES:
    fail(f"job.type must be one of {list(JOB_TYPES)}, got {jtype!r}")
dcs = job.get("datacenters")
if not isinstance(dcs, list) or not dcs or not all(isinstance(d, str) for d in dcs):
    fail("job.datacenters must be a non-empty list of strings")

PLACEMENT = {"micro": "^chittymicro-", "mini": "^chittymini-", "any": None}
placement = job.get("placement", "any")
if placement not in PLACEMENT:
    fail(f"unknown placement {placement!r}; must be one of {sorted(PLACEMENT)}")

UNITS = {"ns": 1, "us": 10**3, "ms": 10**6, "s": 10**9, "m": 60 * 10**9, "h": 3600 * 10**9}


def duration(v, field):
    if isinstance(v, int) and not isinstance(v, bool):
        return v
    mm = re.fullmatch(r"(\d+)(ns|us|ms|s|m|h)", str(v))
    if not mm:
        fail(f"{field}: invalid duration {v!r} (use e.g. 15s, 30m, 1h)")
    return int(mm.group(1)) * UNITS[mm.group(2)]


def check_image(img, field):
    if not isinstance(img, str) or not img:
        fail(f"{field}: image is required")
    if "@sha256:" in img:
        return
    last = img.rsplit("/", 1)[-1]
    if ":" not in last:
        fail(f"{field}: image {img!r} is untagged; pin a tag or digest")
    if last.rsplit(":", 1)[1] == "latest":
        fail(f"{field}: image {img!r} uses tag 'latest'; pin a tag or digest")


SECRET_NAME = re.compile(r"^[A-Z][A-Z0-9_]*$")

# Defaults Nomad fills in server-side (taken from `nomad job inspect` output).
UPDATE_JOB = {"AutoPromote": False, "AutoRevert": False, "Canary": 0, "HealthCheck": "",
              "HealthyDeadline": 0, "MaxParallel": 1, "MinHealthyTime": 0,
              "ProgressDeadline": 0, "Stagger": 30 * 10**9}
UPDATE_GROUP = {"AutoPromote": False, "AutoRevert": False, "Canary": 0, "HealthCheck": "checks",
                "HealthyDeadline": 300 * 10**9, "MaxParallel": 1, "MinHealthyTime": 10 * 10**9,
                "ProgressDeadline": 600 * 10**9, "Stagger": 30 * 10**9}
IDENTITY = {"Audience": ["nomadproject.io"], "ChangeMode": "", "ChangeSignal": "", "Env": False,
            "File": False, "Filepath": "", "Name": "default", "ServiceName": "", "TTL": 0}
LOG_CONFIG = {"Disabled": False, "MaxFileSizeMB": 10, "MaxFiles": 10}
has_update = jtype != "batch"  # Nomad rejects an update block on batch jobs

groups_in = job.get("groups")
if not isinstance(groups_in, list) or not groups_in:
    fail("job.groups must be a non-empty list")

groups = []
for gi, g in enumerate(groups_in):
    gf = f"job.groups[{gi}]"
    if not isinstance(g, dict) or not g.get("name"):
        fail(f"{gf}: must be a mapping with a name")
    group = {
        "Count": int(g.get("count", 1)),
        "EphemeralDisk": {"Migrate": False, "SizeMB": int(g.get("ephemeral_disk_mb", 300)), "Sticky": False},
        "Name": g["name"],
        "PreventRescheduleOnLost": False,
    }
    restart = None
    if g.get("restart") is not None:
        r = g["restart"]
        if not isinstance(r, dict):
            fail(f"{gf}.restart must be a mapping")
        restart = {"Attempts": int(r.get("attempts", 2)),
                   "Delay": duration(r.get("delay", "15s"), f"{gf}.restart.delay"),
                   "Interval": duration(r.get("interval", "30m"), f"{gf}.restart.interval"),
                   "Mode": r.get("mode", "fail"), "RenderTemplates": False}
        group["RestartPolicy"] = restart
    ports = g.get("ports") or []
    if ports:
        reserved, dynamic = [], []
        for pi, p in enumerate(ports):
            if not isinstance(p, dict) or not p.get("label"):
                fail(f"{gf}.ports[{pi}]: must be a mapping with a label")
            port = {"HostNetwork": "default", "Label": p["label"], "To": int(p.get("to", 0)),
                    "Value": int(p.get("static", 0))}
            (reserved if "static" in p else dynamic).append(port)
        net = {}
        if reserved:
            net["ReservedPorts"] = reserved
        if dynamic:
            net["DynamicPorts"] = dynamic
        group["Networks"] = [net]
    if has_update:
        group["Update"] = copy.deepcopy(UPDATE_GROUP)

    tasks_in = g.get("tasks")
    if not isinstance(tasks_in, list) or not tasks_in:
        fail(f"{gf}.tasks must be a non-empty list")
    tasks = []
    for ti, t in enumerate(tasks_in):
        tf = f"{gf}.tasks[{ti}]"
        if not isinstance(t, dict) or not t.get("name"):
            fail(f"{tf}: must be a mapping with a name")
        driver = t.get("driver", "docker")
        check_image(t.get("image"), tf)
        config = {"image": t["image"]}
        for key in ("ports", "privileged", "volumes", "args"):
            if key in t:
                config[key] = t[key]
        env = t.get("env") or {}
        if not isinstance(env, dict):
            fail(f"{tf}.env must be a mapping")
        env = {str(k): str(v) for k, v in env.items()}
        secrets = t.get("secrets") or []
        if not isinstance(secrets, list):
            fail(f"{tf}.secrets must be a list of secret NAMES, never a key: value mapping")
        for s in secrets:
            if not isinstance(s, str):
                fail(f"{tf}.secrets entries must be bare secret NAMES, never key: value mappings")
            if not SECRET_NAME.match(s):
                fail(f"{tf}.secrets: {s!r} is not a secret name (expected UPPER_SNAKE_CASE)")
            if s in env:
                fail(f"{tf}: {s!r} is both an env var and a secret")
            env[s] = "${" + s + "}"
        res = t.get("resources") or {}
        task = {
            "Config": config,
            "Driver": driver,
            "Identity": copy.deepcopy(IDENTITY),
            "KillSignal": "",
            "KillTimeout": 5 * 10**9,
            "Kind": "",
            "Leader": False,
            "LogConfig": copy.deepcopy(LOG_CONFIG),
            "Name": t["name"],
            "Resources": {"CPU": int(res.get("cpu", 100)), "Cores": 0, "DiskMB": 0, "IOPS": 0,
                          "MemoryMB": int(res.get("memory_mb", 300)), "MemoryMaxMB": 0, "SecretsMB": 0},
            "ShutdownDelay": 0,
            "User": "",
        }
        if env:
            task["Env"] = env
        if restart is not None:
            task["RestartPolicy"] = copy.deepcopy(restart)
        tasks.append(task)
    group["Tasks"] = tasks
    groups.append(group)

out_job = {
    "AllAtOnce": False,
    "Datacenters": list(dcs),
    "ID": fm["name"],
    "Meta": {"canon_uri": fm["canon_uri"], "canonical_sha": hashlib.sha256(raw).hexdigest()},
    "Name": fm["name"],
    "Namespace": "default",
    "NodePool": "default",
    "Priority": int(job.get("priority", 50)),
    "Region": "global",
    "TaskGroups": groups,
    "Type": jtype,
}
if PLACEMENT[placement]:
    out_job["Constraints"] = [{"LTarget": "${node.unique.name}", "Operand": "regexp",
                               "RTarget": PLACEMENT[placement]}]
if has_update:
    out_job["Update"] = copy.deepcopy(UPDATE_JOB)

with open(out_path, "w", encoding="utf-8") as fh:
    fh.write(json.dumps({"Job": out_job}, indent=2, sort_keys=True) + "\n")
PY

echo "[nomad-job] projected $canonical -> $out"
