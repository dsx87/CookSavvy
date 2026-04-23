# CookSavvy — Technical Debt & Improvement Report

Generated: 2026-04-22

---

## 🔴 Critical

| # | Area | Issue | Location |
|---|------|-------|----------|
| 1 | **Database** | Unprotected mutable `recipeCache` dictionary — concurrent reads/writes with no lock = data race | `DBInterface.swift:31, 341–408, 882` |
| 2 | **Database** | Three `try!` force-tries on DB init — any failure crashes the app with no graceful degradation | `DBInterface.swift:63, 68, 74, 76` |
| 3 | **Data Import** | `CSVParser` uses `as!` force-casts without type validation — crash if type doesn't match | `CSVParser.swift:241, 243, 249` |
| 4 | **AI / Security** | User-supplied ingredient names interpolated directly into LLM prompts — no sanitization, prompt injection risk | `AIService.swift:74–76` |
| 5 | **Security** | Spoonacular API key passed as URL query parameter — logged in server access logs and proxy caches | `SpoonacularProvider.swift:28` |
| 6 | **Subscription** | No subscription status refresh when app returns to foreground — cancelled subscriptions won't be reflected until next launch | `CookSavvyApp.swift` / `StoreKitSubscriptionService.swift` |
| 7 | **Testing** | 11 commented-out `DatasetImportingTests` — data import is entirely untested | `DatasetImportingTests.swift` |
| 8 | **Database** | No formal migration system — schema uses `CREATE TABLE IF NOT EXISTS` only, with one ad-hoc column addition, no versioning | `DBInterface.swift:80–250` |

---

## 🟡 High

| # | Area | Issue | Location |
|---|------|-------|----------|
| 9 | **Architecture** | `AppContainer` singleton: 110-line init chain, 18 services all eagerly instantiated at launch, side-effect `startInitialization()` called during `init`, explicit TODO to fix | `AppContainer.swift:15–151` |
| 10 | **Architecture** | Direct `AppContainer.shared` accessed from views (`TabContainerView`, `AsyncImageDisk`) and `AppCoordinator` — breaks DI | `TabContainerView.swift:13`, `AppCoordinator.swift:45–47`, `CookSavvyApp.swift:55, 60` |
| 11 | **Auth** | Apple Sign-In `ASAuthorizationController` continuation can hang forever — no timeout, awaiting task blocked indefinitely | `AppleSignInManager.swift:37–48` |
| 12 | **Auth** | Anonymous → Apple Sign-In linking has no validation or data migration — existing anonymous recipes could be lost | `SupabaseAuthService.swift:101–119` |
| 13 | **Auth** | `signOut()` clears only auth state — cached user data, recipes, analytics session not cleared | `SupabaseAuthService.swift:121–129` |
| 14 | **Auth** | `currentNonce` stored as instance property with no timeout or thread safety — race condition if multiple sign-in requests | `AppleSignInManager.swift:34–42` |
| 15 | **Network** | Retry uses fixed 1s delay for all attempts — no exponential backoff, hammers rate-limited endpoints | `NetworkConfiguration.swift:20–21` |
| 16 | **AI** | No token limit enforcement — LLM calls accumulate unlimited tokens per user; no quota management | `AIService.swift:45–47` |
| 17 | **AI** | No fallback when AI provider is unavailable — hard error thrown, no degradation to offline recipes | `AIService.swift:28–30` |
| 18 | **Database** | `DBInterface` is a 1151-line god object covering 9 domains — violates SRP, hard to maintain and test | `DBInterface.swift` |
| 19 | **Database** | Swallowed decode errors via `compactMap { try? }` — corrupted recipes silently dropped, users see incomplete lists | `DBInterface.swift:588, 618, 827` |
| 20 | **Testing** | 26+ tests use arbitrary `Task.yield()` counts instead of `XCTestExpectation` — flaky on slower hardware/CI | `DiscoverViewModelTests`, `OnboardingViewModelTests`, `RecipeDetailsViewModelTests` |
| 21 | **Testing** | 4 ViewModels with zero tests: `CameraViewModel`, `RecipeListViewModel`, `SettingsViewModel`, `UpgradeViewModel` | Tests directory |
| 22 | **Testing** | 7 services with zero tests: `AIService`, `SupabaseAuthService`, `DataImportService`, `LoggingService`, `StoreKitSubscriptionService`, `NoOpAuthService`, `DatasetImportingService` | Tests directory |

---

## 🟠 Medium

| # | Area | Issue | Location |
|---|------|-------|----------|
| 23 | **Architecture** | Coordinator protocols (`RecipeDetailsCoordinating`, `JourneyCoordinating`, etc.) defined inside ViewModel files — should be in Coordinators/ | `RecipeDetailsViewModel.swift:11–15`, `JourneyViewModel.swift:5–10` |
| 24 | **Architecture** | `JourneyCoordinator` holds a strong reference to `SettingsCoordinator` — potential retain cycle | `JourneyCoordinator.swift:12` |
| 25 | **Architecture** | All ViewModels call `coordinator?.method()` with weak optional reference and no guard — navigation silently fails if coordinator is nil | Multiple ViewModels |
| 26 | **Database** | `DBInterface` lacks `actor` isolation or any concurrency annotation despite multi-threaded GRDB access | `DBInterface.swift:13` |
| 27 | **Database** | `DatabaseInitializationService` uses busy-wait polling with 50ms sleep — should use async published state | `DatabaseInitializationService.swift:104–119` |
| 28 | **Database** | All `DBInterfaceProtocol` methods are synchronous `throws` — service methods calling them from `async` contexts block the calling thread | `DBInterfaceProtocol.swift:35–105` |
| 29 | **Database** | N+1 query pattern in `IngredientsService.getAllIngredients(byCategory:)` — loops per food group, creating Ingredients just for category mapping | `IngredientsService.swift:125–150` |
| 30 | **Database** | CSV import has no validation, no deduplication, no transactional rollback — partial import can corrupt database | `DataImportService.swift:77–90` |
| 31 | **Database** | Temporary ZIP extraction files never cleaned up by caller — accumulates in `tmp/` directory | `Unarchiver.swift:40–52` |
| 32 | **Models** | `Recipe.id` is derived from `title` — two recipes with the same title hash/equate as identical | `Recipe.swift:193` |
| 33 | **Models** | `ShoppingItem` is not `Codable` despite being persisted to the database — forces manual serialization in DBInterface | `ShoppingItem.swift:8` |
| 34 | **Models** | `Ingredient.emoji` field has no `CodingKey` — always `nil` after decode, silently lost | `Ingredient.swift:30` |
| 35 | **Subscription** | StoreKit `noPurchasesToRestore` error case is dead code — never thrown after `AppStore.sync()` | `SubscriptionServiceProtocol.swift:25` |
| 36 | **Subscription** | Stale cached subscription plan used indefinitely if `refreshSubscriptionStatus()` fails on launch | `StoreKitSubscriptionService.swift:154–163` |
| 37 | **Supabase** | Auth errors from Supabase mapped as `.unknown` instead of `.invalidAPIKey` | `SupabaseLLMProvider.swift:76–91` |
| 38 | **Dead Code** | Legacy direct provider cleanup is partially complete; audit any remaining backend-superseded client code before release | `Services/AI/`, `Network/RecipeAPIProvider/` |
| 39 | **Testing** | Mocks always succeed (never throw errors) — no testing of source unavailability, network failure, or empty collections | `MockServices.swift` |
| 40 | **Testing** | No end-to-end integration tests for critical flows: auth→subscription, scan→search, cook→stats→achievement | Tests directory |
| 41 | **UI** | `CameraView` uses raw `Color.black`, `Color.white`, `Color.orange`, `Color.red` instead of theme tokens | `CameraView.swift:14, 46, 51, 80, 96, 120, 180` |
| 42 | **UI** | `JourneyView` calls both `.onAppear` and `.task` for data loading — redundant, unclear lifecycle intent | `JourneyView.swift:36–38` |
| 43 | **UI** | `DiscoverView` (805 lines) and `JourneyView` (564 lines) are too large — extraction needed | `DiscoverView.swift`, `JourneyView.swift` |
| 44 | **Logging** | `LoggingService` created ad-hoc in `DietaryPreferences` instead of being injected — new instance per call | `DietaryPreferences.swift:88` |

---

## 🟢 Low / Polish

| # | Area | Issue | Location |
|---|------|-------|----------|
| 45 | **Database** | Missing indexes on foreign key columns in `favorite_recipes`, `recent_recipes` join tables — full table scans on JOINs | `DBInterface.swift:162–172` |
| 46 | **Extensions** | `Color(hex:)` has no validation — silently produces wrong color for malformed or short hex strings | `Color+Hex.swift:4–15` |
| 47 | **Extensions** | `Character.isSimpleEmoji` uses magic number threshold `0x238C` with no documentation | `Character+Extensions.swift:14` |
| 48 | **Extensions** | `String.separatedByQuotes` has no error handling for malformed/unclosed quotes | `String+Extensions.swift:11–21` |
| 49 | **Concurrency** | `SpoonacularProvider` uses `@unchecked Sendable` unnecessarily — all properties are `let`, safe to remove | `SpoonacularProvider.swift:3` |
| 50 | **Accessibility** | `RecipeDetailsList` and `RecipeDetailsAdditionalInfo` have zero accessibility labels or identifiers | `RecipeDetailsList.swift`, `RecipeDetailsAdditionalInfo.swift` |
| 51 | **Localization** | `Text("minutes")` hardcoded in CookMode, several other raw English strings in views | `CookModeView.swift:138`, `SettingsView.swift` |
| 52 | **UI** | Camera emoji/icon sizes hardcoded (`size: 60`) — not using `UI` constants, won't scale with Dynamic Type | `CameraView.swift:45, 119` |
| 53 | **Subscription** | `CameraScanTracker` weekly reset doesn't log when reset occurs — invisible side effect, hard to debug | `CameraScanTracker.swift:45–48` |
| 54 | **Subscription** | Week boundary uses `weekOfYear` without locale-aware week start — Sunday vs Monday locales may behave differently | `CameraScanTracker.swift:45–48` |
| 55 | **Achievement** | `unlockedAt` timestamp not preserved on re-evaluation — historical unlock dates lost if evaluator runs again | `AchievementEvaluator.swift:37` |
| 56 | **Nutrition** | Spoonacular `calories` field was never implemented — `TODO: Add calories when addRecipeNutrition=true` left dangling | `SpoonacularModels.swift:61` |
| 57 | **UITests** | UITest seeder relies on recipe title uniqueness (since `Recipe.id = title`) — fragile if seed names change | `UITestDataSeeder.swift:74, 201` |
| 58 | **TODOs** | Vague `// TODO: Review this` in StoreKit service with no resolution plan | `StoreKitSubscriptionService.swift:10` |
| 59 | **TODOs** | `// TODO: do some cleanup for this flow` + swallowed errors in popular ingredients path | `UserDataService.swift:50` |
| 60 | **TODOs** | `// TODO: optimize` loop in DataImportService that mutates recipes by index | `DataImportService.swift:82` |

---

## Top 5 to Fix First

Based on crash/data-loss risk:

1. **#2** — `try!` on DB init (app crash)
2. **#1** — Data race on `recipeCache` (data corruption)
3. **#3** — `CSVParser` force-cast (parsing crash)
4. **#6** — Subscription not refreshed on foreground (revenue/UX)
5. **#4** — Prompt injection in AI service (security)
