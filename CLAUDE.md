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
| **Journey** (tab 2) | Profile header, stats, user-created recipes, weekly calendar, achievements, recent sessions, settings (gear icon in nav bar) |
| **Recipe Details** | Hero image, floating back/bookmark actions, stats row, ingredients (with "Add Missing to List" button for premium), steps, sticky Start Cooking CTA |
| **Recipe List** | Reusable See All destination for recent, saved, and user recipes |
| **Cook Mode** | Full-screen step-by-step cooking flow with progress ring, timer, and prev/next navigation |
| **Create Recipe** | 5-step wizard: Name & Photo → Ingredients → Steps → Details → Review & Save |
| **Settings** | Subscription plan, usage limits, preferences (accessed from Journey nav bar) |
| **Camera** | Camera capture for AI ingredient detection (free users: 5/week via `CameraScanTracker`) |
| **Upgrade** | Single-plan upgrade prompt (CookSavvy+) |
| **Onboarding** | 3-screen first-launch walkthrough (fork.knife.circle → camera.viewfinder → timer); gated by `hasCompletedOnboarding` AppStorage |
| **Shopping List** | Premium checklist of missing ingredients grouped by recipe; swipe-to-delete, toggle checked, clear done; sheet from Recipe Details or Journey |
| **Tab Container** | Root tab bar with 2 tabs: Discover + Journey |

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
- `JourneyCoordinator`: Journey stats, recipe detail, recipe list, settings, create recipe, upgrade
- Each coordinator owns its navigation stack and sheet presentations
- ViewModels hold weak references to coordinators for navigation

### Dependency Injection
- `AppContainer`: `@MainActor` singleton holding all shared service instances
- Services initialized once and injected into ViewModels via coordinators
- Maintains single source of truth for app-wide dependencies
- TODO: refactor away from singleton pattern

### Database Layer
- `DBInterfaceProtocol` / `DBInterface` — GRDB-based SQLite database; tables: `ingredients`, `recipes`, `recipe_ingredients`, `recent_ingredients`, `recent_recipes`, `favorite_recipes`, `recent_searches`, `cooking_sessions`, `shopping_items`
- Used by `RecipeService`, `IngredientsService`, `UserDataService`, `DataImportService`, `DatabaseInitializationService`
- `DBTestHelpers` for test support

### Service Layer
- **Data Services**: `RecipeService`, `IngredientsService`, `UserDataService`
- **Infrastructure**: `ImageService`, `DatabaseInitializationService`, `DataImportService`, `CSVParser`
- **Feature Services**: `IngredientDetectionServiceProtocol` (impl: `AIIngredientDetectionAdapter`), `SubscriptionServiceProtocol` (impl: `StoreKitSubscriptionService` / `MockSubscriptionService`)
- **Network Layer**: `NetworkServiceProtocol` / `NetworkService`, `NetworkConfiguration`, `URLBuilder`, `NetworkRequest`, `NetworkResponse`, `NetworkError`, `HTTPMethod`
- **Recipe Sources** — `RecipeSourceProtocol` → `OfflineRecipeSource`, `OnlineRecipeSource` (via `RecipeAPIProviderProtocol`), `AIRecipeSource`
- **Recipe API Providers** (`Network/RecipeAPIProvider/`):
  - `RecipeAPIProviderProtocol` — common interface for online recipe APIs
  - `SpoonacularProvider` — Spoonacular API integration (complexSearch endpoint)
  - `SpoonacularModels` — DTOs + mapper to convert API responses to `Recipe`
  - `RecipeAPIProviderError` — shared error types
- `OnlineRecipeSource` delegates to a pluggable `RecipeAPIProviderProtocol` (nil = unavailable)
- All services conform to protocols for testability

### AI Service Layer
- `AIServiceProtocol` / `AIService` — main AI interface for ingredient detection and recipe generation
- `AIIngredientDetectionAdapter` — bridges `AIServiceProtocol` to `IngredientDetectionServiceProtocol`
- **LLM Provider layer** (`Services/AI/LLMProvider/`):
  - `LLMProviderProtocol` — common interface
  - `OpenAIProvider` — OpenAI API integration
  - `GeminiProvider` — Google Gemini API integration
  - `MockLLMProvider` — mock for testing/DEBUG builds
  - `LLMModels`, `LLMProviderError` — shared types
- **Provider selection** (in `AppContainer`):
  - DEBUG → `MockLLMProvider`
  - RELEASE → OpenAI (preferred) → Gemini → MockLLMProvider fallback
- **API keys** stored in `Support/APIKeys.plist` (gitignored), read via `APIKeyConfiguration` enum (`App/APIKeyConfiguration.swift`)
  - Keys: `OPENAI_API_KEY`, `GEMINI_API_KEY`, `SPOONACULAR_API_KEY`

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

```
CookSavvy/
├── App/
│   ├── CookSavvyApp.swift           — App entry point
│   ├── AppContainer.swift            — DI container (singleton)
│   └── APIKeyConfiguration.swift     — API key reading from plist
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
│   ├── UserData/
│   │   └── UserDataService.swift
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
│   │       ├── OpenAIProvider.swift
│   │       ├── GeminiProvider.swift
│   │       └── MockLLMProvider.swift
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
│       ├── RecipeAPIProviderProtocol.swift
│       ├── SpoonacularProvider.swift
│       └── SpoonacularModels.swift
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
│   └── Onboarding/                    — First-launch walkthrough (OnboardingView + OnboardingViewModel)
├── Extensions/
│   ├── Character+Extensions.swift
│   └── String+Extensions.swift
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

CookSavvyTests/                        — Unit tests
├── CookSavvyTests.swift
├── IngredientsServiceTests.swift
├── RecipeServiceTests.swift
├── ImageServiceTests.swift
├── OfflineRecipeSourceTests.swift
├── OnlineAndAIRecipeSourceTests.swift
├── RecipeSourceTests.swift
├── CVSDecoderTests.swift
└── DatasetImportingTests.swift
```

## Documentation

Extended documentation lives in the `docs/` directory:

| File | Contents |
|------|----------|
| `docs/IMAGE_SERVICE_README.md` | ImageService usage and API |
| `docs/INGREDIENTS_SERVICE_README.md` | IngredientsService usage and API |
| `docs/RECIPE_SERVICE_README.md` | RecipeService usage and API |
| `docs/PRODUCT_ANALYSIS.md` | Product analysis and feature breakdown |
| `docs/PRODUCT_AUDIT_GPT.md` | Product audit notes |

## Workflow Rules

- **Ask before coding** if you need more info (unless instructed otherwise)
- **Comments:** Default is `none`. Levels: `none` | `needed only` | `every line` — wait for instruction
- **Documentation maintenance:** After introducing structural changes (new services, screens, coordinators, architecture shifts, or dependency changes), check `CLAUDE.md`, `AGENTS.md` and `GEMINI.md` and update them to reflect the current state of the project
