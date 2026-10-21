# canonical/jobs — Nomad job definitions

A `kind: job` canonical projects to a Nomad JSON job spec (`{"Job": {...}}`, the
shape `nomad job run -json` accepts) via `chittyagent-dispatch`:

    runtime nomad  ->  plugins/<plugin>/nomad-jobs/<name>.nomad.json   (adapters/nomad-job.sh)

Never edit the projection; edit the canonical and run
`plugins/chittyagent-dispatch/scripts/dispatch.sh sync <name>`.

## Frontmatter contract

```yaml
name: cadvisor                                   # Job ID and Name
canon_uri: chittycanon://core/services/chittyserv#jobs/cadvisor
kind: job
plugin: chittyos-core                            # existing plugin that homes the projection
runtimes: [nomad]
description: |
  ...
job:
  type: system | service | batch                 # Nomad Type (required)
  datacenters: [homelab]                         # required, non-empty
  priority: 50                                   # default 50
  placement: micro | mini | any                  # default any
  groups:                                        # required, non-empty
    - name: monitor
      count: 1                                   # default 1
      ephemeral_disk_mb: 300                     # default 300
      ports: [{label: http, static: 8081, to: 8080}]   # static -> ReservedPorts, else DynamicPorts
      restart: {attempts: 2, delay: 15s, interval: 30m, mode: fail}
      tasks:                                     # required, non-empty
        - name: cadvisor
          driver: docker                         # default docker
          image: gcr.io/cadvisor/cadvisor:v0.49.1   # tag or @sha256 digest; never latest/untagged
          ports: [http]
          privileged: false
          volumes: [...]
          args: [...]
          env: {FOO: bar}
          secrets: [SERVICES_NEONDB_CONNECTION_STRING]   # NAMES only
          resources: {cpu: 200, memory_mb: 256}
```

## Projection rules

- `placement`: `micro` -> Constraint `${node.unique.name}` regexp `^chittymicro-`;
  `mini` -> `^chittymini-`; `any` -> no constraint.
- `secrets` are names only and are emitted as Env placeholders `NAME: "${NAME}"`.
  A secret written as `NAME: value` (mapping or list item) is rejected. The
  adapter also rejects `env:` entries whose key looks like a credential
  (`TOKEN|SECRET|PASSWORD|PASSWD|_KEY$|^KEY_|CONNECTION_STRING|DSN|CREDENTIAL|PRIVATE`,
  case-insensitive) or whose value is `scheme://user:pass@...` or over 200
  characters; list such names under `secrets:` instead. This is a guard, not a
  proof: the adapter cannot detect every secret, so do not put one in `env:`.
  Values are never delivered through this repo.
- `restart` becomes the group RestartPolicy and is copied to each task, as Nomad does.
- Durations accept `ns|us|ms|s|m|h` suffixes and are emitted in nanoseconds.
- The defaults Nomad fills in server-side (Region, Namespace, NodePool, Update,
  Identity, LogConfig, KillTimeout, zeroed Resources fields) are emitted
  explicitly, so a projection compares field-for-field with `nomad job inspect`.
  `batch` jobs get no Update block.
- `Job.Meta` carries `canon_uri` and `canonical_sha` (sha256 of the canonical
  file) so a reconciler can tell projections apart.
- Output is deterministic: sorted keys, 2-space indent, trailing newline.

## How secrets are delivered

The `${NAME}` placeholders are declarations only: Nomad does not substitute
them. At start the workload resolves each declared name from the node-local
chittyserv endpoint `http://127.0.0.1:8080/v1/credentials/<vault>/<item>/<field>`,
authenticating with the node's `CHITTY_SERV_TOKEN`. vault/item/field are derived
from the name, e.g. `SERVICES_NEONDB_CONNECTION_STRING` ->
`services/neondb/connection_string`.

Invalid input (missing `job`, `latest`/untagged image, unknown placement,
secret values) exits 2 with a message naming the field.

Tests: `plugins/chittyagent-dispatch/scripts/test-nomad-job-adapter.sh`.
