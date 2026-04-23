# CookSavvy — Agent Instructions

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

> **DO NOT run UI tests** — UITests are disabled in all test plans and must not be executed by agents or any automated tool. They require manual execution only.

## UI Test Launch Arguments

- `--uitesting` — enables deterministic UI-test bootstrapping
- `--skip-onboarding` — skips onboarding unless paired with `--fresh-install`
- `--fresh-install` — forces first-launch onboarding
- `--premium-user` — boots with premium entitlements via `MockSubscriptionService`
- `--with-cooking-history` — seeds deterministic cooking sessions
- `--with-favorites` — seeds favorite recipes
- `--with-shopping-items` — seeds shopping list rows
- `--empty-db` — skips DB seeding for empty-state coverage
- `--large-dataset` — adds a larger deterministic recipe set
- `--camera-limit-reached` — preloads free-tier camera usage to the weekly cap
- `--signed-in-apple` — boots with a mock Apple-authenticated session (non-anonymous)

## Subscription Tiers

| Tier | Display Name | Recipe Source | Ingredient Detection |
|------|--------------|---------------|---------------------|
| Free | Free | Local database (`OfflineRecipeSource`) | Manual text input + 5 camera scans/week |
| Premium | CookSavvy+ | Local + REST API + AI (`OnlineRecipeSource`, `AIRecipeSource`) | Unlimited AI photo recognition |

- Product identifier: `com.cooksavvy.subscription.premium`
- Free tier weekly camera scan limit tracked via `CameraScanTracker` (UserDefaults)
- Premium-gated features: `PaidFeature` enum — `cameraIngredientDetection`, `onlineRecipes`, `aiRecipes`, `shoppingList`

## App Screens

| Screen | Description |
|--------|-------------|
| **Discover** (tab 1) | Two-state flow: ingredient selection (grid, categories, search, recent/saved cards) and recipe results (mood filter, hero best match, recipe rows) |
| **My Kitchen** (tab 2) | Saved recipes, recent cooks, shopping list shortcut, compact stats, user recipes + create card, achievements, settings (gear icon in nav bar) |
| **Recipe Details** | Hero image, floating back/bookmark actions, stats row, ingredients (with "Add Missing to List" button for premium), steps, sticky Start Cooking CTA |
| **Recipe List** | Reusable See All destination for recent, saved, and user recipes |
| **Cook Mode** | Full-screen step-by-step cooking flow with progress ring, timer, and prev/next navigation |
| **Create Recipe** | 5-step wizard: Name & Photo → Ingredients → Steps → Details → Review & Save |
| **Settings** | Subscription plan, usage limits, account (Sign in with Apple / Sign Out), preferences (accessed from My Kitchen nav bar) |
| **Camera** | Camera capture for AI ingredient detection (free users: 5/week via `CameraScanTracker`) |
| **Upgrade** | Single-plan upgrade prompt (CookSavvy+) |
| **Onboarding** | Camera-first first-launch walkthrough: 2 static intro pages followed by an embedded camera scan page; skip/type fallback lands on Discover ingredient selection and a successful first scan hands ingredients to Discover for immediate results |
| **Shopping List** | Premium checklist of missing ingredients grouped by recipe; swipe-to-delete, toggle checked, clear done; sheet from Recipe Details or My Kitchen |
| **Tab Container** | Root tab bar with 2 tabs: Discover + My Kitchen |
| **UI Tests** | XCUITest target under `CookSavvyUITests/` with launch-argument driven app setup and feature-focused suites |

> All screens are subject to extension and modification.

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

### Coordinator Hierarchy
- `AppCoordinator`: Root coordinator managing tab-level coordinators via lazy factory methods
- Feature coordinators: `DiscoverCoordinator`, `JourneyCoordinator`, `SettingsCoordinator`
- `DiscoverCoordinator`: Discover landing/results flow, recipe detail, recipe list, cook mode (full screen cover), camera, create recipe, upgrade
- `JourneyCoordinator`: My Kitchen navigation for saved recipes, recent cooks, shopping list, stats, recipe detail, recipe list, settings, create recipe, upgrade
- Each coordinator owns its navigation stack and sheet presentations
- ViewModels hold weak references to coordinators for navigation

### Dependency Injection
- `AppContainer`: `@MainActor` singleton holding all shared service instances
- Services initialized once and exposed via protocol-typed dependencies in coordinators and view models
- Shared cross-cutting services such as `LoggingServiceProtocol` are resolved in `AppContainer`, and feature-specific `LoggerProtocol` instances are injected into view models
- Construction is throwing; startup database/container failures render a blocking startup error instead of falling back to in-memory storage
- Maintains single source of truth for app-wide dependencies
- TODO: refactor away from singleton pattern

### Database Layer
- `DBInterfaceProtocol` / `DBInterface` — GRDB-based SQLite database; tables: `ingredients`, `recipes`, `recipe_ingredients`, `recent_ingredients`, `recent_recipes`, `favorite_recipes`, `recent_searches`, `cooking_sessions`, `shopping_items`
- Used by `RecipeService`, `IngredientsService`, `UserDataService`, `DataImportService`, `DatabaseInitializationService`, `ShoppingListService`, `RecipeRecommendationService`
- `DBTestHelpers` for test support

### Service Layer
- **Data Services**: `RecipeServiceProtocol` / `RecipeService`, `IngredientsServiceProtocol` / `IngredientsService`, `UserDataServiceProtocol` / `UserDataService`
- **Infrastructure**: `ImageServiceProtocol` / `ImageService`, `DatabaseInitializationServiceProtocol` / `DatabaseInitializationService`, `DataImportServiceProtocol` / `DataImportService`, `CSVParser`
- **Cross-cutting**: `LoggingServiceProtocol` / `LoggingService` creates feature-scoped `LoggerProtocol` instances backed by `os.Logger`
- **Feature Services**: `ShoppingListServiceProtocol` / `ShoppingListService`, `RecipeRecommendationServiceProtocol` / `RecipeRecommendationService`, `CameraScanTrackerProtocol` / `CameraScanTracker`, `IngredientDetectionServiceProtocol` (impl: `AIIngredientDetectionAdapter`), `SubscriptionServiceProtocol` (impl: `StoreKitSubscriptionService` / `MockSubscriptionService`)
- **Auth Services**: `AuthServiceProtocol`, `SupabaseAuthService`, `MockAuthService`, `NoOpAuthService` (RELEASE fallback when Supabase keys are missing), `SignInWithAppleAction` (shared SIWA flow, analytics, concurrency guard), `AppleSignInManager` / `AppleSignInManaging` (ASAuthorizationController + SHA256 nonce for SIWA flow)
- **Network Layer**: `NetworkServiceProtocol` / `NetworkService`, `NetworkConfiguration`, `URLBuilder`, `NetworkRequest`, `NetworkResponse`, `NetworkError`, `HTTPMethod`
- **Supabase Layer** (`Services/Supabase/`): `SupabaseConfiguration`, `SupabaseClientProviderProtocol` / `SupabaseClientProvider`, `SupabaseLLMProvider`, `SupabaseRecipeAPIProvider`, `SupabaseRecipeDTOs`, `SupabaseServiceAssembly`
- **Recipe Sources** — `RecipeSourceProtocol` → `OfflineRecipeSource`, `OnlineRecipeSource` (via `RecipeAPIProviderProtocol`), `AIRecipeSource`
- **Recipe API Providers**:
  - `RecipeAPIProviderProtocol` — common backend provider interface for online recipes
  - `SupabaseRecipeAPIProvider` — app runtime implementation for the `search-recipes` backend flow
  - `RecipeAPIProviderError` — shared error types
- `OnlineRecipeSource` delegates to a pluggable `RecipeAPIProviderProtocol` (nil = unavailable)
- All services conform to protocols for testability

### AI Service Layer
- `AIServiceProtocol` / `AIService` — main AI interface for ingredient detection and recipe generation
- `AIIngredientDetectionAdapter` — bridges `AIServiceProtocol` to `IngredientDetectionServiceProtocol`
- **LLM Provider layer** (`Services/AI/LLMProvider/`):
  - `LLMProviderProtocol` — common interface for backend-proxied AI calls
  - `SupabaseLLMProvider` — app runtime implementation for Supabase Edge Functions
  - `MockLLMProvider` — mock retained for UI testing and DEBUG-only helpers
  - `LLMModels`, `LLMProviderError` — shared types
- **Provider selection** (in `AppContainer`):
  - Normal DEBUG and RELEASE app runtime use `SupabaseServiceAssembly` for AI and online recipe providers when configured
  - `OnlineRecipeSource` receives `SupabaseRecipeAPIProvider` for the `search-recipes` backend flow when Supabase is configured
- **API keys** stored in `Support/APIKeys.plist` (gitignored)
  - Active Supabase keys: `SUPABASE_URL`, `SUPABASE_ANON_KEY`
  - Direct OpenAI/Gemini keys are not read by the app; model provider keys live in backend secrets
- **Supabase runtime wiring**:
  - Swift package dependency: `supabase-swift`
  - `SupabaseConfiguration` reads optional `SUPABASE_URL` and `SUPABASE_ANON_KEY` placeholders from `APIKeys.plist`
  - Normal app runtime wires `AIService` through `SupabaseLLMProvider`; `OnlineRecipeSource` is wired through `SupabaseRecipeAPIProvider`
  - DEBUG runtime uses `SupabaseAuthService` when Supabase is configured; DEBUG without Supabase and UI tests use mock auth/sign-in managers
  - `SupabaseAuthService` handles anonymous auth bootstrap and Sign in with Apple identity linking

### Subscription Layer
- `SubscriptionServiceProtocol` — common interface (plan access, purchases, restore)
- `StoreKitSubscriptionService` — real StoreKit 2 implementation (RELEASE)
- `MockSubscriptionService` — mock with configurable initial plan (DEBUG)
- `SubscriptionPlan` — plan enum (free/api/ai)
- `PaidFeature` — feature gating
- `Configuration.storekit` — StoreKit testing configuration

### Theme & Localization
- **Layout constants** — `UI` struct with nested domain structs (`UI.RecipeCell.imageSize`, `UI.V2.heroImageHeight`)
- **Theme system** — `AppTheme` protocol + `LightTheme` / `DarkTheme` + `SystemTheme` helper, injected via `@Environment(\.appTheme)`
  - Color tokens: `bg`, `surface`, `surfaceLight`, `card`, `accent`, `accentSoft`, `mint`, `mintSoft`, `rose`, `roseSoft`, `lavender`, `lavenderSoft`, `sky`, `skySoft`, `gold`, `text1`, `text2`, `text3`, `divider`
  - Corner radius tokens: `cornerRadiusSmall` (12), `cornerRadiusMedium` (16), `cornerRadiusLarge` (20), `cornerRadiusXL` (24), `cornerRadiusPill` (32)
- **View Modifiers** (`Theme/ViewModifiers.swift`): `.frostCard()`, `.neonGlow(_:radius:)`, `.sectionLabel()`
- **Strings** — `Strings` enum with nested screen enums, using `String(localized:defaultValue:)` for localization; accessed as `Strings.Settings.navigationTitle`
  - Screen enums include `Discover`, `Journey`, `CookMode`, `CreateRecipe`, `RecipeList`, `MoodFilter`
- **Icons** — `Icons` enum with nested screen enums for SF Symbol names; accessed as `Icons.Settings.trash`
  - Screen enums include `Discover`, `Journey`, `CookMode`, `CreateRecipe`, `Mood`
- **String Catalog** — `Localizable.xcstrings` (Xcode 15+), auto-populated from `String(localized:)` calls
- Adding a new theme: create a struct conforming to `AppTheme` and inject at app root
- Adding a new language: add translations in the String Catalog via Xcode

### Code Organization
- Create services as needed
- Follow **Single Responsibility Principle**
- Maintain consistent app structure and best practices

### Code Duplication Policy
- **No duplication** — search for existing solutions first
- Refactor only when necessary; prefer adding new methods over modifying existing ones
- Duplication allowed only for:
  - Unrelated modules
  - Logic that may diverge in the future
  - **Requires explicit approval**

### Code Style
- **SwiftUI readability** — avoid deeply nested view bodies by extracting subviews into `private var` or `private func` computed properties
- **No magic numbers/strings** — all layout values go in `UI` constants; all user-facing strings go in `Strings`; all SF Symbol names go in `Icons`
- **Services always have protocols** — every new service must be defined behind a protocol so it can be mocked in tests and DEBUG builds

## Project Structure

```text
CookSavvy/
├── App/
│   ├── CookSavvyApp.swift           — App entry point
│   ├── AppContainer.swift            — DI container (singleton)
│   ├── UITestConfiguration.swift     — DEBUG-only UI test launch-argument parsing
│   └── UITestDataSeeder.swift        — DEBUG-only deterministic UI test data seeding
├── Models/
│   ├── ShoppingItem.swift            — Shopping list item (id, name, isChecked, addedAt, recipeTitle)
│   ├── Recipe.swift                 — Recipe + Recipe.Step + AdditionalInfo
│   ├── Ingredient.swift              — Ingredient + IngredientCategory enum
│   ├── IngredientEmojiProvider.swift  — Static emoji resolution (exact→contains→word→foodGroup→default)
│   ├── CookingSession.swift          — Cooking session tracking
│   ├── Achievement.swift             — Achievement definitions (7 achievements)
│   └── SubscriptionPlan.swift
├── Services/
│   ├── Recipe/
│   │   ├── RecipeService.swift
│   │   ├── RecipeMatchRanker.swift
│   │   ├── RecipeMoodRanker.swift
│   │   ├── RecipeRecommendationService.swift  — personalized suggestions from cooking history
│   │   ├── RecipeSourceProtocol.swift — Protocol + RecipeSourceType + errors
│   │   ├── OfflineRecipeSource.swift
│   │   ├── OnlineRecipeSource.swift
│   │   └── AIRecipeSource.swift
│   ├── Ingredient/
│   │   ├── IngredientsService.swift
│   │   └── IngredientDetectionProtocol.swift — Protocol + errors
│   ├── Image/
│   │   ├── ImageService.swift
│   │   └── ImageExtractor.swift
│   ├── Logging/
│   │   └── LoggingService.swift
│   ├── UserData/
│   │   └── UserDataService.swift
│   ├── Auth/
│   │   ├── AuthServiceProtocol.swift
│   │   ├── SupabaseAuthService.swift
│   │   ├── MockAuthService.swift
│   │   ├── NoOpAuthService.swift
│   │   ├── AppleSignInManager.swift
│   │   └── SignInWithAppleAction.swift
│   ├── Subscription/
│   │   ├── SubscriptionServiceProtocol.swift
│   │   ├── StoreKitSubscriptionService.swift
│   │   ├── MockSubscriptionService.swift
│   │   └── CameraScanTracker.swift         — weekly scan counter (UserDefaults, resets each calendar week)
│   ├── ShoppingList/
│   │   └── ShoppingListService.swift       — CRUD for shopping items via DBInterface
│   ├── AI/
│   │   ├── AIServiceProtocol.swift
│   │   ├── AIService.swift
│   │   ├── AIServiceError.swift
│   │   ├── AIIngredientDetectionAdapter.swift
│   │   └── LLMProvider/
│   │       ├── LLMProviderProtocol.swift
│   │       ├── LLMProviderError.swift
│   │       ├── LLMModels.swift
│   │       └── MockLLMProvider.swift
│   ├── Supabase/
│   │   ├── SupabaseConfiguration.swift
│   │   ├── SupabaseClientProvider.swift
│   │   ├── SupabaseRecipeDTOs.swift
│   │   ├── SupabaseServiceAssembly.swift
│   │   ├── SupabaseLLMProvider.swift
│   │   └── SupabaseRecipeAPIProvider.swift
│   └── Database/
│       ├── DBInterfaceProtocol.swift  — Protocol + errors
│       ├── DBInterface.swift          — GRDB implementation
│       ├── DBTestHelpers.swift        — Test helper (used by DBInterface in test mode)
│       └── DatabaseInitializationService.swift
├── Network/
│   ├── NetworkServiceProtocol.swift
│   ├── NetworkService.swift
│   ├── NetworkConfiguration.swift
│   ├── NetworkRequest.swift
│   ├── NetworkResponse.swift
│   ├── NetworkError.swift
│   ├── HTTPMethod.swift
│   ├── URLBuilder.swift
│   └── RecipeAPIProvider/
│       └── RecipeAPIProviderProtocol.swift
├── DataImport/
│   ├── DataImportService.swift
│   ├── CSVParser.swift
│   ├── DatasetImporting.swift
│   └── Unarchiver.swift
├── Coordinators/
│   ├── Coordinator.swift              — Base protocol
│   ├── AppCoordinator.swift           — Root coordinator (Discover + Journey)
│   ├── DiscoverCoordinator.swift      — Discover tab navigation
│   ├── JourneyCoordinator.swift       — Journey tab navigation
│   └── SettingsCoordinator.swift
├── Views/
│   ├── Shared/
│   │   ├── AsyncImageDisk.swift
│   │   ├── TabContainerView.swift
│   │   ├── RecipeCardComponents.swift   — RecipeImage, MiniRecipeCard, RecipeRow (shared across screens)
│   │   └── CommonComponents.swift       — StarRating, StatPill (shared across screens)
│   ├── Discover/                      — Two-state discover screen (DiscoverView + DiscoverViewModel + DiscoverComponents)
│   ├── Journey/                       — Journey screen (JourneyView + JourneyViewModel + JourneyComponents)
│   ├── RecipeList/                    — Recipe list (RecipeListView + RecipeListViewModel)
│   ├── RecipeDetails/                 — Recipe details with hero image + sticky CTA
│   ├── CookMode/                      — Cook mode with step nav + timer (CookModeView + CookModeViewModel)
│   ├── CreateRecipe/                  — Create recipe wizard (CreateRecipeView + CreateRecipeViewModel)
│   ├── Camera/                        — Camera capture screen
│   ├── ShoppingList/                  — Shopping list (ShoppingListView + ShoppingListViewModel)
│   ├── Settings/                      — Settings screen
│   ├── Upgrade/                       — Subscription upgrade screen (single CookSavvy+ plan)
│   └── Onboarding/                    — First-launch walkthrough with embedded camera page (OnboardingView + OnboardingViewModel + OnboardingCameraPage)
├── Extensions/
│   ├── Character+Extensions.swift
│   └── String+Extensions.swift
├── CookSavvyUITests/
│   ├── Helpers/
│   │   ├── AccessibilityID.swift     — shared UI test identifiers
│   │   ├── BaseUITest.swift          — base classes for common launch configurations
│   │   └── XCUIApplication+Helpers.swift
│   └── *.swift                       — feature-oriented XCUITest suites
├── Theme/
│   ├── UIConstants.swift              — Layout constants (nested `UI` struct + `UI.V2`)
│   ├── AppTheme.swift                 — Theme protocol + LightTheme + DarkTheme + SystemTheme
│   ├── ViewModifiers.swift            — FrostCard, NeonGlow, SectionLabel modifiers
│   ├── Strings.swift                  — Localized strings (`String(localized:)`) by screen
│   └── Icons.swift                    — SF Symbol names by screen
├── Localizable.xcstrings              — String Catalog (Xcode 15+)
├── Utilities/
│   └── DeviceUtility.swift
└── Support/
    ├── APIKeys.plist                  — API keys (gitignored)
    ├── Assets/                        — Asset catalogs
    └── Preview Content/

CookSavvyTests/                        — Unit + integration tests
├── Mocks/
│   ├── MockServices.swift              — MockDatabaseInitService, MockIngredientsService, MockRecipeService, MockRecommendationService, MockCameraScanTracker, MockImageService
│   ├── MockSupabaseClientProvider.swift
│   ├── MockUserDataService.swift
│   └── MockShoppingListService.swift
├── SupabaseConfigurationTests.swift
├── SupabaseProviderTests.swift
├── SupabaseServiceAssemblyTests.swift
├── CookSavvyTests.swift                — DBInterface integration tests
├── IngredientsServiceTests.swift
├── RecipeServiceTests.swift
├── ImageServiceTests.swift
├── OfflineRecipeSourceTests.swift
├── OnlineAndAIRecipeSourceTests.swift
├── RecipeSourceTests.swift
├── CVSDecoderTests.swift
├── DatasetImportingTests.swift
├── RecipeMoodRankerTests.swift
├── RecipeMatchRankerTests.swift
├── RecipeRecommendationServiceTests.swift
├── CameraScanTrackerTests.swift
├── ShoppingListServiceTests.swift
├── AchievementEvaluatorTests.swift
├── URLBuilderTests.swift
├── NetworkServiceTests.swift
├── IngredientTests.swift
├── RecipeModelTests.swift
├── UserDataServiceTests.swift
├── DiscoverViewModelTests.swift
├── JourneyViewModelTests.swift
├── CookModeViewModelTests.swift
├── CreateRecipeViewModelTests.swift
├── ShoppingListViewModelTests.swift
├── RecipeDetailsViewModelTests.swift
└── SettingsViewModelAuthTests.swift
```

## Documentation

Extended documentation lives in the `docs/` directory:

| File | Contents |
|------|----------|
| `docs/IMAGE_SERVICE_README.md` | ImageService usage and API |
| `docs/INGREDIENTS_SERVICE_README.md` | IngredientsService usage and API |
| `docs/RECIPE_SERVICE_README.md` | RecipeService usage and API |
| `prod/` | Product documentation — see `prod/00-README.md` for index |
| `prod/2026-03-13/` | First product assessment (pre-improvements) |
| `prod/2026-03-30/` | Current product assessment (analysis, audit, strategy, decisions log) |
| `docs/MANUAL_QA_CHECKLIST.md` | Scenarios that remain manual after UI test automation |

## Workflow Rules

- **Ask before coding** if you need more info (unless instructed otherwise)
- **Comments:** Default is `none` for trivial or self-explanatory code. Every addition of meaningful, nontrivial logic must include inline comments and a concise explanation of the logic where it is implemented. When introducing complex objects, document them inline with their purpose, relation to surrounding types/services, and a clear description of what the object represents or coordinates.
- **Documentation maintenance:** After introducing structural changes (new services, screens, coordinators, architecture shifts, or dependency changes), check `CLAUDE.md`, `AGENTS.md` and `GEMINI.md` and update them to reflect the current state of the project
- **Build check:** After each finished request that changes code, verify the project builds using `xcodebuild -scheme CookSavvy -destination 'generic/platform=iOS Simulator' build` — always target generic iOS Simulator, never a specific simulator version (unless explicitly requested). If no code changes were introduced, no build needs to be run.
- **Unit tests:** After significant logic changes, run the unit tests test plan: `xcodebuild test -scheme CookSavvy -destination 'platform=iOS Simulator,name=iPhone 16' -testPlan UnitTests` — do not run the default test plan (which includes everything) unless explicitly requested
