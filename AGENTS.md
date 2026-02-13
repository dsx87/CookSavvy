# CookSavvy — Agent Instructions

> For detailed project documentation, see `CLAUDE.md`

## Quick Reference

**Project:** iOS recipe app (Swift + SwiftUI)  
**Purpose:** Suggest recipes from user-provided ingredients  
**Database:** GRDB (SQLite)  
**Subscriptions:** StoreKit 2

## Must Follow

### Architecture
- **MVVM + Coordinator** — Views hold only `viewModel`, ViewModels hold weak coordinator refs
- **Coordinators** — handle navigation and ViewModel creation (AppCoordinator → `DiscoverCoordinator`, `JourneyCoordinator`, `SettingsCoordinator`)
- **Dependency Injection** — `AppContainer` `@MainActor` singleton provides all services
- **Service Layer** — data services, infrastructure services, feature services, network layer
- **Recipe Sources** — `RecipeSourceProtocol` → `OfflineRecipeSource`, `OnlineRecipeSource` (via `RecipeAPIProviderProtocol`), `AIRecipeSource`
- **Recipe API Providers** — `RecipeAPIProviderProtocol` → `SpoonacularProvider`; available if API key present (both DEBUG and RELEASE)
- **AI Layer** — `AIService` with pluggable LLM providers (`OpenAI`, `Gemini`, `Mock`); DEBUG uses mock, RELEASE uses real with fallback chain
- **Subscription Layer** — `SubscriptionServiceProtocol` → `StoreKitSubscriptionService` (RELEASE) / `MockSubscriptionService` (DEBUG)
- **Theme** — `AppTheme` protocol + `LightTheme` / `DarkTheme` + `SystemTheme`, injected via `@Environment(\.appTheme)`; V2 tokens: `bg`, `surface`, `card`, `accent`, `mint`, `rose`, `lavender`, `sky`, `gold`, `text1`–`text3`; legacy aliases: `borderAccent`, etc.
- **View Modifiers** — `.frostCard()`, `.neonGlow(_:radius:)`, `.sectionLabel()` in `Theme/ViewModifiers.swift`
- **UI Constants** — `UI` struct with nested domain structs (`UI.RecipeCell.imageSize`, `UI.V2.heroImageHeight`)
- **Strings** — `Strings` enum with `String(localized:)` per screen; `Icons` enum for SF Symbol names
- **Localization** — `Localizable.xcstrings` String Catalog (Xcode 15+)
- **Models** — `Recipe.Step` (text + timerMinutes), `IngredientCategory`, `CookingSession`, `Achievement`, `IngredientEmojiProvider`
- **Two ratings** — `userRating` + `apiRating` on `Recipe`; `matchPercentage` set at search time
- **User recipes** — `isUserCreated` flag on `Recipe`, CRUD via `UserDataService`
- **Create Recipe** — `CreateRecipeViewModel` 5-step wizard (Name & Photo → Ingredients → Steps → Details → Review & Save)
- **Single Responsibility Principle** — create services as needed
- **SwiftUI first** — UIKit only when unavoidable
- **Apple frameworks preferred**

### Code Standards
- **No code duplication** — search existing code before writing new
- Refactor only when necessary; prefer new methods over modifying existing
- Duplication requires explicit user approval

### Workflow
- Ask for clarification before coding if info is missing
- No comments unless instructed (levels: `none` | `needed only` | `every line`)
- **After structural changes** (new services, screens, coordinators, architecture shifts, dependencies) — check and update `CLAUDE.md` and `AGENTS.md`

## Subscription Tiers

| Tier | Recipes | Photo AI |
|------|---------|----------|
| Free | Local DB (`OfflineRecipeSource`) | ❌ |
| API | REST API (`OnlineRecipeSource`) | ✅ |
| AI | AI-generated (`AIRecipeSource`) | ✅ |

## Key Services

- **Data:** `RecipeService`, `IngredientsService`, `UserDataService`
- **Infrastructure:** `ImageService`, `DatabaseInitializationService`, `DataImportService`, `CSVParser`
- **Database:** `DBInterfaceProtocol` / `DBInterface` (GRDB)
- **Network:** `NetworkService`, `URLBuilder`, `NetworkRequest`, `NetworkResponse`, `NetworkError`, `HTTPMethod`
- **AI:** `AIService` → `LLMProviderProtocol` (`OpenAIProvider`, `GeminiProvider`, `MockLLMProvider`)
- **Detection:** `IngredientDetectionServiceProtocol` → `AIIngredientDetectionAdapter`
- **Subscriptions:** `SubscriptionServiceProtocol` → `StoreKitSubscriptionService` / `MockSubscriptionService`
- **Recipe API:** `RecipeAPIProviderProtocol` → `SpoonacularProvider` (complexSearch endpoint), `SpoonacularModels` (DTOs + mapper)
- **API Keys:** `APIKeys.plist` (gitignored) via `APIKeyConfiguration` — `OPENAI_API_KEY`, `GEMINI_API_KEY`, `SPOONACULAR_API_KEY`

## Screens

- **Discover** (tab 1) — ingredient input, recipe search, recent/saved recipes, mood filter
- **Journey** (tab 2) — stats, achievements, user recipes, cooking sessions, settings (gear in nav bar)
- **Ingredients Input** — text + autocomplete, camera (paid), recent/fast ingredients
- **Search Results** — recipe list (name, image, complexity, time, match %), source header
- **Recipe Details** — full recipe info + additional info section
- **Recipe List** — reusable list for recent, saved, user recipes
- **Cook Mode** — step-by-step cooking with visual timer (full screen)
- **Create Recipe** — 5-step wizard (Name & Photo → Ingredients → Steps → Details → Review & Save)
- **Settings** — subscription, limits (accessed from Journey nav bar)
- **Camera** — AI ingredient detection (paid tiers)
- **Upgrade** — subscription upgrade prompt
- **Tab Container** — 2 tabs: Discover (`compass.drawing`) + Journey (`trophy.fill`)
