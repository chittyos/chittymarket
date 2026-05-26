# Capability Placement Decision Matrix

## Primary questions

| Question | If yes | Decision |
|---|---|---|
| Does it already exist under another name? | yes | merge or project |
| Is it only a platform adapter for an existing capability? | yes | project |
| Does it perform a genuinely new job-to-be-done? | yes | promote or keep |
| Does it only need reasoning, templates, or repeatable procedure? | yes | skill |
| Does it need API/tool execution? | yes | gateway |
| Does it need many latent tools but only some per task? | yes | search-and-execute gateway |
| Does it need local filesystem, device state, metadata preservation, or high privilege? | yes | local-only |
| Does it touch memory capture, bit-stream acquisition, hashes, custody, or forensic state? | yes | legal-only |
| Does it touch governance, valuation, removal docs, claims, filings, disputes, or legal records? | yes | legal-only plus non-repudiation gate |
| Is it obsolete, redundant, unsafe, or ownerless? | yes | retire |

## System footprint

| Score | Label | Definition |
|---|---|---|
| 0 | context-only | conversation, templates, reasoning only |
| 1 | read-only connector | reads existing docs, repos, messages, files, or registry records |
| 2 | write-capable | updates artifacts, records, tickets, docs, or state |
| 3 | network-service | calls API, MCP server, worker, webhook, or external service |
| 4 | filesystem-local | needs local path, metadata, bulk files, or machine-local state |
| 5 | admin-system | changes auth, secrets, config, infra, deployment, or policy |
| 6 | forensic-legal-grade | custody, evidence, hashes, timestamps, bit-stream, live memory, claims |

## Evidentiary risk

| Score | Label | Definition |
|---|---|---|
| 0 | none | no durable record implications |
| 1 | low | internal productivity artifact |
| 2 | medium | business record or operational decision support |
| 3 | high | money, compliance, dispute, claim, executive action, or audit trail |
| 4 | legal-grade | court, evidence, custody, sworn claim, forensic state, non-repudiation |

## Tie-breaker

The highest-risk axis controls placement. A low-footprint summarizer becomes legal-only if it touches legal exhibits. A high-privilege local cleaner remains local-only even if it has no legal risk.
