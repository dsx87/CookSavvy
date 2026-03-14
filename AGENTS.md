# CookSavvy — Agent Instructions

> For detailed project documentation, see `CLAUDE.md`

## Quick Reference

**Project:** iOS recipe app (Swift + SwiftUI)  
**Purpose:** Suggest recipes from user-provided ingredients  
**Database:** GRDB (SQLite)  
**Subscriptions:** StoreKit 2

## Build Instructions

To build for any iOS Simulator (avoiding version errors):

```bash
xcodebuild -scheme CookSavvy -destination 'generic/platform=iOS Simulator' build
```

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
- **Theme** — `AppTheme` protocol + `LightTheme` / `DarkTheme` + `SystemTheme`, injected via `@Environment(\.appTheme)`; primary tokens include `bg`, `surface`, `card`, `accent`, `mint`, `rose`, `lavender`, `sky`, `gold`, `text1`–`text3`
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
- **After structural changes** (new services, screens, coordinators, architecture shifts, dependencies) — check and update `CLAUDE.md`, `AGENTS.md` and `GEMINI.md`

## Subscription Tiers

| Tier | Display Name | Recipes | Camera Scanning |
|------|--------------|---------|-----------------|
| Free | Free | Local DB (`OfflineRecipeSource`) | 5 scans/week (`CameraScanTracker`) |
| Premium | CookSavvy+ | Local + API + AI | Unlimited |

Product ID: `com.cooksavvy.subscription.premium`

## Key Services

- **Data:** `RecipeService`, `IngredientsService`, `UserDataService`
- **Infrastructure:** `ImageService`, `DatabaseInitializationService`, `DataImportService`, `CSVParser`
- **Database:** `DBInterfaceProtocol` / `DBInterface` (GRDB)
- **Network:** `NetworkService`, `URLBuilder`, `NetworkRequest`, `NetworkResponse`, `NetworkError`, `HTTPMethod`
- **AI:** `AIService` → `LLMProviderProtocol` (`OpenAIProvider`, `GeminiProvider`, `MockLLMProvider`)
- **Detection:** `IngredientDetectionServiceProtocol` → `AIIngredientDetectionAdapter`
- **Subscriptions:** `SubscriptionServiceProtocol` → `StoreKitSubscriptionService` / `MockSubscriptionService`
- **Mood Ranking:** `RecipeMoodRanker` (stateless recipe ranking helper)
- **Recipe API:** `RecipeAPIProviderProtocol` → `SpoonacularProvider` (complexSearch endpoint), `SpoonacularModels` (DTOs + mapper)
- **API Keys:** `APIKeys.plist` (gitignored) via `APIKeyConfiguration` — `OPENAI_API_KEY`, `GEMINI_API_KEY`, `SPOONACULAR_API_KEY`

## Screens

- **Discover** (tab 1) — Two-state flow: ingredient selection (grid, categories, search, recent/saved cards) ↔ recipe results (mood filter, hero best-match, recipe rows). `DiscoverView` + `DiscoverViewModel`
- **Journey** (tab 2) — Profile header, stats grid, my recipes + create card, weekly calendar, achievements, recent sessions. `JourneyView` + `JourneyViewModel`
- **Recipe Details** — Hero image (340pt), floating back/bookmark, content card overlay, stats row, ingredient list, steps with timer badges, sticky "Start Cooking" CTA. `RecipeDetailsView` + `RecipeDetailsViewModel`
- **Recipe List** — Reusable "See All" destination with `RecipeRow` cards. `RecipeListView` + `RecipeListViewModel`
- **Cook Mode** — Full-screen: progress ring, step dots, large text, countdown timer, prev/next/done nav. `CookModeView` + `CookModeViewModel`
- **Create Recipe** — 5-step wizard sheet (Name & Photo → Ingredients → Steps → Details → Review & Save). `CreateRecipeView` + `CreateRecipeViewModel`
- **Shared Components** — split by feature:
  - `Shared/RecipeCardComponents.swift`: `RecipeImage`, `MiniRecipeCard`, `RecipeRow`
  - `Shared/CommonComponents.swift`: `StarRating`, `StatPill`
  - `Discover/DiscoverComponents.swift`: `CategoryChip`, `IngredientBubble`, `SelectedChip`, `MoodPill`, `AddYourOwnCard`
  - `Journey/JourneyComponents.swift`: `CreateRecipeCard`, `UserMiniRecipeCard`
- **Settings** — subscription, preferences (accessed from Journey nav bar); single "Extended Recipes" toggle for premium users
- **Camera** — AI ingredient detection; free users get 5 scans/week tracked by `CameraScanTracker`
- **Upgrade** — single CookSavvy+ plan upgrade prompt
- **Onboarding** — 3-screen first-launch flow (gated by `hasCompletedOnboarding` UserDefaults/AppStorage)
- **Tab Container** — 2 tabs: Discover (`compass.drawing`) + Journey (`trophy.fill`)
