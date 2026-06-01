---
paths:
  - "CookSavvy/Services/**"
  - "CookSavvy/Network/**"
  - "CookSavvy/DataImport/**"
---

# Service Layer

## Database Layer
- `DBInterfaceProtocol` / `DBInterface` — GRDB-based SQLite database; tables: `ingredients`, `recipes`, `recipe_ingredients`, `recent_ingredients`, `recent_recipes`, `favorite_recipes`, `recent_searches`, `pantry_items`, `cooking_sessions`, `shopping_items`
- Used by `RecipeService`, `IngredientsService`, `UserDataService`, `DataImportService`, `DatabaseInitializationService`, `ShoppingListService`, `PantryService`, `RecipeRecommendationService`
- `DBTestHelpers` for test support

## Data Services
- **Data Services**: `RecipeServiceProtocol` / `RecipeService`, `IngredientsServiceProtocol` / `IngredientsService`, `UserDataServiceProtocol` / `UserDataService`
- **Infrastructure**: `ImageServiceProtocol` / `ImageService`, `RecipeShareCardGenerating` / `RecipeShareCardGenerator`, `DatabaseInitializationServiceProtocol` / `DatabaseInitializationService`, `DataImportServiceProtocol` / `DataImportService`, `RecipeDatasetReading` / `JSONRecipeDatasetReader`
- **Cross-cutting**: `LoggingServiceProtocol` / `LoggingService` creates feature-scoped `LoggerProtocol` instances backed by `os.Logger`
- **Feature Services**: `ShoppingListServiceProtocol` / `ShoppingListService`, `PantryServiceProtocol` / `PantryService`, `RecipeRecommendationServiceProtocol` / `RecipeRecommendationService`, `SubstitutionServiceProtocol` / `SubstitutionService`, `CameraScanTrackerProtocol` / `CameraScanTracker`, `IngredientDetectionServiceProtocol` (impl: `AIIngredientDetectionAdapter`), `SubscriptionServiceProtocol` (impl: `StoreKitSubscriptionService` / `MockSubscriptionService`)
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

## AI Service Layer
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

## Subscription Layer
- `SubscriptionServiceProtocol` — common interface (plan access, monthly/annual purchases, restore)
- `StoreKitSubscriptionService` — real StoreKit 2 implementation (RELEASE)
- `MockSubscriptionService` — mock with configurable initial plan (DEBUG)
- `SubscriptionPlan` — entitlement tier enum (`free`, `premium`)
- `PremiumSubscriptionOption` — purchasable CookSavvy+ products (`monthly`, `yearly`)
- `SubscriptionStatus` — subscription snapshot including active option, monthly trial eligibility, and active free-trial state for Upgrade + Settings UI
- `PaidFeature` — feature gating
- `Configuration.storekit` — StoreKit testing configuration

## File Map

```
Services/
├── Recipe/
│   ├── RecipeService.swift
│   ├── RecipeMatchRanker.swift
│   ├── RecipeMoodRanker.swift
│   ├── RecipeRecommendationService.swift  — personalized suggestions from cooking history
│   ├── RecipeSourceProtocol.swift — Protocol + RecipeSourceType + errors
│   ├── OfflineRecipeSource.swift
│   ├── OnlineRecipeSource.swift
│   └── AIRecipeSource.swift
├── Ingredient/
│   ├── IngredientsService.swift
│   └── IngredientDetectionProtocol.swift — Protocol + errors
├── Image/
│   ├── ImageService.swift
│   └── ImageExtractor.swift
├── Sharing/
│   ├── RecipeShareCard.swift
│   └── RecipeShareCardGenerator.swift
├── Logging/
│   └── LoggingService.swift
├── UserData/
│   └── UserDataService.swift
├── Auth/
│   ├── AuthServiceProtocol.swift
│   ├── SupabaseAuthService.swift
│   ├── MockAuthService.swift
│   ├── NoOpAuthService.swift
│   ├── AppleSignInManager.swift
│   └── SignInWithAppleAction.swift
├── Subscription/
│   ├── SubscriptionServiceProtocol.swift
│   ├── StoreKitSubscriptionService.swift
│   ├── MockSubscriptionService.swift
│   └── CameraScanTracker.swift         — weekly scan counter (UserDefaults, resets each calendar week)
├── ShoppingList/
│   └── ShoppingListService.swift       — CRUD for shopping items via DBInterface
├── Pantry/
│   ├── PantryServiceProtocol.swift     — Protocol for free pantry staples
│   └── PantryService.swift             — CRUD for always-available pantry ingredients via DBInterface
├── Substitution/
│   ├── SubstitutionServiceProtocol.swift
│   ├── SubstitutionCatalogLoader.swift
│   ├── SubstitutionService.swift
│   └── MockSubstitutionService.swift   — DEBUG/test canned substitution results
├── AI/
│   ├── AIServiceProtocol.swift
│   ├── AIService.swift
│   ├── AIServiceError.swift
│   ├── AIIngredientDetectionAdapter.swift
│   └── LLMProvider/
│       ├── LLMProviderProtocol.swift
│       ├── LLMProviderError.swift
│       ├── LLMModels.swift
│       └── MockLLMProvider.swift
├── Supabase/
│   ├── SupabaseConfiguration.swift
│   ├── SupabaseClientProvider.swift
│   ├── SupabaseRecipeDTOs.swift
│   ├── SupabaseServiceAssembly.swift
│   ├── SupabaseLLMProvider.swift
│   └── SupabaseRecipeAPIProvider.swift
└── Database/
    ├── DBInterfaceProtocol.swift  — Protocol + errors
    ├── DBInterface.swift          — GRDB implementation
    ├── DBTestHelpers.swift        — Test helper (used by DBInterface in test mode)
    └── DatabaseInitializationService.swift

Network/
├── NetworkServiceProtocol.swift
├── NetworkService.swift
├── NetworkConfiguration.swift
├── NetworkRequest.swift
├── NetworkResponse.swift
├── NetworkError.swift
├── HTTPMethod.swift
├── URLBuilder.swift
└── RecipeAPIProvider/
    └── RecipeAPIProviderProtocol.swift

DataImport/
├── DataImportService.swift
├── RecipeDatasetReader.swift
└── Unarchiver.swift
```
