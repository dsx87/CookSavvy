# CookSavvy 🍳

An iOS recipe app that suggests recipes based on the ingredients you already have. Snap a photo
of your fridge or type what's on hand, and CookSavvy finds matching recipes — fully offline on the
free tier, with AI photo recognition and online recipe sources for CookSavvy+ subscribers.

> A solo side project built to production quality: Swift 6 strict concurrency, MVVM-C, a tested
> service layer, StoreKit 2 subscriptions, and a Supabase backend that keeps all third-party API
> keys server-side.

<!-- Add screenshots/GIF here — a hero shot of ingredient input → results goes a long way. -->
<!-- ![CookSavvy](docs/screenshots/hero.png) -->

## Highlights

- **Ingredient-first discovery** — rank recipes by how well they match your pantry, with
  human-readable match explanations.
- **AI photo ingredient detection** — point the camera at your ingredients; a backend vision model
  returns a list (CookSavvy+; free tier gets 3 scans/week).
- **Smart natural-language search** — "quick gluten-free pasta under 30 minutes" is parsed into
  structured filters. Runs **on-device** via Apple Foundation Models on iOS 26+, with a server-side
  fallback for older devices.
- **Offline-first** — the free tier works entirely against a local SQLite (GRDB) recipe database;
  the network only ever enhances, never blocks.
- **Subscriptions** — CookSavvy+ monthly/annual via StoreKit 2, with a 7-day free trial.

## Tech Stack

| Area | Choice |
|------|--------|
| Language | **Swift 6** (full language mode, complete data-race safety) |
| Min target | iOS 18.0 |
| UI | SwiftUI (UIKit only where unavoidable) |
| Concurrency | Approachable Concurrency, `@MainActor`-by-default, actors for background work |
| Persistence | GRDB (SQLite) |
| Subscriptions | StoreKit 2 |
| Backend | Supabase Edge Functions (separate repo — keys held server-side) |
| AI (on-device) | Apple Foundation Models (iOS 26+) |
| Analytics / Crash | TelemetryDeck / Sentry (inert unless configured) |
| Observation | `@Observable` macro (no Combine in the app layer) |

## Architecture

CookSavvy follows **MVVM + Coordinator** with strict separation of concerns:

- **Views** — SwiftUI, presentation only; each owns a single `viewModel`.
- **ViewModels** — all state and business logic (`@Observable`).
- **Coordinators** — navigation flow and ViewModel construction.
- **Services** — data, AI, auth, subscription, persistence, all behind protocols for testability.
- **`AppContainer`** — dependency-injection container holding shared service instances.

**Concurrency model.** The app is `@MainActor` by default. UI types stay on the main actor;
genuinely heavy work is pushed off explicitly — stateful background services are `actor`s
(`DBInterface`, `ImageService`), and CPU-heavy leaves use `@concurrent`. Async results that can race
carry monotonic tokens so a slow earlier task can't overwrite a newer result.

See [`docs/HLD.md`](docs/HLD.md) for the full architecture (layer map, data flows, DB schema) and
[`docs/services/`](docs/services/) for per-service references.

## Subscription Tiers

| Tier | Recipe Sources | Ingredient Detection |
|------|----------------|----------------------|
| **Free** | Local database | Manual text input + 3 camera scans/week |
| **CookSavvy+** | Local + online (Spoonacular) + AI-generated | Unlimited AI photo recognition |

## Project Structure

```
CookSavvy/
├── App/            — Entry point, DI container (AppContainer)
├── Models/         — Recipe, Ingredient, ShoppingItem, CookingSession, …
├── Services/       — Data, auth, AI, subscription, DB, SmartSearch
├── Network/        — Networking + Supabase providers
├── Coordinators/   — Navigation
├── Views/          — SwiftUI screens
├── Theme/          — UI constants, Strings, Icons (no magic numbers/strings)
└── Support/        — Assets, privacy manifest, API key plist (gitignored)
```

## Building

```bash
xcodebuild -scheme CookSavvy -destination 'generic/platform=iOS Simulator' build
```

Third-party identifiers live in a gitignored `Support/APIKeys.plist` (all client-safe — `SUPABASE_URL`,
`SUPABASE_ANON_KEY`, `TELEMETRYDECK_APP_ID`, `SENTRY_DSN`). Any absent key makes that integration
inert, so the app builds and runs without it.

## Testing

```bash
xcodebuild test -scheme CookSavvy -destination 'platform=iOS Simulator,name=iPhone 16' -testPlan UnitTests
```

Unit and integration tests live in `CookSavvyTests/`. UI flows are covered by a manual QA checklist
(`docs/MANUAL_QA_CHECKLIST.md`).

## Backend

The Supabase backend (edge functions, Postgres migrations, rate-limiting/quota logic) lives in a
separate repository: **[CookSavvyBE](https://github.com/dsx87/CookSavvyBE)**. All AI/online-recipe
calls are proxied there so provider API keys never ship in the client.

## License

[MIT](LICENSE) © Igor Pivnyk
