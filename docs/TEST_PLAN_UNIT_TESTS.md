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

## Implementation Status

### Unit Tests (fast, mocks only — `UnitTestPlan.xctestplan`)

| # | Test File | Status | Tests |
|---|-----------|--------|-------|
| 1 | `RecipeMoodRankerTests.swift` | ✅ Done | 7 |
| 2 | `AchievementEvaluatorTests.swift` | ✅ Done | 6 |
| 3 | `CameraScanTrackerTests.swift` | ✅ Done | 6 |
| 4 | `URLBuilderTests.swift` | ✅ Done | 5 |
| 5 | `SpoonacularMapperTests.swift` | ✅ Done | 4 |
| 6 | `IngredientTests.swift` | ✅ Done | 4 |
| 7 | `RecipeModelTests.swift` | ✅ Done | 4 |
| 8 | `DiscoverViewModelTests.swift` | ✅ Done | 9 |
| 9 | `JourneyViewModelTests.swift` | ✅ Done | 7 |
| 10 | `CookModeViewModelTests.swift` | ✅ Done | 10 |
| 11 | `CreateRecipeViewModelTests.swift` | ✅ Done | 11 |
| 12 | `ShoppingListViewModelTests.swift` | ✅ Done | 4 |
| 13 | `RecipeDetailsViewModelTests.swift` | ✅ Done | 9 |
| 14 | `RecipeSourceTests.swift` | ✅ Done | 7 |
| 15 | `OnlineAndAIRecipeSourceTests.swift` | ✅ Done | 9 |
| 16 | `RecipeDatasetReaderTests.swift` | ✅ Done | 5 |

**Unit test total:** ~103

### Integration Tests (real DB or network — `IntegrationTestPlan.xctestplan`)

| # | Test File | Status | Tests |
|---|-----------|--------|-------|
| 1 | `CookSavvyTests.swift` (DBInterface) | ✅ Done | 27 |
| 2 | `UserDataServiceTests.swift` | ✅ Done | 10 |
| 3 | `ShoppingListServiceTests.swift` | ✅ Done | 7 |
| 4 | `RecipeRecommendationServiceTests.swift` | ✅ Done | 5 |
| 5 | `IngredientsServiceTests.swift` | ✅ Done | 24 |
| 6 | `RecipeServiceTests.swift` | ✅ Done | 17 |
| 7 | `ImageServiceTests.swift` | ✅ Done | 22 |
| 8 | `OfflineRecipeSourceTests.swift` | ✅ Done | 10 |
| 9 | `NetworkServiceTests.swift` | ✅ Done | 3 |
| 10 | `RecipeDatasetReaderTests.swift` | ✅ Done | 5 |
| — | `DatabaseInitializationServiceTests.swift` | ❌ Not started | — |

**Integration test total:** ~125

**Grand total:** ~228 tests across 25 test files

---

## 1. RecipeMoodRanker Tests ✅

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

## 2. RecipeRecommendationService Tests ✅

**File:** `RecipeRecommendationServiceTests.swift`
**What it does:** Suggests recipes based on user favorites and cooking history. Weights ingredients from favorites (2x) and highly-rated sessions (2x), picks top ingredient, queries DB, filters out recently cooked.
**Why test it:** Core personalization feature. Logic around weighting, filtering, and edge cases matters.

### Test cases:

- **Favorites drive suggestions:** Mock favorites with chicken recipes. Verify suggestions contain chicken-related recipes. Verify reason string says "Chicken".
- **Highly-rated sessions boost weight:** Mock sessions where 4+ star ratings exist for salmon recipes. Verify salmon surfaces as top ingredient over a less-rated one.
- **Recently cooked filtering:** Mock 3 candidate recipes, 2 of which are in recent sessions. Verify those 2 are filtered out from results.
- **Empty history returns empty:** No favorites, no sessions. Verify `([], nil)` is returned.
- **Limit parameter:** Request limit of 2 when 5 candidates exist. Verify only 2 returned.

> Note: `testNoMatchingKnownIngredients` case was not implemented — the service's `knownIngredients` list is hardcoded and hard to avoid when constructing test data.

**Implementation hints:**
- Needs mocks for: `UserDataServiceProtocol`, `DBInterfaceProtocol`, `DatabaseInitializationServiceProtocol`.
- Mock `DatabaseInitializationServiceProtocol.waitForRecipes()` to return immediately.
- Mock `UserDataServiceProtocol.getFavorites()` and `.getCookingSessions(limit:)` to return controlled data.
- Mock `DBInterfaceProtocol.getRecipes(byIngredients:offset:limit:)` to return predictable candidates.
- The service uses `knownIngredients` — a hardcoded list of 18 protein/staple keywords. Tests should use ingredients that match these keywords.

---

## 3. CameraScanTracker Tests ✅

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

## 4. ShoppingListService Tests ✅

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

## 5. AchievementEvaluator Tests ✅

**File:** `AchievementEvaluatorTests.swift`
**What it does:** Maps cooking metrics to achievement progress. Pure function: metrics in, achievements out.
**Why test it:** Pure logic, zero dependencies. Wrong thresholds = broken achievement UI.

### Test cases:

- **Zero metrics — all locked:** Pass all-zero `AchievementMetrics`. Verify all 7 achievements have `isUnlocked == false` and `currentProgress == 0`.
- **First cook unlocked:** Pass `recipesCooked: 1`. Verify "first_cook" is unlocked. Verify others remain locked.
- **Week streak threshold:** Pass `dayStreak: 7`. Verify "week_streak" unlocked. Pass `dayStreak: 6`, verify still locked.
- **Recipe creator from user recipes:** Pass `userRecipeCount: 1`. Verify "recipe_creator" unlocked. Pass `userRecipeCount: 5`, verify "five_created" also unlocked.
- **Progress capped at maxProgress:** Pass `recipesCooked: 999`. Verify "first_cook" has `currentProgress == 1` (maxProgress), not 999.
- **UnlockedAt date:** Pass a fixed reference date. Verify unlocked achievements have that date, locked ones have nil.

> Note: `testDistinctRecipesForTenAndFiftyRecipes` and `testHourCooking` cases were not implemented.

**Implementation hints:**
- `AchievementEvaluator.evaluate(metrics:referenceDate:)` is static, pure function.
- `AchievementMetrics` is a simple struct — construct directly.
- `Achievement.allAchievements` defines the 7 achievements with their `maxProgress` values.

---

## 6. ViewModel Tests ✅

### 6.1 DiscoverViewModel Tests ✅

**File:** `DiscoverViewModelTests.swift`
**What it does:** Manages ingredient selection, search, recipe results, mood filtering, suggestions.
**Why test it:** Central user-facing state machine. Two-state flow (selection ↔ results) is the core UX.

#### Implemented test cases:

- **Toggle ingredient:** Add/remove ingredient, verify `selectedIngredients` state.
- **Find recipes populates results:** Trigger search, verify `searchResultRecipes` populated, `showResults` flips to true.
- **Mood filter ranking:** Set mood, verify recipes are re-ranked via `RecipeMoodRanker`.
- **Clear ingredients resets:** Verify state reset when ingredients cleared.
- **Camera free user with scans:** Free user with remaining scans — camera permitted.
- **Camera free user no scans:** Free user at limit — camera blocked.
- **Source accessibility filtering:** Free user removes premium sources; premium user keeps all.
- **Database ready flag for offline-only:** Verify DB readiness check applies only when offline source is needed.

> Note: suggestion loading test not implemented.

**Implementation hints:**
- ViewModel is `@MainActor`. Use `@MainActor` on test class or `await MainActor.run {}`.
- Needs mocks for: `IngredientsServiceProtocol`, `RecipeServiceProtocol`, `UserDataServiceProtocol`, `SubscriptionServiceProtocol`, `CameraScanTrackerProtocol`, `RecipeRecommendationServiceProtocol`, `DatabaseInitializationServiceProtocol`, `ImageServiceProtocol`.

### 6.2 JourneyViewModel Tests ✅

**File:** `JourneyViewModelTests.swift`
**What it does:** Loads and displays user stats, achievements, user recipes, weekly calendar, recent sessions.

#### Implemented test cases:

- **Stats loaded from UserDataService:** Verify ViewModel properties match mocked stats.
- **User recipes loaded:** Mock returns 3 user-created recipes. Verify `userRecipes` has count 3.
- **Achievements evaluated correctly:** Mock cooking metrics. Verify achievement unlock states.
- **Week cooking dates:** Mock sessions on specific days. Verify `weekCookingDates` set.
- **Empty state:** All mocks return empty. Verify no crashes.
- **Integration: buildAchievements uses loaded metrics.**
- **Integration: incomplete milestones remain locked.**

### 6.3 CookModeViewModel Tests ✅

**File:** `CookModeViewModelTests.swift`
**What it does:** Manages step-by-step cooking navigation, progress tracking, timer, and session recording.

#### Implemented test cases:

- **Initial state:** Verify `currentStep` starts at 0.
- **Go next advances step:** Verify step increments.
- **Go previous from zero stays:** Verify can't go below 0.
- **Go next at last step stays:** Verify can't go past last step.
- **Progress calculation:** Verify fraction at step 2/5 ≈ 0.4.
- **Finish shows feedback:** Completing all steps shows feedback prompt.
- **Submit feedback calls service and dismisses.**
- **Skip feedback calls service and dismisses.**
- **Timer reset on step change.**
- **Dismiss stops timer and calls onDismiss.**

### 6.4 CreateRecipeViewModel Tests ✅

**File:** `CreateRecipeViewModelTests.swift`
**What it does:** Manages 5-step wizard state for recipe creation.

#### Implemented test cases:

- **Initial step:** Verify wizard starts at step 0.
- **Go next advances step.**
- **Blocked when invalid:** Cannot advance past invalid step.
- **Go back from first stays.**
- **Validation per step:** Name empty blocks step 1; no ingredients blocks step 2; no steps blocks step 3.
- **Save calls service:** Verify `UserDataService.saveUserRecipe()` called with correct data.
- **Data persists across steps.**
- **Blank ingredient rows trimmed.**
- **Blank step rows trimmed.**
- **Emoji/tagline/cuisine saved.**
- **Save failure sets error.**

### 6.5 ShoppingListViewModel Tests ✅

**File:** `ShoppingListViewModelTests.swift`
**What it does:** CRUD wrapper for shopping list UI state.

#### Implemented test cases:

- **Load items on appear:** Mock returns 3 items. Verify `items` populated.
- **Toggle updates local state:** Toggle item, verify `isChecked` state updates.
- **Delete removes item.**
- **Clear completed:** 2 checked, 1 unchecked → 1 remains.

> Note: premium gate check test not implemented.

### 6.6 RecipeDetailsViewModel Tests ✅

**File:** `RecipeDetailsViewModelTests.swift`
**What it does:** Manages favorite toggle, missing ingredients computation, shopping list access.

#### Implemented test cases:

- **Favorite toggle:** Toggle on/off. Verify `isFavorite` state and `UserDataService.toggleFavorite()` called.
- **Missing ingredients calculation:** Recipe [A, B, C], selected [A, C] → missing = [B].
- **Missing empty when no selection.**
- **Add to list premium gate:** Free user triggers upgrade.
- **Add to list for premium user:** Succeeds.
- **Record recipe view on init.**
- **Missing falls back to precomputed missing.**
- **Coordinator routing: add to list shows shopping list.**
- **Coordinator routing: add to list shows upgrade for free user.**

---

## 7. Network Layer Tests ✅

### 7.1 URLBuilder Tests ✅

**File:** `URLBuilderTests.swift`

#### Implemented test cases:

- Base URL construction with path.
- Appending additional path segment.
- Query parameter encoding (special characters → percent-encoded).
- Multiple query params all present in output URL.
- Empty params → no `?` in URL.

### 7.2 NetworkService Tests ✅

**File:** `NetworkServiceTests.swift`

#### Implemented test cases:

- **Successful response:** Mock `URLProtocol` returns valid JSON. Verify decoded object matches.
- **HTTP error throws:** Mock returns 404. Verify `NetworkError.badStatusCode` thrown.
- **Timeout throws.**

> Note: `testDecodingError` and `testInvalidURL` cases were not implemented.

**Implementation hints:**
- Uses a custom `MockURLProtocol` subclass to intercept requests.

---

## 8. SpoonacularMapper Tests ✅

**File:** `SpoonacularMapperTests.swift`
**What it does:** DTO → `Recipe` model mapping.

### Implemented test cases:

- **Full DTO mapping:** Verify title, ingredients, image URL in output `Recipe`.
- **Missing optional fields:** Nil optional fields → graceful defaults, no crash.
- **Complexity mapping.**
- **Empty results:** Verify `RecipeAPIProviderError.noResults` thrown.

---

## 9. Model Tests ✅

### 9.1 Ingredient Category Mapping ✅

**File:** `IngredientTests.swift`

#### Implemented test cases:

- Known food group mappings (Meat → `.proteins`, Vegetables → `.veggies`, etc.).
- Nil food group → `.other`.
- Unknown food group → `.other`.
- Case sensitivity handling.

### 9.2 Recipe Model Tests ✅

**File:** `RecipeModelTests.swift`

#### Implemented test cases:

- Step timer minutes correctly stored.
- `AdditionalInfo` construction (`.time`, `.servings`, `.complexity`, `.calories`).
- Ingredient `ExpressibleByStringLiteral` init.
- Ingredient equality by name.

> Note: Codable round-trip and `Recipe.mocks(count:)` factory tests were not implemented.

---

## 10. UserDataService Integration Tests ✅

**File:** `UserDataServiceTests.swift`

### Implemented test cases:

- **Record and retrieve recent ingredients.**
- **Record and retrieve recent recipes.**
- **Favorite toggle cycle:** Toggle on → isFavorite true. Toggle again → false.
- **Get favorites list.**
- **Cooking session recording.**
- **Recipes cooked count increments.**
- **User recipe CRUD:** Save, retrieve, update, delete.
- **Clear recent preserves favorites.**
- **Theme preference persistence.**
- **Enabled sources preference.**

> Note: Day streak and week cooking dates tests not implemented (require date injection).

---

## 11. DatabaseInitializationService Tests ❌

**File:** `DatabaseInitializationServiceTests.swift` — **not yet created**
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
| `UnitTestPlan.xctestplan` | RecipeMoodRanker, AchievementEvaluator, URLBuilder, Model tests, ViewModel tests, CameraScanTracker, SpoonacularMapper mapping | Fast (<10s) |
| `IntegrationTestPlan.xctestplan` | DBInterface, UserDataService, ShoppingListService, RecipeRecommendationService, IngredientsService, NetworkService, DatabaseInitializationService | Medium (<30s) |
| `DefaultTestPlan.xctestplan` | Both of the above | All |

## Mock Inventory

Shared mocks in `CookSavvyTests/Mocks/`:

| Mock | Protocol | File | Status |
|------|----------|------|--------|
| `MockUserDataService` | `UserDataServiceProtocol` | `Mocks/MockUserDataService.swift` | ✅ Created |
| `MockShoppingListService` | `ShoppingListServiceProtocol` | `Mocks/MockShoppingListService.swift` | ✅ Created |
| `MockDatabaseInitService` | `DatabaseInitializationServiceProtocol` | `Mocks/MockServices.swift` | ✅ Created |
| `MockIngredientsService` | `IngredientsServiceProtocol` | `Mocks/MockServices.swift` | ✅ Created |
| `MockRecipeService` | `RecipeServiceProtocol` | `Mocks/MockServices.swift` | ✅ Created |
| `MockRecommendationService` | `RecipeRecommendationServiceProtocol` | `Mocks/MockServices.swift` | ✅ Created |
| `MockCameraScanTracker` | `CameraScanTrackerProtocol` | `Mocks/MockServices.swift` | ✅ Created |
| `MockImageService` | `ImageServiceProtocol` | `Mocks/MockServices.swift` | ✅ Created |
| `MockSubscriptionService` | `SubscriptionServiceProtocol` | Main target (reused in tests) | ✅ Exists |
| `MockDBInterface` | `DBInterfaceProtocol` | Inline in test files | ✅ Exists |
| `MockNetworkService` | `NetworkServiceProtocol` | `MockURLProtocol` in `NetworkServiceTests.swift` | ✅ Created |

## Priority Order for Implementation

Remaining work:

1. **DatabaseInitializationService** — async coordination, last piece of service coverage
