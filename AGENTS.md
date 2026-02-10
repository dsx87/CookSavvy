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
- **Coordinators** — handle navigation and ViewModel creation (AppCoordinator → feature coordinators)
- **Dependency Injection** — `AppContainer` `@MainActor` singleton provides all services
- **Service Layer** — data services, infrastructure services, feature services, network layer
- **Recipe Sources** — `RecipeSourceProtocol` → `OfflineRecipeSource`, `OnlineRecipeSource`, `AIRecipeSource`
- **AI Layer** — `AIService` with pluggable LLM providers (`OpenAI`, `Gemini`, `Mock`); DEBUG uses mock, RELEASE uses real with fallback chain
- **Subscription Layer** — `SubscriptionServiceProtocol` → `StoreKitSubscriptionService` (RELEASE) / `MockSubscriptionService` (DEBUG)
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
- **Infrastructure:** `ImageService`, `DatabaseInitializationService`, `DataImportService`, `CSVToJSONReader`
- **Database:** `DBInterfaceProtocol` / `DBInterface` (GRDB)
- **Network:** `NetworkService`, `URLBuilder`, `NetworkRequest`, `NetworkResponse`, `NetworkError`, `HTTPMethod`
- **AI:** `AIService` → `LLMProviderProtocol` (`OpenAIProvider`, `GeminiProvider`, `MockLLMProvider`)
- **Detection:** `IngredientDetectionServiceProtocol` → `AIIngredientDetectionAdapter`
- **Subscriptions:** `SubscriptionServiceProtocol` → `StoreKitSubscriptionService` / `MockSubscriptionService`
- **API Keys:** `APIKeys.plist` (gitignored) via `APIKeyConfiguration` — `OPENAI_API_KEY`, `GEMINI_API_KEY`

## Screens

- **Ingredients Input** — text + autocomplete, camera (paid), recent/fast ingredients
- **Search Results** — recipe list (name, image, complexity, time), source header
- **Recipe Details** — full recipe info + additional info section
- **Recent/Favorites** — same layout as search results
- **Settings** — subscription, limits
- **Camera** — AI ingredient detection (paid tiers)
- **Upgrade** — subscription upgrade prompt
- **Tab Container** — root tab bar
