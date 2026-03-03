# ChittyMarket Design

**Date**: 2026-03-03
**Canonical URI**: `chittycanon://docs/tech/spec/chittymarket-data-model`
**Status**: APPROVED

## Purpose

ChittyMarket is a marketplace for ChittyOS artifacts: agents, skills, templates, MCP configs, hook recipes, and service blueprints. Developer-first with a browsable consumer experience.

## Architecture: Hybrid

Two deployment targets sharing a single Neon PostgreSQL database:

1. **ChittyAgent Studio** (Express + Drizzle + React) — full marketplace UI for building, publishing, browsing, reviewing, and installing artifacts. Admin and authenticated user experience.
2. **Cloudflare Worker at `market.chitty.cc`** — read-only public storefront. Queries the same Neon DB via `@neondatabase/serverless`. Cached via Cloudflare Cache API.

### Relationship to ChittyRegistry

ChittyRegistry (`registry.chitty.cc`) remains the internal indexer/crawler. ChittyMarket is the user-facing marketplace layer on top. Registry indexes; Market presents, rates, and distributes.

## Data Model

### Canonical Annotations

Every table carries P/L/T/E/A entity type annotations per `chittycanon://gov/governance#core-types`. All column names use snake_case. All IDs are `varchar` with `gen_random_uuid()`.

### Existing Table Modifications

```sql
-- agents table (Thing/T, Digital)
ALTER TABLE agents
  ADD COLUMN published      boolean     NOT NULL DEFAULT false,
  ADD COLUMN published_at   timestamptz,
  ADD COLUMN version        text        NOT NULL DEFAULT '1.0.0',
  ADD COLUMN tags           text[]      NOT NULL DEFAULT '{}',
  ADD COLUMN author_id      varchar     REFERENCES users(id) ON DELETE SET NULL;

-- skills table (Thing/T, Digital)
ALTER TABLE skills
  ADD COLUMN published      boolean     NOT NULL DEFAULT false,
  ADD COLUMN published_at   timestamptz,
  ADD COLUMN version        text        NOT NULL DEFAULT '1.0.0',
  ADD COLUMN tags           text[]      NOT NULL DEFAULT '{}',
  ADD COLUMN author_id      varchar     REFERENCES users(id) ON DELETE SET NULL;
```

### New Tables

#### `listings` — Thing (T), Digital

Unified marketplace entry wrapping any artifact type.

```sql
-- @canonical-type T (Thing, Digital)
-- @canonical-uri chittycanon://core/services/chittymarket/schema/listings
CREATE TABLE listings (
  id              varchar     PRIMARY KEY DEFAULT gen_random_uuid(),
  type            text        NOT NULL CHECK (type IN (
                    'agent','skill','template','mcp-config','hook-recipe','service-blueprint'
                  )),
  agent_id        varchar     REFERENCES agents(id) ON DELETE SET NULL,
  skill_id        varchar     REFERENCES skills(id) ON DELETE SET NULL,
  slug            text        NOT NULL UNIQUE,
  title           text        NOT NULL,
  description     text        NOT NULL,
  author_id       varchar     REFERENCES users(id) ON DELETE SET NULL,
  version         text        NOT NULL DEFAULT '1.0.0',
  tags            text[]      NOT NULL DEFAULT '{}',
  category        text        NOT NULL DEFAULT 'general',
  icon            text        NOT NULL DEFAULT 'package',
  color           text        NOT NULL DEFAULT '#4285f4',
  published       boolean     NOT NULL DEFAULT false,
  featured        boolean     NOT NULL DEFAULT false,
  install_count   integer     NOT NULL DEFAULT 0,
  avg_rating      numeric(3,2),
  review_count    integer     NOT NULL DEFAULT 0,
  screenshots     jsonb       NOT NULL DEFAULT '[]',
  readme_content  text,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT listings_source_xor CHECK (
    (type = 'agent'  AND agent_id IS NOT NULL AND skill_id IS NULL) OR
    (type = 'skill'  AND skill_id IS NOT NULL AND agent_id IS NULL) OR
    (type IN ('template','mcp-config','hook-recipe','service-blueprint')
      AND agent_id IS NULL AND skill_id IS NULL)
  )
);
```

**JSON Field Schemas:**
- `screenshots`: `[{"url": "https://...", "caption": "Dashboard view"}]`
- `tags`: `["legal", "devops", "automation"]`

#### `listing_reviews` — Event (E), Transaction

```sql
-- @canonical-type E (Event, Transaction)
CREATE TABLE listing_reviews (
  id              varchar     PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id      varchar     NOT NULL REFERENCES listings(id) ON DELETE CASCADE,
  user_id         varchar     REFERENCES users(id) ON DELETE SET NULL,
  rating          integer     NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment         text,
  created_at      timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT listing_reviews_one_per_user UNIQUE (listing_id, user_id)
);
```

#### `marketplace_collections` — Thing (T), Digital

```sql
-- @canonical-type T (Thing, Digital)
CREATE TABLE marketplace_collections (
  id              varchar     PRIMARY KEY DEFAULT gen_random_uuid(),
  name            text        NOT NULL,
  description     text,
  slug            text        NOT NULL UNIQUE,
  curated_by      varchar     REFERENCES users(id) ON DELETE SET NULL,
  created_at      timestamptz NOT NULL DEFAULT now()
);
```

#### `collection_listings` — Junction Table

```sql
CREATE TABLE collection_listings (
  collection_id   varchar     NOT NULL REFERENCES marketplace_collections(id) ON DELETE CASCADE,
  listing_id      varchar     NOT NULL REFERENCES listings(id) ON DELETE CASCADE,
  position        integer     NOT NULL DEFAULT 0,
  added_at        timestamptz NOT NULL DEFAULT now(),

  PRIMARY KEY (collection_id, listing_id)
);
```

#### `listing_installs` — Event (E), Transaction

```sql
-- @canonical-type E (Event, Transaction)
CREATE TABLE listing_installs (
  id              varchar     PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id      varchar     NOT NULL REFERENCES listings(id) ON DELETE CASCADE,
  user_id         varchar     REFERENCES users(id) ON DELETE SET NULL,
  version         text        NOT NULL,
  installed_at    timestamptz NOT NULL DEFAULT now()
);
```

### Indexes

```sql
CREATE INDEX CONCURRENTLY idx_listings_browse     ON listings (type, category) WHERE published = true;
CREATE INDEX CONCURRENTLY idx_listings_featured   ON listings (featured, install_count DESC) WHERE published = true;
CREATE INDEX CONCURRENTLY idx_listings_rating     ON listings (avg_rating DESC NULLS LAST) WHERE published = true;
CREATE INDEX CONCURRENTLY idx_listings_tags       ON listings USING gin (tags);
CREATE INDEX CONCURRENTLY idx_listings_fts        ON listings USING gin (
  to_tsvector('english', coalesce(title,'') || ' ' || coalesce(description,''))
);
CREATE INDEX CONCURRENTLY idx_listings_author     ON listings (author_id, published, created_at DESC);
CREATE INDEX CONCURRENTLY idx_reviews_listing     ON listing_reviews (listing_id);
CREATE INDEX CONCURRENTLY idx_installs_listing    ON listing_installs (listing_id);
CREATE INDEX CONCURRENTLY idx_installs_user       ON listing_installs (user_id, installed_at DESC);
CREATE INDEX CONCURRENTLY idx_collection_position ON collection_listings (collection_id, position);
```

### Denormalization Sync Strategy

- **`avg_rating` + `review_count`**: PostgreSQL trigger on `listing_reviews` INSERT/UPDATE/DELETE — low write volume, correctness critical for trust signals.
- **`install_count`**: Application-level atomic `SET install_count = install_count + 1` — potentially high volume, safe as atomic increment.

## Worker Cache Strategy (market.chitty.cc)

| Data | Strategy | TTL |
|------|----------|-----|
| Browse/featured listings | Cloudflare Cache API by query params | 60s |
| Listing detail by slug | Cache API, purge on publish via Studio webhook | 5min |
| Collections | Cache API | 2min |
| Search results | No cache | — |
| Writes (review, install) | Proxy to Studio API | — |

The Worker queries Neon directly via `@neondatabase/serverless` HTTP driver.

## Shared Schema Package

The Drizzle schema definition lives in the `chittymarket` repo at `src/schema.ts`. Both Studio and the Worker import it to prevent schema drift. A `schema_version` is exposed via health endpoints on both sides.

## Artifact Types

All six types are Thing (T), Digital. Registered at `chittycanon://docs/tech/registry/marketplace-artifact-types`:

| Type | Source | Description |
|------|--------|-------------|
| `agent` | ChittyAgent Studio `agents` table | Agent definition (Thing/T) — the artifact. Running instances are Person/P, Synthetic per canonical ontology |
| `skill` | ChittyAgent Studio `skills` table | Capability module with repo link and install tracking |
| `template` | Standalone in `listings` | Starter project or agent scaffold |
| `mcp-config` | Standalone in `listings` | MCP server configuration (`.mcp.json` snippet) |
| `hook-recipe` | Standalone in `listings` | Pre/PostToolUse hook pattern with shell script |
| `service-blueprint` | Standalone in `listings` | Cloudflare Worker service scaffold with compliance triad |

## Migration Safety

All changes are zero-downtime compatible:
- `ADD COLUMN ... DEFAULT` is metadata-only in PostgreSQL 11+
- `CREATE TABLE` does not lock existing tables
- `CREATE INDEX CONCURRENTLY` builds without exclusive locks
- Drizzle-generated migration SQL must be reviewed before applying

## Dependencies

- ChittyAgent Studio (Express + Drizzle + PostgreSQL + React)
- Neon PostgreSQL (Studio's existing project — needs discovery)
- Cloudflare Workers (for `market.chitty.cc`)
- ChittyRegistry (upstream catalog data)
- ChittyAuth (user identity for reviews/installs)
