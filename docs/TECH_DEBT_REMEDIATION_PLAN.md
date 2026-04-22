# CookSavvy — Tech Debt Remediation Plan

Generated: 2026-04-22  
Source audits: `TECH_DEBT.md`, `TECHNICAL_IMPROVEMENTS_AUDIT.md`, `HLD_TECH_DEBT_REVIEW.md`  
Architecture reference: `HLD.md`

---

## How to Use This Document

Each issue is numbered. Major architectural items include a **detailed implementation guide** designed for an LLM to execute without re-reading the codebase. Minor items carry a short note. Every item lists affected files and any dependent issues.

Phases are ordered for safe execution: each phase should be fully completed and the build verified before starting the next. Within a phase, items marked **[PARALLEL]** are independent and can be worked concurrently.

### Review Corrections Applied

This plan has been reviewed against `TECH_DEBT.md`, `TECHNICAL_IMPROVEMENTS_AUDIT.md`, `HLD_TECH_DEBT_REVIEW.md`, `HLD.md`, and the current source tree.

Important corrections:

- The app is in development and has no users. Do **not** build a backwards-compatible migration framework right now. Prefer destructive schema resets, fixture reseeding, and removal of ad-hoc `ALTER TABLE` development migrations when schema changes are made.
- Recipe identity must be fixed **before** splitting the database layer. Otherwise the repository refactor will encode the current title-based identity problem and require a second broad data-layer rewrite.
- Server-side Supabase subscription/rate-limit enforcement is an external dependency. The iOS app can document and call it, but the security fix is incomplete until edge functions enforce it.
- Spoonacular is a backend-only implementation detail. The iOS app should not know which third-party recipe API the backend uses, and should not compile/test direct Spoonacular request code.
- Legacy direct LLM providers (`OpenAIProvider`, `GeminiProvider`) should either be deleted or kept behind explicit DEBUG/test-only wiring. Moving any provider API key from query string to header does not make a mobile-shipped key secret.
- StoreKit, auth, database, and recipe-search fixes need acceptance tests or focused unit tests. UI tests must still not be run by agents.

### Non-Goals For This Development Stage

- No production data migrations. If the schema changes, reset the local development database and update seed/import code.
- No UI-test automation runs. Keep UI tests manual as documented in `AGENTS.md`.
- No broad rewrite. Refactors should preserve the current MVVM + Coordinator app shape unless a specific item says otherwise.

### Documentation Maintenance

After any phase that changes architecture, schema, navigation, service wiring, dependency injection, or runtime provider selection, update `docs/HLD.md` and the root agent docs (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`) if they exist and are stale. Several HLD sections are already known stale: build/provider matrix, recipe identity, app-container/singleton wording, scan-week wording, and ViewModel state counts.

**Build verification command (after every phase):**
```bash
xcodebuild -scheme CookSavvy -destination 'generic/platform=iOS Simulator' build
```
**Unit test verification command:**
```bash
xcodebuild test -scheme CookSavvy -destination 'platform=iOS Simulator,name=iPhone 16' -testPlan UnitTests
```
> Do NOT run UI tests — they require manual execution only.

---

## Phase 0 — Critical: Crash & Security Fixes

These items are independent of each other and can be done in parallel. None requires an architectural change. Fix all of them before any Phase 1 work.

**Phase 0 completion verification — 2026-04-22**

- `xcodebuild -scheme CookSavvy -destination 'generic/platform=iOS Simulator' build` — passed.
- `xcodebuild test -scheme CookSavvy -destination 'platform=iOS Simulator,name=iPhone 16' -testPlan UnitTests` — attempted; Xcode could not find an iPhone 16 destination for `OS:latest` on this machine.
- `xcodebuild test -scheme CookSavvy -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' -testPlan UnitTests` — passed, 302 selected tests, 0 failures.
- UI tests were not run.

**Code-review follow-up verification — 2026-04-22**

- Removed the last production `AppContainer.shared` read from `AsyncImageDisk`; `ImageServiceProtocol` and `LoggingServiceProtocol` are now injected through SwiftUI environment values at the ready app root.
- `AppContainer.handleSceneBecameActive()` now starts auth and subscription refresh concurrently.
- `DBInterface.init(inMemory: false)` now delegates to the normal on-disk initializer instead of silently creating an in-memory database.
- `AppContainer.init()` is explicitly internal and documented as singleton lifecycle construction.
- `DefaultImageStore.thumbnail(for:size:)` now generates bounded thumbnail data when the stored payload is an image.
- `CSVDecoder` logs skipped malformed rows through `LoggingService` with `LogCategory.csvParser`.
- The DEBUG-only `RecipeService` convenience initializer remains gated behind `#if DEBUG`.
- `AppContainerLifecycleTests` now uses `AppContainer.makeInMemory()` instead of `UITestConfiguration`.
- `CSVZipAdapter.importAll` checks cancellation before emitting initial `0` progress.
- Verification: generic iOS Simulator build passed; `UnitTests` passed on `iPhone 16,OS=18.5` with 303 selected tests and 0 failures. The unpinned `iPhone 16` unit-test command still fails on this machine because Xcode resolves it to `OS:latest`, while only iOS 18.5 exists for that simulator name.

---

### [P0-1] Replace `try!` force-tries in DBInterface init

**Status:** ✅ Completed — 2026-04-22. `DBInterface` initialization is now throwing, schema setup errors propagate, `AppContainer` construction is throwing, and `CookSavvyApp` renders an explicit blocking startup failure state instead of falling back to in-memory storage. Added coverage for invalid database paths and startup lifecycle behavior. Verified with the Phase 0 completion commands above.

**Severity:** 🔴 Critical — app crash on any init failure  
**Files:** `CookSavvy/Services/Database/DBInterface.swift` lines 63, 68, 74, 76  
**Parallel:** Yes

**Problem:**  
Four `try!` calls during database initialization (schema creation, development schema setup, FTS setup). Any failure — disk full, permission error, SQLite corruption — crashes the app with no error surface.

**Target state:**  
Each `try!` becomes `try`. Database-open/schema failures propagate through app startup before services are constructed. Data-import failures still surface through `DatabaseInitializationService.state = .failed(...)`.

**Implementation steps:**

1. Change `DBInterface.init` and `DBInterface.init(inMemory:)` to `throws`. Do not silently fall back to an in-memory database in normal app runtime; that hides persistence failures and can lose local state. Keep in-memory creation only for tests/UI-test bootstrapping.
2. Replace each `try!` with `try`. The expression stays the same; only the `!` is removed.
3. Let `AppContainer` construction handle the thrown error through an explicit startup state. Because `AppContainer` currently has a private non-throwing singleton init, either make the composition-root initializer throwing or add a small `AppStartupState` wrapper in `CookSavvyApp` that can hold `.failed(Error)` before the main coordinator is built.
4. In `DatabaseInitializationService`, keep data-import failures in `state = .failed(...)`, but do not use it as the first place to discover that the database could not be opened. Database-open/schema failures happen before services can safely exist.
5. In `CookSavvyApp` / `AppCoordinator`, handle startup failure by showing a blocking error surface (e.g., "Database could not be opened. Please restart the app or contact support.") instead of continuing with a half-initialized container.
6. Update `CookSavvyTests/CookSavvyTests.swift` (DBInterface integration tests) to verify that a bad path or corrupted state produces a recoverable error, not a crash.

---

### [P0-2] Fix data race on `recipeCache`

**Status:** ✅ Completed — 2026-04-22. `DBInterface` now guards all `recipeCache` reads, writes, evictions, and clears behind a private serial cache queue without holding it during GRDB work. Added concurrent in-memory cache access coverage. Verified with the Phase 0 completion commands above.

**Severity:** 🔴 Critical — data corruption under concurrent reads/writes  
**Files:** `CookSavvy/Services/Database/DBInterface.swift` lines 31, 341–408, 882  
**Parallel:** Yes

**Problem:**  
`recipeCache` is a plain `[String: Recipe]` dictionary mutated from multiple call sites with no synchronisation. Concurrent reads and writes produce undefined behaviour under Swift's strict concurrency.

**Target state:**  
The cache is accessed only from a single serialised context. The simplest correct fix is to gate all cache reads/writes behind a dedicated serial `DispatchQueue` or, preferably, to make `DBInterface` a Swift actor (see P2-1, which does this more thoroughly). For an immediate standalone fix use a serial queue.

**Implementation steps:**

1. Add a private serial queue at the top of `DBInterface`:
   ```swift
   private let cacheQueue = DispatchQueue(label: "com.cooksavvy.dbinterface.cache")
   ```
2. Wrap every read of `recipeCache` (lines ~341–408) as:
   ```swift
   cacheQueue.sync { recipeCache[key] }
   ```
3. Wrap every write to `recipeCache` (including evictions at line ~882) as:
   ```swift
   cacheQueue.sync { recipeCache[key] = value }
   ```
4. For `compactMap`/`forEach` cache sweeps, wrap the entire loop in `cacheQueue.sync`. Do not hold the cache queue while performing GRDB reads/writes; cache only the in-memory dictionary operation.
5. If a concurrent queue is chosen instead of a serial queue, then use `queue.sync(flags: .barrier)` for writes. Do not mix a serial queue with barrier flags; the barrier flag has no useful effect there.
6. Build and run the unit tests. Enable Thread Sanitizer in the test scheme (`Product → Scheme → Edit Scheme → Diagnostics → Thread Sanitizer`) and run `CookSavvyTests` to confirm no data-race warnings.

> **Note:** P2-1 (making `DBInterface` an actor) will eventually supersede this fix. The queue is a safe bridge until that refactor is done.

---

### [P0-3] Fix `CSVParser` force-casts

**Status:** ✅ Completed — 2026-04-22. `CSVParser` no longer force-casts Foundation generic decoding paths, malformed row decoding is skipped with parser logging, and malformed headers/empty files still throw. Added CSV tests for malformed rows plus `Date`, `Data`, and `URL` decoding failures. Verified with the Phase 0 completion commands above.

**Severity:** 🔴 Critical — parsing crash on type mismatch  
**Files:** `CookSavvy/DataImport/CSVParser.swift` lines 241, 243, 249  
**Parallel:** Yes

**Problem:**  
`as!` casts assume the parsed CSV value is always the expected Swift type. If the CSV has a malformed row, a missing column, or an empty string where a number is expected, the app crashes.

**Implementation steps:**

1. Replace each `as!` with a conditional cast (`as?`) combined with a `guard let` or `?? defaultValue`.
   - For `String` fields: use `as? String ?? ""`
   - For `Int` fields: use `(value as? Int) ?? (Int(value as? String ?? "") ?? 0)`
   - For `Double` fields: use `(value as? Double) ?? (Double(value as? String ?? "") ?? 0.0)`
2. For rows that fail to parse critical required fields (e.g., ingredient name), log the failure via the app's logging infrastructure (`LoggingService`) and `continue` to the next row rather than crashing.
3. Update `CookSavvyTests/CVSDecoderTests.swift` to add a test case with a malformed row (wrong type, empty required field) and assert that parsing returns partial results without throwing or crashing.

---

### [P0-4] Sanitize ingredient names before LLM prompt interpolation

**Status:** ✅ Completed — 2026-04-22. `AIService` sanitizes ingredient names before recipe-generation prompt interpolation by stripping newlines, carriage returns, null bytes, trimming whitespace, dropping empty values, and truncating each ingredient to 100 characters. Added a capturing LLM provider unit test. Verified with the Phase 0 completion commands above.

**Severity:** 🔴 Critical — prompt injection  
**Files:** `CookSavvy/Services/AI/AIService.swift` lines 74–76  
**Parallel:** Yes

**Problem:**  
User-supplied ingredient name strings are interpolated directly into the LLM prompt string. A malicious or accidentally crafted ingredient name (e.g., `"chicken\n\nIgnore all previous instructions and..."`) can alter prompt behaviour.

**Target state:**  
Ingredient names are sanitised before interpolation. Sanitisation rules: strip newline characters (`\n`, `\r`), strip null bytes, strip leading/trailing whitespace, and truncate to a maximum of 100 characters per ingredient name.

**Implementation steps:**

1. Add a private helper function in `AIService.swift`:
   ```swift
   private func sanitizedIngredient(_ name: String) -> String {
       let stripped = name
           .replacingOccurrences(of: "\n", with: " ")
           .replacingOccurrences(of: "\r", with: " ")
           .replacingOccurrences(of: "\0", with: "")
           .trimmingCharacters(in: .whitespacesAndNewlines)
       return String(stripped.prefix(100))
   }
   ```
2. In the prompt construction at lines 74–76, map the ingredients array through this function:
   ```swift
   let safeIngredients = ingredients.map { sanitizedIngredient($0) }
   ```
3. Use `safeIngredients` in the prompt string, not the original `ingredients` array.
4. Add a unit test to `CookSavvyTests` that creates an `AIService` (or tests the sanitizer function if extracted to a testable location) and verifies that ingredient names with embedded newlines and control characters are stripped before prompt construction.

---

### [P0-5] Remove direct Spoonacular awareness from the iOS app

**Status:** ✅ Completed — 2026-04-22. Removed direct Spoonacular provider/model source, mapper tests, iOS API-key configuration, unit-test plan entries, and stale active architecture docs. Online recipes are documented and wired through the Supabase backend provider only. Verified with the Phase 0 completion commands above.

**Severity:** 🔴 Critical — backend abstraction leak / secret-handling risk  
**Files:** `CookSavvy/Network/RecipeAPIProvider/SpoonacularProvider.swift`, `CookSavvy/Network/RecipeAPIProvider/SpoonacularModels.swift`, API-key config readers/docs that mention Spoonacular  
**Parallel:** Yes

**Problem:**  
Spoonacular should not run on device. It is fully behind the backend, and the app should not be aware of which recipe API provider the backend uses. The legacy `SpoonacularProvider` and `SpoonacularModels` make the app compile direct-provider code and preserve API-specific concepts that belong on the server.

**Target state:**  
The iOS app talks only to the app backend abstraction (`SupabaseRecipeAPIProvider` / edge functions) for online recipes. No iOS runtime path, model, tests, API-key configuration, or docs should require knowledge of Spoonacular.

**Implementation steps:**

1. Delete `SpoonacularProvider.swift` and `SpoonacularModels.swift` from the iOS target.
2. Delete direct-provider tests such as `SpoonacularMapperTests.swift` unless they are moved to the backend repository.
3. Remove `SPOONACULAR_API_KEY` from iOS API-key config readers, sample docs, and HLD/agent docs. Backend secret configuration belongs in backend docs only.
4. Ensure `OnlineRecipeSource` can only be constructed with the backend provider abstraction (`RecipeAPIProviderProtocol` implemented by `SupabaseRecipeAPIProvider` in app runtime).
5. Keep iOS tests focused on `SupabaseRecipeAPIProvider` DTO mapping and `OnlineRecipeSource` behavior, not third-party provider DTOs.
6. Confirm a code search for `Spoonacular` in the iOS project returns no app-source references after removal. Mentions may remain only in historical audit docs if clearly marked obsolete.

---

### [P0-6] Refresh subscription status when app returns to foreground

**Status:** ✅ Completed — 2026-04-22. Added `AppContainer.handleSceneBecameActive()` and wired ready app startup plus active scene transitions to start auth if needed and refresh subscription status. `MockSubscriptionService` tracks refresh calls for focused unit coverage. Verified with the Phase 0 completion commands above.

**Severity:** 🔴 Critical — cancelled subscriptions not reflected until restart  
**Files:** `CookSavvy/Services/Subscription/StoreKitSubscriptionService.swift`, `CookSavvy/App/CookSavvyApp.swift`  
**Parallel:** Yes

**Problem:**  
`StoreKitSubscriptionService` only checks entitlements at launch and during explicit `listenForTransactions()`. If a user cancels a subscription on another device, the app continues showing premium features indefinitely until the next cold launch.

**Implementation steps:**

1. In `CookSavvyApp.swift`, observe `scenePhase` using `@Environment(\.scenePhase)`:
   ```swift
   @Environment(\.scenePhase) private var scenePhase
   ```
2. Add a `.onChange(of: scenePhase)` modifier on the root view body:
   ```swift
   .onChange(of: scenePhase) { _, newPhase in
       if newPhase == .active {
           Task { await container.subscriptionService.refreshSubscriptionStatus() }
       }
   }
   ```
3. Ensure `SubscriptionServiceProtocol` declares `refreshSubscriptionStatus() async`. The method already exists in `StoreKitSubscriptionService`; verify it is on the protocol.
4. `MockSubscriptionService` should implement `refreshSubscriptionStatus()` as a no-op (it already controls the plan through its initialiser).
5. Add a focused test seam for foreground refresh. `scenePhase` itself is hard to unit-test directly, so expose a root/app-coordinator method such as `handleSceneBecameActive()` or use a mock subscription service with `refreshCallCount`, then verify the active-scene path calls `refreshSubscriptionStatus()`.
6. For `StoreKitSubscriptionService`, add tests around `currentPlanPublisher` updates separately from the scene-phase test.

---

### [P0-7] Uncomment and fix DatasetImportingTests

**Status:** ✅ Completed — 2026-04-22. Replaced the disabled dataset-import tests with compiling in-memory/temp-directory coverage, and implemented minimal ZIP detection, archive validation, progress/cancellation, image-store content-hash dedupe, thumbnail reads, and coordinator delegation. Verified with the Phase 0 completion commands above.

**Severity:** 🔴 Critical — data import is entirely untested  
**Files:** `CookSavvyTests/DatasetImportingTests.swift`  
**Parallel:** Yes

**Problem:**  
11 tests are commented out, meaning the data import path (CSV parsing, ZIP extraction, DB insertion) has zero automated test coverage.

**Implementation steps:**

1. Uncomment all disabled tests in `DatasetImportingTests.swift`.
2. For each test that fails to compile, fix the API mismatch — the service interfaces have likely changed since the tests were written.
3. For each test that fails at runtime, investigate and fix the root cause in the test setup (not by re-commenting the test).
4. Ensure the tests use an in-memory `DBInterface` (via `DBTestHelpers`) and do not touch the real app database.
5. After P0-3 (CSVParser force-casts fixed), run the tests again to confirm they exercise the safe parsing path.

---

## Phase 1 — High: Core Architecture Refactors

These are the three highest-leverage architectural changes. **Do P1-3 before P1-1** so the repository split is built around stable recipe identity instead of preserving the current title-derived ID problem. P1-2 can run in parallel with P1-3 if ownership is kept separate.

---

### [P1-1] Decompose `DBInterface` into domain repositories

**Severity:** 🟡 High — god object, violates SRP, oversized protocol surface  
**Files:** `CookSavvy/Services/Database/DBInterface.swift` (1151 lines), `CookSavvy/Services/Database/DBInterfaceProtocol.swift`  
**Depends on:** P0-1 (safe init), P0-2 (safe cache), P1-3 (stable recipe identity) — complete those first  
**Parallel with:** P1-2

**Problem:**  
`DBInterface` is a 1151-line class covering 9 distinct domains through a single broad protocol. Every service that touches any data must depend on the entire protocol, making mocks heavy, refactors risky, and data ownership unclear.

Current domain responsibilities in `DBInterface`:
- Schema management & destructive development resets
- Ingredient queries (search, all, by category, recent)
- Recipe CRUD (insert, fetch, FTS search, cache)
- Favorites (add, remove, check, fetch)
- Recent items (recipes, ingredients, searches)
- Cooking sessions (insert, fetch, stats)
- Shopping list (insert, fetch, update, delete)
- Database management (vacuum, reset)

**Target architecture:**

```
DatabaseWriter (shared GRDB DatabasePool/DatabaseQueue, owned by AppContainer)
     │
     ├─▶ RecipeRepository : RecipeRepositoryProtocol
     ├─▶ IngredientRepository : IngredientRepositoryProtocol
     ├─▶ UserHistoryRepository : UserHistoryRepositoryProtocol
     ├─▶ CookingSessionRepository : CookingSessionRepositoryProtocol
     └─▶ ShoppingListRepository : ShoppingListRepositoryProtocol

Each repository takes `DatabaseWriter` in its init.
Each service depends on only the repository protocol it needs.
```

Use GRDB's `DatabaseWriter` protocol as the constructor dependency instead of hard-coding `DatabaseQueue`. The production app currently uses `DatabasePool`; tests can still use `DatabaseQueue`.

**Implementation steps — Part A: New protocol files**

Create five new protocol files in `CookSavvy/Services/Database/Repositories/`:

1. **`RecipeRepositoryProtocol.swift`**
   ```swift
   protocol RecipeRepositoryProtocol: AnyObject {
       func fetchRecipes(matchingIngredients: [String]) throws -> [Recipe]
       func fetchRecipe(byId id: Int) throws -> Recipe?
       func fetchRecipe(byTitle title: String) throws -> Recipe?
       func searchRecipes(query: String) throws -> [Recipe]
       func insertRecipes(_ recipes: [Recipe]) throws
       func upsertRecipes(_ recipes: [Recipe]) throws         // NEW — online/AI dedup
       func fetchUserRecipes() throws -> [Recipe]
       func insertUserRecipe(_ recipe: Recipe) throws
       func deleteUserRecipe(id: Int) throws
   }
   ```

2. **`IngredientRepositoryProtocol.swift`**
   ```swift
   protocol IngredientRepositoryProtocol: AnyObject {
       func fetchAllIngredients() throws -> [Ingredient]
       func fetchIngredients(byCategory category: String) throws -> [Ingredient]
       func searchIngredients(query: String) throws -> [Ingredient]
       func fetchIngredient(byName name: String) throws -> Ingredient?
       func insertIngredients(_ ingredients: [Ingredient]) throws
   }
   ```

3. **`UserHistoryRepositoryProtocol.swift`**
   ```swift
   protocol UserHistoryRepositoryProtocol: AnyObject {
       // Favorites
       func addFavorite(recipeId: Int) throws
       func removeFavorite(recipeId: Int) throws
       func isFavorite(recipeId: Int) throws -> Bool
       func fetchFavoriteRecipes() throws -> [Recipe]
       // Recents
       func addRecentRecipe(recipeId: Int) throws
       func fetchRecentRecipes(limit: Int) throws -> [Recipe]
       func addRecentIngredient(name: String) throws
       func fetchRecentIngredients(limit: Int) throws -> [String]
       func addRecentSearch(ingredientNames: [String]) throws
       func fetchRecentSearches(limit: Int) throws -> [[String]]
       // Stats
       func fetchUniqueIngredientCount() throws -> Int
   }
   ```

4. **`CookingSessionRepositoryProtocol.swift`**
   ```swift
   protocol CookingSessionRepositoryProtocol: AnyObject {
       func insertSession(_ session: CookingSession) throws
       func fetchSessions(limit: Int?) throws -> [CookingSession]
       func fetchSessionCount() throws -> Int
       func fetchTotalDurationSeconds() throws -> Int
       func fetchMonthlySessionCount() throws -> Int
       func fetchMonthlyRescuedIngredientCount() throws -> Int
       func fetchWeekCookingDates() throws -> [Date]
   }
   ```

5. **`ShoppingListRepositoryProtocol.swift`**
   ```swift
   protocol ShoppingListRepositoryProtocol: AnyObject {
       func fetchItems() throws -> [ShoppingItem]
       func insertItem(_ item: ShoppingItem) throws
       func updateItem(_ item: ShoppingItem) throws
       func deleteItem(id: Int) throws
       func deleteCheckedItems() throws
   }
   ```

**Implementation steps — Part B: Concrete repository classes**

Create five concrete classes in `CookSavvy/Services/Database/Repositories/`. Each class receives a `DatabaseWriter` through its initialiser and extracts its relevant methods from the current `DBInterface`.

Example structure for `RecipeRepository`:
```swift
final class RecipeRepository: RecipeRepositoryProtocol {
    private let db: DatabaseWriter

    init(db: DatabaseWriter) {
        self.db = db
    }

    func fetchRecipes(matchingIngredients: [String]) throws -> [Recipe] {
        // Move the SQL from DBInterface.fetchRecipes(matchingIngredients:) here
    }
    // ... remaining methods
}
```

Move the recipe in-memory cache (`recipeCache` dictionary + the cache queue added in P0-2) into `RecipeRepository` instead of `DBInterface`. The cache is only relevant to recipe reads, not ingredient or session queries.

**Implementation steps — Part C: Update AppContainer**

1. In `AppContainer.swift`, create a single shared `DatabaseWriter` instance:
   ```swift
   private let sharedDatabaseWriter: DatabaseWriter = /* existing DBInterface writer init logic */
   ```
2. Instantiate each repository:
   ```swift
   let recipeRepository: RecipeRepositoryProtocol = RecipeRepository(db: sharedDatabaseWriter)
   let ingredientRepository: IngredientRepositoryProtocol = IngredientRepository(db: sharedDatabaseWriter)
   // ... etc.
   ```
3. Pass narrower repositories to each service instead of the full `DBInterface`:
   - `RecipeService` → receives `RecipeRepositoryProtocol`
   - `IngredientsService` → receives `IngredientRepositoryProtocol`
   - `UserDataService` → receives `UserHistoryRepositoryProtocol` + `CookingSessionRepositoryProtocol`
   - `ShoppingListService` → receives `ShoppingListRepositoryProtocol`
   - `DatabaseInitializationService` → receives `DatabaseWriter` directly (it owns schema creation)

**Implementation steps — Part D: Update service constructors**

Update `RecipeService`, `IngredientsService`, `UserDataService`, `ShoppingListService` to accept their narrowed repository protocol type instead of `DBInterfaceProtocol`. Remove any `import` or dependency on `DBInterface` from services that no longer need it.

**Implementation steps — Part E: Update `SettingsViewModel`**

`SettingsViewModel` currently takes `DBInterface` directly for stat counts. Give it `UserHistoryRepositoryProtocol` and `CookingSessionRepositoryProtocol` (or create a thin `StatsRepositoryProtocol` that returns the counts it needs).

**Implementation steps — Part F: Mocks**

1. Update `CookSavvyTests/Mocks/MockServices.swift` to provide mock implementations of each new repository protocol.
2. Remove `MockDBInterface` (or its equivalent) if it existed for the full protocol.
3. Update all test files that inject `DBInterfaceProtocol` to inject the correct narrow mock instead.

**Implementation steps — Part G: Retire old `DBInterfaceProtocol`**

Once all services are updated:
1. Remove the broad `DBInterfaceProtocol`.
2. Keep the `DBInterface` class only as an internal implementation detail of `DatabaseInitializationService` (schema creation / destructive development reset). It no longer needs to be a protocol.
3. Or delete `DBInterface.swift` entirely and replace with the repository implementations.

**Tests to verify:**
- `CookSavvyTests/CookSavvyTests.swift` (integration tests) — update to use repositories
- `CookSavvyTests/RecipeServiceTests.swift`
- `CookSavvyTests/IngredientsServiceTests.swift`
- `CookSavvyTests/UserDataServiceTests.swift`
- `CookSavvyTests/ShoppingListServiceTests.swift`

---

### [P1-2] Remove `AppContainer.shared` from views and coordinators

**Status:** Partially completed — 2026-04-22. Current app source no longer reads `AppContainer.shared` from views or coordinators. `AsyncImageDisk` receives image/logging services through SwiftUI environment values, `AppCoordinator` owns the injected container, and `TabContainerView` is navigation-only. The singleton is still assigned inside `AppContainer` startup/factory code and should be deprecated or deleted in a later cleanup.

**Severity:** 🟡 High — breaks DI, hidden dependencies, blocks test isolation  
**Files:** `CookSavvy/Views/Shared/TabContainerView.swift:13`, `CookSavvy/Views/Shared/AsyncImageDisk.swift:85`, `CookSavvy/Coordinators/AppCoordinator.swift:45–47`, `CookSavvy/App/CookSavvyApp.swift:55,60`  
**Parallel with:** P1-3

**Problem:**  
Three locations bypass the coordinator/container DI contract by pulling `AppContainer.shared` directly:
- `TabContainerView` (a SwiftUI view) reads the singleton to get services
- `AsyncImageDisk` reads the singleton to get `ImageService` and `LoggingService`
- `AppCoordinator.makeOnboardingViewModel()` reads the singleton

This creates hidden dependencies and makes views untestable in isolation.

**Target state:**  
`AppContainer` is created once at the app root (`CookSavvyApp`) and passed through the coordinator chain. Views receive only what they need through their view model or Environment. The `AppContainer.shared` accessor is never called outside of `CookSavvyApp`.

**Implementation steps:**

**Step 1 — `CookSavvyApp` is the sole owner**

In `CookSavvyApp.swift`:
```swift
@main
struct CookSavvyApp: App {
    @StateObject private var appCoordinator: AppCoordinator

    init() {
        let container = try AppContainer()
        _appCoordinator = StateObject(wrappedValue: AppCoordinator(container: container))
    }
    // ...
}
```

The real implementation needs an app-startup wrapper because `App.init` cannot throw directly. Store either `.ready(AppContainer)` or `.failed(Error)` in root state and render the blocking startup error surface from P0-1 when construction fails.

Make `AppContainer.init` internal (or otherwise available to the app composition root). It is currently private because the singleton owns construction.

**Step 2 — `AppCoordinator` receives `AppContainer` through init**

```swift
final class AppCoordinator: ObservableObject {
    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
    }
}
```

All calls to `AppContainer.shared` inside `AppCoordinator` become `container`. Each child coordinator factory method passes only what the coordinator needs:
```swift
func makeDiscoverCoordinator() -> DiscoverCoordinator {
    DiscoverCoordinator(
        recipeService: container.recipeService,
        ingredientsService: container.ingredientsService,
        // ... other services this coordinator uses
    )
}
```

**Step 3 — Fix `TabContainerView`**

`TabContainerView` should not access services at all; it is pure navigation scaffolding. Replace any service access with explicit init parameters or remove the access if it was only for analytics/logging that can be moved to the coordinator.

If `TabContainerView` genuinely needs a service (e.g., `AppCoordinator` reference for tab switching), pass it through the view's init:
```swift
struct TabContainerView: View {
    @ObservedObject var coordinator: AppCoordinator
    // No AppContainer.shared anywhere in this file
}
```

**Step 4 — Fix `AsyncImageDisk`**

`AsyncImageDisk` is a shared view used across many screens. Instead of pulling `AppContainer.shared`, it should receive the services it needs through an `@Environment` value or init parameters.

Option A (Environment — preferred for a widely-used view):
```swift
// In AppTheme.swift or a new file:
struct ImageServiceKey: EnvironmentKey {
    static let defaultValue: ImageServiceProtocol = NoOpImageService()
}
extension EnvironmentValues {
    var imageService: ImageServiceProtocol { ... }
}
```
Inject at the root in `CookSavvyApp` or `TabContainerView`:
```swift
.environment(\.imageService, container.imageService)
```
In `AsyncImageDisk`:
```swift
@Environment(\.imageService) private var imageService
```

Option B (init parameter — simpler for now):
```swift
struct AsyncImageDisk: View {
    let imageService: ImageServiceProtocol
    // ...
}
```
Pass it at every call site. Since all call sites are within views that already have their view model (which came from a coordinator that has the service), this is straightforward.

**Step 5 — Fix `AppCoordinator.makeOnboardingViewModel()`**

The coordinator already has `container` from Step 2. Replace:
```swift
// Before:
let vm = OnboardingViewModel(service: AppContainer.shared.ingredientDetectionService, ...)
// After:
let vm = OnboardingViewModel(service: container.ingredientDetectionService, ...)
```

**Step 6 — Add `@available(*, deprecated)` to `AppContainer.shared`**

After fixing production usages, replace DEBUG UI-test bootstrapping before removing or deprecating the singleton. `configureForUITesting(_:)` currently assigns `AppContainer.shared = container`, so deprecating `shared` too early will leave a noisy but still-required test path.

Preferred UI-test-safe target:
- Parse `UITestConfiguration` before container creation in `CookSavvyApp`.
- Build the appropriate container through a factory, e.g. `AppContainer.makeForUITesting(config:)`.
- Pass that container to `AppCoordinator`.

Once both production and UI-test paths receive the container explicitly, mark `shared` as deprecated or delete it:
```swift
@available(*, deprecated, message: "Inject dependencies through coordinators instead of accessing the shared singleton.")
static let shared = AppContainer()
```

Eventually, when no code references it, remove `shared` entirely.

**Tests to verify:**
- Build succeeds with no warnings about `AppContainer.shared`
- `CookSavvyTests/DiscoverViewModelTests.swift` — ensure mocks are injected, not pulled from container
- `CookSavvyTests/JourneyViewModelTests.swift`

---

### [P1-3] Redesign `Recipe` identity — replace title-derived ID with stable UUID

**Severity:** 🔴/🟡 Critical/High — data integrity; favorites/history can attach to wrong rows  
**Files:** `CookSavvy/Models/Recipe.swift:193`, `CookSavvy/Services/Database/DBInterface.swift:119,390,432,944`  
**Parallel with:** P1-2. Do before P1-1.

**Problem:**  
`Recipe.id` is computed from `title` (likely a hash or the title string itself). Two recipes with the same title hash as identical. Online and AI recipe inserts use plain `INSERT` with no dedup/upsert, creating duplicate rows. The cache, favorites, recents, and cooking history all resolve recipes through title matching, which is ambiguous.

Because the app has no production users, a clean schema reset is the right fix — no migration needed.

**Target state:**  
`Recipe` has a stable `UUID` identifier. The database `recipes` table has a `uuid TEXT NOT NULL UNIQUE` column. Online/AI recipes are upserted by `(uuid OR source_identifier)`. The in-memory cache keys by UUID. Favorites, recents, and cooking sessions reference `recipe_uuid` (or keep the integer `id` as the DB row key but ensure uniqueness via the uuid column).

**Implementation steps:**

**Step 1 — Update the `Recipe` model**

In `Recipe.swift`:
```swift
struct Recipe: Identifiable, Hashable {
    let uuid: UUID          // stable domain identity
    let dbId: Int?          // database row integer ID (nil before persistence)
    let title: String
    let sourceIdentifier: String? // backend/external provider ID if supplied by the backend
    // ... rest of existing fields unchanged
}

// Identifiable conformance uses uuid, not title
var id: UUID { uuid }
```

Remove the computed `id: String` that was `title`.

Use initializer defaults during the refactor so fixtures and source mappers can be updated incrementally:
```swift
init(
    uuid: UUID = UUID(),
    dbId: Int? = nil,
    title: String,
    // existing parameters...
    sourceIdentifier: String? = nil
)
```

Do not add whole-`Recipe` `Codable` conformance unless a caller needs it. The current model is `Hashable`/`Sendable` with nested codable payloads, and the database layer already serializes selected fields.

**Step 2 — Update the database schema**

Since there are no users, perform a destructive schema reset:

1. In `DatabaseInitializationService` or the repository's schema creation, drop and recreate the `recipes` table with a `uuid TEXT NOT NULL` column:
   ```sql
   CREATE TABLE IF NOT EXISTS recipes (
       id INTEGER PRIMARY KEY AUTOINCREMENT,
       uuid TEXT NOT NULL UNIQUE,
       title TEXT NOT NULL,
       source_identifier TEXT,    -- external API ID
       source TEXT NOT NULL,
       image TEXT,
       instructions_json TEXT,
       ingredients_json TEXT,
       cleaned_ingredients_json TEXT,
       additional_info_json TEXT,
       tagline TEXT,
       user_rating REAL DEFAULT 0,
       api_rating REAL DEFAULT 0,
       author TEXT,
       is_user_created INTEGER DEFAULT 0,
       emoji TEXT,
       cuisine TEXT
   )
   ```
2. Update `recipe_ingredients`, `favorite_recipes`, `recent_recipes`, `cooking_sessions` to use integer `recipe_id` (the DB primary key). No FK type change needed — they already use integer IDs.
3. Add uniqueness for stable identity and external-provider deduplication:
   ```sql
   CREATE UNIQUE INDEX IF NOT EXISTS idx_recipes_uuid ON recipes(uuid)
   CREATE UNIQUE INDEX IF NOT EXISTS idx_recipes_source_identifier
       ON recipes(source, source_identifier)
       WHERE source_identifier IS NOT NULL;
   ```

**Step 3 — Implement upsert in `RecipeRepository` (from P1-1)**

In `insertRecipes` (or a new `upsertRecipes`), use SQLite `ON CONFLICT DO UPDATE` keyed on `uuid`:
```sql
INSERT INTO recipes (uuid, title, source_identifier, source, ...)
VALUES (?, ?, ?, ?, ...)
ON CONFLICT(uuid) DO UPDATE SET
    title = excluded.title,
    source_identifier = excluded.source_identifier,
    source = excluded.source,
    image = excluded.image,
    instructions_json = excluded.instructions_json,
    ingredients_json = excluded.ingredients_json,
    cleaned_ingredients_json = excluded.cleaned_ingredients_json,
    additional_info_json = excluded.additional_info_json,
    tagline = excluded.tagline,
    user_rating = excluded.user_rating,
    api_rating = excluded.api_rating,
    author = excluded.author,
    is_user_created = excluded.is_user_created,
    emoji = excluded.emoji,
    cuisine = excluded.cuisine;
```

Do **not** use `INSERT OR REPLACE` for recipes. In SQLite, replace is implemented as delete + insert, which can change row IDs and cascade-delete favorites, recents, recipe ingredients, or cooking sessions.

For offline (CSV-imported) recipes: generate a deterministic UUID v5 from the title at import time so re-imports are idempotent.
For online/AI recipes: use the external `sourceIdentifier` to generate a deterministic UUID, or use the UUID returned by the API.

Swift Foundation does not provide UUID v5. Add a small deterministic UUID helper (for example SHA-256 of `namespace + source + sourceIdentifier/title`, truncated into UUID bytes with RFC 4122 version/variant bits set) and unit-test it for stability.

**Step 4 — Update `RecipeService` dedup logic**

The `merge + deduplicate` step in `RecipeService` (which merges offline, online, AI results) currently deduplicates by title. Change it to deduplicate by `uuid` or `sourceIdentifier`:
```swift
var seen = Set<UUID>()
let deduped = allResults.filter { recipe in
    seen.insert(recipe.uuid).inserted
}
```

**Step 5 — Update the recipe in-memory cache**

Change cache key from `String` (title) to `UUID`:
```swift
private var recipeCache: [UUID: Recipe] = [:]
```

**Step 6 — Update all call sites that use `recipe.id` as a `String`**

Search for `recipe.id` in the codebase:
- `UITestDataSeeder.swift:74,201` — uses title uniqueness; update to UUID matching
- `RecipeDetailsViewModel` — if it compares recipes by ID
- `DiscoverViewModel` — if it deduplicates by ID
- Any `Hashable` or `Equatable` conformance using `id`

**Step 7 — Update mock/test data**

In `CookSavvyTests`, update fixture `Recipe` objects to include a `uuid` field.
In `UITestDataSeeder`, use deterministic UUID generation based on title (e.g., UUID v5 / UUID(uuidString:) with a fixed namespace + title hash).

**Tests to verify:**
- `CookSavvyTests/RecipeServiceTests.swift` — dedup behaviour
- `CookSavvyTests/RecipeModelTests.swift` — identity, Hashable, Equatable
- `CookSavvyTests/OfflineRecipeSourceTests.swift`
- `CookSavvyTests/OnlineAndAIRecipeSourceTests.swift`

---

## Phase 2 — Concurrency Hardening

These items can be done in parallel after Phase 1 is complete.

---

### [P2-1] Add actor isolation to `DBInterface` / repositories

**Severity:** 🟠 Medium-High — Swift 6 incompatibility, thread safety  
**Files:** `CookSavvy/Services/Database/DBInterface.swift:13` and the new repository files from P1-1  
**Depends on:** P1-1

**Problem:**  
`DBInterface` (and the new repositories) are classes with no actor annotation. GRDB's `DatabaseQueue` is thread-safe internally, but the Swift wrapper classes mutate state (cache, properties) without isolation.

**Implementation steps:**

1. Do not mark database repositories `@MainActor`; DB I/O and JSON decoding should not be isolated to the UI actor. Prefer actors or a clearly-owned serial database execution boundary:
   ```swift
   actor RecipeRepository: RecipeRepositoryProtocol {
       // All methods become async implicitly
   }
   ```
2. Update the repository protocols to use `async throws` for all methods:
   ```swift
   protocol RecipeRepositoryProtocol {
       func fetchRecipes(matchingIngredients: [String]) async throws -> [Recipe]
       // ...
   }
   ```
3. Update all call sites in services to use `try await`.
4. If GRDB's `DatabaseWriter` triggers `Sendable` warnings inside actors, keep the writer private to the repository actor and avoid passing it across actor boundaries after initialization. If needed, add a small `DatabaseContext` wrapper with a documented concurrency contract instead of sprinkling `@unchecked Sendable` across repositories.
5. In `DBInterfaceProtocol` (if still present), also convert to `async throws`.
6. Update mocks in `MockServices.swift` to use `async throws` signatures.

> This change cascades through all services and view models. Do it in a single focused PR to avoid merge conflicts. Run full unit tests after.

---

### [P2-2] Fix `SupabaseAuthService` actor isolation warnings

**Severity:** 🟡 High — Swift 6 build blocker  
**Files:** `CookSavvy/Services/Auth/SupabaseAuthService.swift:35,50`  
**Parallel:** Yes (independent)

**Problem:**  
`isAnonymous` reads actor-isolated state (`clientProvider`) from a `nonisolated` computed property. The initializer calls an actor-isolated method synchronously. These are currently warnings that become errors under Swift 6.

**Implementation steps:**

1. Choose one isolation model. The current type is an `actor`; do not also try to make the actor `@MainActor`. Either keep it as an actor or convert it to a `@MainActor final class`.
2. Preferred: keep `SupabaseAuthService` as an `actor`, and stop reading `clientProvider` from `nonisolated isAnonymous`. Cache anonymous state in a nonisolated/thread-safe publisher-backed value when session state is refreshed:
   ```swift
   nonisolated var isAnonymous: Bool { anonymousSubject.value }

   private func updateAuthState(for session: Session) {
       anonymousSubject.send(session.user.isAnonymous)
   }
   ```
3. Remove the synchronous actor-isolated initializer call. Either make the initializer set only nonisolated defaults and require `startSessionIfNeeded()` to refresh state, or add an explicit `initialize() async` that `AppContainer` calls after construction.
4. If converting to `@MainActor final class` instead, update `AuthServiceProtocol`, `MockAuthService`, and every call site consistently. Do not leave a mixed actor/global-actor design.
5. Build and confirm zero actor-isolation warnings in `SupabaseAuthService.swift`.

---

### [P2-3] Add timeout to `ASAuthorizationController` continuation

**Severity:** 🟡 High — sign-in can hang forever  
**Files:** `CookSavvy/Services/Auth/AppleSignInManager.swift:37–48`  
**Parallel:** Yes

**Problem:**  
The `withCheckedThrowingContinuation` wrapping `ASAuthorizationController` has no timeout. If the system auth sheet is dismissed without a result (e.g., interrupted by a phone call), the `async` task blocks indefinitely.

**Implementation steps:**

1. Wrap the sign-in continuation in a `withThrowingTaskGroup` or use `Task.sleep` with a timeout race:
   ```swift
   func signIn() async throws -> ASAuthorization {
       try await withTimeout(seconds: 60) {
           try await withCheckedThrowingContinuation { continuation in
               self.continuation = continuation
               // ... present controller
           }
       }
   }

   private func withTimeout<T>(seconds: Double, operation: () async throws -> T) async throws -> T {
       try await withThrowingTaskGroup(of: T.self) { group in
           group.addTask { try await operation() }
           group.addTask {
               try await Task.sleep(for: .seconds(seconds))
               throw AuthError.timeout
           }
           let result = try await group.next()!
           group.cancelAll()
           return result
       }
   }
   ```
2. Add `timeout` as a case to `AuthError` (or the existing sign-in error enum).
3. In `SignInWithAppleAction`, handle `AuthError.timeout` explicitly to show a user-facing error rather than silently failing.
4. Ensure timeout cleanup resumes and clears the stored continuation exactly once. After the timeout wins, set `continuation = nil` and `currentNonce = nil` on the main actor so a later delegate callback cannot resume an already-completed continuation.

---

### [P2-4] Fix `currentNonce` race condition in `AppleSignInManager`

**Severity:** 🟡 High — race condition if multiple sign-in requests  
**Files:** `CookSavvy/Services/Auth/AppleSignInManager.swift:34–42`  
**Parallel:** Yes (same file as P2-3 — do both together)

**Problem:**  
`currentNonce` is a plain stored instance property. If the user triggers Sign in with Apple twice rapidly (e.g., double-tap), two nonces can be generated and the second will overwrite the first before the first completes.

**Implementation steps:**

1. Add a guard that prevents a second sign-in flow from starting if one is already in progress:
   ```swift
   private var isSigningIn = false

   func signIn() async throws -> ASAuthorization {
       guard !isSigningIn else { throw AuthError.signInAlreadyInProgress }
       isSigningIn = true
       defer { isSigningIn = false }
       // ... existing logic
   }
   ```
2. Since `AppleSignInManager` should be `@MainActor` (it interacts with UI), this guard is safe without additional synchronisation.
3. If not already `@MainActor`, mark it so: `@MainActor final class AppleSignInManager`.
4. Add `signInAlreadyInProgress` to `AuthError` (or map it to an existing user-facing sign-in-in-progress error). The current enum does not contain that case.

---

### [P2-5] Fix `DatabaseInitializationService` busy-wait polling

**Severity:** 🟠 Medium — spins CPU, unclear readiness propagation  
**Files:** `CookSavvy/Services/Database/DatabaseInitializationService.swift:104–119`  
**Parallel:** Yes

**Problem:**  
The service uses a polling loop with `Task.sleep(nanoseconds: 50_000_000)` (50ms intervals) to wait for database readiness. This wastes CPU and is hard to reason about.

**Implementation steps:**

1. Change `initializationState` from a polled flag to an `@Published` property (it may already be; the issue is callers polling rather than observing).
2. Callers that await readiness should use `AsyncStream` or an `async` method that suspends on an internal `AsyncStream.Continuation` or `CheckedContinuation` until state becomes `.ready` or `.failed`:
   ```swift
   func waitUntilReady() async throws {
       for await state in $initializationState.values {
           switch state {
           case .ready: return
           case .failed(let error): throw error
           case .initializing: continue
           }
       }
   }
   ```
3. Update `DiscoverViewModel` and any other callers that polled state to `await service.waitUntilReady()` instead.

---

### [P2-6] Fix retry logic — add exponential backoff

**Severity:** 🟡 High — hammers rate-limited endpoints  
**Files:** `CookSavvy/Network/NetworkConfiguration.swift:20–21`  
**Parallel:** Yes

**Problem:**  
Retry delay is fixed at 1 second for all attempts. Rate-limited backend APIs respond with 429 status; hammering them with retries at 1s intervals worsens the situation.

**Implementation steps:**

1. In `NetworkConfiguration`, replace the fixed delay with an exponential backoff function:
   ```swift
   static func retryDelay(attempt: Int, baseDelaySeconds: Double = 1.0) -> Duration {
       let delay = baseDelaySeconds * pow(2.0, Double(attempt - 1))  // 1s, 2s, 4s...
       let jitter = Double.random(in: 0...0.3) * delay               // ±30% jitter
       return .seconds(min(delay + jitter, 30.0))                    // cap at 30s
   }
   ```
2. Update `NetworkService.retry` logic to call `retryDelay(attempt: currentAttempt)` instead of the fixed constant.
3. Honour `Retry-After` response headers when present (parse the header value and sleep for that duration instead of the computed backoff).
4. Update `CookSavvyTests/NetworkServiceTests.swift` to verify backoff increases between retries.

---

## Phase 3 — Medium: Auth, Data Integrity & UX Fixes

---

### [P3-1] Fix incomplete `signOut()` — clear all user state

**Severity:** 🟡 High — stale data visible after sign-out  
**Files:** `CookSavvy/Services/Auth/SupabaseAuthService.swift:121–129`  
**Parallel:** Yes

**Problem:**  
`signOut()` clears Supabase auth state only. Cached user data, recipe history, favorites, and analytics session identity remain tied to the previous user.

**Implementation steps:**

1. Add a `clearUserData() async` method to `UserDataServiceProtocol` that deletes all user-specific rows (recents, favorites, cooking sessions, shopping items).
2. In `SupabaseAuthService.signOut()`:
   ```swift
   func signOut() async throws {
       try await supabaseClient.auth.signOut()
       await userDataService?.clearUserData()
       await analyticsService?.resetSession()
       // re-sign in anonymously so app has a valid session
       try await signInAnonymously()
   }
   ```
3. Inject `userDataService` and `analyticsService` into `SupabaseAuthService` through its initialiser (or add a weak delegate/callback pattern).
4. Update `CookSavvyTests/SettingsViewModelAuthTests.swift` to verify that after sign-out, the user data mock receives a `clearUserData()` call.

---

### [P3-2] Validate data before Anonymous → Apple Sign-In linking

**Severity:** 🟡 High — anonymous recipes could be lost  
**Files:** `CookSavvy/Services/Auth/SupabaseAuthService.swift:101–119`  
**Parallel:** Yes (same file as P3-1 — do together)

**Problem:**  
When an anonymous user links their Apple ID, the current implementation calls `linkIdentity` without any pre-check or post-validation. Existing anonymous recipes/history could be lost if the Supabase edge function does not migrate them.

Current iOS persistence is mostly local and does not appear to key recipe/history tables by Supabase user ID, so the immediate local-data-loss risk may be lower than the audit wording suggests. The real risk is any server-side state attached to the anonymous Supabase identity, plus future local user-scoped tables. Verify the actual data ownership before implementing a transfer/linking flow.

**Implementation steps:**

1. Before calling `linkIdentity`, snapshot the user's anonymous ID and capture counts of any local data that should survive the link:
   ```swift
   let anonymousId = currentUser?.id
   let recipesBeforeLink = try await cookingSessionRepo.fetchSessionCount()
   ```
2. After successful `linkIdentity`, verify the data is still accessible. If counts differ, log the discrepancy.
3. If `linkIdentity` fails, ensure the anonymous session is fully restored (the user should not end up in a state with no valid session).
4. Document the expected Supabase edge function behaviour for anonymous-to-Apple identity linking in a code comment, and add a TODO if the server-side transfer/linking behavior is not yet implemented.

---

### [P3-3] Fix stale cached subscription plan on launch failure

**Severity:** 🟠 Medium  
**Files:** `CookSavvy/Services/Subscription/StoreKitSubscriptionService.swift:154–163`  

**Problem:**  
If `refreshSubscriptionStatus()` fails on launch (network unavailable), the stale cached `.premium` plan is used indefinitely.

**Implementation steps:**

1. Track the timestamp of the last successful refresh in `UserDefaults`.
2. If the cached plan is `.premium` AND the last successful refresh is older than 24 hours AND the current refresh failed, downgrade the display to `.free` with a banner indicating connectivity is needed to verify premium status.
3. Alternatively (simpler): if refresh fails on foreground, show a non-blocking subtle indicator rather than silently serving stale premium access.
4. Mark `StoreKitSubscriptionService` as `@MainActor` (see P2 notes) so transaction observation runs on a known actor.

---

### [P3-4] Add LLM token limit enforcement

**Severity:** 🟡 High — no quota management  
**Files:** `CookSavvy/Services/AI/AIService.swift:45–47`  
**Parallel:** Yes

**Problem:**  
No per-user or per-session token budget is enforced. Unlimited LLM calls can run up API costs.

**Implementation steps:**

1. Add server-side quota/rate enforcement to the Supabase edge functions that perform LLM work. Client-side `UserDefaults` counters are UX hints only and cannot control API cost.
2. Add a `DailyAIUsageTracker` (or extend `CameraScanTracker`'s pattern) that counts visible LLM calls per day/week using `UserDefaults`, keyed to a date stamp, so the UI can display remaining usage.
3. In `AIService`, check the local tracker before making a call for fast feedback. Treat the server response as authoritative.
4. If the local or server limit is reached, throw `AIServiceError.quotaExceeded` and let the caller surface an appropriate UI message.
5. Expose the remaining quota through `AIServiceProtocol` so `CameraViewModel` can show a usage indicator.

---

### [P3-5] Add AI provider fallback to offline recipes

**Severity:** 🟡 High — hard error with no graceful degradation  
**Files:** `CookSavvy/Services/AI/AIService.swift:28–30`  
**Parallel:** Yes

**Problem:**  
When the AI provider is unavailable (no Supabase keys, network failure), `AIService` throws a hard error. The caller gets no results instead of falling back to offline/online recipes.

**Implementation steps:**

1. In `RecipeService.fetchRecipes(...)`, wrap the `AIRecipeSource.fetch(...)` call in a `do/catch`:
   ```swift
   if let aiResults = try? await aiSource.fetch(ingredients) {
       results.append(contentsOf: aiResults)
   }
   // Offline and online results already collected; AI is additive, not required
   ```
2. Log the error through `LoggingService` at `.info` level (not `.error`, since it is expected in some configurations).
3. Update `CookSavvyTests/OnlineAndAIRecipeSourceTests.swift` to verify that when `AIRecipeSource` throws, `RecipeService` still returns offline/online results.
4. Apply the same source-isolation rule to online recipe failures: online/AI failures should set `hadSourceFailures = true`, but must not discard successful offline results.

---

### [P3-6] Fix Discover full-screen cover dismissal — separate camera vs. cook mode reset

**Severity:** 🟡 High — finishing cook mode clears search results  
**Files:** `CookSavvy/Coordinators/DiscoverCoordinator.swift:231`  
**Parallel:** Yes

**Problem:**  
A single `onDismiss` closure for all full-screen covers resets `navigationPath` and `showResults = false`. This means finishing Cook Mode (which is a full-screen cover) unexpectedly pops the user out of search results.

**Implementation steps:**

1. In `DiscoverCoordinator`, distinguish the reason for cover dismissal by maintaining separate `@Published` flags:
   ```swift
   @Published var isCookModePresented = false
   @Published var isCameraPresented = false
   ```
2. The `.fullScreenCover` for Cook Mode gets an `onDismiss` that does NOT reset navigation or `showResults`:
   ```swift
   .fullScreenCover(isPresented: $coordinator.isCookModePresented) {
       CookModeView(viewModel: coordinator.makeCookModeViewModel())
   }
   ```
3. The camera sheet gets its own `onDismiss` that handles the camera-specific state reset only (no clearing of ingredient selection or recipe results).
4. Remove the shared `onDismiss` that blanket-resets state.
5. Test by: navigating to recipe results → opening recipe detail → starting cook mode → finishing cook → verify results screen is still shown.

---

### [P3-7] Fix Recipe DB readiness check for premium users

**Severity:** 🟡 High — premium users can get incomplete offline results on startup  
**Files:** `CookSavvy/Services/Recipe/RecipeSourceProtocol.swift:49`, `CookSavvy/Views/Discover/DiscoverViewModel.swift:407`, `CookSavvy/Services/Recipe/RecipeService.swift:160`  
**Parallel:** Yes

**Problem:**  
The offline DB readiness wait is skipped when the source set includes online or AI sources (premium path). Offline results can be empty or partial when returned.

**Implementation steps:**

1. Move the database-readiness decision into `RecipeService`, close to source execution. `RecipeSourceType.requiresDatabaseReady(_:)` is currently wrong because it returns `true` only for exactly `[.offline]`; replace it with `sources.contains(.offline)` or remove the helper.
2. If offline is requested, wait for recipe import before querying `OfflineRecipeSource`. Online and AI requests can be launched concurrently while that wait is happening; do not block them unnecessarily on local import.
3. Use a non-throwing task group with per-source error handling instead of a single throwing tuple, so one source failure does not cancel all successful sources:
   ```swift
   await withTaskGroup(of: SourceResult.self) { group in
       if sourceTypes.contains(.offline) {
           group.addTask {
               await dbInitService.waitForRecipes()
               return await fetchSource(.offline)
           }
       }
       if sourceTypes.contains(.online) {
           group.addTask { await fetchSource(.online) }
       }
       if sourceTypes.contains(.ai) {
           group.addTask { await fetchSource(.ai) }
       }
       // Collect successes and mark individual failures without throwing away all results.
   }
   ```
4. This ensures offline results are always complete while online/AI are fetched in parallel.

---

### [P3-8] Fix CSV import — add validation, dedup, and transaction rollback

**Severity:** 🟠 Medium  
**Files:** `CookSavvy/DataImport/DataImportService.swift:77–90`

**Problem:**  
CSV import performs no input validation, no deduplication, and no transactional rollback. A partial import can leave the database in a corrupted state.

**Implementation steps:**

1. Wrap the entire import in a single GRDB write transaction:
   ```swift
   try dbQueue.write { db in
       for recipe in parsedRecipes {
           guard !recipe.title.isEmpty else { continue }  // validation
           try recipe.upsert(db)                          // upsert via P1-3
       }
   }
   ```
2. If the transaction throws, GRDB rolls back automatically — no partial state.
3. Add deduplication: before inserting, check if a recipe with the same `uuid` (or `title + source`) already exists, and skip or update accordingly (upsert handles this if P1-3 is done).
4. Log skipped rows (empty title, invalid data) rather than silently dropping them.

---

### [P3-9] Clean up temporary ZIP extraction files

**Severity:** 🟠 Medium  
**Files:** `CookSavvy/DataImport/Unarchiver.swift:40–52`

**Problem:**  
Temporary files extracted from ZIP archives accumulate in `tmp/` directory.

**Implementation steps:**

1. In `Unarchiver`, add a `defer` block that removes the temporary extraction directory after use:
   ```swift
   defer {
       try? FileManager.default.removeItem(at: tempDirectory)
   }
   ```
2. Ensure the cleanup runs even if extraction or import throws.

---

### [P3-10] Fix N+1 query in `IngredientsService.getAllIngredients(byCategory:)`

**Severity:** 🟠 Medium — performance, creates unnecessary objects  
**Files:** `CookSavvy/Services/Ingredient/IngredientsService.swift:125–150`

**Problem:**  
The method loops per food group, issuing a separate DB query for each group. With potentially dozens of categories, this is N+1 queries.

**Implementation steps:**

1. Replace per-group queries with a single query that fetches all ingredients and groups them in Swift:
   ```swift
   let all = try await ingredientRepository.fetchAllIngredients()
   let grouped = Dictionary(grouping: all) { $0.category }
   ```
2. Remove the per-category DB loop.
3. Update `CookSavvyTests/IngredientsServiceTests.swift` to verify only one DB query is issued (use a query-counting mock or check that `fetchAllIngredients` is called once).

---

### [P3-11] Move coordinator protocols to `Coordinators/` directory

**Severity:** 🟠 Medium — wrong file placement  
**Files:** `CookSavvy/Views/RecipeDetails/RecipeDetailsViewModel.swift:11–15`, `CookSavvy/Views/Journey/JourneyViewModel.swift:5–10`  
**Parallel:** Yes

Coordinator protocol definitions (`RecipeDetailsCoordinating`, `JourneyCoordinating`, etc.) live inside ViewModel files. Move each one to a corresponding file inside `CookSavvy/Coordinators/`.

---

### [P3-12] Fix strong reference in `JourneyCoordinator` → `SettingsCoordinator`

**Severity:** 🟠 Medium — potential retain cycle  
**Files:** `CookSavvy/Coordinators/JourneyCoordinator.swift:12`  
**Parallel:** Yes

Review before changing. A strong `JourneyCoordinator -> SettingsCoordinator` reference is not automatically a retain cycle; the current `SettingsCoordinator` does not obviously retain `JourneyCoordinator`. Changing this to `weak` without another strong owner can deallocate the settings coordinator while the sheet needs it.

Target fix:
- If no back-reference exists, leave the strong reference and remove/downgrade this item from the debt list.
- If a cycle is introduced later, make sheet ownership explicit with `@StateObject`/factory-created `SettingsCoordinator` owned by `JourneyCoordinatorView`, or ensure some other object holds the coordinator strongly before using `weak`.
- Add a lightweight lifecycle test or manual memory-graph check only if there is evidence of a real cycle.

---

### [P3-13] Fix `Ingredient.emoji` missing `CodingKey`

**Severity:** 🟠 Medium — emoji always nil after decode  
**Files:** `CookSavvy/Models/Ingredient.swift:30`

Add `emoji` to the `CodingKeys` enum (or the field's coding key). If the field name in JSON differs from the Swift property name, add the mapping. Add a unit test in `CookSavvyTests/IngredientTests.swift` that encodes and decodes an `Ingredient` with a non-nil `emoji` and asserts it survives the round-trip.

---

### [P3-14] Make `Recipe.id` title-collision-safe (if P1-3 not yet done)

**Severity:** 🟠 Medium — recipes with identical titles treated as the same  
**Depends on:** P1-3 fully supersedes this; only apply if P1-3 is deferred

If P1-3 is not yet done: enforce a unique constraint on `(title, source)` in the `recipes` table so duplicate-title rows from different sources are differentiated.

---

### [P3-15] Fix `JourneyView` redundant `.onAppear` + `.task`

**Severity:** 🟠 Medium — double data load on appear  
**Files:** `CookSavvy/Views/Journey/JourneyView.swift:36–38`

Remove whichever of `.onAppear` or `.task` is redundant. Prefer `.task` for async work since it is cancellable and lifecycle-aware. Keep `.onAppear` only for synchronous, non-async setup.

---

### [P3-16] Fix `LoggingService` created ad-hoc in `DietaryPreferences`

**Severity:** 🟠 Medium — new logger instance per call  
**Files:** `CookSavvy/Services/UserData/DietaryPreferences.swift:88` (or similar)

Inject a `LoggerProtocol` instance through `DietaryPreferences`'s initialiser from `AppContainer`, instead of creating a new `LoggingService()` inline.

---

### [P3-17] Make `ShoppingItem` `Codable`

**Severity:** 🟠 Medium — forces manual serialization  
**Files:** `CookSavvy/Models/ShoppingItem.swift:8`

Add `Codable` conformance to `ShoppingItem`. Remove any manual JSON serialization in `DBInterface`/`ShoppingListRepository` that works around the absence of `Codable`. After P1-1, `ShoppingListRepository` can use standard GRDB `FetchableRecord`/`PersistableRecord` if `ShoppingItem` is `Codable`.

---

### [P3-18] Fix Supabase auth errors mapped as `.unknown`

**Severity:** 🟠 Medium — wrong error type  
**Files:** `CookSavvy/Services/Supabase/SupabaseLLMProvider.swift:76–91`

Map specific Supabase HTTP 401/403 errors to `.invalidAPIKey` or `.unauthorized` instead of `.unknown`. Add a test that verifies the mapping.

---

### [P3-19] Fix `StoreKitSubscriptionService` `@MainActor` isolation for transaction observation

**Severity:** 🟡 High — stale cache can temporarily unlock premium  
**Files:** `CookSavvy/Services/Subscription/StoreKitSubscriptionService.swift:27,129,154`

Mark `StoreKitSubscriptionService` as `@MainActor`. Move the `Task.detached` transaction listener into a structured `Task { @MainActor in ... }` to ensure updates run on a known actor. Treat the cached plan as display-only until StoreKit entitlements are verified (show a loading state for premium features on first launch rather than optimistically unlocking from cache).

---

### [P3-20] Verify/enforce server-side premium gating in Supabase edge functions

**Severity:** 🔴 Security  
**Files:** Supabase edge functions (outside the iOS codebase), `CookSavvy/Services/Supabase/SupabaseRecipeAPIProvider.swift:30`, `SupabaseLLMProvider.swift:35`

Client-side `PaidFeature` checks are UI hints only. The Supabase edge functions for recipe search and LLM calls must independently verify that the caller has a valid premium subscription (e.g., by checking the JWT claims or a Supabase RLS policy). Document this requirement with a code comment in both provider files pointing at the edge function deployment.

Acceptance criteria:
- Edge functions reject unauthenticated calls.
- Edge functions reject authenticated free-tier calls for premium-only recipe/LLM endpoints.
- Edge functions enforce per-user rate limits/quotas for LLM endpoints.
- iOS providers map 401/403/429 responses to typed errors that the UI can explain.
- If the Supabase edge-function source is not in this repository, track the external work item in product/engineering docs and mark the iOS-only part as incomplete until the server change lands.

---

### [P3-21] Stop silently dropping corrupted recipes on decode

**Severity:** 🟡 High — incomplete recipe lists with no diagnosis  
**Files:** `CookSavvy/Services/Database/DBInterface.swift:588,618,827` or future `RecipeRepository`

**Problem:**  
Several recipe fetch paths use `compactMap { try? ... }`, which silently drops rows when decoding fails. Users see missing recipes and developers get no signal.

**Implementation steps:**

1. Replace silent `try?` drops with explicit `do/catch` per row.
2. Log decode failures with enough row context to diagnose the bad record (`recipe_id`, title if available, source).
3. For list queries, continue past the bad row only after logging.
4. For direct lookups by ID/title, throw a typed `DatabaseError.queryFailed` or `DatabaseError.recipeNotFound` rather than returning nil for corrupt data.
5. Add a repository/DB test that inserts a malformed JSON payload and verifies the failure is logged/thrown according to the query type.

---

### [P3-22] Make navigation failures explicit when coordinator is nil

**Severity:** 🟠 Medium — user taps can silently do nothing  
**Files:** Multiple ViewModels with `coordinator?.method()` calls

**Problem:**  
ViewModels hold weak optional coordinators and call them with optional chaining. If a coordinator is unexpectedly nil, navigation silently fails.

**Implementation steps:**

1. Keep weak coordinator references to avoid cycles, but add a small helper for navigation calls:
   ```swift
   private func withCoordinator(_ action: (DiscoverCoordinating) -> Void) {
       guard let coordinator else {
           logger.error("Navigation requested without coordinator")
           assertionFailure("Missing coordinator")
           return
       }
       action(coordinator)
   }
   ```
2. Use the helper for user-triggered navigation paths such as recipe detail, recipe list, settings, create recipe, upgrade, and camera.
3. In tests, instantiate affected ViewModels with nil coordinators and verify business logic does not crash; for navigation-specific methods, verify the logger/mock records a missing coordinator.

---

### [P3-23] Update stale HLD sections after core fixes

**Severity:** 🟠 Medium — docs can mislead future agents  
**Files:** `docs/HLD.md`

After P1/P2/P3 data or DI changes, update the HLD sections that are known stale:
- `Recipe.id = title` diagrams and dedup-by-title data flow.
- AppContainer singleton wording after DI cleanup.
- DEBUG/provider matrix for Supabase vs mock providers.
- Camera scan reset wording (`Calendar.current` vs fixed ISO/Monday behavior after P6-11).
- ViewModel published-state counts after Discover/Journey refactors.

---

## Phase 4 — Reduce Discover Complexity

This is a significant refactor of the app's most active feature. Do it after Phase 1–3 are stable.

---

### [P4-1] Decompose `DiscoverViewModel` into focused state units

**Severity:** 🟡 High — 21 `@Published` properties, mixed responsibilities  
**Files:** `CookSavvy/Views/Discover/DiscoverViewModel.swift`, `CookSavvy/Views/Discover/DiscoverView.swift` (805 lines)  
**Depends on:** P1-2 (DI cleanup should be done first so services are injected, not pulled from container)

**Problem:**  
`DiscoverViewModel` owns 21 published properties spanning ingredient selection, recipe search orchestration, result filtering/ranking, curated collections, camera scan state, dietary preferences, and presentation flags. It is injected with 10 services. Any change to Discover touches this single large file, and the mixed responsibilities make it hard to test any one concern in isolation.

**Target architecture:**

Split into three child objects, owned by `DiscoverViewModel` (which becomes a thin coordinator):

```
DiscoverViewModel (thin coordinator)
├── IngredientSelectionState  (value type / ObservableObject)
│     selectedIngredients, shownIngredients, recentIngredients
│     popularIngredients, categories, searchText, selectedCategory
│     activeDietaryRestrictions
│
├── RecipeSearchState  (ObservableObject)
│     isSearching, searchError, searchResultRecipes
│     collections, loadingCollectionID
│     suggestedRecipes, suggestionReason
│     recentRecipes, savedRecipes
│
└── RecipeFilterState  (value type)
      selectedMood, useItAllFilter
      filteredRecipes (computed from searchResultRecipes + selectedMood)
      bestMatch (computed)
      moreRecipes (computed)
```

**Implementation steps:**

1. **Create `IngredientSelectionState.swift`** in `CookSavvy/Views/Discover/`:
   - Move all ingredient-related published properties here
   - Move `loadPopularIngredients()`, `loadRecentIngredients()`, `addIngredient()`, `removeIngredient()`, `clearIngredients()` here
   - Dependencies: `IngredientsService`, `DietaryPreferences`

2. **Create `RecipeSearchState.swift`** in `CookSavvy/Views/Discover/`:
   - Move recipe search, collections, recommendations, saved/recent recipe tracking here
   - Move `findRecipes()`, `loadCollections()`, `loadRecentSavedRecipes()` here
   - Dependencies: `RecipeService`, `UserDataService`, `RecommendationService`, `CuratedCollectionService`, `SubscriptionService`, `AnalyticsService`, `DatabaseInitService`

3. **Create `RecipeFilterState.swift`** as a plain `struct` (no `ObservableObject`) — it computes derived values from `RecipeSearchState`:
   ```swift
   struct RecipeFilterState {
       var selectedMood: RecipeMood?
       var useItAllFilter: Bool = false

       func filteredRecipes(from results: [Recipe]) -> [Recipe] { ... }
       var bestMatch: Recipe? { ... }
       var moreRecipes: [Recipe] { ... }
   }
   ```

4. **Slim down `DiscoverViewModel`**:
   ```swift
   @MainActor
   final class DiscoverViewModel: ObservableObject {
       @Published var ingredientState = IngredientSelectionState(...)
       @Published var searchState = RecipeSearchState(...)
       @Published var filterState = RecipeFilterState()
       @Published var showResults = false
       @Published var isMatchInfoPopoverPresented = false

       weak var coordinator: DiscoverCoordinatorProtocol?
   }
   ```

5. **Update `DiscoverView.swift`**:
   - The view accesses `viewModel.ingredientState.selectedIngredients` etc. instead of flat `viewModel.selectedIngredients`
   - Extract large view sections into private computed properties / sub-views (see P4-2)
   - The two-state flow (`showResults`) remains on `DiscoverViewModel`

6. **Update tests**:
   - `CookSavvyTests/DiscoverViewModelTests.swift` — split into three test files matching the three state objects
   - Mock only the services each state object needs, not all 10

---

### [P4-2] Extract large sub-views from `DiscoverView` and `JourneyView`

**Severity:** 🟠 Medium — 805 and 564-line files  
**Files:** `CookSavvy/Views/Discover/DiscoverView.swift`, `CookSavvy/Views/Journey/JourneyView.swift`  
**Parallel with:** P4-1

Extract repeating horizontal recipe list blocks, ingredient grid sections, and stats sections into `private var` computed properties or separate `private struct` view files within their respective `Views/Discover/` and `Views/Journey/` directories. No new state or logic — pure view extraction for readability. Target: each top-level view file under 300 lines.

---

## Phase 5 — Testing Gaps

These can be done in parallel with Phase 3–4.

---

### [P5-1] Fix flaky `Task.yield()`-based tests

**Severity:** 🟡 High — 26+ flaky tests  
**Files:** `CookSavvyTests/DiscoverViewModelTests.swift`, `CookSavvyTests/RecipeDetailsViewModelTests.swift`, and others

Replace all `for _ in 0..<N { await Task.yield() }` patterns with proper `XCTestExpectation`:
```swift
let expectation = XCTestExpectation(description: "State updated")
viewModel.$somePublishedProp
    .dropFirst()
    .sink { _ in expectation.fulfill() }
    .store(in: &cancellables)
await fulfillment(of: [expectation], timeout: 2.0)
```
Alternatively, use `AsyncStream`-based test helpers or the `@MainActor` test pattern with `await MainActor.run { }`. Run with Thread Sanitizer enabled to confirm no races.

---

### [P5-2] Add tests for `CameraViewModel`

**Severity:** 🟡 High — zero test coverage  
**Target file:** `CookSavvyTests/CameraViewModelTests.swift`

Test: permission request → granted → capture → AI detection → detected/empty/error state transitions. Mock `IngredientDetectionServiceProtocol` to control outcomes. Verify that `CameraScanTracker` is incremented on successful scan and not incremented on error.

---

### [P5-3] Add tests for `RecipeListViewModel`

**Severity:** 🟡 High — zero test coverage  
**Target file:** `CookSavvyTests/RecipeListViewModelTests.swift`

Test: loads recipes on init, saves/unsaves recipe, updates `savedIds` correctly. Use `MockUserDataService`.

---

### [P5-4] Add tests for `SettingsViewModel` (non-auth paths)

**Severity:** 🟡 High — zero coverage beyond auth flow  
**Target file:** Extend `CookSavvyTests/SettingsViewModelAuthTests.swift`

`SettingsViewModelAuthTests.swift` exists but covers only auth. Add tests for: plan display, usage stats loading, clearing recents/favorites (with confirmation alert), restore purchases flow, theme preference change.

---

### [P5-5] Add tests for `UpgradeViewModel`

**Severity:** 🟡 High — zero test coverage  
**Target file:** `CookSavvyTests/UpgradeViewModelTests.swift`

Test: initial plan displayed, purchase success → plan updates, purchase failure → `purchaseError` set, restore → plan updates. Use `MockSubscriptionService`.

---

### [P5-6] Add error-path tests to `MockServices`

**Severity:** 🟠 Medium — mocks always succeed  
**Files:** `CookSavvyTests/Mocks/MockServices.swift`

Add `shouldThrow: Bool` flags and configurable `error: Error` properties to each mock:
```swift
class MockRecipeService: RecipeServiceProtocol {
    var shouldThrowOnFetch = false
    var fetchError: Error = RecipeServiceError.unknown

    func fetchRecipes(...) async throws -> [Recipe] {
        if shouldThrowOnFetch { throw fetchError }
        return stubbedResults
    }
}
```
Add test cases that exercise error paths (network unavailability, empty collections, DB failure).

---

### [P5-7] Add tests for `AIService`

**Severity:** 🟡 High — zero test coverage  
**Target file:** `CookSavvyTests/AIServiceTests.swift`

Test: ingredient detection success, detection failure maps to correct error, recipe generation success, provider unavailable → `AIServiceError.providerUnavailable`. Use `MockLLMProvider`.

---

### [P5-8] Add integration tests for critical user flows

**Severity:** 🟠 Medium  
**Target files:** `CookSavvyTests/IntegrationTests/` (new directory)

Three critical flows:
1. **Scan → Search**: `CameraScanTracker` increments → `AIIngredientDetectionAdapter` returns ingredients → `DiscoverViewModel.findRecipes()` → results displayed
2. **Cook → Stats → Achievement**: `CookModeViewModel.finishCooking()` → `CookingSession` inserted → `UserDataService.fetchStats()` returns updated counts → `AchievementEvaluator` unlocks `first_cook`
3. **Anonymous → Apple → Sign-Out**: full auth state machine transitions (use `MockAuthService`)

---

## Phase 6 — Low / Polish

All items in this phase are independent and can be done in any order.

---

### [P6-1] Add indexes on `favorite_recipes` and `recent_recipes` FK columns
Missing indexes on join columns — add `CREATE INDEX idx_favorites_recipe_id ON favorite_recipes(recipe_id)`. Minor SQL fix.

### [P6-2] Validate `Color(hex:)` input
Add guard for string length ≥ 6 and valid hex characters; return `Color.clear` or `.gray` for invalid input. Add unit test.

### [P6-3] Document `0x238C` threshold in `Character+Extensions.swift`
Replace magic number with a named constant and a comment explaining the Unicode code point range.

### [P6-4] Fix `String.separatedByQuotes` for unclosed quotes
Add error handling or a fallback (return the raw string) when quotes are not closed.

### [P6-5] Remove obsolete `@unchecked Sendable` provider conformances
After P0-5 removes direct Spoonacular code, verify no obsolete `@unchecked Sendable` conformance remains in provider types. Keep `@unchecked Sendable` only with a short justification when a dependency is safe but not compiler-verifiable.

### [P6-6] Add accessibility labels to `RecipeDetailsList` and `RecipeDetailsAdditionalInfo`
Add `.accessibilityLabel()` modifiers to ingredient rows and additional info items.

### [P6-7] Fix hardcoded `"minutes"` in `CookModeView`
Move to `Strings.CookMode.minutesSuffix` and add to `Localizable.xcstrings`.

### [P6-8] Fix raw color usage in `CameraView`
Replace `Color.black`, `Color.white`, `Color.orange`, `Color.red` with `theme.bg`, `theme.text1`, `theme.accent`, `theme.rose` (or equivalent theme tokens). Use `@Environment(\.appTheme)`.

### [P6-9] Fix hardcoded `size: 60` in `CameraView`
Add `UI.Camera.iconSize: CGFloat = 60` to `UIConstants.swift`.

### [P6-10] Log `CameraScanTracker` weekly reset
Add a `logger.info("Camera scan tracker reset for new week")` call when the weekly count is reset.

### [P6-11] Fix locale-aware week start in `CameraScanTracker`
Use `Calendar(identifier: .iso8601)` or explicitly set `calendar.firstWeekday = 2` (Monday) to ensure consistent behaviour across locales.

### [P6-12] Preserve `unlockedAt` timestamp in `AchievementEvaluator`
Before updating an achievement's `isUnlocked`, check if it was already unlocked and preserve the original `unlockedAt` timestamp.

### [P6-13] Remove obsolete third-party nutrition TODOs from the iOS app
The `SpoonacularModels` calories TODO belongs on the backend if that provider is used there. Delete the iOS model/TODO as part of P0-5; if calorie mapping is still a product requirement, track it against the backend API contract and `SupabaseRecipeDTOs`.

### [P6-14] Fix `UITestDataSeeder` fragility on title changes
After P1-3 (UUID identity), update `UITestDataSeeder` to look up recipes by deterministic UUID, not by title string.

### [P6-15] Resolve vague `// TODO` comments
- `StoreKitSubscriptionService.swift:10` — add a specific issue description or remove the comment
- `UserDataService.swift:50` — implement proper error handling instead of swallowing
- `DataImportService.swift:82` — replace the flagged loop with the upsert approach from P3-8

### [P6-16] Remove dead direct-provider code: `OpenAIProvider`, `GeminiProvider`
`SpoonacularProvider` is removed by P0-5 because recipe providers are backend-only. The remaining direct LLM providers are compiled but not instantiated in active runtime paths. Either add explicit DEBUG/test-only wiring with tests, or delete them if they are permanently superseded by Supabase edge functions. Keeping dead code with no tests increases the maintenance surface without benefit.

Also remove unused API-key reader paths and stale docs for legacy direct-provider keys if nothing references them.

### [P6-17] Remove or implement `noPurchasesToRestore`
`SubscriptionError.noPurchasesToRestore` is currently dead code after `AppStore.sync()`. Either remove the enum case and localized string, or implement an explicit post-sync entitlement check that throws it when there are no active/restorable transactions.

### [P6-18] Audit remaining hardcoded user-facing strings
P6-7 fixes the known `"minutes"` string in `CookModeView`, but the audit also flags other raw English strings in views such as Settings. Run a targeted search for `Text("`, `Button("`, `Label("`, and alert titles/messages in `CookSavvy/Views`, then move user-facing strings into `Strings.swift` / `Localizable.xcstrings`.

---

## Execution Summary

| Phase | Items | Effort | Risk | Prerequisite |
|-------|-------|--------|------|--------------|
| 0 — Critical fixes | P0-1 to P0-7 | Medium | Low | None |
| 1 — Core architecture | P1-1, P1-2, P1-3 | High | Medium | Phase 0 |
| 2 — Concurrency | P2-1 to P2-6 | Medium | Low-Medium | Phase 1 |
| 3 — Auth, data, UX | P3-1 to P3-23 | Medium | Low | Phase 0 |
| 4 — Discover complexity | P4-1, P4-2 | High | Medium | Phase 1-2 |
| 5 — Testing | P5-1 to P5-8 | Medium | Low | Phase 0–4 (best after) |
| 6 — Polish | P6-1 to P6-18 | Low | Very Low | None |

**Recommended execution order:**
1. Phase 0 (parallel — all 7 items together)
2. Phase 1 (P1-3 first; P1-2 can run in parallel; P1-1 after identity is stable)
3. Phase 2 (parallel after Phase 1)
4. Phase 3 (parallel with Phase 2; most items are independent)
5. Phase 4 (after Phase 1–2 are stable)
6. Phase 5 (alongside Phase 3–4, best done after each area it tests is refactored)
7. Phase 6 (any time, low risk, low effort)

---

*End of remediation plan.*
