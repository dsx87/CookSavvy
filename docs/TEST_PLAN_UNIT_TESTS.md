# Unit Test Plan

This document defines the unit test plan for CookSavvy. It covers services, ViewModels, models, and utilities that are not yet tested or are undertested.

## LLM Implementation Hints — Global

- **Test target:** `CookSavvyTests`
- **Framework:** XCTest (not Swift Testing — the existing tests use XCTest, stay consistent)
- **Test plan:** Update `DefaultTestPlan.xctestplan` to include any new test configurations. Consider creating a second plan `UnitTestPlan.xctestplan` for fast unit-only runs (exclude slow/integration tests).
- **Xcode test plan strategy:**
  - `UnitTestPlan.xctestplan` — fast, no network, mocks only, runs in CI
  - `IntegrationTestPlan.xctestplan` — includes DB integration tests (existing `DBInterfaceTests`), can be slower
  - `DefaultTestPlan.xctestplan` — runs both
- **Mocking approach:** All services have protocols. Create mock implementations in the test target. Follow the pattern already established in `RecipeServiceTests.swift` (e.g. `MockRecipeSource`) and `IngredientsServiceTests.swift` (e.g. `MockDBInterfaceForIngredients`). Place shared mocks in a `CookSavvyTests/Mocks/` group.
- **Database tests:** Use `DBInterface(inMemory: true)` for any test that needs a real DB, as established in `CookSavvyTests.swift`.
- **Async tests:** Use `async throws` test methods. The existing tests already do this.
- **Import:** Always `@testable import CookSavvy`.
- **File naming:** `<ClassUnderTest>Tests.swift`
- **No over-testing:** Don't test trivial getters/setters or Apple framework behavior. Focus on business logic, edge cases, and integration points between components.

---

## 1. RecipeMoodRanker Tests

**File:** `RecipeMoodRankerTests.swift`
**What it does:** Scores and sorts recipes based on mood (cozy, fresh, bold, comfort, quick) using keyword matching, cook time, and complexity.
**Why test it:** Pure logic, no dependencies, easy to test. Ranking correctness directly affects what users see first.

### Test cases:

- **Keyword matching per mood:** Create recipes with mood-specific keywords in title/ingredients (e.g. "Warm Chicken Soup" for `.cozy`, "Fresh Avocado Salad" for `.fresh`). Rank a mixed batch for each mood. Assert the keyword-matching recipe ranks first.
- **Cook time scoring:** Create two identical-keyword recipes, one with 10 min cook time, one with 45 min. Rank for `.quick` — verify the short one wins. Rank for `.cozy` — verify the long one wins.
- **Complexity scoring:** Create two recipes, one "easy" and one "medium" complexity. Rank for `.quick` — verify "easy" ranks higher (gets complexity bonus).
- **Cuisine bonus for bold:** Create a recipe with cuisine "Thai". Rank for `.bold`. Verify it gets the featured keyword weight (3 vs 2).
- **Stable sort on tie:** Create recipes with equal scores. Verify original order is preserved (the ranker uses `enumerated()` offset as tiebreaker).
- **No-match baseline:** Rank recipes with zero mood-relevant keywords. Verify all score 0 and original order is preserved.
- **Searchable text composition:** Verify that title, tagline, cuisine, and ingredient names all contribute to keyword matching (test each field individually).

**Implementation hints:**
- `RecipeMoodRanker.rank(_:for:)` is the only public API — a static method, no setup needed.
- Use `Recipe` mock factories to create recipes with specific titles, ingredients, `additionalInfo` (for cook time/complexity), and `cuisine`.
- `AdditionalInfo` contains `.time("30 min")` and `.complexity("Easy")` cases — check `Recipe.swift` for the exact enum structure.

---

## 2. RecipeRecommendationService Tests

**File:** `RecipeRecommendationServiceTests.swift`
**What it does:** Suggests recipes based on user favorites and cooking history. Weights ingredients from favorites (2x) and highly-rated sessions (2x), picks top ingredient, queries DB, filters out recently cooked.
**Why test it:** Core personalization feature. Logic around weighting, filtering, and edge cases matters.

### Test cases:

- **Favorites drive suggestions:** Mock favorites with chicken recipes. Verify suggestions contain chicken-related recipes. Verify reason string says "Chicken".
- **Highly-rated sessions boost weight:** Mock sessions where 4+ star ratings exist for salmon recipes. Verify salmon surfaces as top ingredient over a less-rated one.
- **Recently cooked filtering:** Mock 3 candidate recipes, 2 of which are in recent sessions. Verify those 2 are filtered out from results.
- **Empty history returns empty:** No favorites, no sessions. Verify `([], nil)` is returned.
- **No matching known ingredients:** Favorites with ingredients not in `knownIngredients` list. Verify empty result (no crash, no random suggestion).
- **Limit parameter:** Request limit of 2 when 5 candidates exist. Verify only 2 returned.

**Implementation hints:**
- Needs mocks for: `UserDataServiceProtocol`, `DBInterfaceProtocol`, `DatabaseInitializationServiceProtocol`.
- Mock `DatabaseInitializationServiceProtocol.waitForRecipes()` to return immediately.
- Mock `UserDataServiceProtocol.getFavorites()` and `.getCookingSessions(limit:)` to return controlled data.
- Mock `DBInterfaceProtocol.getRecipes(byIngredients:offset:limit:)` to return predictable candidates.
- The service uses `knownIngredients` — a hardcoded list of 18 protein/staple keywords. Tests should use ingredients that match these keywords.

---

## 3. CameraScanTracker Tests

**File:** `CameraScanTrackerTests.swift`
**What it does:** Tracks weekly camera scan usage via UserDefaults. Resets on new calendar week. Free tier limited to 5/week.
**Why test it:** Directly controls a paywall gate. Wrong counting = angry free users or free premium access.

### Test cases:

- **Fresh state allows scans:** New tracker (clean UserDefaults). Verify `canScan()` returns true, `remainingScans()` returns 5.
- **Recording decrements remaining:** Record 3 scans. Verify `remainingScans()` returns 2. Verify `canScan()` still true.
- **Limit reached blocks scans:** Record 5 scans. Verify `canScan()` returns false. Verify `remainingScans()` returns 0.
- **Custom limit:** Pass `limit: 3` to `canScan(limit:)`. Record 3 scans. Verify blocked. Verify `remainingScans(limit: 3)` returns 0.
- **Week reset:** Record 5 scans, then simulate a new calendar week. Verify `canScan()` returns true again, `remainingScans()` returns 5.
- **Over-limit doesn't go negative:** Record 10 scans (past limit). Verify `remainingScans()` returns 0 (not negative).

**Implementation hints:**
- The tracker uses `UserDefaults.standard` directly. For test isolation, inject a custom `UserDefaults(suiteName:)` — this requires a small refactor to accept `UserDefaults` as an init parameter. Alternatively, clear the specific keys in `setUp`/`tearDown`.
- Week reset relies on `Calendar.current.component(.weekOfYear)`. To test the reset, you'd either need to inject a date provider or manipulate the stored `weekStart` date directly in UserDefaults to simulate a past week.
- The refactor to inject `UserDefaults` and a `Date` provider is minimal and improves testability without changing behavior. Document this as a prerequisite change.

---

## 4. ShoppingListService Tests

**File:** `ShoppingListServiceTests.swift`
**What it does:** CRUD for shopping items — add, toggle checked, remove, clear completed. Thin wrapper around `DBInterfaceProtocol`.
**Why test it:** Data integrity for user's shopping list. Especially toggle and clear logic.

### Test cases:

- **Add items with recipe title:** Add ["Salt", "Pepper"] with recipeTitle "Pasta". Verify 2 items returned by `getItems()`. Verify both have correct recipe title.
- **Add items without recipe title:** Add items with nil title. Verify they exist and have nil `recipeTitle`.
- **Toggle item:** Add item, toggle it. Verify `isChecked` flips. Toggle again, verify it flips back. Verify the return value of `toggleItem` matches the new state.
- **Remove item:** Add 3 items, remove the middle one. Verify only 2 remain, and the removed one is gone.
- **Clear completed:** Add 3 items, check 2 of them, call `clearCompleted()`. Verify only the 1 unchecked item remains.
- **Clear completed when none checked:** Call `clearCompleted()` with all unchecked. Verify all items still exist.
- **Empty list operations:** Call `getItems()`, `clearCompleted()` on empty list. Verify no crash, empty array returned.

**Implementation hints:**
- Can test against real `DBInterface(inMemory: true)` for integration-style tests — the service is a thin wrapper so mocking the DB doesn't add much value here.
- `ShoppingItem` has `id`, `name`, `isChecked`, `addedAt`, `recipeTitle`.

---

## 5. AchievementEvaluator Tests

**File:** `AchievementEvaluatorTests.swift`
**What it does:** Maps cooking metrics to achievement progress. Pure function: metrics in, achievements out.
**Why test it:** Pure logic, zero dependencies. Wrong thresholds = broken achievement UI.

### Test cases:

- **Zero metrics — all locked:** Pass all-zero `AchievementMetrics`. Verify all 7 achievements have `isUnlocked == false` and `currentProgress == 0`.
- **First cook unlocked:** Pass `recipesCooked: 1`. Verify "first_cook" is unlocked. Verify others remain locked.
- **Week streak threshold:** Pass `dayStreak: 7`. Verify "week_streak" unlocked. Pass `dayStreak: 6`, verify still locked.
- **Recipe creator from user recipes:** Pass `userRecipeCount: 1`. Verify "recipe_creator" unlocked. Pass `userRecipeCount: 5`, verify "five_created" also unlocked.
- **Distinct recipes for "ten_recipes" and "fifty_recipes":** Pass `distinctRecipesCooked: 10`. Verify "ten_recipes" unlocked, "fifty_recipes" still locked (needs 50). Pass 50, verify both unlocked.
- **Hour cooking:** Pass `totalCookingHours: 10.5`. Verify "hour_cooking" unlocked (rounds down to 10, threshold is 10).
- **Progress capped at maxProgress:** Pass `recipesCooked: 999`. Verify "first_cook" has `currentProgress == 1` (maxProgress), not 999.
- **UnlockedAt date:** Pass a fixed reference date. Verify unlocked achievements have that date, locked ones have nil.

**Implementation hints:**
- `AchievementEvaluator.evaluate(metrics:referenceDate:)` is static, pure function.
- `AchievementMetrics` is a simple struct — construct directly.
- `Achievement.allAchievements` defines the 7 achievements with their `maxProgress` values.

---

## 6. ViewModel Tests

### 6.1 DiscoverViewModel Tests

**File:** `DiscoverViewModelTests.swift` (expand existing)
**What it does:** Manages ingredient selection, search, recipe results, mood filtering, suggestions.
**Why test it:** Central user-facing state machine. Two-state flow (selection ↔ results) is the core UX.

#### Test cases:

- **Adding/removing ingredients updates state:** Add ingredient, verify `selectedIngredients` contains it. Remove, verify it doesn't.
- **Search triggers recipe fetch:** Set selected ingredients, trigger search. Verify `searchResultRecipes` is populated from mock service. Verify `showResults` flips to true.
- **Mood filter applies ranking:** Set recipes and mood. Verify recipes are re-ranked via `RecipeMoodRanker` (order changes for relevant mood).
- **Source accessibility filtering by subscription:** Free user — verify only `.offline` source accessible. Premium — verify `.offline`, `.online`, `.ai` accessible.
- **Database not ready blocks search:** Mock `databaseInitService` as not ready. Verify search doesn't proceed or shows appropriate state.
- **Suggestion loading:** Mock `RecipeRecommendationService` to return suggestions. Verify `suggestedRecipes` is populated on load.

**Implementation hints:**
- ViewModel is `@MainActor`. Use `@MainActor` on test class or `await MainActor.run {}`.
- Needs mocks for: `IngredientsServiceProtocol`, `RecipeServiceProtocol`, `UserDataServiceProtocol`, `SubscriptionServiceProtocol`, `CameraScanTrackerProtocol`, `RecipeRecommendationServiceProtocol`, `DatabaseInitializationServiceProtocol`, `ImageServiceProtocol`.
- The ViewModel is created by coordinators. For tests, construct it directly with mocks.
- Check the ViewModel's `init` signature and required dependencies by reading `DiscoverViewModel.swift`.

### 6.2 JourneyViewModel Tests

**File:** `JourneyViewModelTests.swift` (expand existing)
**What it does:** Loads and displays user stats, achievements, user recipes, weekly calendar, recent sessions.

#### Test cases:

- **Stats loaded from UserDataService:** Mock returns `recipesCooked: 5`, `dayStreak: 3`, `totalCookingTime: 7200`. Verify ViewModel properties match.
- **Achievements evaluated correctly:** Mock returns cooking metrics. Verify `achievements` array has correct unlock states (delegates to `AchievementEvaluator`).
- **User recipes loaded:** Mock returns 3 user-created recipes. Verify `userRecipes` has count 3.
- **Week cooking dates:** Mock returns sessions on Monday and Wednesday. Verify `weekCookingDates` set contains those day indices.
- **Empty state:** All mocks return empty. Verify all stats are 0, no crashes.

**Implementation hints:**
- Similar mocking approach to DiscoverViewModel.
- The ViewModel loads data in an `onAppear`-triggered method — find it and call it in tests.

### 6.3 CookModeViewModel Tests

**File:** `CookModeViewModelTests.swift`
**What it does:** Manages step-by-step cooking navigation, progress tracking, timer, and session recording.
**Why test it:** Step navigation logic and session recording are testable and important.

#### Test cases:

- **Step navigation:** Init with a 5-step recipe. Verify `currentStep` is 0. Call next, verify 1. Call previous from 0, verify stays at 0. Navigate to last step, call next, verify doesn't go past.
- **Progress calculation:** At step 2 of 5, verify progress fraction is ~0.4.
- **Session recording on completion:** Complete all steps. Verify `UserDataService.markAsCooked()` was called with correct recipe.
- **Timer presence:** Step with `timerMinutes` set — verify timer-related state is available. Step without — verify no timer.

**Implementation hints:**
- Read `CookModeViewModel.swift` to understand the exact step navigation methods and published properties.
- Mock `UserDataServiceProtocol` to verify session recording.

### 6.4 CreateRecipeViewModel Tests

**File:** `CreateRecipeViewModelTests.swift`
**What it does:** Manages 5-step wizard state for recipe creation.

#### Test cases:

- **Step progression:** Verify initial step is 0. Advance through steps 0→4. Verify can't go past step 4 or below step 0.
- **Validation per step:** Step 1 — empty name blocks advancement. Step 2 — no ingredients blocks. Step 3 — no steps blocks.
- **Save creates recipe:** Fill all fields, save. Verify `UserDataService.saveUserRecipe()` called with correct data.
- **Data persistence across steps:** Set name in step 1, add ingredients in step 2, go back to step 1, verify name still there.

**Implementation hints:**
- Read `CreateRecipeViewModel.swift` to understand the wizard step model and validation logic.

### 6.5 ShoppingListViewModel Tests

**File:** `ShoppingListViewModelTests.swift`
**What it does:** CRUD wrapper for shopping list UI state.

#### Test cases:

- **Load items on appear:** Mock service returns 3 items. Verify `items` is populated.
- **Toggle updates local state:** Toggle an item. Verify `isChecked` state updates without full reload.
- **Delete removes item:** Delete item. Verify removed from `items` array.
- **Clear completed:** 2 checked, 1 unchecked. Clear. Verify 1 item remains.
- **Premium gate check:** Free user — verify `canAccess` is false (ViewModel should check subscription).

**Implementation hints:**
- Mock `ShoppingListServiceProtocol` and `SubscriptionServiceProtocol`.

### 6.6 RecipeDetailsViewModel Tests

**File:** `RecipeDetailsViewModelTests.swift`
**What it does:** Manages favorite toggle, missing ingredients computation, shopping list access.

#### Test cases:

- **Favorite toggle:** Toggle favorite on. Verify `isFavorite` is true. Toggle off. Verify false. Verify `UserDataService.toggleFavorite()` called.
- **Missing ingredients calculation:** Recipe needs [A, B, C], user selected [A, C]. Verify missing = [B].
- **Shopping list premium gate:** Free user taps add to list. Verify upgrade is triggered (coordinator method called or state set).

**Implementation hints:**
- The ViewModel takes a `Recipe` and selected ingredients. Check its init signature.
- Mock `UserDataServiceProtocol` for favorite operations.

---

## 7. Network Layer Tests

### 7.1 URLBuilder Tests

**File:** `URLBuilderTests.swift`
**What it does:** Constructs URLs with query parameters.
**Why test it:** Wrong URL = wrong API calls. Pure logic, trivial to test.

#### Test cases:

- **Base URL construction:** Verify correct URL from base + path.
- **Query parameter encoding:** Add params with special characters. Verify percent-encoding.
- **Multiple query params:** Add 3 params. Verify all present in output URL.
- **Empty params:** No params added. Verify clean URL without `?`.

**Implementation hints:**
- Read `URLBuilder.swift` for the exact API. Likely a builder pattern with `addQueryItem` / `build` methods.

### 7.2 NetworkService Tests

**File:** `NetworkServiceTests.swift`
**What it does:** Executes HTTP requests and decodes responses.
**Why test it:** Verify request construction, error mapping, decoding.

#### Test cases:

- **Successful decode:** Use `URLProtocol` mock to return valid JSON. Verify decoded object matches.
- **Bad status code:** Mock returns 404. Verify `NetworkError.badStatusCode` thrown.
- **Decoding error:** Mock returns invalid JSON. Verify `NetworkError.decodingError` thrown.
- **Invalid URL:** Construct request with garbage URL. Verify `NetworkError.invalidURL` thrown.

**Implementation hints:**
- Use a custom `URLProtocol` subclass to intercept requests. Register it on a custom `URLSession` and inject that session into `NetworkService` (or via `NetworkConfiguration`).
- This is a standard iOS testing pattern — search for "URLProtocol mock testing" for reference.
- If `NetworkService` doesn't support session injection, a small refactor to its init may be needed. Document this as a prerequisite.

---

## 8. SpoonacularProvider Tests

**File:** `SpoonacularProviderTests.swift`
**What it does:** Calls Spoonacular API, maps response DTOs to `Recipe` models.
**Why test it:** DTO → model mapping is error-prone. Test the mapping, not the network call.

### Test cases:

- **DTO to Recipe mapping:** Create a `SpoonacularModels` response DTO manually. Verify the mapper produces correct `Recipe` (title, ingredients, image URL, etc.).
- **Missing fields handling:** DTO with nil optional fields. Verify no crash, graceful defaults.
- **Empty results:** Response with empty results array. Verify `RecipeAPIProviderError.noResults` thrown.

**Implementation hints:**
- Read `SpoonacularModels.swift` for the DTO structure and any `toRecipe()` or mapping functions.
- These tests should NOT hit the real API — test only the mapping/parsing logic.
- If the provider doesn't separate mapping from network call, test by feeding it mock JSON through the `URLProtocol` approach.

---

## 9. Model Tests

### 9.1 Ingredient Category Mapping

**File:** `IngredientTests.swift`
**What it does:** `Ingredient.category` is a computed property mapping `foodGroup` strings to `IngredientCategory` enum.
**Why test it:** Category determines which filter section an ingredient appears in. Wrong mapping = ingredient in wrong category.

#### Test cases:

- **Known food groups:** "Meat" → `.proteins`, "Vegetables" → `.veggies`, "Dairy" → `.dairy`, etc. Test each major mapping.
- **Nil food group:** Verify falls to `.other`.
- **Unknown food group:** Random string → `.other`.
- **Case sensitivity:** Verify mapping handles capitalization as implemented.

**Implementation hints:**
- Read the `category` computed property in `Ingredient.swift` for exact mapping logic.
- `ExpressibleByStringLiteral` conformance means you can create test ingredients with just string literals — but for category tests, use full init with `foodGroup` parameter.

### 9.2 Recipe Model Tests

**File:** `RecipeModelTests.swift`
**What it does:** Recipe has Codable conformance, step timer parsing, additional info handling.

#### Test cases:

- **Codable round-trip:** Encode a Recipe to JSON, decode back. Verify equality.
- **Step timer parsing:** Step with `timerMinutes: 5` — verify it's correctly stored. Step without timer — verify nil.
- **AdditionalInfo construction:** Verify `.time("30 min")`, `.servings("4")`, `.complexity("Easy")`, `.calories("350")` all round-trip.
- **Mock factory validity:** `Recipe.mocks(count: n)` — verify returned array has n recipes, all with non-empty titles and ingredients.

**Implementation hints:**
- `Recipe` already has `.mocks(count:)` factory — use it as baseline, extend for edge cases.

---

## 10. UserDataService Integration Tests

**File:** `UserDataServiceTests.swift`
**What it does:** CRUD for favorites, recents, cooking sessions, user recipes, preferences — all via DB.
**Why test it:** Central user data layer. All Journey stats depend on it.

### Test cases:

- **Record and retrieve recent ingredients:** Record 3 ingredients. Verify `getRecentIngredients(limit: 10)` returns them.
- **Record and retrieve recent recipes:** View 2 recipes. Verify `getRecentRecipes(limit: 10)` returns them.
- **Favorite toggle cycle:** Toggle recipe as favorite. Verify `isFavorite` true. Toggle again, verify false.
- **Get favorites list:** Favorite 3 recipes. Verify `getFavorites()` returns 3.
- **Cooking session recording:** Mark recipe as cooked. Verify `getCookingSessions(limit: 10)` returns the session. Verify `recipesCooked()` increments.
- **Day streak calculation:** Record sessions on consecutive days. Verify `currentStreak()` returns correct count.
- **Week cooking dates:** Record sessions on specific dates. Verify `getWeekCookingDates()` returns correct day indices.
- **User recipe CRUD:** Save user recipe, retrieve it, update title, verify update persists, delete, verify gone.
- **Clear recent data:** Record data, call `clearRecentData()`. Verify recents are empty. Verify favorites/sessions are NOT cleared.
- **Theme preference persistence:** Set theme, retrieve. Verify match.

**Implementation hints:**
- Use `DBInterface(inMemory: true)` and construct `UserDataService` with it.
- This is an integration test (real DB, real service) — appropriate because the service is mostly DB pass-through.
- For streak/date tests, you'll need to insert cooking sessions with specific dates. Check if `DBInterface` has methods to insert sessions with custom dates, or use direct GRDB access.
- Place in `IntegrationTestPlan.xctestplan`.

---

## 11. DatabaseInitializationService Tests

**File:** `DatabaseInitializationServiceTests.swift`
**What it does:** Coordinates ingredient loading and dataset import. Signals when DB is ready.
**Why test it:** App won't function if DB init fails silently.

### Test cases:

- **Successful initialization:** Mock all sub-services to succeed. Verify `waitForRecipes()` completes. Verify ingredients and recipes are loaded.
- **Ingredient load failure doesn't block:** Mock ingredient import to fail. Verify service still attempts recipe import and doesn't hang.
- **Wait completes after background init:** Start init, immediately call `waitForRecipes()`. Verify it awaits and eventually returns.

**Implementation hints:**
- Read `DatabaseInitializationService.swift` for the exact initialization flow.
- Mock `IngredientsServiceProtocol`, `DataImportServiceProtocol`.
- The service likely uses a continuation or async signal — verify the waiting mechanism.

---

## Test Organization Summary

| Test Plan | Contents | Speed |
|-----------|----------|-------|
| `UnitTestPlan.xctestplan` | RecipeMoodRanker, AchievementEvaluator, URLBuilder, Model tests, ViewModel tests, CameraScanTracker, SpoonacularProvider mapping | Fast (<10s) |
| `IntegrationTestPlan.xctestplan` | DBInterface, UserDataService, ShoppingListService, RecipeRecommendationService, IngredientsService, NetworkService, DatabaseInitializationService | Medium (<30s) |
| `DefaultTestPlan.xctestplan` | Both of the above | All |

## Mock Inventory

These mocks will be needed across multiple test files. Create them in `CookSavvyTests/Mocks/`:

| Mock | Protocol | Key behaviors to mock |
|------|----------|----------------------|
| `MockUserDataService` | `UserDataServiceProtocol` | Return configurable favorites, sessions, metrics. Track method calls. |
| `MockDBInterface` | `DBInterfaceProtocol` | Return configurable recipes/ingredients. In-memory storage or stubbed returns. |
| `MockRecipeService` | `RecipeServiceProtocol` | Return configurable recipes. Track source requests. |
| `MockIngredientsService` | `IngredientsServiceProtocol` | Return configurable search results. |
| `MockSubscriptionService` | `SubscriptionServiceProtocol` | Already exists — `MockSubscriptionService` in main target. Reuse or mirror for tests. |
| `MockImageService` | `ImageServiceProtocol` | Return nil or placeholder images. |
| `MockCameraScanTracker` | `CameraScanTrackerProtocol` | Configurable `canScan` / `remainingScans`. |
| `MockDatabaseInitService` | `DatabaseInitializationServiceProtocol` | `waitForRecipes()` returns immediately. |
| `MockShoppingListService` | `ShoppingListServiceProtocol` | In-memory item storage. |
| `MockRecommendationService` | `RecipeRecommendationServiceProtocol` | Return configurable suggestions. |
| `MockNetworkService` | `NetworkServiceProtocol` | Return configurable responses or throw errors. |

## Priority Order for Implementation

If implementing incrementally, this order maximizes value:

1. **AchievementEvaluator** + **RecipeMoodRanker** — pure logic, zero mocks, highest confidence gain
2. **CameraScanTracker** — paywall gate, small refactor + tests
3. **ShoppingListService** — CRUD against in-memory DB, straightforward
4. **UserDataService integration** — covers the biggest surface area
5. **ViewModel tests** (Discover, CookMode, CreateRecipe) — most complex but most valuable for catching regressions
6. **Network layer** (URLBuilder, NetworkService, SpoonacularProvider mapping)
7. **RecipeRecommendationService** — depends on mocks from #4
8. **Model tests** — lower priority, mostly Codable round-trips
9. **DatabaseInitializationService** — async coordination, test last
