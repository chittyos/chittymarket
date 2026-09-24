---
name: furnished-condos-design
description: Apply the canonical Furnished-Condos.com design system to branded interfaces, documents, signage, print assets, marketing materials, and production UI. Preserve the immutable canonical [ ƒ ] SVG and exact brand tokens; use for brand identity, print/signage, visual asset, and design-system compliance work.
canon_uri: chittycanon://core/services/chittymarket#skills/furnished-condos-design
kind: skill
classification:
  - design
  - brand
  - visual-system
  - print
runtimes:
  - claude-code
  - codex
  - chatgpt
plugin: furnished-condos-design
canonical_capability_ref: "chittycanon://capability/design/furnished-condos-design"
overlay:
  title: "Furnished-Condos.com Design"
  capability_group: "design"
  group_assignment_source: "explicit"
  execution_class: "@chitty/advisory"
  canonical_version: "1.0.0"
  projection_version_policy: "inherit-canonical"
  ontology:
    primary: ["P"]
    secondary: ["A"]
  authority:
    requires_chittyid: false
  execution:
    default_surface: "chatgpt"
    local_allowed: true
    context_cost: "medium"
    mutation_risk: "low"
  discovery:
    indexable: true
    session_index: "summary"
    ambient_by_intent: true
    verbs: ["design", "brand", "style", "print", "signage"]
    fallback_search: true
  auth_flow:
    mode: "local-only"
    stores_credentials_in: "n/a"
    fail_closed_if_unavailable: false
  runtime_exclusions: {}
  phase0_audit:
    job_to_be_done: "create"
    environmental_footprint: "artifact"
    evidentiary_risk: "none"
    advisory_disposition: "local-only"
  legacy_category: "design"
  deprecated_aliases: []
  visibility: "recommended"
  access: "readwrite"
  compatible_channels: ["claude_code", "claude_ai", "claude_desktop", "chatgpt", "codex"]
---

# Furnished-Condos.com Design

Canonical source for the `furnished-condos-design` skill.

The runtime projection MUST carry the supplied `f-canonical-mark.svg` unchanged and preserve the design rules bundled with the plugin. The canonical mark is immutable: no redraw, recolor, reconstruction, tracing, geometry/viewBox changes, cropping, or optical recentering.

Use the packaged runtime skill for detailed workflow, tokens, QA, signage/QR rules, and brand references.
