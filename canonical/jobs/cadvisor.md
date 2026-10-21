---
name: cadvisor
canon_uri: chittycanon://core/services/chittyserv#jobs/cadvisor
kind: job
plugin: chittyos-core
runtimes: [nomad]
description: |
  cAdvisor container-metrics exporter, one per Nomad client in the homelab
  datacenter. Ported from chittyos/chittyserv nomad/cadvisor.nomad.json (the
  live spec); placement `any` keeps that spec's no-constraint behaviour.
job:
  type: system
  datacenters: [homelab]
  priority: 50
  placement: any
  groups:
    - name: monitor
      count: 1
      ephemeral_disk_mb: 300
      ports:
        - {label: http, static: 8081, to: 8080}
      restart: {attempts: 2, delay: 15s, interval: 30m, mode: fail}
      tasks:
        - name: cadvisor
          driver: docker
          image: gcr.io/cadvisor/cadvisor:v0.49.1
          ports: [http]
          privileged: false
          volumes:
            - /:/rootfs:ro
            - /var/run:/var/run:ro
            - /sys:/sys:ro
            - /var/lib/docker/:/var/lib/docker:ro
            - /dev/disk/:/dev/disk:ro
          resources: {cpu: 200, memory_mb: 256}
---

# cadvisor

Exposes container metrics on port 8081 of every Nomad client (`system` job).
Projected to a Nomad JSON job spec by `chittyagent-dispatch` (`runtime: nomad`).
