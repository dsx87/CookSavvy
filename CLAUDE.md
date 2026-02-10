# CookSavvy

A hobby iOS recipe app that suggests recipes based on user-provided ingredients.

## Tech Stack

- **Language:** Swift
- **UI Framework:** SwiftUI (UIKit only when absolutely necessary)
- **Database:** GRDB (SQLite wrapper)
- **Subscriptions:** StoreKit 2
- **Philosophy:** Maximize use of Apple frameworks

## Subscription Tiers

| Tier | Recipe Source | Ingredient Detection |
|------|---------------|---------------------|
| Free | Local database (`OfflineRecipeSource`) | Manual text input only |
| API | REST API (`OnlineRecipeSource`) | AI photo recognition |
| AI | AI-generated (`AIRecipeSource`) | AI photo recognition |

## App Screens

| Screen | Description |
|--------|-------------|
| **Ingredients Input** (initial) | Text input with autocomplete, camera input (AI recognition on paid tiers), recent/fast ingredients |
| **Search Results** | Recipe table with name, image, complexity, cook time; header with source info |
| **Recipe Details** | Full recipe information with additional info section |
| **Recent Recipes** | Recently viewed recipes (same layout as search results) |
| **Favorites** | Bookmarked recipes (same layout as search results) |
| **Settings** | Subscription plan, usage limits, preferences |
| **Camera** | Camera capture for AI ingredient detection (paid tiers) |
| **Upgrade** | Subscription upgrade prompt |
| **Tab Container** | Root tab bar hosting all main screens |

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
- Feature coordinators: `IngredientsCoordinator`, `FavoritesCoordinator`, `RecentRecipesCoordinator`, `SettingsCoordinator`
- Each coordinator owns its navigation stack and sheet presentations
- ViewModels hold weak references to coordinators for navigation

### Dependency Injection
- `AppContainer`: `@MainActor` singleton holding all shared service instances
- Services initialized once and injected into ViewModels via coordinators
- Maintains single source of truth for app-wide dependencies
- TODO: refactor away from singleton pattern

### Database Layer
- `DBInterfaceProtocol` / `DBInterface` — GRDB-based SQLite database
- Used by `RecipeService`, `IngredientsService`, `UserDataService`, `DataImportService`, `DatabaseInitializationService`
- `DBTestHelpers` for test support

### Service Layer
- **Data Services**: `RecipeService`, `IngredientsService`, `UserDataService`
- **Infrastructure**: `ImageService`, `DatabaseInitializationService`, `DataImportService`, `CSVToJSONReader`
- **Feature Services**: `IngredientDetectionServiceProtocol` (impl: `AIIngredientDetectionAdapter`), `SubscriptionServiceProtocol` (impl: `StoreKitSubscriptionService` / `MockSubscriptionService`)
- **Network Layer**: `NetworkServiceProtocol` / `NetworkService`, `NetworkConfiguration`, `URLBuilder`, `NetworkRequest`, `NetworkResponse`, `NetworkError`, `HTTPMethod`
- **Recipe Sources** — `RecipeSourceProtocol` → `OfflineRecipeSource`, `OnlineRecipeSource` (via `RecipeAPIProviderProtocol`), `AIRecipeSource`
- **Recipe API Providers** (`Model/Network/RecipeAPIProvider/`):
  - `RecipeAPIProviderProtocol` — common interface for online recipe APIs
  - `SpoonacularProvider` — Spoonacular API integration (complexSearch endpoint)
  - `SpoonacularModels` — DTOs + mapper to convert API responses to `Recipe`
  - `RecipeAPIProviderError` — shared error types
- `OnlineRecipeSource` delegates to a pluggable `RecipeAPIProviderProtocol` (nil = unavailable)
- All services conform to protocols for testability

### AI Service Layer
- `AIServiceProtocol` / `AIService` — main AI interface for ingredient detection and recipe generation
- `AIIngredientDetectionAdapter` — bridges `AIServiceProtocol` to `IngredientDetectionServiceProtocol`
- **LLM Provider layer** (`Model/AI/LLMProvider/`):
  - `LLMProviderProtocol` — common interface
  - `OpenAIProvider` — OpenAI API integration
  - `GeminiProvider` — Google Gemini API integration
  - `MockLLMProvider` — mock for testing/DEBUG builds
  - `LLMModels`, `LLMProviderError` — shared types
- **Provider selection** (in `AppContainer`):
  - DEBUG → `MockLLMProvider`
  - RELEASE → OpenAI (preferred) → Gemini → MockLLMProvider fallback
- **API keys** stored in `Support/APIKeys.plist` (gitignored), read via `APIKeyConfiguration` enum
  - Keys: `OPENAI_API_KEY`, `GEMINI_API_KEY`, `SPOONACULAR_API_KEY`

### Subscription Layer
- `SubscriptionServiceProtocol` — common interface (plan access, purchases, restore)
- `StoreKitSubscriptionService` — real StoreKit 2 implementation (RELEASE)
- `MockSubscriptionService` — mock with configurable initial plan (DEBUG)
- `SubscriptionPlan` — plan enum (free/api/ai)
- `PaidFeature` — feature gating
- `Configuration.storekit` — StoreKit testing configuration

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

## Project Structure

```
CookSavvy/
├── CookSavvyApp.swift              — App entry point
├── AppContainer.swift               — DI container (singleton)
├── IngredientsProvider.swift        — Ingredients data provider
├── Coordinators/                    — Navigation coordinators
│   ├── Coordinator.swift            — Base protocol
│   ├── AppCoordinator.swift         — Root coordinator
│   ├── IngredientsCoordinator.swift
│   ├── FavoritesCoordinator.swift
│   ├── RecentRecipesCoordinator.swift
│   └── SettingsCoordinator.swift
├── Model/
│   ├── Ingredient.swift, Recipe.swift — Core models
│   ├── DBInterfaceProtocol.swift    — Database layer (GRDB)
│   ├── RecipeService.swift, IngredientsService.swift, UserDataService.swift
│   ├── ImageService.swift, DataImportService.swift, DatabaseInitializationService.swift
│   ├── RecipeSource.swift           — RecipeSourceProtocol + RecipeSourceType
│   ├── OfflineRecipeSource.swift, OnlineRecipeSource.swift, AIRecipeSource.swift
│   ├── IngredientDetectionService.swift — Protocol + errors
│   ├── AI/                          — AI service + LLM providers
│   ├── Network/                     — Network layer + RecipeAPIProvider/
│   └── Subscription/                — Subscription service layer
├── Views/
│   ├── TabContainerView.swift       — Root tab bar
│   ├── IngredientsInputView/        — Ingredients input screen + subviews
│   ├── RecipesResultView/           — Search results screen
│   ├── RecipeView/                  — Recipe details screen
│   ├── FavoritesView/               — Favorites screen
│   ├── RecentRecipesView/           — Recent recipes screen
│   ├── SettingsView/                — Settings screen
│   ├── CameraView/                  — Camera capture screen
│   ├── UpgradeView/                 — Subscription upgrade screen
│   ├── AsyncImageDisk.swift         — Async image with disk caching
│   ├── Colors.swift                 — Color definitions
│   └── UIConstants.swift            — Shared UI constants
├── Utilities/
│   └── DeviceUtility.swift
├── Support/
│   ├── APIKeys.plist                — API keys (gitignored)
│   ├── Assets/                      — Asset catalogs
│   └── Preview Content/
├── String+extensions.swift
└── Character+extensions.swift

CookSavvyTests/                      — Unit tests
├── CookSavvyTests.swift             — Core integration tests
├── IngredientsServiceTests.swift
├── RecipeServiceTests.swift
├── ImageServiceTests.swift
├── OfflineRecipeSourceTests.swift
├── OnlineAndAIRecipeSourceTests.swift
├── RecipeSourceTests.swift
├── CVSDecoderTests.swift
└── DatasetImportingTests.swift
```

## Workflow Rules

- **Ask before coding** if you need more info (unless instructed otherwise)
- **Comments:** Default is `none`. Levels: `none` | `needed only` | `every line` — wait for instruction
- **Documentation maintenance:** After introducing structural changes (new services, screens, coordinators, architecture shifts, or dependency changes), check `CLAUDE.md` and `AGENTS.md` and update them to reflect the current state of the project
