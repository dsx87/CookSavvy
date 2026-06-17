# Unit Test Plan

Guidance for writing unit/integration tests in CookSavvy, plus the remaining test gaps.

> **Status (2026-06-08):** The original backlog this plan tracked is **complete** — all ranker,
> tracker, model, network, ViewModel, and service-coverage items have been implemented, including
> `DatabaseInitializationServiceTests`. The detailed per-test specs were removed once shipped; the
> shipped tests in `CookSavvyTests/` are now the source of truth for what is covered. What remains
> below is the evergreen authoring guidance and the still-open gaps.

## LLM Implementation Hints — Global

- **Test target:** `CookSavvyTests`
- **Framework:** XCTest (not Swift Testing — the existing tests use XCTest, stay consistent)
- **Test plans:** the project ships three `.xctestplan` files at the repo root:
  - `UnitTests.xctestplan` — fast, no network, mocks only
  - `IntegrationTests.xctestplan` — includes DB integration tests (real `DBInterface(inMemory:)`)
  - `DefaultTestPlan.xctestplan` — runs everything
- **Mocking approach:** All services have protocols. Create mock implementations in the test target.
  Follow the pattern in `RecipeServiceTests.swift` (`MockRecipeSource`) and `IngredientsServiceTests.swift`
  (`MockDBInterfaceForIngredients`). Shared mocks live in `CookSavvyTests/Mocks/`.
- **Database tests:** Use `DBInterface(inMemory: true)` for any test that needs a real DB, as
  established in `CookSavvyTests.swift`.
- **Async tests:** Use `async throws` test methods.
- **MainActor ViewModels:** annotate the test class `@MainActor` or wrap calls in `await MainActor.run {}`.
- **Import:** Always `@testable import CookSavvy`.
- **File naming:** `<ClassUnderTest>Tests.swift`
- **No over-testing:** Don't test trivial getters/setters or Apple framework behavior. Focus on
  business logic, edge cases, and integration points between components.

---

## Remaining Gaps

The two most release-sensitive services still have **no direct unit tests**. Both are called out in
the engineering audit (`docs/audits/AUDIT_2026-06-06.md`) as the highest-value missing coverage.

### 1. `StoreKitSubscriptionService` — `CookSavvy/Services/Subscription/StoreKitSubscriptionService.swift`

**Why test it:** It gates all paid features and the free trial. Trial-state and entitlement bugs
either hand out premium for free or hide the "7 days free" badge — both directly hit revenue.

Suggested cases (drive via StoreKit `Transaction`/`Product` test fixtures or a protocol seam):
- Active subscription → `isPremium == true` and the correct tier is reported.
- Expired / cancelled entitlement → reverts to free.
- Introductory-offer eligibility correctly reflected in trial-state reporting.
- Foreground refresh (`scenePhase`) re-evaluates entitlements after an out-of-app cancellation.

> Note: `MockSubscriptionServiceTests` exercises the *mock*, not the real StoreKit-backed service.

### 2. `DataImportService` — `CookSavvy/DataImport/DataImportService.swift`

**Why test it:** Startup dataset import. Silent failure here means an empty/partial recipe DB on
first launch with no error surfaced.

Suggested cases:
- Successful end-to-end import: bundle lookup → decode → DB insertion; row count matches fixture.
- Missing/renamed bundle resource → throws (not a silent no-op).
- Malformed JSON record → handled per the documented policy (skip-with-log vs fail-fast), asserted explicitly.

**Implementation hints:** Mock `DBInterfaceProtocol`; use a small bundled JSON fixture rather than
the full production dataset. `RecipeDatasetReaderTests` and `DatabaseInitializationServiceTests`
already cover adjacent layers — test `DataImportService`'s own orchestration, not theirs.

---

## Mock Inventory

Shared mocks in `CookSavvyTests/Mocks/`:

| Mock | Protocol | File |
|------|----------|------|
| `MockUserDataService` | `UserDataServiceProtocol` | `Mocks/MockUserDataService.swift` |
| `MockShoppingListService` | `ShoppingListServiceProtocol` | `Mocks/MockShoppingListService.swift` |
| `MockSupabaseClientProvider` | Supabase client provider | `Mocks/MockSupabaseClientProvider.swift` |
| `MockDatabaseInitService`, `MockIngredientsService`, `MockRecipeService`, `MockRecommendationService`, `MockCameraScanTracker`, `MockImageService` | respective protocols | `Mocks/MockServices.swift` |
| `MockSubscriptionService` | `SubscriptionServiceProtocol` | main target (reused in tests) |
| `MockDBInterface` | `DBInterfaceProtocol` | inline in test files |
| `MockURLProtocol` | URL interception | `NetworkServiceTests.swift` |
