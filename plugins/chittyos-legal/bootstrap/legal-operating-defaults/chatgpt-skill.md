# Legal Operating Defaults — ChatGPT skill entry

**Capability:** `legal-operating-defaults` (ChittyMarket, plugin `chittyos-legal`)
**Canonical:** `chittycanon://core/services/chittymarket#skills/legal-operating-defaults`
**Canonical source:** `canonical/skills/legal-operating-defaults.md` @ `394083c00f70c5306f4aeef39962af6743532e93`

Legal, litigation, evidentiary, dispute, court-record, or legal-governance work — including
requests that sound administrative — loads `legal-operating-defaults` BEFORE acting on the request. It governs
evidence handling, the factual lifecycle, provenance, matter isolation, and privilege.

This file is a pointer. It states no rules of its own. Where it and the canonical document
appear to differ, the canonical document governs and this file is drift.

Dependency routing is defined in the canonical document; resolve dependencies when their
trigger fires, not in advance. For any code, infrastructure, or system-design work, also load
`nb-development-defaults` and apply startup-mode.

Matter facts, evidence, privileged material, strategy, work product, credentials, and
custody-sensitive hashes are never carried in this file or any other projection.
