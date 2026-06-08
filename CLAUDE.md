# CookSavvy

A hobby iOS recipe app that suggests recipes based on user-provided ingredients.

## Tech Stack

- **Language:** Swift
- **UI Framework:** SwiftUI (UIKit only when absolutely necessary)
- **Database:** GRDB (SQLite wrapper)
- **Subscriptions:** StoreKit 2
- **Backend:** Supabase (Edge Functions proxy AI/online-recipe calls; keys held server-side)
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

> **DO NOT run UI tests** — UITests are disabled in all test plans and must not be executed by Claude or any automated tool. They require manual execution only.

## Subscription Tiers

| Tier | Display Name | Recipe Source | Ingredient Detection |
|------|--------------|---------------|---------------------|
| Free | Free | Local database (`OfflineRecipeSource`) | Manual text input + 5 camera scans/week |
| Premium | CookSavvy+ | Local + REST API + AI (`OnlineRecipeSource`, `AIRecipeSource`) | Unlimited AI photo recognition |

- Product identifiers: monthly `com.cooksavvy.subscription.premium` (7-day introductory free trial), annual `com.cooksavvy.subscription.premium.yearly`
- Free tier weekly camera scan limit tracked via `CameraScanTracker` (UserDefaults)
- Premium-gated features: `PaidFeature` enum — `cameraIngredientDetection`, `onlineRecipes`, `aiRecipes`, `shoppingList`

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
CookSavvyUITests/          — XCUITest suites (see uitests.md rule)
```

## Documentation

| File | Contents |
|------|----------|
| `docs/HLD.md` | Cross-cutting architecture: layer map, coordinator hierarchy, data flows, state machines, DB schema. Read when a task spans multiple layers. Directional — verify specifics against code; per-layer inventory/conventions live in `.claude/rules/*.md` |
| `docs/services/` | Per-service usage/API references: `IMAGE_SERVICE_README.md`, `INGREDIENTS_SERVICE_README.md`, `RECIPE_SERVICE_README.md` |
| `docs/audits/` | Dated point-in-time audits. Current cycle (2026-06): `AUDIT_2026-06-06.md` (engineering), `PRODUCT_AUDIT_2026-06-06.md` (product), `UX_UI_AUDIT_2026-06-06.md` (UX/UI), and `APPSTORE_BLOCKERS_STATUS_2026-06-07.md` (live release-blocker tracker, source of truth) |
| `docs/BACKEND_PLAN.md` | Supabase backend plan; still the reference for open backend work (e.g. server-side scan-quota enforcement) |
| `docs/TEST_PLAN_UNIT_TESTS.md` | Test-authoring guidance + remaining unit-test gaps (StoreKit/DataImport services) |
| `docs/MANUAL_QA_CHECKLIST.md` | Scenarios that remain manual after UI test automation |
| `prod/` | Product documentation — see `prod/00-README.md` for index |
| `prod/2026-06-07/` | Current product assessment (analysis, decision audit, strategy). `prod/2026-03-30/04-decisions-log.md` is the live decisions ledger |

## Workflow Rules

- **Ask before coding** if you need more info (unless instructed otherwise)
- **Comments:** Default is `none` for trivial or self-explanatory code. Every addition of meaningful, nontrivial logic must include inline comments and a concise explanation of the logic where it is implemented. When introducing complex objects, document them inline with their purpose, relation to surrounding types/services, and a clear description of what the object represents or coordinates.
- **Documentation maintenance:** After introducing structural changes (new services, screens, coordinators, architecture shifts, or dependency changes), check `CLAUDE.md`, `AGENTS.md` and `GEMINI.md` and update them to reflect the current state of the project
- **Build check:** After each finished request that changes code, verify the project builds using `xcodebuild -scheme CookSavvy -destination 'generic/platform=iOS Simulator' build` — always target generic iOS Simulator, never a specific simulator version (unless explicitly requested). If no code changes were introduced, no build needs to be run.
- **Unit tests:** After significant logic changes, run the `UnitTests` test plan: `xcodebuild test -scheme CookSavvy -destination '<destination>' -testPlan UnitTests` — do not run the default test plan (which includes everything) unless explicitly requested. Never hardcode a specific simulator name/version (a bare `platform=iOS Simulator` only works for `build`, not `test` — `test` needs a concrete device). Resolve `<destination>` in this order:
  1. **Booted simulator** — if one is already running, target it by UDID: `xcrun simctl list devices booted` → `-destination 'platform=iOS Simulator,id=<UDID>'`
  2. **Available simulator** — otherwise list installed devices (`xcrun simctl list devices available`) and target any available iPhone by UDID
