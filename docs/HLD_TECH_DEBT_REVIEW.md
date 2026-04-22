# HLD Tech Debt Review

Reviewed against `docs/HLD.md` and the current implementation.

Context: the HLD is useful as a map, but it is stale in several places. The app is still in development, has no users, and does not need backwards-compatible database migrations yet. That makes this the right time to simplify schema and identity choices instead of preserving historical shapes.

## Highest-Risk Findings

### 1. Supabase auth has real Swift 6 concurrency debt

The build warns that `SupabaseAuthService.isAnonymous` reads actor-isolated state from a `nonisolated` context, and the initializer calls an actor-isolated method synchronously.

Evidence:

- `CookSavvy/Services/Auth/SupabaseAuthService.swift:35`
- `CookSavvy/Services/Auth/SupabaseAuthService.swift:50`

Risk: Xcode currently builds, but the warning says this becomes an error in Swift 6 language mode.

Recommendation: fix actor isolation before it becomes a toolchain blocker. Avoid exposing `clientProvider` access through nonisolated computed properties unless the underlying dependency is safely nonisolated.

### 2. Recipe identity is inconsistent

The HLD says `Recipe` is keyed by title, the database uses integer ids, and the Swift model exposes `id` as `title`. User data then resolves recipes with `SELECT id FROM recipes WHERE title = ? LIMIT 1`.

Evidence:

- `docs/HLD.md:210`
- `CookSavvy/Services/Database/DBInterface.swift:119`
- `CookSavvy/Models/Recipe.swift:90`
- `CookSavvy/Services/Database/DBInterface.swift:944`

Risk: favorites, recents, cooking history, cache entries, and online recipe inserts can attach to the wrong row when titles collide or duplicate remote recipes are cached.

Recommendation: because there are no users, change this now. Give `Recipe` a stable DB id or UUID, or enforce a deliberate unique key such as `(normalized_title, source)`.

### 3. Online and AI recipes are cached without upsert or uniqueness

`insertRecipes` does plain `INSERT`, while `RecipeService` stores every non-offline result. Repeated searches can grow duplicate rows. The in-memory recipe cache is also keyed only by title.

Evidence:

- `CookSavvy/Services/Database/DBInterface.swift:432`
- `CookSavvy/Services/Recipe/RecipeService.swift:183`
- `CookSavvy/Services/Database/DBInterface.swift:390`

Risk: duplicated rows, ambiguous favorites/history, and stale cache entries.

Recommendation: pair the identity redesign with an upsert/dedup policy. If remote recipes are cached locally, define whether title/source, external id, or generated UUID is canonical.

### 4. Premium/source gating is mostly client-side in visible code

Discover filters source access using `SubscriptionService`, but the Supabase providers simply invoke edge functions.

Evidence:

- `CookSavvy/Views/Discover/DiscoverViewModel.swift:454`
- `CookSavvy/Services/Supabase/SupabaseRecipeAPIProvider.swift:30`
- `CookSavvy/Services/Supabase/SupabaseLLMProvider.swift:35`
- `CookSavvy/Services/Supabase/SupabaseClientProvider.swift:29`

Risk: if edge functions do not independently enforce auth, subscription, and rate limits, clients can bypass premium gating.

Recommendation: verify or add server-side enforcement in Supabase edge functions. Client-side gates are UI hints only.

### 5. Premium recipe search can skip local DB readiness

Discover waits for recipes only when the active source set is exactly `[.offline]`. Premium users search with offline, online, and AI together, so offline can be queried before import finishes.

Evidence:

- `CookSavvy/Services/Recipe/RecipeSourceProtocol.swift:49`
- `CookSavvy/Views/Discover/DiscoverViewModel.swift:407`
- `CookSavvy/Services/Recipe/RecipeService.swift:160`

Risk: premium users can get fewer offline results during startup and inconsistent search behavior.

Recommendation: if offline is included in the source set, wait for offline readiness. Then fetch independent sources in parallel rather than sequentially.

### 6. Discover full-screen dismissal destroys navigation/search state

Any full-screen cover dismissal in Discover resets the navigation path and sets `showResults` to false. This affects both camera and cook mode.

Evidence:

- `CookSavvy/Coordinators/DiscoverCoordinator.swift:231`

Risk: finishing cook mode from recipe details can unexpectedly pop the user back and clear results.

Recommendation: make dismissal behavior destination-specific. Camera dismissal and cook mode dismissal should not share the same state reset.

### 7. Startup/import work is async-shaped but still potentially blocking

`DatabaseInitializationService` starts an unstructured task, polls readiness, and calls synchronous import/parsing work from async APIs.

Evidence:

- `CookSavvy/Services/Database/DatabaseInitializationService.swift:57`
- `CookSavvy/Services/Database/DatabaseInitializationService.swift:112`
- `CookSavvy/Services/Ingredient/IngredientsService.swift:203`
- `CookSavvy/DataImport/DataImportService.swift:77`

Risk: startup responsiveness and state readiness are harder to reason about.

Recommendation: since there are no users, prefer a simpler destructive dev reset/seed path over accumulating ad hoc migration/import checks. Move heavy parsing/import work off main-sensitive paths.

### 8. StoreKit state can temporarily unlock from stale cache

`StoreKitSubscriptionService` loads a cached plan immediately, then refreshes asynchronously. Transaction updates also happen from `Task.detached`.

Evidence:

- `CookSavvy/Services/Subscription/StoreKitSubscriptionService.swift:27`
- `CookSavvy/Services/Subscription/StoreKitSubscriptionService.swift:129`
- `CookSavvy/Services/Subscription/StoreKitSubscriptionService.swift:154`

Risk: cached premium can temporarily unlock features before current StoreKit entitlements are verified.

Recommendation: isolate the service, likely with `@MainActor`, and treat cached premium as display-only until entitlements are verified.

### 9. Dependency injection is still partly a service locator

The HLD presents `AppContainer` as DI, but it is a singleton and some views read it directly.

Evidence:

- `docs/HLD.md:68`
- `CookSavvy/App/AppContainer.swift:15`
- `CookSavvy/Views/Shared/TabContainerView.swift:13`
- `CookSavvy/Views/Shared/AsyncImageDisk.swift:85`

Risk: hidden dependencies, harder tests, and a split architecture where some dependencies are explicit and others are global.

Recommendation: pass the container or narrower dependencies from the app root and coordinators. Keep shared views dependency-free where possible.

### 10. The database boundary is too broad

`DBInterfaceProtocol` spans ingredients, recipes, recents, favorites, sessions, shopping list, stats, and database management.

Evidence:

- `CookSavvy/Services/Database/DBInterfaceProtocol.swift:35`

Risk: unrelated feature changes share a large protocol and implementation surface.

Recommendation: split into focused repositories, for example:

- `RecipeRepository`
- `IngredientRepository`
- `UserHistoryRepository`
- `ShoppingListRepository`
- `CookingSessionRepository`

Because there are no users, also consider replacing the current `CREATE TABLE IF NOT EXISTS` plus one-off `ALTER TABLE` development flow with a clean schema reset.

## Stale HLD Notes

### Build matrix is stale

The HLD says DEBUG/UI testing uses mock LLM and offline API. Current normal DEBUG can use Supabase when keys are configured. Only UI testing forces mocks.

Evidence:

- `docs/HLD.md:830`
- `CookSavvy/App/AppContainer.swift:74`
- `CookSavvy/App/AppContainer.swift:206`

### Camera scan reset wording is stale or imprecise

The HLD says scans reset on Monday, but `CameraScanTracker` uses `Calendar.current.weekOfYear`, which is locale-dependent. Journey hardcodes Monday-first labels while service date ranges also use `Calendar.current`.

Evidence:

- `docs/HLD.md:39`
- `CookSavvy/Services/Subscription/CameraScanTracker.swift:43`
- `CookSavvy/Views/Journey/JourneyViewModel.swift:108`
- `CookSavvy/Services/UserData/UserDataService.swift:222`

### ViewModel state counts are stale

The HLD says `DiscoverViewModel` has 16 `@Published` properties and `JourneyViewModel` has 11. Current code has more in both.

Evidence:

- `docs/HLD.md:884`
- `CookSavvy/Views/Discover/DiscoverViewModel.swift:7`
- `docs/HLD.md:896`
- `CookSavvy/Views/Journey/JourneyViewModel.swift:14`

### Achievement detail is stale

The HLD says `fridge_cleaner` has max progress 1. The code says 5.

Evidence:

- `docs/HLD.md:258`
- `CookSavvy/Models/Achievement.swift:119`

## Recommended Order

1. Fix `SupabaseAuthService` actor isolation warnings.
2. Redesign recipe identity and dedup/upsert behavior while migrations are irrelevant.
3. Verify/enforce server-side Supabase auth, subscription, and rate limits.
4. Fix Discover full-screen dismissal and DB readiness for premium searches.
5. Refactor `DBInterface` into repositories and remove singleton access from views.
6. Update `docs/HLD.md` after the above, or mark it explicitly as stale/generated.

## Verification

Build command used during review:

```bash
xcodebuild -scheme CookSavvy -destination 'generic/platform=iOS Simulator' build
```

Result: build succeeded. UI tests were not run.
