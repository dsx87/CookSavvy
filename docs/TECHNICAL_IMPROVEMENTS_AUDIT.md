# CookSavvy Technical Improvements Audit

This document consolidates a parallel review of the CookSavvy codebase with a focus on **architecture**, **performance**, **readability**, and **maintainability**. The goal is not cosmetic cleanup; it is to reduce change friction, improve testability, and remove the main sources of technical drag.

## Overall assessment

The codebase has a **good foundation**:

- MVVM + Coordinator is applied consistently.
- Most services are protocol-backed and test-friendly.
- Theme, strings, icons, and screen structure are centralized.
- The project already has meaningful unit-test coverage.

The biggest issues are concentrated in a few hotspots:

1. **Global dependency access via `AppContainer.shared` weakens the DI architecture.**
2. **The Discover flow has accumulated too much UI, state, and orchestration logic in one place.**
3. **`DBInterface` has become a large multi-domain data layer with a fat protocol surface.**
4. **Some async APIs still perform synchronous work on the caller thread.**
5. **A few reusable paths bypass the coordinator/container design, which makes the architecture less consistent.**

## Priority summary

| Priority | Area | Why it matters | Main evidence |
| --- | --- | --- | --- |
| P1 | Remove global container access | Restores real dependency injection and improves test isolation | `CookSavvy/App/AppContainer.swift`, `CookSavvy/Views/Shared/TabContainerView.swift`, `CookSavvy/Views/Shared/AsyncImageDisk.swift`, `CookSavvy/Coordinators/AppCoordinator.swift` |
| P1 | Break up Discover feature complexity | Reduces change risk in the app's highest-touch feature | `CookSavvy/Views/Discover/DiscoverView.swift`, `CookSavvy/Views/Discover/DiscoverViewModel.swift` |
| P1 | Split the database boundary by domain | Lowers coupling and makes data logic easier to evolve safely | `CookSavvy/Services/Database/DBInterface.swift`, `CookSavvy/Services/Database/DBInterfaceProtocol.swift` |
| P2 | Move blocking data work off the main actor path | Improves responsiveness during ingredient and recipe operations | `CookSavvy/Services/Ingredient/IngredientsService.swift`, `CookSavvy/Views/Discover/DiscoverViewModel.swift` |
| P2 | Reuse section/navigation abstractions | Reduces duplication and keeps coordinators/view models easier to extend | `CookSavvy/Coordinators/DiscoverCoordinator.swift`, `CookSavvy/Coordinators/JourneyCoordinator.swift`, `CookSavvy/Views/Discover/DiscoverView.swift` |
| P3 | Tighten startup/state orchestration | Makes initialization and screen state transitions easier to reason about | `CookSavvy/Services/Database/DatabaseInitializationService.swift`, `CookSavvy/Coordinators/AppCoordinator.swift` |

## Findings and recommendations

### 1. Global `AppContainer.shared` access is the main architectural leak

The project documents DI as a core pattern, but a few important surfaces still bypass it:

- `AppContainer.shared` is the app-wide singleton in `CookSavvy/App/AppContainer.swift`
- `TabContainerView` pulls `AppContainer.shared` directly
- `AsyncImageDisk` loads images and logging from `AppContainer.shared`
- `AppCoordinator.makeOnboardingViewModel()` also reaches into the singleton directly

This creates a split architecture: some objects are created through coordinators with explicit dependencies, while others quietly fetch global state.

**Why improve it**

- Makes unit tests depend on global mutable setup.
- Hides the real dependency graph.
- Lets views bypass the coordinator/container contracts.
- Makes future modularization harder.

**Recommendation**

- Pass `AppContainer` explicitly from app root to `AppCoordinator`, then to child coordinators and any shared helper views that need services.
- Remove direct `AppContainer.shared` reads from view code.
- Treat `AppContainer` as composition-root infrastructure, not a service locator.

### 2. Discover is carrying too much complexity in both the view and the view model

The Discover flow is clearly a high-value feature, but it has become the main maintainability hotspot:

- `DiscoverView.swift` is one of the largest files in the project.
- `DiscoverViewModel.swift` owns a large amount of published state, search orchestration, filtering, loading, suggestions, collections, and presentation flags.
- Filtering logic such as `filteredRecipes`, `bestMatch`, and `moreRecipes` sits beside unrelated responsibilities like ingredient refresh and collection loading.

**Why improve it**

- Small feature changes require touching large files with many unrelated concerns.
- State transitions are implicit rather than modeled.
- It is hard to reuse or test parts of the feature in isolation.
- The most active screen is also the hardest place to make safe changes.

**Recommendation**

- Split Discover into smaller subdomains:
  - ingredient selection state
  - recipe search orchestration
  - result filtering/ranking
  - curated collections/suggestions
- Extract reusable section views from `DiscoverView` for repeated horizontal recipe blocks.
- Group view-model state into nested structures such as `SearchState`, `HomeFeedState`, and `FilterState`, or move orchestration into dedicated use-case/services.

### 3. `DBInterface` has grown into a god object

`CookSavvy/Services/Database/DBInterface.swift` is a very large file handling:

- schema creation and migrations
- ingredient queries
- recipe queries and caching
- favorites
- recent items/searches
- cooking sessions
- shopping list storage

Its protocol is also broad, which means many services depend on a large surface even when they only need one domain.

**Why improve it**

- Changes to one data area raise the regression surface for unrelated features.
- Tests and mocks become heavier than necessary.
- SQL, caching, schema, and mapping logic are tightly interleaved.
- Data ownership is unclear at the service level.

**Recommendation**

- Keep a thin database infrastructure layer, but split domain access into focused repositories, for example:
  - `RecipeRepository`
  - `IngredientRepository`
  - `UserHistoryRepository`
  - `ShoppingListRepository`
  - `CookingSessionRepository`
- Narrow service dependencies so each service consumes only the repository interfaces it needs.
- Move recipe cache policy behind the recipe repository instead of keeping it inside the generic DB interface.

### 4. Some async APIs still do synchronous work, and some computed work is too expensive to repeat

There are a few concrete performance issues that are worth addressing early:

- `IngredientsService` exposes async methods but directly performs synchronous DB work through `dbInterface`.
- `getAllIngredients(category:)` does a multi-step lookup and loops over matching groups.
- `DiscoverViewModel.filteredRecipes` recomputes sorting/filtering work from live state.
- `ImageService.prefetchImages(for:)` exists, but shared image loading still relies heavily on per-view tasks through `AsyncImageDisk`.

**Why improve it**

- The app's most interactive flow is search and filtering.
- Repeated filtering and blocking reads are easy ways to create UI lag.
- The fixes are smaller than the architecture refactors and likely give visible wins.

**Recommendation**

- Move expensive DB-backed reads off the caller path where appropriate.
- Cache or memoize derived recipe filtering results when inputs have not changed.
- Batch category/group fetches instead of repeated per-group reads when possible.
- Introduce coordinated image prefetching for visible recipe sections instead of relying only on per-cell loads.

### 5. Shared view and coordinator patterns can be tightened

The coordinator pattern is solid overall, but some patterns are repeated or inconsistent:

- `DiscoverCoordinator` and `JourneyCoordinator` duplicate a lot of factory and presentation wiring.
- Dismiss/navigation behavior is mostly passed with closures.
- Some shared views still pull dependencies globally rather than receiving them explicitly.

**Why improve it**

- Repeated flow wiring makes it easier for the two tabs to drift apart.
- Navigation intent is harder to test when expressed as ad hoc closures everywhere.
- Shared infrastructure becomes less predictable.

**Recommendation**

- Standardize navigation communication behind small intent-style coordinator protocols where it helps.
- Extract repeated coordinator factory patterns only where they genuinely reduce duplication.
- Keep shared views dependency-free unless they explicitly accept a dependency or view model.

### 6. Startup and screen state orchestration can be made more explicit

`DatabaseInitializationService` is straightforward, but it coordinates staged readiness with polling-style waits. `AppCoordinator` also lazily creates and retains child coordinators while onboarding state and pending ingredients are handled at the root.

This works, but it leaves state ownership slightly implicit.

**Recommendation**

- Consider a clearer startup/app-state model for onboarding, database readiness, and initial tab flow.
- Prefer explicit readiness propagation over polling loops where practical.
- Document which state belongs to app root, feature root, and screen root.

## Suggested implementation order

### First wave

1. Remove `AppContainer.shared` usage from views/coordinators that can receive dependencies explicitly.
2. Decompose Discover into smaller state and UI units.
3. Memoize or restructure expensive recipe filtering paths.

### Second wave

1. Introduce domain repositories around `DBInterface`.
2. Narrow service dependencies to smaller protocols.
3. Improve image/data prefetch paths for recipe-heavy screens.

### Third wave

1. Revisit startup/state orchestration.
2. Standardize navigation intent patterns where closures are becoming noisy.
3. Add focused tests around coordinator/state transitions during refactors.

## What is already working well

- The codebase already prefers protocols for core services.
- Coordinator ownership is generally clear.
- Theme and localization infrastructure is stronger than average for a project of this size.
- The project structure is understandable, and the technical debt is concentrated rather than chaotic.

## Bottom line

CookSavvy does **not** need a wholesale rewrite. The right move is a targeted refactor plan focused on:

1. **making dependency flow explicit**
2. **shrinking the Discover feature into clearer units**
3. **splitting the database layer by domain**
4. **removing avoidable synchronous and repeated work from the most interactive paths**

Those changes would improve architecture, readability, and performance at the same time, while preserving the overall app design that is already working.
