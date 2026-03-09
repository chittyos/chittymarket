# ChittyMarket Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add marketplace features to ChittyAgent Studio and deploy a read-only public Worker at market.chitty.cc.

**Architecture:** Marketplace tables added to Studio's Drizzle schema, new API routes and React pages in Studio, plus a lightweight Cloudflare Worker that reads the same Neon DB for public browsing.

**Tech Stack:** TypeScript, Express, Drizzle ORM, PostgreSQL (Neon), React 18, Radix UI, TailwindCSS, Cloudflare Workers, Hono

---

## Prerequisites

Before starting, clone chittyagent-studio locally:
```bash
cd /Users/nb/Desktop/Projects/github.com/chittyapps
git clone git@github.com:chittyapps/chittyagent-studio.git
cd chittyagent-studio
npm install
```

---

### Task 1: Extend Drizzle Schema with Marketplace Tables

**Files:**
- Modify: `shared/schema.ts`

**Step 1: Write the marketplace schema additions**

Add to the bottom of `shared/schema.ts`:

```typescript
// --- ChittyMarket Schema ---
// @canonical-uri chittycanon://core/services/chittymarket/schema
// @canon: chittycanon://gov/governance#core-types

export const listings = pgTable("listings", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  type: text("type").notNull(),
  agentId: varchar("agent_id").references(() => agents.id, { onDelete: "set null" }),
  skillId: varchar("skill_id").references(() => skills.id, { onDelete: "set null" }),
  slug: text("slug").notNull().unique(),
  title: text("title").notNull(),
  description: text("description").notNull(),
  authorId: varchar("author_id").references(() => users.id, { onDelete: "set null" }),
  version: text("version").notNull().default("1.0.0"),
  tags: text("tags").array().notNull().default(sql`'{}'::text[]`),
  category: text("category").notNull().default("general"),
  icon: text("icon").notNull().default("package"),
  color: text("color").notNull().default("#4285f4"),
  published: boolean("published").notNull().default(false),
  featured: boolean("featured").notNull().default(false),
  installCount: integer("install_count").notNull().default(0),
  avgRating: text("avg_rating"),
  reviewCount: integer("review_count").notNull().default(0),
  screenshots: jsonb("screenshots").$type<{ url: string; caption: string }[]>().notNull().default([]),
  readmeContent: text("readme_content"),
  createdAt: timestamp("created_at").notNull().defaultNow(),
  updatedAt: timestamp("updated_at").notNull().defaultNow(),
});

export const insertListingSchema = createInsertSchema(listings).omit({
  id: true,
  installCount: true,
  avgRating: true,
  reviewCount: true,
  createdAt: true,
  updatedAt: true,
});

export type InsertListing = z.infer<typeof insertListingSchema>;
export type Listing = typeof listings.$inferSelect;

export const listingReviews = pgTable("listing_reviews", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  listingId: varchar("listing_id").notNull().references(() => listings.id, { onDelete: "cascade" }),
  userId: varchar("user_id").references(() => users.id, { onDelete: "set null" }),
  rating: integer("rating").notNull(),
  comment: text("comment"),
  createdAt: timestamp("created_at").notNull().defaultNow(),
});

export const insertListingReviewSchema = createInsertSchema(listingReviews).omit({
  id: true,
  createdAt: true,
});

export type InsertListingReview = z.infer<typeof insertListingReviewSchema>;
export type ListingReview = typeof listingReviews.$inferSelect;

export const marketplaceCollections = pgTable("marketplace_collections", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  name: text("name").notNull(),
  description: text("description"),
  slug: text("slug").notNull().unique(),
  curatedBy: varchar("curated_by").references(() => users.id, { onDelete: "set null" }),
  createdAt: timestamp("created_at").notNull().defaultNow(),
});

export const insertCollectionSchema = createInsertSchema(marketplaceCollections).omit({
  id: true,
  createdAt: true,
});

export type InsertCollection = z.infer<typeof insertCollectionSchema>;
export type MarketplaceCollection = typeof marketplaceCollections.$inferSelect;

export const collectionListings = pgTable("collection_listings", {
  collectionId: varchar("collection_id").notNull().references(() => marketplaceCollections.id, { onDelete: "cascade" }),
  listingId: varchar("listing_id").notNull().references(() => listings.id, { onDelete: "cascade" }),
  position: integer("position").notNull().default(0),
  addedAt: timestamp("added_at").notNull().defaultNow(),
}, (table) => ({
  pk: { columns: [table.collectionId, table.listingId] },
}));

export type CollectionListing = typeof collectionListings.$inferSelect;

export const listingInstalls = pgTable("listing_installs", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  listingId: varchar("listing_id").notNull().references(() => listings.id, { onDelete: "cascade" }),
  userId: varchar("user_id").references(() => users.id, { onDelete: "set null" }),
  version: text("version").notNull(),
  installedAt: timestamp("installed_at").notNull().defaultNow(),
});

export type ListingInstall = typeof listingInstalls.$inferSelect;

// Marketplace artifact type constants
export const LISTING_TYPES = [
  "agent", "skill", "template", "mcp-config", "hook-recipe", "service-blueprint",
] as const;
export type ListingType = typeof LISTING_TYPES[number];
```

**Step 2: Add published/tags/version columns to existing agents and skills tables**

In the existing `agents` table definition, add these columns:

```typescript
  published: boolean("published").notNull().default(false),
  publishedAt: timestamp("published_at"),
  version: text("version").notNull().default("1.0.0"),
  tags: text("tags").array().notNull().default(sql`'{}'::text[]`),
  authorId: varchar("author_id").references(() => users.id, { onDelete: "set null" }),
```

Same columns in the `skills` table definition:

```typescript
  published: boolean("published").notNull().default(false),
  publishedAt: timestamp("published_at"),
  version: text("version").notNull().default("1.0.0"),
  tags: text("tags").array().notNull().default(sql`'{}'::text[]`),
  authorId: varchar("author_id").references(() => users.id, { onDelete: "set null" }),
```

**Step 3: Push schema to database**

Run: `npx drizzle-kit push`
Review the generated SQL before confirming. Verify all `ADD COLUMN` statements include `DEFAULT`.

**Step 4: Commit**

```bash
git add shared/schema.ts
git commit -m "feat(schema): add marketplace tables — listings, reviews, collections, installs"
```

---

### Task 2: Add Marketplace Storage Methods

**Files:**
- Modify: `server/storage.ts`

**Step 1: Add marketplace imports**

Add to the imports at the top of `storage.ts`:

```typescript
import {
  // ... existing imports ...
  type Listing, type InsertListing,
  type ListingReview, type InsertListingReview,
  type MarketplaceCollection, type InsertCollection,
  type CollectionListing,
  type ListingInstall,
  listings, listingReviews, marketplaceCollections,
  collectionListings, listingInstalls,
} from "@shared/schema";
```

**Step 2: Add interface methods to IStorage**

```typescript
  // Marketplace - Listings
  getListings(filters?: { type?: string; category?: string; published?: boolean; featured?: boolean }): Promise<Listing[]>;
  getListing(id: string): Promise<Listing | undefined>;
  getListingBySlug(slug: string): Promise<Listing | undefined>;
  createListing(listing: InsertListing): Promise<Listing>;
  updateListing(id: string, data: Partial<InsertListing>): Promise<Listing | undefined>;
  deleteListing(id: string): Promise<boolean>;
  searchListings(query: string): Promise<Listing[]>;

  // Marketplace - Reviews
  getListingReviews(listingId: string): Promise<ListingReview[]>;
  createReview(review: InsertListingReview): Promise<ListingReview>;

  // Marketplace - Collections
  getCollections(): Promise<MarketplaceCollection[]>;
  getCollectionBySlug(slug: string): Promise<MarketplaceCollection & { listings: Listing[] } | undefined>;
  createCollection(collection: InsertCollection): Promise<MarketplaceCollection>;

  // Marketplace - Installs
  installListing(listingId: string, userId: string, version: string): Promise<void>;
```

**Step 3: Implement DatabaseStorage methods**

```typescript
  // --- Marketplace: Listings ---

  async getListings(filters?: { type?: string; category?: string; published?: boolean; featured?: boolean }): Promise<Listing[]> {
    let query = db.select().from(listings);
    const conditions = [];
    if (filters?.type) conditions.push(eq(listings.type, filters.type));
    if (filters?.category) conditions.push(eq(listings.category, filters.category));
    if (filters?.published !== undefined) conditions.push(eq(listings.published, filters.published));
    if (filters?.featured) conditions.push(eq(listings.featured, true));
    if (conditions.length > 0) query = query.where(and(...conditions));
    return query.orderBy(desc(listings.installCount));
  }

  async getListing(id: string): Promise<Listing | undefined> {
    const [listing] = await db.select().from(listings).where(eq(listings.id, id));
    return listing;
  }

  async getListingBySlug(slug: string): Promise<Listing | undefined> {
    const [listing] = await db.select().from(listings).where(eq(listings.slug, slug));
    return listing;
  }

  async createListing(data: InsertListing): Promise<Listing> {
    const [listing] = await db.insert(listings).values(data as any).returning();
    return listing;
  }

  async updateListing(id: string, data: Partial<InsertListing>): Promise<Listing | undefined> {
    const [listing] = await db
      .update(listings)
      .set({ ...data, updatedAt: new Date() } as any)
      .where(eq(listings.id, id))
      .returning();
    return listing;
  }

  async deleteListing(id: string): Promise<boolean> {
    const result = await db.delete(listings).where(eq(listings.id, id)).returning();
    return result.length > 0;
  }

  async searchListings(query: string): Promise<Listing[]> {
    return db.select().from(listings)
      .where(and(
        eq(listings.published, true),
        sql`to_tsvector('english', coalesce(${listings.title},'') || ' ' || coalesce(${listings.description},'')) @@ plainto_tsquery('english', ${query})`
      ))
      .orderBy(desc(listings.installCount))
      .limit(50);
  }

  // --- Marketplace: Reviews ---

  async getListingReviews(listingId: string): Promise<ListingReview[]> {
    return db.select().from(listingReviews)
      .where(eq(listingReviews.listingId, listingId))
      .orderBy(desc(listingReviews.createdAt));
  }

  async createReview(data: InsertListingReview): Promise<ListingReview> {
    const [review] = await db.insert(listingReviews).values(data).returning();
    // Update listing avg_rating and review_count
    await db.execute(sql`
      UPDATE listings SET
        avg_rating = (SELECT ROUND(AVG(rating)::numeric, 2)::text FROM listing_reviews WHERE listing_id = ${data.listingId}),
        review_count = (SELECT COUNT(*) FROM listing_reviews WHERE listing_id = ${data.listingId}),
        updated_at = now()
      WHERE id = ${data.listingId}
    `);
    return review;
  }

  // --- Marketplace: Collections ---

  async getCollections(): Promise<MarketplaceCollection[]> {
    return db.select().from(marketplaceCollections).orderBy(marketplaceCollections.name);
  }

  async getCollectionBySlug(slug: string): Promise<(MarketplaceCollection & { listings: Listing[] }) | undefined> {
    const [collection] = await db.select().from(marketplaceCollections)
      .where(eq(marketplaceCollections.slug, slug));
    if (!collection) return undefined;
    const items = await db.select({ listing: listings })
      .from(collectionListings)
      .innerJoin(listings, eq(collectionListings.listingId, listings.id))
      .where(eq(collectionListings.collectionId, collection.id))
      .orderBy(collectionListings.position);
    return { ...collection, listings: items.map(i => i.listing) };
  }

  async createCollection(data: InsertCollection): Promise<MarketplaceCollection> {
    const [collection] = await db.insert(marketplaceCollections).values(data).returning();
    return collection;
  }

  // --- Marketplace: Installs ---

  async installListing(listingId: string, userId: string, version: string): Promise<void> {
    await db.insert(listingInstalls).values({ listingId, userId, version });
    await db.execute(sql`
      UPDATE listings SET install_count = install_count + 1, updated_at = now()
      WHERE id = ${listingId}
    `);
  }
```

**Step 4: Commit**

```bash
git add server/storage.ts
git commit -m "feat(storage): add marketplace CRUD — listings, reviews, collections, installs"
```

---

### Task 3: Add Marketplace API Routes

**Files:**
- Modify: `server/routes.ts`

**Step 1: Add listing validation schemas**

Add at the top of `routes.ts` after existing schemas:

```typescript
const createListingSchema = z.object({
  type: z.enum(["agent", "skill", "template", "mcp-config", "hook-recipe", "service-blueprint"]),
  agentId: z.string().optional(),
  skillId: z.string().optional(),
  slug: z.string().min(1).max(100),
  title: z.string().min(1).max(200),
  description: z.string().min(1).max(2000),
  version: z.string().default("1.0.0"),
  tags: z.array(z.string()).default([]),
  category: z.string().default("general"),
  icon: z.string().default("package"),
  color: z.string().default("#4285f4"),
  published: z.boolean().default(false),
  screenshots: z.array(z.object({ url: z.string(), caption: z.string() })).default([]),
  readmeContent: z.string().optional(),
});

const createReviewSchema = z.object({
  rating: z.number().int().min(1).max(5),
  comment: z.string().max(2000).optional(),
});
```

**Step 2: Add marketplace routes inside `registerRoutes`**

```typescript
  // --- Marketplace: Listings ---

  app.get("/api/market/listings", async (req, res) => {
    try {
      const { type, category, featured } = req.query;
      const listings = await storage.getListings({
        type: type as string | undefined,
        category: category as string | undefined,
        published: true,
        featured: featured === "true" ? true : undefined,
      });
      res.json(listings);
    } catch (err: any) {
      res.status(500).json({ message: err.message });
    }
  });

  app.get("/api/market/listings/search", async (req, res) => {
    try {
      const q = req.query.q as string;
      if (!q) return res.status(400).json({ message: "Query parameter 'q' is required" });
      const results = await storage.searchListings(q);
      res.json(results);
    } catch (err: any) {
      res.status(500).json({ message: err.message });
    }
  });

  app.get("/api/market/listings/:slug", async (req, res) => {
    try {
      const listing = await storage.getListingBySlug(req.params.slug);
      if (!listing) return res.status(404).json({ message: "Listing not found" });
      res.json(listing);
    } catch (err: any) {
      res.status(500).json({ message: err.message });
    }
  });

  app.post("/api/market/listings", async (req, res) => {
    try {
      const parsed = createListingSchema.safeParse(req.body);
      if (!parsed.success) return res.status(400).json({ message: parsed.error.issues.map(i => i.message).join(", ") });
      const listing = await storage.createListing(parsed.data);
      res.status(201).json(listing);
    } catch (err: any) {
      res.status(500).json({ message: err.message });
    }
  });

  app.patch("/api/market/listings/:id", async (req, res) => {
    try {
      const listing = await storage.updateListing(req.params.id, req.body);
      if (!listing) return res.status(404).json({ message: "Listing not found" });
      res.json(listing);
    } catch (err: any) {
      res.status(500).json({ message: err.message });
    }
  });

  app.delete("/api/market/listings/:id", async (req, res) => {
    try {
      const deleted = await storage.deleteListing(req.params.id);
      if (!deleted) return res.status(404).json({ message: "Listing not found" });
      res.json({ success: true });
    } catch (err: any) {
      res.status(500).json({ message: err.message });
    }
  });

  // --- Marketplace: Reviews ---

  app.get("/api/market/listings/:slug/reviews", async (req, res) => {
    try {
      const listing = await storage.getListingBySlug(req.params.slug);
      if (!listing) return res.status(404).json({ message: "Listing not found" });
      const reviews = await storage.getListingReviews(listing.id);
      res.json(reviews);
    } catch (err: any) {
      res.status(500).json({ message: err.message });
    }
  });

  app.post("/api/market/listings/:id/reviews", async (req, res) => {
    try {
      const parsed = createReviewSchema.safeParse(req.body);
      if (!parsed.success) return res.status(400).json({ message: parsed.error.issues.map(i => i.message).join(", ") });
      const review = await storage.createReview({
        listingId: req.params.id,
        userId: null,
        ...parsed.data,
      });
      res.status(201).json(review);
    } catch (err: any) {
      res.status(500).json({ message: err.message });
    }
  });

  // --- Marketplace: Install ---

  app.post("/api/market/listings/:id/install", async (req, res) => {
    try {
      const listing = await storage.getListing(req.params.id);
      if (!listing) return res.status(404).json({ message: "Listing not found" });
      await storage.installListing(listing.id, "anonymous", listing.version);
      res.json({ success: true, installCount: listing.installCount + 1 });
    } catch (err: any) {
      res.status(500).json({ message: err.message });
    }
  });

  // --- Marketplace: Collections ---

  app.get("/api/market/collections", async (_req, res) => {
    try {
      const collections = await storage.getCollections();
      res.json(collections);
    } catch (err: any) {
      res.status(500).json({ message: err.message });
    }
  });

  app.get("/api/market/collections/:slug", async (req, res) => {
    try {
      const collection = await storage.getCollectionBySlug(req.params.slug);
      if (!collection) return res.status(404).json({ message: "Collection not found" });
      res.json(collection);
    } catch (err: any) {
      res.status(500).json({ message: err.message });
    }
  });
```

**Step 3: Commit**

```bash
git add server/routes.ts
git commit -m "feat(api): add marketplace routes — /api/market/listings, reviews, collections, installs"
```

---

### Task 4: Add Marketplace Constants and Types

**Files:**
- Modify: `client/src/lib/constants.ts`

**Step 1: Add marketplace constants**

```typescript
export const LISTING_TYPE_LABELS: Record<string, string> = {
  agent: "Agent",
  skill: "Skill",
  template: "Template",
  "mcp-config": "MCP Config",
  "hook-recipe": "Hook Recipe",
  "service-blueprint": "Service Blueprint",
};

export const LISTING_TYPE_ICONS: Record<string, string> = {
  agent: "bot",
  skill: "puzzle",
  template: "layout",
  "mcp-config": "settings",
  "hook-recipe": "git-branch",
  "service-blueprint": "server",
};

export const MARKETPLACE_CATEGORIES = [
  { value: "all", label: "All" },
  { value: "trust", label: "Trust" },
  { value: "verification", label: "Verification" },
  { value: "intelligence", label: "Intelligence" },
  { value: "monitoring", label: "Monitoring" },
  { value: "data", label: "Data" },
  { value: "legal", label: "Legal" },
  { value: "automation", label: "Automation" },
  { value: "ai", label: "AI" },
  { value: "communication", label: "Communication" },
  { value: "utility", label: "Utility" },
  { value: "devops", label: "DevOps" },
];

export const LISTING_TYPE_FILTERS = [
  { value: "all", label: "All Types" },
  { value: "agent", label: "Agents" },
  { value: "skill", label: "Skills" },
  { value: "template", label: "Templates" },
  { value: "mcp-config", label: "MCP Configs" },
  { value: "hook-recipe", label: "Hook Recipes" },
  { value: "service-blueprint", label: "Blueprints" },
];
```

**Step 2: Commit**

```bash
git add client/src/lib/constants.ts
git commit -m "feat(ui): add marketplace constants — types, categories, filters"
```

---

### Task 5: Build Marketplace Browse Page

**Files:**
- Create: `client/src/pages/marketplace.tsx`
- Create: `client/src/components/listing-card.tsx`

**Step 1: Create the listing card component**

Create `client/src/components/listing-card.tsx`:

```typescript
import { type Listing } from "@shared/schema";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { iconMap } from "@/lib/icons";
import { LISTING_TYPE_LABELS } from "@/lib/constants";
import { Download, Star, Package } from "lucide-react";
import { useLocation } from "wouter";

interface ListingCardProps {
  listing: Listing;
  onInstall?: (id: string) => void;
  installing?: boolean;
}

export function ListingCard({ listing, onInstall, installing }: ListingCardProps) {
  const [, navigate] = useLocation();
  const IconComponent = iconMap[listing.icon] || Package;

  return (
    <Card
      className="p-5 flex flex-col gap-3 hover-elevate transition-all cursor-pointer"
      onClick={() => navigate(`/market/${listing.slug}`)}
      data-testid={`card-listing-${listing.slug}`}
    >
      <div className="flex items-start justify-between gap-2">
        <div className="flex items-start gap-3">
          <div
            className="w-10 h-10 rounded-md flex items-center justify-center shrink-0"
            style={{ backgroundColor: listing.color + "18", color: listing.color }}
          >
            <IconComponent className="w-5 h-5" />
          </div>
          <div className="min-w-0">
            <h3 className="font-semibold text-sm">{listing.title}</h3>
            <span className="text-[10px] text-muted-foreground">
              v{listing.version}
            </span>
          </div>
        </div>
        <Badge variant="secondary" className="text-[10px] shrink-0">
          {LISTING_TYPE_LABELS[listing.type] || listing.type}
        </Badge>
      </div>

      <p className="text-xs text-muted-foreground line-clamp-2">
        {listing.description}
      </p>

      {listing.tags && listing.tags.length > 0 && (
        <div className="flex flex-wrap gap-1">
          {listing.tags.slice(0, 3).map((tag, idx) => (
            <span
              key={idx}
              className="text-[10px] px-1.5 py-0.5 rounded bg-muted text-muted-foreground"
            >
              {tag}
            </span>
          ))}
          {listing.tags.length > 3 && (
            <span className="text-[10px] text-muted-foreground">
              +{listing.tags.length - 3}
            </span>
          )}
        </div>
      )}

      <div className="flex items-center justify-between mt-auto pt-1">
        <div className="flex items-center gap-3 text-[11px] text-muted-foreground">
          <span className="flex items-center gap-1">
            <Download className="w-3 h-3" /> {listing.installCount}
          </span>
          {listing.avgRating && (
            <span className="flex items-center gap-1">
              <Star className="w-3 h-3 fill-amber-400 text-amber-400" /> {listing.avgRating}
            </span>
          )}
        </div>
        <Button
          size="sm"
          variant="secondary"
          onClick={(e) => {
            e.stopPropagation();
            onInstall?.(listing.id);
          }}
          disabled={installing}
          data-testid={`button-install-${listing.slug}`}
        >
          <Download className="w-3 h-3 mr-1" /> Install
        </Button>
      </div>
    </Card>
  );
}
```

**Step 2: Create the marketplace browse page**

Create `client/src/pages/marketplace.tsx`:

```typescript
import { useQuery } from "@tanstack/react-query";
import { type Listing } from "@shared/schema";
import { apiRequest } from "@/lib/queryClient";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Card } from "@/components/ui/card";
import { ListingCard } from "@/components/listing-card";
import { MARKETPLACE_CATEGORIES, LISTING_TYPE_FILTERS } from "@/lib/constants";
import { useMutationWithToast } from "@/hooks/use-mutation-with-toast";
import { Search, Store, Loader2 } from "lucide-react";
import { useState } from "react";

export default function Marketplace() {
  const [activeCategory, setActiveCategory] = useState("all");
  const [activeType, setActiveType] = useState("all");
  const [searchQuery, setSearchQuery] = useState("");
  const [isSearching, setIsSearching] = useState(false);

  const { data: allListings, isLoading } = useQuery<Listing[]>({
    queryKey: ["/api/market/listings",
      activeType !== "all" ? `?type=${activeType}` : "",
      activeCategory !== "all" ? `${activeType !== "all" ? "&" : "?"}category=${activeCategory}` : "",
    ].join(""),
  });

  const { data: searchResults } = useQuery<Listing[]>({
    queryKey: ["/api/market/listings/search", `?q=${searchQuery}`].join(""),
    enabled: searchQuery.length >= 2,
  });

  const installMutation = useMutationWithToast<void, string>({
    mutationFn: async (listingId: string) => {
      await apiRequest("POST", `/api/market/listings/${listingId}/install`);
    },
    invalidateKeys: [["/api/market/listings"]],
    successMessage: { title: "Installed", description: "Artifact installed successfully." },
  });

  const displayListings = searchQuery.length >= 2 ? searchResults : allListings;

  return (
    <div className="max-w-6xl mx-auto px-4 sm:px-6 py-6">
      <div className="flex items-center gap-3 mb-2">
        <Store className="w-5 h-5 text-primary" />
        <h1 className="text-2xl font-bold" data-testid="text-market-title">Marketplace</h1>
        <Badge variant="secondary" className="text-xs">ChittyMarket</Badge>
      </div>
      <p className="text-sm text-muted-foreground mb-6">
        Discover and install agents, skills, templates, and more from the ChittyOS ecosystem
      </p>

      {/* Search */}
      <div className="relative max-w-md mb-6">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
        <Input
          type="search"
          placeholder="Search marketplace..."
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          className="pl-9"
          data-testid="input-market-search"
        />
      </div>

      {/* Type filters */}
      <div className="flex items-center gap-2 mb-3 flex-wrap">
        {LISTING_TYPE_FILTERS.map((filter) => (
          <Button
            key={filter.value}
            variant={activeType === filter.value ? "default" : "secondary"}
            size="sm"
            onClick={() => setActiveType(filter.value)}
            data-testid={`button-type-${filter.value}`}
          >
            {filter.label}
          </Button>
        ))}
      </div>

      {/* Category filters */}
      <div className="flex items-center gap-2 mb-6 flex-wrap">
        {MARKETPLACE_CATEGORIES.map((cat) => (
          <Button
            key={cat.value}
            variant={activeCategory === cat.value ? "outline" : "ghost"}
            size="sm"
            onClick={() => setActiveCategory(cat.value)}
            data-testid={`button-cat-${cat.value}`}
          >
            {cat.label}
          </Button>
        ))}
      </div>

      {/* Listings grid */}
      {isLoading ? (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
          {Array.from({ length: 6 }).map((_, i) => (
            <Card key={i} className="p-5">
              <div className="animate-pulse space-y-3">
                <div className="flex items-start gap-3">
                  <div className="w-10 h-10 rounded-md bg-muted" />
                  <div className="flex-1 space-y-2">
                    <div className="h-4 bg-muted rounded w-2/3" />
                    <div className="h-3 bg-muted rounded w-full" />
                  </div>
                </div>
              </div>
            </Card>
          ))}
        </div>
      ) : displayListings && displayListings.length > 0 ? (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
          {displayListings.map((listing) => (
            <ListingCard
              key={listing.id}
              listing={listing}
              onInstall={(id) => installMutation.mutate(id)}
              installing={installMutation.isPending}
            />
          ))}
        </div>
      ) : (
        <div className="text-center py-16">
          <Store className="w-8 h-8 mx-auto text-muted-foreground mb-3" />
          <p className="text-sm text-muted-foreground">
            {searchQuery ? "No results found" : "No listings in this category"}
          </p>
        </div>
      )}
    </div>
  );
}
```

**Step 3: Commit**

```bash
git add client/src/pages/marketplace.tsx client/src/components/listing-card.tsx
git commit -m "feat(ui): add marketplace browse page with search, filters, and listing cards"
```

---

### Task 6: Build Listing Detail Page

**Files:**
- Create: `client/src/pages/listing-detail.tsx`

**Step 1: Create the listing detail page**

Create `client/src/pages/listing-detail.tsx`:

```typescript
import { useQuery } from "@tanstack/react-query";
import { useRoute, useLocation } from "wouter";
import { type Listing, type ListingReview } from "@shared/schema";
import { apiRequest } from "@/lib/queryClient";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Card } from "@/components/ui/card";
import { Textarea } from "@/components/ui/textarea";
import { iconMap } from "@/lib/icons";
import { LISTING_TYPE_LABELS } from "@/lib/constants";
import { useMutationWithToast } from "@/hooks/use-mutation-with-toast";
import {
  ArrowLeft, Download, Star, Package, ExternalLink, Loader2
} from "lucide-react";
import { useState } from "react";

export default function ListingDetail() {
  const [, params] = useRoute("/market/:slug");
  const [, navigate] = useLocation();
  const [rating, setRating] = useState(0);
  const [comment, setComment] = useState("");

  const { data: listing, isLoading } = useQuery<Listing>({
    queryKey: [`/api/market/listings/${params?.slug}`],
    enabled: !!params?.slug,
  });

  const { data: reviews } = useQuery<ListingReview[]>({
    queryKey: [`/api/market/listings/${params?.slug}/reviews`],
    enabled: !!params?.slug,
  });

  const installMutation = useMutationWithToast<void, void>({
    mutationFn: async () => {
      if (!listing) return;
      await apiRequest("POST", `/api/market/listings/${listing.id}/install`);
    },
    invalidateKeys: [[`/api/market/listings/${params?.slug}`]],
    successMessage: { title: "Installed", description: "Artifact installed successfully." },
  });

  const reviewMutation = useMutationWithToast<void, void>({
    mutationFn: async () => {
      if (!listing) return;
      await apiRequest("POST", `/api/market/listings/${listing.id}/reviews`, { rating, comment });
    },
    invalidateKeys: [
      [`/api/market/listings/${params?.slug}`],
      [`/api/market/listings/${params?.slug}/reviews`],
    ],
    successMessage: { title: "Review submitted", description: "Thanks for your feedback." },
  });

  if (isLoading || !listing) {
    return (
      <div className="max-w-4xl mx-auto px-4 sm:px-6 py-6">
        <div className="animate-pulse space-y-4">
          <div className="h-8 bg-muted rounded w-1/3" />
          <div className="h-4 bg-muted rounded w-2/3" />
        </div>
      </div>
    );
  }

  const IconComponent = iconMap[listing.icon] || Package;

  return (
    <div className="max-w-4xl mx-auto px-4 sm:px-6 py-6">
      <Button variant="ghost" size="sm" onClick={() => navigate("/market")} className="mb-4 -ml-2">
        <ArrowLeft className="w-4 h-4 mr-1" /> Marketplace
      </Button>

      {/* Header */}
      <div className="flex items-start gap-4 mb-6">
        <div
          className="w-14 h-14 rounded-lg flex items-center justify-center shrink-0"
          style={{ backgroundColor: listing.color + "18", color: listing.color }}
        >
          <IconComponent className="w-7 h-7" />
        </div>
        <div className="flex-1">
          <div className="flex items-center gap-2 mb-1">
            <h1 className="text-2xl font-bold">{listing.title}</h1>
            <Badge variant="secondary">{LISTING_TYPE_LABELS[listing.type]}</Badge>
          </div>
          <p className="text-sm text-muted-foreground">{listing.description}</p>
          <div className="flex items-center gap-4 mt-2 text-sm text-muted-foreground">
            <span className="flex items-center gap-1">
              <Download className="w-4 h-4" /> {listing.installCount} installs
            </span>
            {listing.avgRating && (
              <span className="flex items-center gap-1">
                <Star className="w-4 h-4 fill-amber-400 text-amber-400" /> {listing.avgRating} ({listing.reviewCount})
              </span>
            )}
            <span>v{listing.version}</span>
          </div>
        </div>
        <Button onClick={() => installMutation.mutate()} disabled={installMutation.isPending}>
          {installMutation.isPending ? <Loader2 className="w-4 h-4 mr-1 animate-spin" /> : <Download className="w-4 h-4 mr-1" />}
          Install
        </Button>
      </div>

      {/* Tags */}
      {listing.tags && listing.tags.length > 0 && (
        <div className="flex flex-wrap gap-1.5 mb-6">
          {listing.tags.map((tag, idx) => (
            <Badge key={idx} variant="outline" className="text-xs">{tag}</Badge>
          ))}
        </div>
      )}

      {/* README */}
      {listing.readmeContent && (
        <Card className="p-6 mb-6">
          <h2 className="font-semibold mb-3">Documentation</h2>
          <div className="prose prose-sm dark:prose-invert max-w-none whitespace-pre-wrap">
            {listing.readmeContent}
          </div>
        </Card>
      )}

      {/* Reviews */}
      <Card className="p-6">
        <h2 className="font-semibold mb-4">Reviews ({listing.reviewCount})</h2>

        {/* Submit review */}
        <div className="border rounded-lg p-4 mb-4">
          <div className="flex items-center gap-1 mb-2">
            {[1, 2, 3, 4, 5].map((n) => (
              <button key={n} onClick={() => setRating(n)} className="focus:outline-none">
                <Star className={`w-5 h-5 ${n <= rating ? "fill-amber-400 text-amber-400" : "text-muted-foreground"}`} />
              </button>
            ))}
          </div>
          <Textarea
            placeholder="Write a review..."
            value={comment}
            onChange={(e) => setComment(e.target.value)}
            className="mb-2"
          />
          <Button
            size="sm"
            onClick={() => reviewMutation.mutate()}
            disabled={rating === 0 || reviewMutation.isPending}
          >
            Submit Review
          </Button>
        </div>

        {/* Review list */}
        {reviews && reviews.length > 0 ? (
          <div className="space-y-3">
            {reviews.map((review) => (
              <div key={review.id} className="border-b pb-3 last:border-0">
                <div className="flex items-center gap-1 mb-1">
                  {[1, 2, 3, 4, 5].map((n) => (
                    <Star key={n} className={`w-3 h-3 ${n <= review.rating ? "fill-amber-400 text-amber-400" : "text-muted-foreground"}`} />
                  ))}
                  <span className="text-[10px] text-muted-foreground ml-2">
                    {new Date(review.createdAt).toLocaleDateString()}
                  </span>
                </div>
                {review.comment && <p className="text-sm">{review.comment}</p>}
              </div>
            ))}
          </div>
        ) : (
          <p className="text-sm text-muted-foreground">No reviews yet. Be the first!</p>
        )}
      </Card>
    </div>
  );
}
```

**Step 2: Commit**

```bash
git add client/src/pages/listing-detail.tsx
git commit -m "feat(ui): add listing detail page with reviews and install"
```

---

### Task 7: Wire Marketplace into App Router and Header

**Files:**
- Modify: `client/src/App.tsx`
- Modify: `client/src/components/app-header.tsx`

**Step 1: Add routes to App.tsx**

Import the new pages and add routes:

```typescript
import Marketplace from "@/pages/marketplace";
import ListingDetail from "@/pages/listing-detail";
```

Add inside the `<Switch>`:

```typescript
<Route path="/market" component={Marketplace} />
<Route path="/market/:slug" component={ListingDetail} />
```

**Step 2: Add Market nav button to app-header.tsx**

Import `Store` from lucide-react. Add before the Skills button:

```typescript
<Button
  size="sm"
  variant="ghost"
  onClick={() => navigate("/market")}
  data-testid="button-nav-market"
>
  <Store className="w-4 h-4 mr-1" />
  <span className="hidden sm:inline">Market</span>
</Button>
```

**Step 3: Commit**

```bash
git add client/src/App.tsx client/src/components/app-header.tsx
git commit -m "feat(ui): wire marketplace routes and nav button into app shell"
```

---

### Task 8: Seed Marketplace Data

**Files:**
- Modify: `server/seed.ts`

**Step 1: Add marketplace seeding**

Add a `seedMarketplace` function that converts existing skills to marketplace listings:

```typescript
import { listings } from "@shared/schema";

export async function seedMarketplace(): Promise<void> {
  try {
    const existingListings = await db.select().from(listings);
    if (existingListings.length > 0) return;

    const allSkills = await db.select().from(skills);
    let count = 0;

    for (const skill of allSkills) {
      const slug = skill.repoName || skill.name.toLowerCase().replace(/[^a-z0-9]+/g, "-");
      await db.insert(listings).values({
        type: "skill",
        skillId: skill.id,
        slug,
        title: skill.name,
        description: skill.description,
        version: "1.0.0",
        tags: skill.capabilities || [],
        category: skill.category,
        icon: skill.icon,
        color: skill.color,
        published: true,
        installCount: skill.installCount,
      });
      count++;
    }

    // Seed a few template listings
    const templateListings = [
      {
        type: "template" as const,
        slug: "cloudflare-worker-starter",
        title: "Cloudflare Worker Starter",
        description: "ChittyOS-compliant Worker template with health endpoint, CHARTER.md, and wrangler.toml",
        tags: ["cloudflare", "worker", "starter"],
        category: "devops",
        icon: "server",
        color: "#f97316",
        published: true,
      },
      {
        type: "mcp-config" as const,
        slug: "neon-mcp-config",
        title: "Neon PostgreSQL MCP Config",
        description: "Pre-configured .mcp.json for @neondatabase/mcp-server-neon with 1Password credential injection",
        tags: ["neon", "postgresql", "mcp"],
        category: "data",
        icon: "settings",
        color: "#06b6d4",
        published: true,
      },
      {
        type: "hook-recipe" as const,
        slug: "credential-blocker",
        title: "Credential Leakage Blocker",
        description: "PostToolUse hook that blocks responses containing API keys, tokens, or connection strings",
        tags: ["security", "hooks", "credentials"],
        category: "trust",
        icon: "shield",
        color: "#ea4335",
        published: true,
      },
    ];

    for (const tpl of templateListings) {
      await db.insert(listings).values(tpl);
    }

    console.log(`Seeded ${count} skill listings + ${templateListings.length} artifact listings to marketplace`);
  } catch (error) {
    console.error("Failed to seed marketplace:", error);
  }
}
```

Call `seedMarketplace()` at the end of `seedDatabase()`.

**Step 2: Commit**

```bash
git add server/seed.ts
git commit -m "feat(seed): populate marketplace from existing skills + sample artifacts"
```

---

### Task 9: Deploy market.chitty.cc Worker

**Files:**
- Create: `/Users/nb/Desktop/Projects/github.com/CHITTYOS/chittymarket/src/index.ts`
- Create: `/Users/nb/Desktop/Projects/github.com/CHITTYOS/chittymarket/wrangler.toml`
- Create: `/Users/nb/Desktop/Projects/github.com/CHITTYOS/chittymarket/package.json`
- Create: `/Users/nb/Desktop/Projects/github.com/CHITTYOS/chittymarket/tsconfig.json`

**Step 1: Initialize the Worker project**

`package.json`:
```json
{
  "name": "chittymarket",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev": "wrangler dev",
    "deploy": "wrangler deploy",
    "check": "tsc --noEmit"
  },
  "dependencies": {
    "hono": "^4.0.0",
    "@neondatabase/serverless": "^0.10.0"
  },
  "devDependencies": {
    "@cloudflare/workers-types": "^4.0.0",
    "typescript": "^5.0.0",
    "wrangler": "^3.0.0"
  }
}
```

`wrangler.toml`:
```toml
name = "chittymarket"
main = "src/index.ts"
compatibility_date = "2025-12-01"

[vars]
ENVIRONMENT = "production"

# DATABASE_URL set via: wrangler secret put DATABASE_URL
```

`tsconfig.json`:
```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ES2022",
    "moduleResolution": "bundler",
    "strict": true,
    "esModuleInterop": true,
    "types": ["@cloudflare/workers-types"]
  },
  "include": ["src"]
}
```

**Step 2: Write the Worker**

`src/index.ts`:
```typescript
import { Hono } from "hono";
import { cors } from "hono/cors";
import { neon } from "@neondatabase/serverless";

type Bindings = {
  DATABASE_URL: string;
};

const app = new Hono<{ Bindings: Bindings }>();

app.use("*", cors());

app.get("/health", (c) =>
  c.json({ status: "ok", service: "chittymarket", version: "1.0.0" })
);

app.get("/api/v1/listings", async (c) => {
  const sql = neon(c.env.DATABASE_URL);
  const type = c.req.query("type");
  const category = c.req.query("category");
  const featured = c.req.query("featured");

  let query = "SELECT * FROM listings WHERE published = true";
  const params: string[] = [];

  if (type) {
    params.push(type);
    query += ` AND type = $${params.length}`;
  }
  if (category) {
    params.push(category);
    query += ` AND category = $${params.length}`;
  }
  if (featured === "true") {
    query += " AND featured = true";
  }

  query += " ORDER BY install_count DESC LIMIT 100";

  const rows = await sql(query, params);
  return c.json(rows);
});

app.get("/api/v1/listings/search", async (c) => {
  const q = c.req.query("q");
  if (!q) return c.json({ error: "Query parameter 'q' is required" }, 400);

  const sql = neon(c.env.DATABASE_URL);
  const rows = await sql(
    `SELECT * FROM listings
     WHERE published = true
       AND to_tsvector('english', coalesce(title,'') || ' ' || coalesce(description,''))
           @@ plainto_tsquery('english', $1)
     ORDER BY install_count DESC LIMIT 50`,
    [q]
  );
  return c.json(rows);
});

app.get("/api/v1/listings/:slug", async (c) => {
  const sql = neon(c.env.DATABASE_URL);
  const rows = await sql(
    "SELECT * FROM listings WHERE slug = $1 AND published = true",
    [c.req.param("slug")]
  );
  if (rows.length === 0) return c.json({ error: "Not found" }, 404);
  return c.json(rows[0]);
});

app.get("/api/v1/listings/:slug/reviews", async (c) => {
  const sql = neon(c.env.DATABASE_URL);
  const listing = await sql(
    "SELECT id FROM listings WHERE slug = $1",
    [c.req.param("slug")]
  );
  if (listing.length === 0) return c.json({ error: "Not found" }, 404);

  const reviews = await sql(
    "SELECT * FROM listing_reviews WHERE listing_id = $1 ORDER BY created_at DESC",
    [listing[0].id]
  );
  return c.json(reviews);
});

app.get("/api/v1/collections", async (c) => {
  const sql = neon(c.env.DATABASE_URL);
  const rows = await sql("SELECT * FROM marketplace_collections ORDER BY name");
  return c.json(rows);
});

app.get("/api/v1/collections/:slug", async (c) => {
  const sql = neon(c.env.DATABASE_URL);
  const collection = await sql(
    "SELECT * FROM marketplace_collections WHERE slug = $1",
    [c.req.param("slug")]
  );
  if (collection.length === 0) return c.json({ error: "Not found" }, 404);

  const items = await sql(
    `SELECT l.* FROM listings l
     INNER JOIN collection_listings cl ON cl.listing_id = l.id
     WHERE cl.collection_id = $1
     ORDER BY cl.position`,
    [collection[0].id]
  );

  return c.json({ ...collection[0], listings: items });
});

export default app;
```

**Step 3: Install dependencies and type-check**

```bash
cd /Users/nb/Desktop/Projects/github.com/CHITTYOS/chittymarket
npm install
npx tsc --noEmit
```

**Step 4: Deploy**

```bash
# Set the database URL secret (from Studio's Neon project)
wrangler secret put DATABASE_URL

# Deploy
npx wrangler deploy
curl -s https://market.chitty.cc/health | jq .
```

**Step 5: Commit**

```bash
git add src/ wrangler.toml package.json tsconfig.json
git commit -m "feat: deploy market.chitty.cc Worker — read-only public marketplace API"
```

---

### Task 10: Create Compliance Triad

**Files:**
- Create: `/Users/nb/Desktop/Projects/github.com/CHITTYOS/chittymarket/CHARTER.md`
- Create: `/Users/nb/Desktop/Projects/github.com/CHITTYOS/chittymarket/CHITTY.md`
- Create: `/Users/nb/Desktop/Projects/github.com/CHITTYOS/chittymarket/CLAUDE.md`

**Step 1: Write CHARTER.md**

Core content: canonical URI `chittycanon://gov/charter/chittymarket`, Tier 5 (Application), mission ("unified marketplace for ChittyOS artifacts"), scope (IS: browse/search/install/review; IS NOT: agent execution, payment processing), dependencies (ChittyAgent Studio, Neon, ChittyRegistry), API contract for `market.chitty.cc` endpoints.

**Step 2: Write CHITTY.md**

Core content: canonical URI `chittycanon://docs/tech/architecture/chittymarket`, hybrid architecture (Studio + Worker), stack (TypeScript, Hono, Drizzle, Neon, Cloudflare Workers), ecosystem position, certification status DRAFT.

**Step 3: Write CLAUDE.md**

Core content: canonical URI `chittycanon://docs/tech/spec/chittymarket`, dev commands (`npm run dev`, `wrangler deploy`), schema patterns (snake_case columns, UUID PKs, canonical annotations), integration with Studio.

**Step 4: Commit**

```bash
git add CHARTER.md CHITTY.md CLAUDE.md
git commit -m "docs: add compliance triad — CHARTER.md, CHITTY.md, CLAUDE.md"
```

---

## Summary

| Task | What | Files |
|------|------|-------|
| 1 | Drizzle schema: marketplace tables | `shared/schema.ts` |
| 2 | Storage layer: CRUD methods | `server/storage.ts` |
| 3 | API routes: `/api/market/*` | `server/routes.ts` |
| 4 | UI constants: types, categories | `client/src/lib/constants.ts` |
| 5 | Browse page + listing card | `client/src/pages/marketplace.tsx`, `client/src/components/listing-card.tsx` |
| 6 | Detail page with reviews | `client/src/pages/listing-detail.tsx` |
| 7 | Router + header nav | `client/src/App.tsx`, `client/src/components/app-header.tsx` |
| 8 | Seed data | `server/seed.ts` |
| 9 | Worker at market.chitty.cc | `chittymarket/src/index.ts`, `wrangler.toml`, `package.json` |
| 10 | Compliance triad | `CHARTER.md`, `CHITTY.md`, `CLAUDE.md` |
