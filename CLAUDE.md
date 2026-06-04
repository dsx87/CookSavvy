# CookSavvy

A hobby iOS recipe app that suggests recipes based on user-provided ingredients.

## Tech Stack

- **Language:** Swift
- **UI Framework:** SwiftUI (UIKit only when absolutely necessary)
- **Database:** GRDB (SQLite wrapper)
- **Subscriptions:** StoreKit 2
- **Philosophy:** Maximize use of Apple frameworks

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
├── Utilities/             — DeviceUtility
├── Localizable.xcstrings  — String Catalog (Xcode 15+)
└── Support/               — APIKeys.plist (gitignored), Assets, Substitutions.json

CookSavvyTests/            — Unit + integration tests (see tests.md rule)
CookSavvyUITests/          — XCUITest suites (see uitests.md rule)
```

## Documentation

| File | Contents |
|------|----------|
| `docs/HLD.md` | Cross-cutting architecture: layer map, coordinator hierarchy, data flows, state machines, DB schema. Read when a task spans multiple layers. Directional — verify specifics against code; per-layer inventory/conventions live in `.claude/rules/*.md` |
| `docs/IMAGE_SERVICE_README.md` | ImageService usage and API |
| `docs/INGREDIENTS_SERVICE_README.md` | IngredientsService usage and API |
| `docs/RECIPE_SERVICE_README.md` | RecipeService usage and API |
| `prod/` | Product documentation — see `prod/00-README.md` for index |
| `prod/2026-03-30/` | Current product assessment (analysis, audit, strategy, decisions log) |
| `docs/MANUAL_QA_CHECKLIST.md` | Scenarios that remain manual after UI test automation |

## Workflow Rules

- **Ask before coding** if you need more info (unless instructed otherwise)
- **Comments:** Default is `none` for trivial or self-explanatory code. Every addition of meaningful, nontrivial logic must include inline comments and a concise explanation of the logic where it is implemented. When introducing complex objects, document them inline with their purpose, relation to surrounding types/services, and a clear description of what the object represents or coordinates.
- **Documentation maintenance:** After introducing structural changes (new services, screens, coordinators, architecture shifts, or dependency changes), check `CLAUDE.md`, `AGENTS.md` and `GEMINI.md` and update them to reflect the current state of the project
- **Build check:** After each finished request that changes code, verify the project builds using `xcodebuild -scheme CookSavvy -destination 'generic/platform=iOS Simulator' build` — always target generic iOS Simulator, never a specific simulator version (unless explicitly requested). If no code changes were introduced, no build needs to be run.
- **Unit tests:** After significant logic changes, run the unit tests test plan: `xcodebuild test -scheme CookSavvy -destination 'platform=iOS Simulator,name=iPhone 16' -testPlan UnitTests` — do not run the default test plan (which includes everything) unless explicitly requested
