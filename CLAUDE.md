# CookSavvy

A hobby iOS recipe app that suggests recipes based on user-provided ingredients.

## Tech Stack

- **Minimum deployment target:** **iOS 18.0**, set uniformly via `IPHONEOS_DEPLOYMENT_TARGET`
  across the app, test, and project-level build settings (single floor — keep them in sync).
- **Language:** Swift 6 — both the app target **and** the `CookSavvyTests` test target build in
  **Swift 6 language mode** with complete data-race safety. The test target overrides the project-wide
  default isolation to **`SWIFT_DEFAULT_ACTOR_ISOLATION = nonisolated`** (the app/project default is
  `MainActor`): an `XCTestCase` subclass must keep XCTest's *inherited* `nonisolated` initializers, so a
  `@MainActor` test class — or an explicit `nonisolated override init()` to dodge the compile error —
  crashes at runtime with `init(selector:)` unimplemented. The XCTest pattern is therefore **nonisolated
  test class + `@MainActor` on each `setUp`/`tearDown`/test method/helper** that touches MainActor app
  types. Synchronous test methods that construct then release a MainActor-isolated app object are written
  **`async`** (same body, no `await` needed) to avoid a pre-existing toolchain malloc double-free on the
  ObjC sync-invocation path (see memory `project_viewmodel_test_malloc_crash`); only the 3
  `measure`/`wait(for:)` performance tests stay synchronous. There is **no UI test target** — UI flows
  are covered by manual QA (see `docs/MANUAL_QA_CHECKLIST.md`).
- **Concurrency:** Approachable Concurrency is on (`SWIFT_APPROACHABLE_CONCURRENCY = YES`,
  `SWIFT_STRICT_CONCURRENCY = complete`) with **default actor isolation = `MainActor`**
  (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`), set at the project level. See "Concurrency Model" below.
- **UI Framework:** SwiftUI (UIKit only when absolutely necessary)
- **Database:** GRDB (SQLite wrapper)
- **Subscriptions:** StoreKit 2
- **Backend:** Supabase (Edge Functions proxy AI/online-recipe calls; keys held server-side). Lives in a **separate repo** at `/Users/dsx/Developer/CookSavvyBE` (`git@github.com:dsx87/CookSavvyBE.git`) — edge functions (`supabase/functions/`), Postgres migrations, and server-side rate-limit/quota logic are there, **not** in this iOS repo. The `supabase/` dir here holds only empty, untracked placeholder folders.
- **Analytics:** TelemetryDeck in RELEASE when configured, else `os.Logger` (`AnalyticsServiceProtocol`)
- **Crash reporting:** Sentry in RELEASE when a DSN is configured, else no-op (`CrashReportingServiceProtocol`)
- **Philosophy:** Maximize use of Apple frameworks

Third-party identifiers live in the gitignored `Support/APIKeys.plist` (all client-safe, never
secrets): `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `TELEMETRYDECK_APP_ID`, `SENTRY_DSN`. Any key left
absent makes that integration inert (analytics falls back to `os.Logger`; crash reporting no-ops).

## Build Instructions

To build the app for any available iOS Simulator (avoiding specific version issues), use:

```bash
xcodebuild -scheme CookSavvy -destination 'generic/platform=iOS Simulator' build
```

## Subscription Tiers

| Tier | Display Name | Recipe Source | Ingredient Detection |
|------|--------------|---------------|---------------------|
| Free | Free | Local database (`OfflineRecipeSource`) | Manual text input + 3 camera scans/week |
| Premium | CookSavvy+ | Local + REST API + AI (`OnlineRecipeSource`, `AIRecipeSource`) | Unlimited AI photo recognition |

- Product identifiers: monthly `com.cooksavvy.subscription.premium` (7-day introductory free trial), annual `com.cooksavvy.subscription.premium.yearly`
- Free tier weekly camera scan limit (3 per rolling 7 days, mirrors the backend) tracked via `CameraScanTracker` (UserDefaults)
- Premium-gated features: `PaidFeature` enum — `cameraIngredientDetection`, `onlineRecipes`, `aiRecipes`, `shoppingList`
- **DEBUG builds run as CookSavvy+** — `AppContainer`'s DEBUG `init()` seeds `MockSubscriptionService` with `.premium`, so every gate is open and no paywall is shown. RELEASE uses `StoreKitSubscriptionService`. (Tests/UI tests are unaffected — they construct subscription state via `makeInMemory`/`--premium-user`.)

## Architecture Rules

### MVVM + Coordinator Pattern
- **Views** contain **only** a `viewModel` property
- All state/variables live inside the **ViewModel**
- **Coordinators** handle navigation and ViewModel creation
- Strict separation of concerns:
  - Views: UI presentation only
  - ViewModels: Business logic and state
  - Coordinators: Navigation flow
  - Services: Data operations

### Dependency Injection
- `AppContainer`: `@MainActor` singleton holding all shared service instances
- Services initialized once and exposed via protocol-typed dependencies in coordinators and view models
- Shared cross-cutting services such as `LoggingServiceProtocol` are resolved in `AppContainer`, and feature-specific `LoggerProtocol` instances are injected into view models
- Construction is throwing; startup database/container failures render a blocking startup error instead of falling back to in-memory storage
- Maintains single source of truth for app-wide dependencies
- TODO: refactor away from singleton pattern

### Concurrency Model
The app is **`@MainActor` by default** (project-level `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`).
*Everything is main-actor-isolated unless it says otherwise* — so the work is to push genuinely
background work explicitly **off** the main actor, not to sprinkle annotations.
- **UI layer stays on main (the default):** `AppContainer`, all ViewModels, Coordinators. Redundant
  declaration-level `@MainActor` on these types/members/protocols has been **removed** — the
  project-wide default already pins them to the main actor, so adding it back is noise. Load-bearing
  `@MainActor` is kept only where it actually does work: closures that hop back to main from a
  *nonisolated* delegate context (e.g. `Task { @MainActor in … }` inside
  `AppleSignInManager`'s `ASAuthorizationControllerDelegate` callbacks and `CameraView`'s
  `AVCapturePhotoCaptureDelegate`).
- **ViewModels & Coordinators use `@Observable`** (the Observation macro), not `ObservableObject`/
  `@Published`. Views own them with `@State` and bind via `@Bindable` (passed-in objects); plain
  `var`/`let` for observe-only. Internal task-handle properties are `@ObservationIgnored`.
- **Stateful background services are `actor`s** so their work runs off main: `DBInterface` (GRDB SQL +
  recipe JSON decode + the `recipeCache`, no explicit lock/queue), `ImageService` (disk I/O + ZIP +
  `UIImage` decode + `imageCache`), `ImageExtractor` (serialised ZIP reads), and `IngredientsService`
  (FTS-backed catalogue search + name-based classification of the ~3.5k-row catalogue + its
  `cachedCategorizedIngredients` cache + pantry-staple filtering). Their protocol methods are `async`
  and callers `await`. An `actor` service that takes an injected store (`IngredientsService` holds an
  `IngredientStoreProtocol`) makes that dependency actor-isolated state, so a **test mock** passed into
  it must be `Sendable` — see `MockDBInterfaceForIngredients`'s documented `@unchecked Sendable`.
- **The *other* services are plain classes = `MainActor` by default** (`RecipeService`,
  `UserDataService`, the recipe sources, etc. — they are **not** `actor`s). They `await` the actors
  above for I/O, but **their own code, including the continuation after each `await`, resumes on the
  main actor.** So CPU work done *in* such a service (e.g. mapping/filtering large arrays) runs **on
  main** unless explicitly wrapped in `@concurrent` — calling a `nonisolated` helper does **not** change
  this (see next bullet). This is exactly why `IngredientsService` was promoted to an `actor` (previous
  bullet): as a MainActor class, the continuation after its `DBInterface` `await` ran the
  catalogue-scale `PantryStaples` filtering/classification **on main**, and wrapping only the grouping
  in `@concurrent` still left the ~3.5k-row staple filter on main — so the whole service was moved off
  main. Its `categorizedIngredients()` still keeps the filter+grouping inside `await Task { @concurrent
  in … }.value` so that CPU work runs on the cooperative pool rather than serialising the actor's own
  executor against concurrent searches.
- **Stateless CPU/IO leaves are `nonisolated`**: `Unarchiver`, the rankers (`RecipeMatchRanker`,
  `RecipeMoodRanker`, `RecipeMatchExplainer`). **`nonisolated` only removes actor isolation — it does
  not move work off main.** A `nonisolated` *sync* func runs on its caller's executor (the main thread
  when called from a `@MainActor` default context); a `nonisolated` *async* func, under Swift 6.2's
  `nonisolated(nonsending)` default, likewise runs on the caller's executor. Pushing work onto the
  background (cooperative pool) requires **`@concurrent`** (or an `actor` / `Task.detached`), not
  `nonisolated`. Genuinely heavy off-main work therefore uses `@concurrent` (e.g.
  `JSONRecipeDatasetReader.readRecipes` decodes the dataset on the cooperative pool;
  `FoundationModelsSmartSearchProvider.parse`; `AIIngredientDetectionAdapter` JPEG-encodes the capture
  via `Task { @concurrent in … }`). `DiscoverViewModel`'s result annotation (`RecipeMatchExplainer`)
  runs **synchronously on main** right after the search `await`, behind the stale-result token guard —
  deliberately on main for result determinism; its `nonisolated` helper only keeps it cheap to hoist
  off main later if a large result set ever warrants it.
- **Async results that can race carry a monotonic token:** `DiscoverViewModel` guards both ingredient
  refresh (`ingredientRefreshToken`/`isCurrentRefresh`) and recipe search
  (`searchToken`/`isCurrentSearch`) so a slower earlier task cannot overwrite a newer result.
- **Data models are `nonisolated`** (Recipe, Ingredient, CookingSession, SubscriptionStatus, etc.) so
  the off-main actors can construct/encode/decode them.
- **Service event streams use `AsyncStream`, not Combine** — Combine is fully removed from the app
  layer. `AuthServiceProtocol.authStateUpdates`, `SubscriptionServiceProtocol`'s
  `currentSubscriptionStatusUpdates`/`currentPlanUpdates`, and `SignInWithAppleActionProtocol`'s
  `isSigningInUpdates` are vended by `AsyncValueBroadcaster<Value>` (`Services/Support/`), a
  thread-safe `CurrentValueSubject` replacement (sync `value` reads + replay-then-updates streams).
  Consumers observe via `for await … in` Tasks stored and cancelled in `deinit`.
- **No GCD / locks for app logic:** prefer actors / structured concurrency. `@preconcurrency import`
  is used only for not-yet-Sendable Apple SDKs (AVFoundation, FoundationModels), documented inline.

### Code Duplication Policy
- **No duplication** — search for existing solutions first
- Refactor only when necessary; prefer adding new methods over modifying existing ones
- Duplication allowed only for unrelated modules or logic that may diverge — **requires explicit approval**

### Code Style
- **SwiftUI readability** — avoid deeply nested view bodies by extracting subviews into `private var` or `private func` computed properties
- **No magic numbers/strings** — all layout values go in `UI` constants; all user-facing strings go in `Strings`; all SF Symbol names go in `Icons`
- **Services always have protocols** — every new service must be defined behind a protocol so it can be mocked in tests and DEBUG builds
- Follow **Single Responsibility Principle**

## Project Structure

```
CookSavvy/
├── App/                   — Entry point (CookSavvyApp), DI container (AppContainer), UI test config
├── Models/                — Data models: Recipe, Ingredient, ShoppingItem, CookingSession, Achievement
├── Services/              — All service layer: data, auth, AI, subscription, DB, SmartSearch (see services.md rule)
├── Network/               — Networking infrastructure (see services.md rule)
├── DataImport/            — Dataset import and JSON reading (see services.md rule)
├── Coordinators/          — Navigation coordinators (see coordinators.md rule)
├── Views/                 — All SwiftUI screens (see views.md rule)
├── Extensions/            — Character+Extensions, String+Extensions
├── Theme/                 — Theming, UI constants, Strings, Icons (see theme.md rule)
├── Utilities/             — DeviceUtility, LegalLinks (Terms/Privacy URLs for paywall + Settings)
├── Localizable.xcstrings  — String Catalog (Xcode 15+)
└── Support/               — APIKeys.plist (gitignored), Assets, Substitutions.json, PrivacyInfo.xcprivacy (App Privacy Manifest)

CookSavvyTests/            — Unit + integration tests (see tests.md rule)
```

## Documentation

| File | Contents |
|------|----------|
| `docs/HLD.md` | Cross-cutting architecture: layer map, coordinator hierarchy, data flows, state machines, DB schema. Read when a task spans multiple layers. Directional — verify specifics against code; per-layer inventory/conventions live in `.claude/rules/*.md` |
| `docs/services/` | Per-service usage/API references: `IMAGE_SERVICE_README.md`, `INGREDIENTS_SERVICE_README.md`, `RECIPE_SERVICE_README.md` |
| `docs/BACKEND_PLAN.md` | Supabase backend plan (design/reference). The backend itself lives in the separate `CookSavvyBE` repo (`/Users/dsx/Developer/CookSavvyBE`); consult that repo for the actual edge functions, migrations, and rate-limit/quota logic. Note: server-side scan-quota enforcement is now implemented there (per-user weekly `api_usage` cap in `detect-ingredients`). |
| `docs/TEST_PLAN_UNIT_TESTS.md` | Test-authoring guidance + remaining unit-test gaps (StoreKit/DataImport services) |
| `docs/MANUAL_QA_CHECKLIST.md` | Manual QA scenarios for end-to-end UI flows (no automated UI tests) |

> Internal product docs (`prod/`) and dated engineering/product/UX audits (`docs/audits/`) are
> kept locally but excluded from version control (see `.gitignore`).

## Workflow Rules

- **Ask before coding** if you need more info (unless instructed otherwise)
- **Comments:** Default is `none` for trivial or self-explanatory code. Every addition of meaningful, nontrivial logic must include inline comments and a concise explanation of the logic where it is implemented. When introducing complex objects, document them inline with their purpose, relation to surrounding types/services, and a clear description of what the object represents or coordinates.
- **Documentation maintenance:** After introducing structural changes (new services, screens, coordinators, architecture shifts, or dependency changes), check `CLAUDE.md`, `AGENTS.md` and `GEMINI.md` and update them to reflect the current state of the project
- **Build check:** After each finished request that changes code, verify the project builds using `xcodebuild -scheme CookSavvy -destination 'generic/platform=iOS Simulator' build` — always target generic iOS Simulator, never a specific simulator version (unless explicitly requested). If no code changes were introduced, no build needs to be run.
- **Unit tests:** After significant logic changes, run the `UnitTests` test plan: `xcodebuild test -scheme CookSavvy -destination '<destination>' -testPlan UnitTests` — do not run the default test plan (which includes everything) unless explicitly requested. Never hardcode a specific simulator name/version (a bare `platform=iOS Simulator` only works for `build`, not `test` — `test` needs a concrete device). Resolve `<destination>` in this order:
  1. **Booted simulator** — if one is already running, target it by UDID: `xcrun simctl list devices booted` → `-destination 'platform=iOS Simulator,id=<UDID>'`
  2. **Available simulator** — otherwise list installed devices (`xcrun simctl list devices available`) and target any available iPhone by UDID
