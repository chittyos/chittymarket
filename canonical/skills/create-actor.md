---
name: create-actor
canon_uri: chittycanon://core/services/chittymarket#skills/create-actor
description: Scaffold, repair, or standardize ChittyOS Python actors under chittyentity/chittyactors/{name} using the canonical chittysdks/actor-base package and current Apify/Docker conventions. Use when creating a new ChittyActor, converting an ad hoc scraper/executor into a compliant actor, fixing actor structure or deployment packaging, or preparing an Actor for Apify monorepo deployment. Do not use to create autonomous policy-bearing agents; those belong under chittyagents/.
kind: skill
plugin: chittyos-core
runtimes:
  - claude-code
  - codex
  - skills-sh
classification:
  - development
  - actor
  - apify
canonical_capability_ref: "chittycanon://capability/build/create-actor"
overlay:
  title: "Create ChittyActor"
  capability_group: "build"
  group_assignment_source: "capability"
  execution_class: "@chitty/workspace"
  canonical_version: "1.0.0"
  projection_version_policy: "inherit-canonical"
  ontology:
    primary: ["A"]
    secondary: ["T"]
  authority:
    requires_chittyid: false
  execution:
    default_surface: "workspace"
    local_allowed: true
    context_cost: "low"
    mutation_risk: "medium"
  discovery:
    indexable: true
    session_index: "hidden"
    ambient_by_intent: true
    verbs: ["create actor", "scaffold actor", "build apify actor", "create chittyactor", "repair actor"]
    fallback_search: true
  auth_flow:
    mode: "delegated"
    stores_credentials_in: "none"
    fail_closed_if_unavailable: true
  runtime_exclusions: {}
  phase0_audit:
    job_to_be_done: "generate"
    environmental_footprint: "filesystem-local"
    evidentiary_risk: "none"
    advisory_disposition: "skill"
  legacy_category: "development"
  visibility: "recommended"
  access: "readwrite"
  compatible_channels: ["claude_code", "chatgpt", "codex"]
  source_links:
    - https://github.com/chittyos/chittyentity/issues/690
    - https://github.com/chittyos/chittyentity/pull/889
---

# Create ChittyActor

Canonical skill definition for scaffolding bounded ChittyActors from the reusable
`chittysdks/actor-base` substrate.

The executable skill projection lives at `skills/create-actor/`.
