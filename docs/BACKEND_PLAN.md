# CookSavvy Backend Plan

> Written: 2026-04-03
> Audience: Solo iOS developer with basic backend knowledge

## Table of Contents

1. [Why You Need a Backend](#1-why-you-need-a-backend)
2. [Platform Choice](#2-platform-choice)
3. [Architecture Overview](#3-architecture-overview)
4. [Phase 1 — API Proxy (Ship-Blocker)](#4-phase-1--api-proxy-ship-blocker)
5. [Phase 2 — User Accounts & Sync](#5-phase-2--user-accounts--sync)
6. [Phase 3 — Smart Features](#6-phase-3--smart-features)
7. [Database Design](#7-database-design)
8. [Authentication Strategy](#8-authentication-strategy)
9. [Cost Estimates](#9-cost-estimates)
10. [Alternatives Considered](#10-alternatives-considered)
11. [Security Checklist](#11-security-checklist)
12. [iOS App Changes Required](#12-ios-app-changes-required)
13. [Glossary](#13-glossary)

---

## 1. Why You Need a Backend

Three problems make a backend mandatory before App Store launch:

| Problem | Why it's critical |
|---------|-------------------|
| **API keys in the app binary** | Anyone can extract your OpenAI/Gemini/Spoonacular keys from the `.ipa` file. They can run up your bill or get your keys revoked. This is the #1 ship-blocker. |
| **No analytics** | You can't measure retention, conversion, or feature usage. You're flying blind on what to improve. |
| **No crash reporting** | When something breaks in production you won't know until 1-star reviews appear. |

Beyond these blockers, a backend unlocks:
- User accounts (no data loss on reinstall/device switch)
- Cloud sync of favorites, cooking history, shopping lists
- Personalized recommendations across the user base
- Push notifications for re-engagement
- Recipe sharing via deep links

---

## 2. Platform Choice

### Recommendation: **Supabase**

Supabase is an open-source Firebase alternative built on PostgreSQL. It provides auth, database, storage, edge functions, and real-time sync — all from a single dashboard.

### Why Supabase over alternatives

| Criterion | Supabase | Firebase | CloudKit | Custom (e.g., Railway + Express) |
|-----------|----------|----------|----------|-----------------------------------|
| **Learning curve** | Low — SQL-based, good docs | Low — but NoSQL requires different mental model | Low for basic, steep for advanced | High — you build everything |
| **Auth built-in** | Yes (email, Apple Sign-In, Google) | Yes | Apple ID only | You build it (Passport.js, etc.) |
| **Database** | PostgreSQL (relational, like your SQLite) | Firestore (document/NoSQL) | CloudKit (key-value + records) | Your choice |
| **Edge Functions** | Yes (Deno/TypeScript) | Yes (Cloud Functions, Node.js) | No server-side logic | Yes |
| **Real-time sync** | Yes (Postgres changes → client) | Yes (Firestore listeners) | Yes (CKSubscription) | You build it |
| **Free tier** | 500 MB DB, 1 GB storage, 2 GB bandwidth, 500K edge function invocations/mo | Spark plan: 1 GiB Firestore, 5 GB storage | 1 GB per user (Apple pays) | Varies |
| **Vendor lock-in** | Low — standard Postgres, can self-host | High — proprietary APIs | Very high — Apple only, no Android/web ever | None |
| **Pricing predictability** | Good — usage-based with clear tiers | Risky — Firestore reads can spike unpredictably | Free (Apple pays) | Predictable (fixed server cost) |
| **iOS SDK** | Official Swift SDK (`supabase-swift`) | Official Swift SDK | Native CloudKit framework | You build it (URLSession) |
| **Open source** | Yes — can self-host if needed | No | No | Depends |

### Why not Firebase?

Firebase is the most popular choice, but:

1. **NoSQL mismatch.** Your app already thinks in relational terms (recipes ↔ ingredients junction table, foreign keys, etc.). Firestore's document model would force you to restructure your data and learn denormalization patterns. Supabase uses PostgreSQL — same relational model as your SQLite, so your existing queries translate almost directly.

2. **Unpredictable costs.** Firestore charges per document read. A recipe search returning 20 recipes with ingredients = potentially 60+ reads. At scale this adds up fast and is hard to predict. Supabase charges by database size and bandwidth, which is more predictable.

3. **Vendor lock-in.** Once you're on Firestore, migrating away is painful. Supabase is standard PostgreSQL — you can dump your database and move it anywhere.

### Why not CloudKit?

CloudKit is Apple's "free backend" and tempting for an iOS-only app:

1. **No server-side logic.** You can't run edge functions, so the API proxy problem (hiding API keys) remains unsolved. You'd still need a separate server for that — defeating the purpose.

2. **Apple ID only.** Users must have an Apple ID and be signed into iCloud. While most iPhone users are, it fails silently when iCloud is disabled, creating confusing UX.

3. **No Android/web future.** If you ever want to expand beyond iOS, CloudKit is a dead end.

4. **Limited querying.** CloudKit's query capabilities are basic compared to SQL. Your ingredient-matching logic (find recipes containing 3+ of these 8 ingredients) would be awkward to express.

**However**, CloudKit could be a good *complement* — using it for simple key-value sync (favorites, preferences) while Supabase handles the heavy lifting. This is a valid hybrid approach for later.

### Why not a custom backend (Express/FastAPI on Railway/Fly.io)?

1. **You'd build everything from scratch.** Auth, database migrations, API endpoints, rate limiting, error handling — all on you. For a solo developer, this is months of work before you ship any app features.

2. **Ongoing maintenance burden.** Security patches, scaling, monitoring, backups — these don't go away.

3. **When it makes sense:** If your app becomes very successful and you need custom logic that Supabase can't handle, you can migrate. Supabase is standard Postgres, so this path is always open.

---

## 3. Architecture Overview

```
┌─────────────┐         ┌──────────────────────────────────────────┐
│  CookSavvy  │         │              Supabase                    │
│   iOS App   │         │                                          │
│             │  HTTPS  │  ┌─────────────┐    ┌─────────────────┐  │
│  supabase-  │────────▶│  │  Auth       │    │  PostgreSQL DB  │  │
│  swift SDK  │         │  │  (Apple ID, │    │  (users, sync,  │  │
│             │         │  │   email)    │    │   analytics)    │  │
│  Local GRDB │         │  └─────────────┘    └─────────────────┘  │
│  (offline)  │         │                                          │
│             │         │  ┌─────────────────────────────────────┐  │
│             │────────▶│  │  Edge Functions (Deno/TypeScript)   │  │
│             │         │  │                                     │  │
│             │         │  │  /detect-ingredients → OpenAI API   │  │
│             │         │  │  /generate-recipes  → OpenAI API   │  │
│             │         │  │  /search-recipes    → Spoonacular  │  │
│             │         │  │  /track-event       → Analytics DB  │  │
│             │         │  └─────────────────────────────────────┘  │
│             │         │                                          │
│             │         │  ┌─────────────┐    ┌─────────────────┐  │
│             │────────▶│  │  Storage    │    │  Real-time      │  │
│             │         │  │  (images)   │    │  (sync)         │  │
│             │         │  └─────────────┘    └─────────────────┘  │
└─────────────┘         └──────────────────────────────────────────┘
                                    │
                                    ▼
                        ┌───────────────────────┐
                        │  External APIs         │
                        │  • OpenAI (gpt-4o-mini)│
                        │  • Gemini (fallback)   │
                        │  • Spoonacular         │
                        └───────────────────────┘
```

**Key principle: Offline-first.** The app continues to work fully offline with its local GRDB database for free-tier features. The backend enhances the experience but never blocks it.

---

## 4. Phase 1 — API Proxy (Ship-Blocker)

**Goal:** Remove API keys from the app binary. This is the minimum work needed before App Store submission.

**Timeline estimate:** This is the first thing to build.

### What you build

Three Supabase Edge Functions that act as proxies:

#### 1. `detect-ingredients`

```
POST /functions/v1/detect-ingredients
Authorization: Bearer <supabase-user-jwt>
Content-Type: application/json

{
  "image_base64": "<base64-encoded-photo>",
  "mime_type": "image/jpeg"
}

Response:
{
  "ingredients": ["tomato", "onion", "garlic", "chicken breast"]
}
```

The edge function:
1. Validates the JWT (is this a real logged-in user?)
2. Checks if user is premium (query `subscriptions` table)
3. Checks rate limits (free: 5/week, premium: unlimited)
4. Forwards the image to OpenAI's vision API using the server-side API key
5. Falls back to Gemini if OpenAI fails
6. Returns parsed ingredients
7. Logs the event to the analytics table

#### 2. `generate-recipes`

```
POST /functions/v1/generate-recipes
Authorization: Bearer <supabase-user-jwt>

{
  "ingredients": ["tomato", "onion", "garlic"],
  "count": 5
}

Response:
{
  "recipes": [
    {
      "title": "Quick Tomato Pasta",
      "ingredients": [...],
      "instructions": [...],
      "prep_time": 15,
      "cook_time": 20,
      "servings": 4,
      "complexity": "easy",
      "calories": 350
    }
  ]
}
```

#### 3. `search-recipes`

```
POST /functions/v1/search-recipes
Authorization: Bearer <supabase-user-jwt>

{
  "ingredients": ["chicken", "rice", "broccoli"],
  "count": 10
}

Response:
{
  "recipes": [...]   // Same Recipe format
}
```

### Rate limiting

Implement per-user rate limits in edge functions using a simple `api_usage` table:

| Column | Type | Purpose |
|--------|------|---------|
| `user_id` | UUID | FK to auth.users |
| `endpoint` | text | Which function was called |
| `called_at` | timestamptz | When |

Query: `SELECT count(*) FROM api_usage WHERE user_id = $1 AND endpoint = 'detect-ingredients' AND called_at > now() - interval '7 days'`

If count >= limit → return 429 Too Many Requests.

### Analytics (also Phase 1)

Instead of integrating a third-party analytics service (Mixpanel, Amplitude, etc.), you can start with a simple Supabase table:

```sql
CREATE TABLE analytics_events (
  id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id    uuid REFERENCES auth.users,
  event_name text NOT NULL,
  properties jsonb DEFAULT '{}',
  created_at timestamptz DEFAULT now()
);
```

Edge function `track-event`:

```
POST /functions/v1/track-event
{ "event": "recipe_cooked", "properties": { "recipe_id": "abc", "duration": 1200 } }
```

For crash reporting, integrate a dedicated service like **Sentry** (free tier: 5K events/mo) or **Firebase Crashlytics** (free, no backend needed). These are purpose-built and far better than a custom solution.

**Decision: Sentry vs Crashlytics**
- Crashlytics: zero cost forever, but it's a Firebase dependency (which we're otherwise avoiding)
- Sentry: more powerful, cross-platform, but paid beyond free tier
- **Recommendation:** Start with Crashlytics — it's free, works independently from Firestore, and requires minimal setup. Swap to Sentry later if needed.

---

## 5. Phase 2 — User Accounts & Sync

**Goal:** Users sign in, their data syncs across devices, and they don't lose data on reinstall.

### Authentication

Supabase Auth supports:
- **Sign in with Apple** (required by App Store if you offer any social login)
- Email + password
- Magic links (passwordless email)

**Recommendation:** Ship with **Sign in with Apple only** initially. It's the fastest path, Apple requires it if you offer social login anyway, and most iPhone users prefer it. Add email auth later if needed.

### What gets synced

Not everything needs to sync. The bundled recipe dataset (20K recipes) stays local — it's the same for everyone. Only user-specific data syncs:

| Data | Sync? | Why / Why not |
|------|-------|---------------|
| Favorites | Yes | Core user data, small payload |
| Cooking sessions | Yes | History, achievements depend on it |
| User-created recipes | Yes | User-generated content, would be devastating to lose |
| Shopping list | Yes | Active task list, useful across devices |
| Dietary preferences | Yes | Small, important for experience |
| Recent searches | No | Low value, ephemeral |
| Recent ingredients | No | Low value, ephemeral |
| Recent recipes (viewed) | No | Low value, can be rebuilt from cooking sessions |
| Camera scan count | Server-side | Move tracking to server (more reliable than UserDefaults) |

### Sync strategy: **Offline-first with server timestamps**

This is simpler than full CRDT-based sync and good enough for a single-user app:

1. Each syncable record has a `updated_at` timestamp (both locally and on server)
2. On sync: app sends all records changed since last sync
3. Server responds with all records changed since app's last sync
4. Conflict resolution: **last-write-wins** (newest `updated_at` wins)
5. Soft deletes: deleted records get `deleted_at` timestamp instead of being removed

**Why not real-time sync (Supabase Realtime)?** It's overkill for single-user data. A simple sync-on-app-launch + sync-on-change approach is sufficient and much simpler.

**Why not CRDTs?** Conflict-free replicated data types are the gold standard for sync but extremely complex to implement. Last-write-wins is fine when one user edits their own data on one device at a time (which is 99% of mobile usage).

---

## 6. Phase 3 — Smart Features

These come after launch, based on user feedback and metrics.

### Persistent Pantry

A server-side list of ingredients the user always has (salt, oil, garlic, etc.):

```sql
CREATE TABLE user_pantry (
  user_id         uuid REFERENCES auth.users,
  ingredient_name text NOT NULL,
  added_at        timestamptz DEFAULT now(),
  PRIMARY KEY (user_id, ingredient_name)
);
```

The app includes pantry items when calculating recipe match scores, so "you have 3 of 8 ingredients" becomes "you have 6 of 8" because salt, pepper, and olive oil are in the pantry.

### Better Recommendations

With cooking history on the server, you can run batch jobs (Supabase pg_cron or a scheduled edge function) that:
1. Cluster users by cooking patterns
2. Find recipes popular with similar users
3. Generate personalized "recommended for you" lists

This doesn't need ML initially — simple SQL queries like "recipes cooked by users who also cooked the same 3 recipes as you" (collaborative filtering via SQL) work surprisingly well.

### Recipe Sharing

Generate short links (e.g., `cooksavvy.app/r/abc123`) that:
- Open the app via Universal Links if installed
- Show a web preview if not (simple static page hosted on Supabase Storage)

### Push Notifications

Supabase doesn't have built-in push. Options:
- **OneSignal** (free tier: 10K subscribers) — easiest
- **Firebase Cloud Messaging** — free, but Firebase dependency
- **Direct APNs** via edge function — most control, most work

**Recommendation:** OneSignal for simplicity. Swap later if needed.

---

## 7. Database Design

### Supabase PostgreSQL Schema

```sql
-- Supabase manages auth.users automatically. These tables extend it.

-- User profile (extends Supabase auth)
CREATE TABLE user_profiles (
  id                uuid PRIMARY KEY REFERENCES auth.users ON DELETE CASCADE,
  display_name      text,
  dietary_prefs     jsonb DEFAULT '[]',  -- ["vegetarian", "gluten-free"]
  created_at        timestamptz DEFAULT now(),
  updated_at        timestamptz DEFAULT now()
);

-- Synced favorites
CREATE TABLE user_favorites (
  id          uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id     uuid REFERENCES auth.users ON DELETE CASCADE NOT NULL,
  recipe_id   text NOT NULL,              -- matches local GRDB recipe.id
  added_at    timestamptz DEFAULT now(),
  deleted_at  timestamptz,                -- soft delete for sync
  updated_at  timestamptz DEFAULT now(),
  UNIQUE (user_id, recipe_id)
);

-- Synced cooking sessions
CREATE TABLE user_cooking_sessions (
  id                     uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id                uuid REFERENCES auth.users ON DELETE CASCADE NOT NULL,
  recipe_id              text NOT NULL,
  cooked_at              timestamptz NOT NULL,
  duration_seconds       integer,
  rating                 integer CHECK (rating BETWEEN 1 AND 5),
  ingredients_rescued    jsonb DEFAULT '[]',
  updated_at             timestamptz DEFAULT now(),
  deleted_at             timestamptz
);

-- Synced user-created recipes
CREATE TABLE user_recipes (
  id                 uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id            uuid REFERENCES auth.users ON DELETE CASCADE NOT NULL,
  title              text NOT NULL,
  emoji              text,
  cuisine            text,
  image_url          text,                  -- Supabase Storage URL
  ingredients_json   jsonb NOT NULL,
  instructions_json  jsonb NOT NULL,
  additional_info    jsonb DEFAULT '{}',
  created_at         timestamptz DEFAULT now(),
  updated_at         timestamptz DEFAULT now(),
  deleted_at         timestamptz
);

-- Synced shopping list
CREATE TABLE user_shopping_items (
  id           uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id      uuid REFERENCES auth.users ON DELETE CASCADE NOT NULL,
  name         text NOT NULL,
  is_checked   boolean DEFAULT false,
  recipe_title text,
  added_at     timestamptz DEFAULT now(),
  updated_at   timestamptz DEFAULT now(),
  deleted_at   timestamptz
);

-- API usage tracking (for rate limits)
CREATE TABLE api_usage (
  id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id    uuid REFERENCES auth.users NOT NULL,
  endpoint   text NOT NULL,
  called_at  timestamptz DEFAULT now()
);
CREATE INDEX idx_api_usage_user_endpoint ON api_usage (user_id, endpoint, called_at);

-- Subscription status (server-side source of truth)
CREATE TABLE user_subscriptions (
  user_id             uuid PRIMARY KEY REFERENCES auth.users ON DELETE CASCADE,
  plan                text NOT NULL DEFAULT 'free',  -- 'free' or 'premium'
  original_tx_id      text,                           -- StoreKit original transaction ID
  expires_at          timestamptz,
  updated_at          timestamptz DEFAULT now()
);

-- Analytics events
CREATE TABLE analytics_events (
  id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id    uuid REFERENCES auth.users,
  event_name text NOT NULL,
  properties jsonb DEFAULT '{}',
  created_at timestamptz DEFAULT now()
);
CREATE INDEX idx_analytics_events_name ON analytics_events (event_name, created_at);
CREATE INDEX idx_analytics_events_user ON analytics_events (user_id, created_at);

-- Pantry (Phase 3)
CREATE TABLE user_pantry (
  user_id         uuid REFERENCES auth.users ON DELETE CASCADE,
  ingredient_name text NOT NULL,
  added_at        timestamptz DEFAULT now(),
  PRIMARY KEY (user_id, ingredient_name)
);
```

### Row-Level Security (RLS)

Supabase uses PostgreSQL's Row-Level Security so users can only access their own data. This is critical — without it, any authenticated user could read/modify anyone's data.

```sql
-- Example for favorites (apply same pattern to all user tables)
ALTER TABLE user_favorites ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own favorites"
  ON user_favorites
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
```

Apply this pattern to every `user_*` table. Supabase makes this easy in the dashboard.

---

## 8. Authentication Strategy

### Sign in with Apple (Primary)

Flow:
1. User taps "Sign in with Apple" in app
2. iOS shows system Apple ID sheet
3. App receives identity token
4. App sends token to Supabase Auth
5. Supabase verifies with Apple, creates/returns user
6. App stores Supabase JWT for subsequent requests

```swift
// Simplified — using supabase-swift SDK
let session = try await supabase.auth.signInWithIdToken(
    credentials: .init(
        provider: .apple,
        idToken: appleIDToken
    )
)
```

### Anonymous auth (for analytics before sign-in)

Supabase supports anonymous auth — the user gets a UUID without signing in. This lets you:
- Track analytics from first launch
- Enforce rate limits on free users
- Upgrade to a real account later (linking)

This is important because forcing sign-in before the user sees value kills conversion.

**Flow:**
1. First launch → create anonymous Supabase session
2. User uses app freely (free tier, tracked)
3. User decides to subscribe or wants sync → prompt for Apple Sign-In
4. Link anonymous account to Apple identity (preserves history)

---

## 9. Cost Estimates

### Supabase Pricing (as of 2026)

| Tier | Monthly | What you get |
|------|---------|--------------|
| **Free** | $0 | 500 MB DB, 1 GB storage, 2 GB bandwidth, 500K edge fn invocations, 50K monthly active users |
| **Pro** | $25 | 8 GB DB, 100 GB storage, 250 GB bandwidth, 2M edge fn invocations, 100K MAU |
| **Team** | $599 | SOC2, SSO, priority support — not needed yet |

### API Costs (passed through edge functions)

| API | Cost per call | Monthly estimate (1K users, 20% premium) |
|-----|--------------|-------------------------------------------|
| OpenAI vision (ingredient detection) | ~$0.01-0.03 | $20-60 (200 premium users × 10 scans/mo) |
| OpenAI chat (recipe generation) | ~$0.005 | $10-20 (200 premium users × 10 requests/mo) |
| Spoonacular (recipe search) | ~$0.003 | $6-12 (200 users × 10 searches/mo) |
| **Total API** | — | **~$36-92/mo** |

### Total Phase 1 Cost

| Item | Monthly |
|------|---------|
| Supabase Free tier | $0 |
| OpenAI API | $20-60 |
| Spoonacular API | $6-12 |
| Sentry Free tier | $0 |
| **Total** | **$26-72/mo** |

At $4.99/mo subscription price, you need ~6-15 paying subscribers to break even on API costs. With 1,000 users and 5% conversion, that's 50 subscribers = $250/mo, well above costs.

### When to upgrade to Supabase Pro ($25/mo)

When you hit any of:
- 500 MB database (probably around 10K users with sync data)
- 50K monthly active users
- 500K edge function invocations/month

---

## 10. Alternatives Considered

### Backend-as-a-Service Alternatives

| Service | Pros | Cons | Verdict |
|---------|------|------|---------|
| **Appwrite** | Open source, self-hosted option, similar to Supabase | Smaller community, less mature Swift SDK | Good alternative if you prefer self-hosting |
| **PocketBase** | Single Go binary, extremely simple, SQLite-based | One-person project, no managed hosting, limited edge functions | Too risky for production dependency |
| **AWS Amplify** | Full AWS ecosystem | Complex, over-engineered for this scale, AWS pricing surprises | Overkill |
| **Back4App (Parse)** | Parse Server (open source), managed hosting | Aging technology, smaller community | Not recommended for new projects |
| **Nhost** | GraphQL-first, Hasura-based | GraphQL adds complexity you don't need | Unnecessary complexity |

### "No Backend" Alternatives

| Approach | Pros | Cons | Verdict |
|----------|------|------|---------|
| **CloudKit only** | Free, native, zero server management | Can't proxy API keys (deal-breaker), limited queries, Apple-only | Doesn't solve the main problem |
| **CloudKit + one proxy** | CloudKit for sync, tiny Cloud Run/Lambda for API proxy | Two systems to maintain, CloudKit limitations for queries | Viable but more complex |
| **RevenueCat + TelemetryDeck** | RevenueCat for subscriptions, TelemetryDeck for analytics | Still need API proxy somewhere, no user data sync | Partial solution only |

### Database Alternatives (if not using Supabase's PostgreSQL)

| Database | Pros | Cons | Verdict |
|----------|------|------|---------|
| **Firestore** | Real-time, scales infinitely | NoSQL mismatch, unpredictable pricing, vendor lock-in | Not recommended |
| **PlanetScale (MySQL)** | Branching, scalable | Removed free tier in 2024, MySQL less suited than Postgres | Not recommended |
| **Turso (libSQL)** | SQLite-compatible, edge-native | Very new, small community | Interesting but risky |
| **MongoDB Atlas** | Document store, generous free tier | NoSQL mismatch (same as Firestore argument) | Not recommended |

---

## 11. Security Checklist

Things to get right from day one:

- [ ] **Row-Level Security on every table.** Without this, any authenticated user can read all data. Supabase RLS is your primary defense.
- [ ] **Server-side subscription verification.** Don't trust the app's claim of being premium. Verify StoreKit receipts server-side (Apple's App Store Server API) and store subscription status in `user_subscriptions`.
- [ ] **Rate limits on edge functions.** Even authenticated users shouldn't be able to make 1,000 API calls/minute.
- [ ] **API keys as Supabase secrets.** Store OpenAI/Spoonacular keys as [Supabase Secrets](https://supabase.com/docs/guides/functions/secrets) (encrypted env vars), never in code.
- [ ] **HTTPS only.** Supabase handles this automatically for managed instances.
- [ ] **Input validation in edge functions.** Validate image size, ingredient list length, etc. before forwarding to APIs.
- [ ] **Supabase anon key ≠ secret.** The anon key is safe to embed in the app (it's designed for client-side use). The service_role key must NEVER leave the server.
- [ ] **No direct database access from app.** Use Supabase client SDK (which respects RLS) or edge functions. Never expose the raw Postgres connection string.

---

## 12. iOS App Changes Required

### Phase 1 (API Proxy)

Minimal changes — the existing protocol-based architecture makes this clean:

1. **New `SupabaseService`** — Wraps `supabase-swift` SDK, manages auth session
2. **New `SupabaseLLMProvider`** conforming to `LLMProviderProtocol` — Calls edge function instead of OpenAI directly
3. **New `SupabaseRecipeAPIProvider`** conforming to `RecipeAPIProviderProtocol` — Calls edge function instead of Spoonacular directly
4. **Update `AppContainer`** — Wire new providers in RELEASE builds
5. **Remove `APIKeys.plist`** from the app bundle entirely
6. **Add anonymous auth on first launch** — Silent, no UI needed

The protocol-based provider pattern you already have (`LLMProviderProtocol`, `RecipeAPIProviderProtocol`) means the rest of the app doesn't change at all. The view models, coordinators, and views remain untouched.

### Phase 2 (Auth & Sync)

1. **Sign in with Apple UI** — New view + view model in Settings
2. **`SyncService`** — Manages bidirectional sync on launch and on data changes
3. **Update GRDB tables** — Add `updated_at`, `deleted_at`, `remote_id` columns for sync tracking
4. **Update `UserDataService`** — Trigger sync after local writes

### Adding the Supabase Swift SDK

```swift
// Package.swift or Xcode SPM
.package(url: "https://github.com/supabase/supabase-swift", from: "2.0.0")
```

---

## 13. Glossary

| Term | What it means |
|------|---------------|
| **Edge Function** | A small piece of server code that runs close to the user (on Supabase's infrastructure). Think of it as a mini API endpoint you write in TypeScript. |
| **JWT** | JSON Web Token — a signed string that proves "this user is authenticated." The app sends it with every request. |
| **RLS (Row-Level Security)** | PostgreSQL feature that automatically filters database rows so users can only see their own data. Like an invisible `WHERE user_id = current_user` on every query. |
| **Anon Key** | A public API key that Supabase gives you for client-side use. It's safe to put in the app — it only grants access that RLS allows. |
| **Service Role Key** | A secret admin key that bypasses RLS. Only used server-side (in edge functions). Never put this in the app. |
| **Soft Delete** | Instead of deleting a row, you set `deleted_at = now()`. This lets sync work correctly — the other device learns the item was deleted instead of never seeing the deletion. |
| **Last-Write-Wins** | Conflict resolution where the most recent edit wins. Simple and works well for single-user data. |
| **Anonymous Auth** | Creating a user session without requiring sign-in. The user gets a unique ID for tracking, and can later "upgrade" to a real account. |
| **StoreKit Server API** | Apple's server-to-server API for verifying that a user actually paid for a subscription (rather than trusting the app's claim). |

---

## Summary: What to Do When

| Phase | What | Depends on | Backend work | iOS work |
|-------|------|------------|-------------|----------|
| **1** | API proxy + analytics + crash reporting | Nothing | 3 edge functions, 2 tables, Sentry setup | New providers (swap existing protocol implementations) |
| **2** | Sign in with Apple + cloud sync | Phase 1 | Auth config, sync tables, RLS policies | Sign-in UI, SyncService, GRDB schema migration |
| **3** | Pantry, recommendations, sharing, push | Phase 2 + user feedback | Pantry table, recommendation queries, sharing endpoint | Pantry UI, deep links, notification handling |

Start with Phase 1. It's the smallest amount of work that unblocks App Store submission.
