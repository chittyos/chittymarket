# Cloudflare Runtime for Counsel Style Profiles

This is the preferred runtime design for `counsel-style-adapter`. It is optional: the skill must still work without Cloudflare persistent services.

## Design goal

Maintain an evolving, source-linked counsel profile without commingling style learning with governed case facts.

The runtime has four layers:

1. **Anchor brief** — deterministic first input.
2. **Agent state** — versioning, open hypotheses, source registry, update checkpoints.
3. **Semantic memory** — compact learned tendencies and recalled observations.
4. **Source retrieval** — counsel-authored examples retrieved only when needed.

## Identity and isolation

Key every profile by:

`matter_id + counsel_profile_id`

Never use attorney name alone.

Recommended path prefix:

`legal-style/{matter_id}/{counsel_profile_id}/`

Never allow a query to search across matters unless an explicit cross-matter profile has been authorized.

## 1. Anchor brief: always first

The `COUNSEL_STYLE_BRIEF` is the control document. Load it directly before memory recall or semantic retrieval.

Do not rely on vector ranking to surface it.

Suggested object:

`legal-style/{matter_id}/{counsel_profile_id}/00_COUNSEL_STYLE_BRIEF.md`

Persist:
- profile version
- source inventory
- high-confidence rules
- medium-confidence tendencies
- avoidances
- drafting consequences
- unresolved questions
- last-updated timestamp
- hash of the brief

The anchor brief is work product and is not a source of case facts.

## 2. Deterministic agent state

Use a Cloudflare Agents SDK Agent / Durable Object for compact control state.

Persist via `this.state` / `this.setState()` or Agent SQL:

```ts
type CounselStyleState = {
  matterId: string;
  counselProfileId: string;
  profileVersion: string;
  anchorBriefHash: string;
  lastIngestedAt?: string;
  sourceArtifactIds: string[];
  openQuestionIds: string[];
  activeObservationIds: string[];
  supersededObservationIds: string[];
};
```

Use SQL tables for append-only observation/changelog rows when the profile needs deterministic history.

Do not put full canonical evidence into Agent state.

## 3. Semantic memory

### Preferred: Cloudflare Agent Memory

As of the October 2026 Cloudflare documentation, Agent Memory is in **private beta**. Treat availability as a runtime capability check, not an assumption.

When Agent Memory is available, create a dedicated namespace such as:

`legal-counsel-style`

Use one profile per `matter_id:counsel_profile_id`.

Use explicit `remember()` for normalized style observations. Prefer explicit memories over blindly ingesting whole pleadings or case conversations.

Examples of memory-worthy observations:
- "Counsel generally leads with threshold statutory eligibility before factual proof defects."
- "Counsel tends to preserve unrelated issues expressly for separate motion."
- "Counsel uses adverse facts directly rather than hiding them."

Do **not** store:
- unsourced case facts;
- discovery content merely because counsel received it;
- privileged facts unrelated to style;
- model speculation presented as memory.

Recall memory only after loading the anchor brief.

### Fallback: Durable Object SQL

Agent Memory is not required. If unavailable, store normalized observations and summaries in the Agent's SQLite tables and use deterministic dimension/source queries. The profile remains fully functional, with less semantic recall.

## 4. Style-source retrieval with AI Search

Use AI Search for source examples, not as the profile authority.

Preferred corpus: style-eligible derivative documents or counsel-authored artifacts already permitted in the Legal space.

If using an R2-backed AI Search instance, use folder isolation plus metadata filtering before retrieval.

Suggested custom metadata fields:

- `counsel_profile_id`
- `artifact_type`
- `authorship`
- `style_eligible`
- `profile_version`

Use the built-in `folder` filter for matter isolation so the custom-field budget is not consumed by `matter_id`.

Example retrieval constraint:

```ts
retrieval: {
  filters: {
    folder: `legal-style/${matterId}/${counselProfileId}/sources/`,
    counsel_profile_id: counselProfileId,
    style_eligible: true,
    artifact_type: "pleading"
  }
}
```

Never index a document into the style corpus solely because counsel received it. Require authorship/editing relevance.

## Ingestion workflow

For each new candidate artifact:

1. Verify the matter and counsel identity.
2. Classify authorship:
   - counsel-authored
   - counsel-edited
   - third-party
   - client-note
3. Decide `style_eligible`.
4. Register source ID and source hash/pointer.
5. Extract only style observations.
6. Compare each observation to current active observations.
7. Mark each as `OBSERVED | INFERRED | HYPOTHESIS`.
8. Add contrary links instead of overwriting conflicts.
9. Persist normalized observations.
10. Regenerate the anchor brief when a material profile change occurs.
11. Increment profile version and append changelog.

Never use this ingestion path to promote legal facts.

## Draft adaptation workflow

1. Load governed legal record separately.
2. Load `00_COUNSEL_STYLE_BRIEF.md` directly.
3. Recall relevant compact style memories.
4. Retrieve 2-5 source examples matching artifact type.
5. Draft/adapt the work product.
6. Run style-conformance review.
7. Re-run evidence/fact integrity after style adaptation.
8. Emit `COUNSEL-ADAPTED DRAFT`, never `COUNSEL APPROVED`.

## Dynamic Workers / Code Mode

Dynamic Workers are optional and should be used only for isolated transformations or tool orchestration, such as:
- comparing draft structure against several source examples;
- calculating style metrics;
- generating a diff report;
- chaining retrieval + profile comparison.

Do not use Dynamic Workers as the durable memory or source-of-truth layer.

Keep network access disabled unless a specific approved tool path requires it.

## Security / legal boundaries

- Legal-space-only.
- Matter isolation is fail-closed.
- No last-matter fallback.
- Profile observations must remain source-linked.
- Canonical evidence remains in the existing evidence/fact-governance system.
- Style derivatives are work product and must not silently become exhibits.
- No external filing, transmission, or counsel attribution without explicit authorization.
- Credentials/bindings route through ChittyConnect.

## Provisioning posture

Do not provision a new Agent Memory namespace, AI Search instance, R2 bucket, or recurring Worker solely because this reference exists.

Before provisioning:
1. discover whether an existing legal R2/AI Search substrate can be reused;
2. check current Agent Memory account availability;
3. verify cost/headroom under startup-mode;
4. preserve the existing legal evidence boundary;
5. require explicit deployment authorization.

The skill itself remains usable with only the anchor brief + source files.
