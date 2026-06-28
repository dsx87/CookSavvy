import SwiftUI

/// Single-select cook-time buckets for client-side Discover result filtering.
///
/// Each bucket operates on `Recipe.cookTimeMinutes`, so recipes with missing or
/// unparseable cook times remain visible until the user actively chooses a time filter.
enum RecipeCookTimeFilter: Int, CaseIterable, Identifiable {
    case quick = 0
    case medium = 1
    case long = 2

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .quick:
            return Strings.RecipeFilter.quick
        case .medium:
            return Strings.RecipeFilter.mediumTime
        case .long:
            return Strings.RecipeFilter.long
        }
    }

    func includes(_ minutes: Int) -> Bool {
        switch self {
        case .quick:
            return minutes < 30
        case .medium:
            return (30...60).contains(minutes)
        case .long:
            return minutes > 60
        }
    }
}

/// Single-select recipe complexity filter for Discover results.
///
/// Matching is intentionally case-insensitive because recipe metadata can arrive
/// from local dataset data or backend providers with different capitalization.
enum RecipeComplexityFilter: String, CaseIterable, Identifiable {
    case easy
    case medium
    case hard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .easy:
            return Strings.RecipeFilter.easy
        case .medium:
            return Strings.RecipeFilter.mediumDifficulty
        case .hard:
            return Strings.RecipeFilter.hard
        }
    }

    func matches(_ complexity: String) -> Bool {
        complexity.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(rawValue) == .orderedSame
    }
}

/// Display-ready metadata label for the Discover featured recipe hero.
struct DiscoverHeroLabel: Identifiable {
    let id: String
    let title: String
    let icon: String
}

/// Display-ready match badge content for the Discover featured recipe hero.
struct DiscoverMatchBadgeState {
    let label: String
    let matchingIngredients: [String]
}

/// ViewModel backing the Discover screen — the app's primary recipe discovery flow.
///
/// Manages a two-state UI: the ingredient-selection landing screen and the recipe-results screen.
/// Key responsibilities:
/// - Loading and filtering the ingredient grid (popular, by category, by search query, debounced)
/// - Maintaining the set of user-selected ingredients
/// - Executing multi-source recipe searches (offline, online, AI) gated by subscription tier
/// - Applying mood, dietary restriction, and "use it all" post-fetch filters on `filteredRecipes`
/// - Delegating all navigation to `DiscoverCoordinator` via a weak reference
@Observable final class DiscoverViewModel {
    // MARK: - Observable State

    /// The ingredients the user has tapped to include in their recipe search.
    var selectedIngredients: [Ingredient] = []
    /// Ingredients the user has marked as pantry staples and always has available.
    var pantryIngredients: [Ingredient] = []
    /// The currently active mood filter applied to recipe results (`nil` = no filter).
    var selectedMood: RecipeMood? = nil
    /// The active cook-time bucket applied to recipe results (`nil` = no time filter).
    var selectedCookTimeFilter: RecipeCookTimeFilter? = nil
    /// The active complexity level applied to recipe results (`nil` = no difficulty filter).
    var selectedComplexityFilter: RecipeComplexityFilter? = nil
    /// Text entered in the ingredient search bar; triggers a debounced ingredient grid refresh.
    var searchText = "" {
        didSet {
            guard searchText != oldValue else { return }
            scheduleIngredientRefresh()
        }
    }
    /// The ingredient category chip selected to filter the ingredient grid (`nil` = all categories).
    var selectedCategory: IngredientCategory? = nil {
        didSet {
            guard selectedCategory != oldValue else { return }
            scheduleIngredientRefresh()
        }
    }
    private var categoryIngredients: [Ingredient] = []
    private var loadedCategory: IngredientCategory?
    @ObservationIgnored private var ingredientRefreshTask: Task<Void, Never>?
    @ObservationIgnored private var pantryMutationTask: Task<Void, Never>?
    private var ingredientRefreshToken = 0
    /// Monotonic token guarding `searchRecipes` / `searchBrowseRecipes` against stale overwrites: a
    /// slower earlier search whose token no longer matches the live value is discarded instead of
    /// clobbering a newer result. Mirrors `ingredientRefreshToken` / `isCurrentRefresh`.
    private var searchToken = 0
    /// Memoised `filteredRecipes` result keyed on its six inputs; recomputed only when the key changes.
    @ObservationIgnored private var filteredRecipesCache: (key: FilteredRecipesKey, value: [Recipe])?

    /// High-frequency ingredients shown at the top of the grid, populated from user history or DB.
    var popularIngredients: [Ingredient] = []
    /// Raw search results from `RecipeService`; filtered by `filteredRecipes` before display.
    var searchResultRecipes: [Recipe] = []
    /// `true` while a multi-source recipe search is in flight.
    var isSearching = false
    /// Non-`nil` when the recipe search partially or fully failed; drives an inline error banner.
    var searchError: String? = nil
    /// Non-`nil` when loading home content failed; drives a top-of-screen error banner.
    var homeLoadError: String? = nil
    /// `true` while initial ingredient data is being fetched from the database.
    var isLoadingIngredients = false
    /// `true` when the screen is in the results state; `false` for ingredient-selection state.
    var showResults = false
    /// When `true`, results are narrowed to recipes where no ingredients are missing.
    var useItAllFilter = false
    /// The set of dietary restrictions currently toggled on; used to post-filter recipe results.
    var activeDietaryRestrictions: Set<DietaryRestriction> = []
    /// Controls visibility of the ingredient match info popover.
    var isMatchInfoPopoverPresented = false
    /// `true` while the search bar text field has keyboard focus; drives the suggestions popup.
    var isSearchFocused: Bool = false
    /// Captured height of the rendered search bar; used to offset the suggestions popup correctly.
    var searchBarHeight: CGFloat = 47
    /// Ingredient matches for the inline search suggestions popup; populated while the search bar has
    /// non-empty text. Already-selected ingredients are excluded so tapping always adds, never removes.
    var ingredientSuggestions: [Ingredient] = []
    /// `true` while the smart-search service is parsing a natural-language query.
    var isParsingQuery = false

    // MARK: - Dependencies

    private let ingredientsService: IngredientsServiceProtocol
    private let recipeService: RecipeServiceProtocol
    private let userDataService: UserDataServiceProtocol
    private let subscriptionService: SubscriptionServiceProtocol
    private let databaseInitService: DatabaseInitializationServiceProtocol
    private let cameraScanTracker: CameraScanTrackerProtocol
    private let pantryService: PantryServiceProtocol
    private let analyticsService: AnalyticsServiceProtocol
    private let logger: any LoggerProtocol
    private let dietaryPreferences: DietaryPreferencesProtocol
    private let smartSearchService: SmartSearchServiceProtocol?
    private var initialIngredients: [Ingredient]?
    private weak var coordinator: DiscoverCoordinator?

    // MARK: - Init

    /// Creates the discover view model with required services and optional preselected ingredients.
    init(
        ingredientsService: IngredientsServiceProtocol,
        recipeService: RecipeServiceProtocol,
        userDataService: UserDataServiceProtocol,
        subscriptionService: SubscriptionServiceProtocol,
        databaseInitService: DatabaseInitializationServiceProtocol,
        cameraScanTracker: CameraScanTrackerProtocol,
        pantryService: PantryServiceProtocol,
        analyticsService: AnalyticsServiceProtocol,
        logger: any LoggerProtocol,
        dietaryPreferences: DietaryPreferencesProtocol,
        smartSearchService: SmartSearchServiceProtocol? = nil,
        initialIngredients: [Ingredient]? = nil,
        coordinator: DiscoverCoordinator? = nil
    ) {
        self.ingredientsService = ingredientsService
        self.recipeService = recipeService
        self.userDataService = userDataService
        self.subscriptionService = subscriptionService
        self.databaseInitService = databaseInitService
        self.cameraScanTracker = cameraScanTracker
        self.pantryService = pantryService
        self.analyticsService = analyticsService
        self.logger = logger
        self.dietaryPreferences = dietaryPreferences
        self.smartSearchService = smartSearchService
        self.initialIngredients = initialIngredients
        self.coordinator = coordinator
    }

    deinit {
        ingredientRefreshTask?.cancel()
        pantryMutationTask?.cancel()
    }

    // MARK: - Computed

    /// `true` when at least one ingredient has been selected.
    var hasIngredients: Bool { !selectedIngredients.isEmpty }

    /// `true` when a smart-search service is available; used by the view to show the Smart Search row.
    var hasSmartSearch: Bool { smartSearchService != nil }

    /// Explicit selected ingredients plus pantry staples, deduplicated case-insensitively.
    ///
    /// Discover requires at least one explicit selected ingredient to start a search, but pantry
    /// staples are included once a search is running so match scoring treats them as available.
    var effectiveSearchIngredients: [Ingredient] {
        Self.deduplicatedIngredients(selectedIngredients + pantryIngredients)
    }

    /// `true` when a search has completed but returned no results for the current filters.
    var hasNoResults: Bool {
        !isSearching && searchError == nil && filteredRecipes.isEmpty && showResults
    }

    /// A time-of-day-appropriate greeting string (morning / afternoon / evening / late night).
    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return Strings.Discover.greetingMorning
        case 12..<17: return Strings.Discover.greetingAfternoon
        case 17..<21: return Strings.Discover.greetingEvening
        default: return Strings.Discover.greetingLateNight
        }
    }
    /// The ingredients displayed in the grid (popular, category-filtered, or search results).
    /// Resets to `popularIngredients` if assigned an empty array.
    var shownIngredients: [Ingredient] = [] {
        didSet {
            if shownIngredients.isEmpty {
                shownIngredients = popularIngredients
            }
        }
    }

    /// The sorted and post-filtered recipe list derived from `searchResultRecipes`.
    ///
    /// Filtering pipeline:
    /// 1. Applies `RecipeMatchRanker`, optionally refined by `selectedMood`.
    /// 2. Removes recipes containing blocked ingredient keywords for active dietary restrictions.
    /// 3. Applies active cook-time and complexity filters, excluding unknown metadata only while active.
    /// 4. When `useItAllFilter` is on, keeps only perfect-match recipes (falls back to all if none qualify).
    var filteredRecipes: [Recipe] {
        // Read all six inputs up front so `@Observable` registers a dependency on each one on every
        // access — even when the cached value is returned below — otherwise SwiftUI would miss
        // updates when a filter changes.
        let key = FilteredRecipesKey(
            recipes: searchResultRecipes,
            mood: selectedMood,
            dietary: activeDietaryRestrictions,
            cookTime: selectedCookTimeFilter,
            complexity: selectedComplexityFilter,
            useItAll: useItAllFilter
        )
        if let cache = filteredRecipesCache, cache.key == key {
            return cache.value
        }
        let value = Self.computeFilteredRecipes(key)
        filteredRecipesCache = (key, value)
        return value
    }

    /// Cache key for `filteredRecipes`. The pipeline is pure in these six inputs, so an equal key
    /// guarantees an identical result. Must enumerate *every* input the pipeline reads or the cache
    /// would return stale results.
    private struct FilteredRecipesKey: Equatable {
        let recipes: [Recipe]
        let mood: RecipeMood?
        let dietary: Set<DietaryRestriction>
        let cookTime: RecipeCookTimeFilter?
        let complexity: RecipeComplexityFilter?
        let useItAll: Bool
    }

    /// Pure ranking + filtering pipeline backing `filteredRecipes`. Reads nothing but `key`, so the
    /// same key always yields the same result — which is what makes the memoisation above safe.
    private static func computeFilteredRecipes(_ key: FilteredRecipesKey) -> [Recipe] {
        guard !key.recipes.isEmpty else { return [] }

        let rankedRecipes = RecipeMatchRanker.rank(key.recipes, mood: key.mood)

        var filtered: [Recipe]
        if key.dietary.isEmpty {
            filtered = rankedRecipes
        } else {
            let blockedKeywords = key.dietary.flatMap { $0.filterKeywords }
            filtered = rankedRecipes.filter { recipe in
                let ingredientText = recipe.cleanedIngredients.map { $0.name.lowercased() }.joined(separator: " ")
                return !blockedKeywords.contains { ingredientText.contains($0) }
            }
        }

        if let cookTime = key.cookTime {
            filtered = filtered.filter { recipe in
                guard let minutes = recipe.cookTimeMinutes else { return false }
                return cookTime.includes(minutes)
            }
        }

        if let complexity = key.complexity {
            filtered = filtered.filter { recipe in
                guard let label = recipe.firstComplexityLabel else { return false }
                return complexity.matches(label)
            }
        }

        if key.useItAll {
            let perfect = filtered.filter { $0.missingIngredients?.isEmpty == true }
            if !perfect.isEmpty { return perfect }
        }

        return filtered
    }

    /// The top result from `filteredRecipes`, displayed as the hero card.
    var bestMatch: Recipe? {
        filteredRecipes.first
    }

    /// All results after the first, shown in the recipe list below the hero card.
    var moreRecipes: [Recipe] {
        Array(filteredRecipes.dropFirst())
    }

    /// Returns the display names of selected ingredients that also appear in the given recipe.
    ///
    /// Uses bidirectional partial-match after normalising both sides (lowercase, trimmed), so
    /// "chicken breast" matches a recipe ingredient "chicken" and vice-versa.
    /// - Parameter recipe: The recipe to check against the current selection.
    /// - Returns: Unique display names of matching ingredients, preserving the recipe's original casing.
    func matchingIngredientNames(for recipe: Recipe) -> [String] {
        let queryNames = Set(effectiveSearchIngredients.map { Self.normalizedIngredientName($0.name) }.filter { !$0.isEmpty })
        guard !queryNames.isEmpty else { return [] }

        let recipeIngredients = recipe.cleanedIngredients
        var matches: [String] = []
        var seen = Set<String>()

        for ingredient in recipeIngredients {
            let recipeName = Self.normalizedIngredientName(ingredient.name)
            guard !recipeName.isEmpty else { continue }
            let isMatch = queryNames.contains(where: { recipeName.contains($0) || $0.contains(recipeName) })
            guard isMatch else { continue }

            let displayName = ingredient.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !displayName.isEmpty else { continue }
            let seenKey = displayName.lowercased()
            if seen.insert(seenKey).inserted {
                matches.append(displayName)
            }
        }

        return matches
    }

    /// The section header label for the ingredient grid: the selected category name, else "ALL
    /// INGREDIENTS" while a search query is filtering the full catalogue, else "POPULAR" for the
    /// default quick-pick grid.
    var ingredientGridLabel: String {
        if let selectedCategory {
            return selectedCategory.rawValue.uppercased()
        }
        if !searchText.isEmpty {
            return Strings.Discover.allIngredients
        }
        return Strings.Discover.popularIngredients
    }

    /// Categories exposed in the Discover chip row, excluding the catch-all bucket.
    var visibleCategories: [IngredientCategory] {
        IngredientCategory.allCases.filter { $0 != .other }
    }

    /// Returns `true` when the category chip should render as selected.
    func isCategorySelected(_ category: IngredientCategory) -> Bool {
        selectedCategory == category
    }

    /// `true` when the search box is filtering the full catalogue while a category chip is still
    /// selected — the suggestions popup surfaces a hint that the category filter is currently bypassed.
    var isSearchBypassingCategory: Bool {
        selectedCategory != nil && !searchText.isEmpty
    }

    /// Returns `true` when the ingredient bubble should render as selected.
    func isIngredientSelected(_ ingredient: Ingredient) -> Bool {
        selectedIngredients.contains { $0.id == ingredient.id }
    }

    /// Returns `true` when the ingredient is marked as an always-available pantry staple.
    func isIngredientInPantry(_ ingredient: Ingredient) -> Bool {
        pantryIngredients.contains { Self.normalizedIngredientName($0.name) == Self.normalizedIngredientName(ingredient.name) }
    }

    /// Returns `true` when the mood pill should render as selected.
    func isMoodSelected(_ mood: RecipeMood) -> Bool {
        selectedMood == mood
    }

    /// Returns `true` when the cook-time pill should render as selected.
    func isCookTimeFilterSelected(_ filter: RecipeCookTimeFilter) -> Bool {
        selectedCookTimeFilter == filter
    }

    /// Returns `true` when the complexity pill should render as selected.
    func isComplexityFilterSelected(_ filter: RecipeComplexityFilter) -> Bool {
        selectedComplexityFilter == filter
    }

    /// Builds the metadata labels shown over the featured recipe image.
    func heroLabels(for recipe: Recipe) -> [DiscoverHeroLabel] {
        var labels: [DiscoverHeroLabel] = []
        if let cookTime = recipe.firstCookTimeLabel {
            labels.append(DiscoverHeroLabel(id: "time", title: cookTime, icon: Icons.Discover.clock))
        }
        if let complexity = recipe.firstComplexityLabel {
            labels.append(DiscoverHeroLabel(id: "complexity", title: complexity, icon: Icons.Discover.chartBar))
        }
        return labels
    }

    /// Returns the rating value shown over the featured recipe image, if one is available.
    func heroRating(for recipe: Recipe) -> Double? {
        recipe.apiRating ?? recipe.userRating
    }

    /// Builds the match badge state for a featured recipe, or `nil` when the recipe has no match metadata.
    func matchBadgeState(for recipe: Recipe) -> DiscoverMatchBadgeState? {
        guard recipe.missingIngredients != nil || recipe.matchPercentage != nil else { return nil }

        let total = recipe.cleanedIngredients.count
        let missing = recipe.missingIngredients?.count ?? 0
        let matched = max(0, total - missing)
        let label = recipe.missingIngredients?.isEmpty == true
            ? Strings.Discover.matchLabelAll
            : String(format: Strings.Discover.matchLabel, Int64(matched), Int64(total))

        return DiscoverMatchBadgeState(
            label: label,
            matchingIngredients: matchingIngredientNames(for: recipe)
        )
    }

    // MARK: - Actions

    /// Loads the ingredient grid and pantry staples concurrently.
    /// Waits for database readiness when required, then pre-loads any `initialIngredients`.
    func loadInitialData() async {
        isLoadingIngredients = true
        homeLoadError = nil
        async let ingredientsTask: () = loadIngredients()
        async let pantryTask: () = loadPantryItems()
        _ = await (ingredientsTask, pantryTask)
        isLoadingIngredients = false
        if let initialIngredients, !initialIngredients.isEmpty {
            self.initialIngredients = nil
            preloadIngredients(initialIngredients)
        }
        Task { await reloadOnDatabaseReady() }
    }

    /// Immediately selects the given ingredients and triggers a recipe search.
    ///
    /// Used when the Camera or Onboarding screen hands off detected ingredients to Discover.
    /// - Parameter ingredients: The ingredients to pre-select and search with.
    func preloadIngredients(_ ingredients: [Ingredient]) {
        // Drop pantry staples (salt, pepper, …) a scan may detect — they're auto-assumed in matching
        // and never selectable, so they must not become selection chips. An all-staples scan is a no-op.
        let ingredients = PantryStaples.excludingStaples(ingredients)
        guard !ingredients.isEmpty else { return }

        for ingredient in ingredients where !selectedIngredients.contains(ingredient) {
            selectedIngredients.append(ingredient)
        }

        analyticsService.track(.recipeSearchPerformed)
        showResults = true
        Task { await searchRecipes() }
    }

    /// Toggles the selection state of an ingredient and re-runs the search if results are showing.
    /// Clears results and resets result filters when the last ingredient is deselected.
    /// - Parameter ingredient: The ingredient to toggle.
    func toggleIngredient(_ ingredient: Ingredient) {
        if let idx = selectedIngredients.firstIndex(where: { $0.id == ingredient.id }) {
            selectedIngredients.remove(at: idx)
        } else {
            selectedIngredients.append(ingredient)
            // On selection only: surface the pick at the front of the popular grid for this session and
            // record it so popularity persists and personalises across launches. Recording is
            // fire-and-forget — a failure (e.g. an off-catalogue name) is silently skipped by the DB
            // layer and must not block selection. Deselecting does neither.
            promoteToPopularGrid(ingredient)
            Task { [userDataService] in try? await userDataService.recordIngredientUsage([ingredient]) }
        }

        if !hasIngredients {
            showResults = false
            searchResultRecipes = []
            resetResultFilters()
        } else if showResults {
            Task { await searchRecipes() }
        }
        //searchText = ""
    }

    /// Removes a specific ingredient from the selection, refreshing results if they are visible.
    /// - Parameter ingredient: The ingredient to remove.
    func removeIngredient(_ ingredient: Ingredient) {
        selectedIngredients.removeAll { $0.id == ingredient.id }
        
        if !hasIngredients {
            showResults = false
            searchResultRecipes = []
            resetResultFilters()
        } else if showResults {
            Task { await searchRecipes() }
        }
    }

    /// Adds or removes an ingredient from the always-available pantry list.
    ///
    /// Pantry changes do not mutate explicit selection. If results are visible and at least one
    /// explicit ingredient remains selected, the active search is refreshed with the new effective set.
    func togglePantryItem(_ ingredient: Ingredient) {
        let wasPantryItem = isIngredientInPantry(ingredient)
        if wasPantryItem {
            removePantryIngredientLocally(ingredient)
        } else {
            pantryIngredients = Self.deduplicatedIngredients(pantryIngredients + [ingredient])
        }

        let previousMutation = pantryMutationTask
        pantryMutationTask = Task { [weak self] in
            // Preserve tap order across async persistence so rapid toggles cannot replay stale state.
            await previousMutation?.value
            guard let self else { return }
            do {
                if wasPantryItem {
                    try await pantryService.removeItem(ingredient)
                } else {
                    try await pantryService.addItem(ingredient)
                }

                if showResults, hasIngredients {
                    await searchRecipes()
                }
            } catch {
                logger.error("Failed to update pantry item: \(String(describing: error))")
                homeLoadError = Strings.Errors.actionFailed
                if case DatabaseError.ingredientNotFound = error {
                    rollbackOptimisticPantryMutation(for: ingredient, wasPantryItem: wasPantryItem)
                }
                await loadPantryItems()
            }
        }
    }

    /// Clears all selected ingredients and dismisses the results state.
    func clearIngredients() {
        selectedIngredients.removeAll()
        searchResultRecipes = []
        resetResultFilters()
        showResults = false
    }

    /// Parses a natural-language query into structured intent and applies it to the discover state.
    ///
    /// Filters (mood, cook time, complexity, dietary) are applied whenever they are present in the
    /// intent, independent of whether any ingredients were resolved. Ingredient handling then branches:
    /// - Ingredients resolved → replace the current selection, clear the search bar, run a new search.
    /// - No ingredients resolved, but user already has some selected → keep their selection, apply the
    ///   new filters, and re-run the search so results reflect the updated criteria immediately.
    /// - No ingredients resolved and none selected → surface a hint so the user can add ingredients.
    func runSmartSearch(_ query: String) async {
        guard let service = smartSearchService, !query.isEmpty else { return }
        isParsingQuery = true
        // homeLoadError is the only banner visible in State 1; searchError is State-2-only.
        homeLoadError = nil
        defer { isParsingQuery = false }

        do {
            let intent = try await service.parse(query: query)

            // Resolve free-text names to DB Ingredient objects, skipping unrecognised terms.
            var resolved: [Ingredient] = []
            for name in intent.ingredientNames {
                if let ingredient = await resolveIngredient(for: name) {
                    resolved.append(ingredient)
                }
            }

            // Always apply extracted filters — they are independent of ingredient resolution.
            applySmartSearchFilters(intent)

            if !resolved.isEmpty {
                // Ingredients were found: replace selection, clear bar, run search.
                selectedIngredients = resolved
                searchText = ""
                ingredientSuggestions = []
                analyticsService.track(.recipeSearchPerformed)
                showResults = true
                await searchRecipes()
            } else if hasIngredients {
                // No new ingredients but user already has some: re-run with updated filters.
                if showResults {
                    await searchRecipes()
                }
            } else {
                // No ingredients anywhere: browse all local recipes filtered by whatever was extracted.
                analyticsService.track(.recipeSearchPerformed)
                showResults = true
                await searchBrowseRecipes()
            }
        } catch {
            homeLoadError = Strings.Discover.smartSearchFailedMessage
            logger.error("Smart search failed: \(String(describing: error))")
        }
    }

    /// Applies the filter fields from a parsed intent to the current VM state.
    /// Only overwrites a filter when the intent provides a non-nil value, so existing
    /// user selections are preserved when the query doesn't mention that dimension.
    private func applySmartSearchFilters(_ intent: SmartSearchIntent) {
        if let mood = intent.mood { selectedMood = mood }
        if let cookTime = intent.cookTime { selectedCookTimeFilter = cookTime }
        if let complexity = intent.complexity { selectedComplexityFilter = complexity }
        if !intent.dietary.isEmpty { activeDietaryRestrictions = Set(intent.dietary) }
    }

    /// Selects an ingredient from the suggestions popup: adds it, clears the search field, and
    /// dismisses the popup. The ingredient is always added (never removed) because `ingredientSuggestions`
    /// only contains non-selected ingredients.
    func selectSuggestion(_ ingredient: Ingredient) {
        toggleIngredient(ingredient)
        searchText = ""
        ingredientSuggestions = []
    }

    /// Transitions to the results state and starts a recipe search. No-op if no ingredients are selected.
    func findRecipes() {
        guard hasIngredients else { return }
        analyticsService.track(.recipeSearchPerformed)
        showResults = true
        Task { await searchRecipes() }
    }

    /// Re-runs the recipe search after a failure. Convenience wrapper over `findRecipes()`.
    func retrySearch() {
        findRecipes()
    }

    /// Toggles the active mood filter; deselects the mood if it is already active.
    /// - Parameter mood: The mood to toggle.
    func toggleMood(_ mood: RecipeMood) {
        selectedMood = selectedMood == mood ? nil : mood
    }

    /// Toggles a single cook-time filter bucket; selecting the active bucket clears it.
    /// - Parameter filter: The cook-time bucket to toggle.
    func toggleCookTimeFilter(_ filter: RecipeCookTimeFilter) {
        selectedCookTimeFilter = selectedCookTimeFilter == filter ? nil : filter
    }

    /// Toggles a single complexity filter; selecting the active level clears it.
    /// - Parameter filter: The complexity level to toggle.
    func toggleComplexityFilter(_ filter: RecipeComplexityFilter) {
        selectedComplexityFilter = selectedComplexityFilter == filter ? nil : filter
    }

    /// Toggles the active ingredient category; clearing it reverts the grid to all ingredients.
    /// - Parameter category: The category to toggle.
    func toggleCategory(_ category: IngredientCategory) {
        selectedCategory = selectedCategory == category ? nil : category
    }

    /// Clears the selected category. Backs the "searching all ingredients" popup hint so the grid
    /// doesn't snap back to the category once the user clears the search box.
    func clearSelectedCategory() {
        selectedCategory = nil
    }

    /// Clears all result-only filters that should not survive a new empty ingredient state.
    private func resetResultFilters() {
        selectedMood = nil
        selectedCookTimeFilter = nil
        selectedComplexityFilter = nil
    }

    // MARK: - Navigation

    /// Navigates to the recipe detail screen, passing the current ingredient selection for match highlighting.
    func showRecipeDetails(_ recipe: Recipe) {
        coordinator?.showRecipeDetails(recipe: recipe, selectedIngredients: effectiveSearchIngredients)
    }

    /// Navigates to the "See All" recipe list screen.
    func showRecipeList(title: String, recipes: [Recipe]) {
        coordinator?.showRecipeList(title: title, recipes: recipes)
    }

    /// Navigates to the create recipe wizard.
    func showCreateRecipe() {
        coordinator?.showCreateRecipe()
    }

    /// `true` for free-tier users; indicates the weekly scan badge should be shown on the camera button.
    var showScansBadge: Bool {
        !subscriptionService.canAccessFeature(.cameraIngredientDetection)
    }

    /// The number of camera scans remaining this week for free-tier users.
    var remainingCameraScans: Int {
        cameraScanTracker.remainingScans()
    }

    /// Opens the camera, enforcing the free-tier weekly scan quota.
    /// For premium users the quota is bypassed. For free users a scan is deducted on open
    /// (regardless of detection outcome). Redirects to the Upgrade screen when quota is exhausted.
    func showCamera() {
        if subscriptionService.canAccessFeature(.cameraIngredientDetection) {
            analyticsService.track(.cameraScanStarted)
            cameraScanTracker.recordScanWithoutQuota()
            coordinator?.showCamera()
        } else if cameraScanTracker.canScan() {
            analyticsService.track(.cameraScanStarted)
            // Deduct the scan when the camera opens — the attempt is consumed
            // regardless of whether detection returns results.
            cameraScanTracker.recordScan()
            coordinator?.showCamera()
        } else {
            analyticsService.track(.scanLimitHit)
            coordinator?.showUpgrade()
        }
    }

    /// Reloads active dietary restrictions from persistent preferences.
    /// Called on `onAppear` to stay in sync with Settings changes.
    func refreshDietaryRestrictions() {
        activeDietaryRestrictions = dietaryPreferences.activeRestrictions()
    }

    /// Removes a single active dietary restriction and refreshes the live restriction set.
    /// - Parameter restriction: The restriction to disable.
    func removeDietaryRestriction(_ restriction: DietaryRestriction) {
        dietaryPreferences.toggle(restriction)
        activeDietaryRestrictions = dietaryPreferences.activeRestrictions()
    }

    // MARK: - Private

    /// Waits for the database to finish seeding, then refreshes the ingredient grid and pantry staples.
    /// No-op if the database is already ready at call time.
    private func reloadOnDatabaseReady() async {
        guard !databaseInitService.state.isRecipesReady else { return }
        await databaseInitService.waitForRecipes()
        homeLoadError = nil
        async let ingredientsTask: () = loadIngredients()
        async let pantryTask: () = loadPantryItems()
        _ = await (ingredientsTask, pantryTask)
    }

    /// Fetches popular ingredients from `UserDataService` and fills in missing emoji via `IngredientEmojiProvider`.
    private func loadIngredients() async {
        do {
            // Fetch a full grid's worth so the popular section fills its rows; this is also the cap the
            // move-to-front promotion (`promoteToPopularGrid`) trims back to as the user makes picks.
            var ingredients = try await userDataService.getPopularIngredients(limit: UI.Discover.popularIngredientCount)
            IngredientEmojiProvider.fillIngredientsWithEmoji(&ingredients)
            popularIngredients = ingredients
            shownIngredients = ingredients
        } catch {
            logger.error("Failed to load discover ingredients: \(String(describing: error))")
            homeLoadError = Strings.Errors.loadFailed
        }
    }

    /// Moves a freshly selected ingredient to the front of the popular grid (move-to-front / MRU), so
    /// a pick the user just made leads the quick-pick list.
    ///
    /// Any existing occurrence (matched case-insensitively via `normalizedIngredientName`) is removed
    /// before inserting at index 0, so a re-pick promotes rather than duplicates, and the list is
    /// trimmed back to `UI.Discover.popularIngredientCount` — dropping the least-recent tail. Search-
    /// sourced picks arrive without an emoji (`refreshIngredients` doesn't fill emoji for search
    /// results), so any missing emoji is filled (existing entries are skipped).
    ///
    /// When the grid is in its default popular state (no search text, no category) the visible
    /// `shownIngredients` is reassigned so the reorder animates live under the caller's
    /// `withAnimation`; while a category/search filter is active the underlying MRU still updates but
    /// the visible grid stays put until the user returns to the popular state (the empty-array
    /// `shownIngredients` didSet re-surfaces `popularIngredients` then).
    private func promoteToPopularGrid(_ ingredient: Ingredient) {
        let key = Self.normalizedIngredientName(ingredient.name)
        var updated = popularIngredients.filter { Self.normalizedIngredientName($0.name) != key }
        updated.insert(ingredient, at: 0)
        if updated.count > UI.Discover.popularIngredientCount {
            updated.removeLast(updated.count - UI.Discover.popularIngredientCount)
        }
        IngredientEmojiProvider.fillIngredientsWithEmoji(&updated)
        popularIngredients = updated

        if searchText.isEmpty && selectedCategory == nil {
            shownIngredients = popularIngredients
        }
    }

    /// Loads pantry staples that should be merged into Discover searches.
    func loadPantryItems() async {
        do {
            var items = try await pantryService.getItems()
            IngredientEmojiProvider.fillIngredientsWithEmoji(&items)
            pantryIngredients = Self.deduplicatedIngredients(items)
        } catch {
            logger.error("Failed to load pantry ingredients: \(String(describing: error))")
            homeLoadError = Strings.Errors.loadFailed
        }
    }

    /// Removes an ingredient from the optimistic pantry state using the same name identity as persistence.
    private func removePantryIngredientLocally(_ ingredient: Ingredient) {
        pantryIngredients.removeAll {
            Self.normalizedIngredientName($0.name) == Self.normalizedIngredientName(ingredient.name)
        }
    }

    /// Restores local pantry state when persistence rejects an optimistic pantry toggle.
    private func rollbackOptimisticPantryMutation(for ingredient: Ingredient, wasPantryItem: Bool) {
        if wasPantryItem {
            pantryIngredients = Self.deduplicatedIngredients(pantryIngredients + [ingredient])
        } else {
            removePantryIngredientLocally(ingredient)
        }
    }

    /// Runs a multi-source recipe search for the currently selected ingredients.
    ///
    /// Annotates each result with missing-ingredient and match-reason data via `RecipeMatchExplainer`.
    /// Sets `searchError` for partial source failures; clears `searchResultRecipes` on total failure.
    private func searchRecipes() async {
        guard hasIngredients else { return }
        searchToken += 1
        let token = searchToken
        isSearching = true
        searchError = nil
        do {
            let enabledSources = accessibleEnabledSources()
            if RecipeSourceType.requiresDatabaseReady(enabledSources) {
                await databaseInitService.waitForRecipes()
            }
            let ingredients = effectiveSearchIngredients
            let (rawResults, hadSourceFailures) = try await recipeService.getRecipes(
                for: ingredients,
                from: enabledSources
            )
            // Discard a stale search whose results a newer search has already superseded. The guard
            // sits immediately after the only suspension point so the annotation + assignment below
            // run synchronously on main with the token still current.
            guard isCurrentSearch(token) else { return }
            let results = Self.annotateMatches(rawResults, selectedIngredients: ingredients)
            searchResultRecipes = results
            if hadSourceFailures {
                searchError = rawResults.isEmpty
                    ? Strings.Discover.searchFailedMessage
                    : Strings.Discover.searchErrorMessage
            }
        } catch {
            guard isCurrentSearch(token) else { return }
            searchResultRecipes = []
            searchError = Strings.Discover.searchFailedMessage
        }
        isSearching = false
    }

    /// Annotates raw search results with missing-ingredient and match-reason data via
    /// `RecipeMatchExplainer`. Pure and `nonisolated`, so it stays cheap and could be hoisted off
    /// main later if a large ingredient-search result set ever warrants it.
    private nonisolated static func annotateMatches(
        _ recipes: [Recipe],
        selectedIngredients: [Ingredient]
    ) -> [Recipe] {
        var results = recipes
        for index in results.indices {
            let breakdown = RecipeMatchExplainer.ingredientBreakdown(
                recipe: results[index],
                selectedIngredients: selectedIngredients
            )
            let missing = breakdown.missingIngredientNames
            results[index].missingIngredients = missing
            results[index].assumedPantryIngredients = breakdown.assumedPantryIngredientNames
            results[index].matchReason = RecipeMatchExplainer.explain(
                recipe: results[index],
                missingIngredients: missing
            )
        }
        return results
    }

    /// Fetches all local recipes for ingredient-free smart searches (e.g. "give me something quick").
    ///
    /// No ingredient match data is annotated — `missingIngredients` stays nil, so match badges are
    /// suppressed. The existing `filteredRecipes` pipeline applies any active mood/time/complexity/dietary
    /// filters on top of the raw results, and `RecipeMatchRanker` uses cook time, complexity, and rating
    /// as tiebreakers, naturally surfacing simpler and higher-rated recipes first.
    private func searchBrowseRecipes() async {
        searchToken += 1
        let token = searchToken
        isSearching = true
        searchError = nil
        do {
            await databaseInitService.waitForRecipes()
            let results = try await recipeService.getAllRecipes(limit: UI.Discover.browseRecipeLimit)
            guard isCurrentSearch(token) else { return }
            searchResultRecipes = results
        } catch {
            guard isCurrentSearch(token) else { return }
            searchResultRecipes = []
            searchError = Strings.Discover.searchFailedMessage
        }
        isSearching = false
    }

    /// Debounces ingredient grid refresh requests to avoid thrashing the database on rapid input.
    /// Cancels any pending refresh before scheduling a new one with a unique token.
    private func scheduleIngredientRefresh() {
        ingredientRefreshTask?.cancel()
        ingredientRefreshToken += 1
        let token = ingredientRefreshToken

        ingredientRefreshTask = Task { [weak self] in
            await self?.refreshIngredients(token: token)
        }
    }

    /// Lowercases and trims whitespace from an ingredient name for fuzzy-match comparisons.
    private static func normalizedIngredientName(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Deduplicates ingredient arrays by normalized name while preserving first-seen order.
    private static func deduplicatedIngredients(_ ingredients: [Ingredient]) -> [Ingredient] {
        var seen = Set<String>()
        var result: [Ingredient] = []
        result.reserveCapacity(ingredients.count)
        for ingredient in ingredients {
            let key = normalizedIngredientName(ingredient.name)
            guard !key.isEmpty, seen.insert(key).inserted else { continue }
            result.append(ingredient)
        }
        return result
    }
    /// Returns the recipe source types the current user is entitled to query,
    /// based on their subscription plan.
    private func accessibleEnabledSources() -> Set<RecipeSourceType> {
        RecipeSourceType.accessible(
            from: Set(RecipeSourceType.allCases),
            canAccessOnline: subscriptionService.canAccessFeature(.onlineRecipes),
            canAccessAI: subscriptionService.canAccessFeature(.aiRecipes)
        )
    }

    /// Loads and filters the ingredient grid for the current category and search query.
    ///
    /// Caches category results to avoid re-fetching when only the search query changes.
    /// Discards stale results via `token` if a newer refresh has started.
    /// - Parameter token: Refresh token; must match `ingredientRefreshToken` for results to be applied.
    private func refreshIngredients(token: Int) async {
        let category = selectedCategory
        let query = searchText

        do {
            if !query.isEmpty {
                // A search query always queries the full catalogue, regardless of any selected
                // category, so typing always surfaces what the user types (e.g. "garlic" while the
                // "Grains" chip is selected). The category only governs the grid when the box is empty.
                let fetchedIngredients = try await ingredientsService.searchFullIngredients(matching: query)
                guard isCurrentRefresh(token) else { return }
                shownIngredients = fetchedIngredients
                ingredientSuggestions = makeSuggestions(from: fetchedIngredients, query: query)
            } else if let category {
                if loadedCategory != category || categoryIngredients.isEmpty {
                    var fetchedIngredients = try await ingredientsService.getAllIngredients(category: category)
                    guard isCurrentRefresh(token) else { return }
                    // Match the popular-grid treatment so category bubbles render with emoji too.
                    IngredientEmojiProvider.fillIngredientsWithEmoji(&fetchedIngredients)
                    categoryIngredients = fetchedIngredients
                    loadedCategory = category
                }

                guard isCurrentRefresh(token) else { return }
                shownIngredients = categoryIngredients
                ingredientSuggestions = []
            } else {
                let fetchedIngredients = try await ingredientsService.searchFullIngredients(matching: query)
                guard isCurrentRefresh(token) else { return }
                loadedCategory = nil
                categoryIngredients = []
                shownIngredients = fetchedIngredients
                ingredientSuggestions = makeSuggestions(from: fetchedIngredients, query: query)
            }
        } catch {
            guard isCurrentRefresh(token) else { return }
            ingredientSuggestions = []
            logger.error("Failed to refresh discover ingredients: \(String(describing: error))")
        }
    }

    /// Resolves a free-text ingredient name from the LLM to a local database `Ingredient` object.
    /// Uses prefix/FTS search and takes the best match; returns `nil` if no match is found.
    private func resolveIngredient(for name: String) async -> Ingredient? {
        guard !name.isEmpty else { return nil }
        return try? await ingredientsService.searchFullIngredients(matching: name, limit: 1).first
    }

    /// Builds the popup suggestion list from a fetched ingredient set for the given query.
    /// Returns an empty array when the query is empty; otherwise excludes already-selected ingredients.
    private func makeSuggestions(from ingredients: [Ingredient], query: String) -> [Ingredient] {
        guard !query.isEmpty else { return [] }
        let selectedIDs = Set(selectedIngredients.map { $0.id })
        return ingredients.filter { !selectedIDs.contains($0.id) }
    }

    /// Returns `true` if the given token matches the live refresh token and the task has not been cancelled.
    private func isCurrentRefresh(_ token: Int) -> Bool {
        !Task.isCancelled && token == ingredientRefreshToken
    }

    /// Returns `true` if `token` is still the live search token, i.e. no newer search has started.
    /// Used to discard stale `searchRecipes` / `searchBrowseRecipes` results before they overwrite a
    /// newer search's output.
    private func isCurrentSearch(_ token: Int) -> Bool {
        token == searchToken
    }
}

private extension Recipe {
    /// The first cook-time label stored on the recipe, if provided by its source.
    var firstCookTimeLabel: String? {
        for info in additionalInfo.infos {
            if case .time(let cookTime) = info {
                return cookTime
            }
        }
        return nil
    }

    /// The first complexity label stored on the recipe, if provided by its source.
    var firstComplexityLabel: String? {
        for info in additionalInfo.infos {
            if case .complexity(let complexity) = info {
                return complexity
            }
        }
        return nil
    }
}
