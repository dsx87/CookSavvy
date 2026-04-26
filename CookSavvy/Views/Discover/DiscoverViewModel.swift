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
/// - Loading homepage content: recent/saved/suggested recipes and curated collections
/// - Delegating all navigation to `DiscoverCoordinator` via a weak reference
@MainActor
final class DiscoverViewModel: ObservableObject {
    // MARK: - Published State

    /// The ingredients the user has tapped to include in their recipe search.
    @Published var selectedIngredients: [Ingredient] = []
    /// Ingredients the user has marked as pantry staples and always has available.
    @Published var pantryIngredients: [Ingredient] = []
    /// The currently active mood filter applied to recipe results (`nil` = no filter).
    @Published var selectedMood: RecipeMood? = nil
    /// The active cook-time bucket applied to recipe results (`nil` = no time filter).
    @Published var selectedCookTimeFilter: RecipeCookTimeFilter? = nil
    /// The active complexity level applied to recipe results (`nil` = no difficulty filter).
    @Published var selectedComplexityFilter: RecipeComplexityFilter? = nil
    /// Text entered in the ingredient search bar; triggers a debounced ingredient grid refresh.
    @Published var searchText = "" {
        didSet {
            guard searchText != oldValue else { return }
            scheduleIngredientRefresh()
        }
    }
    /// The ingredient category chip selected to filter the ingredient grid (`nil` = all categories).
    @Published var selectedCategory: IngredientCategory? = nil {
        didSet {
            guard selectedCategory != oldValue else { return }
            scheduleIngredientRefresh()
        }
    }
    private var categoryIngredients: [Ingredient] = []
    private var loadedCategory: IngredientCategory?
    private var ingredientRefreshTask: Task<Void, Never>?
    private var pantryMutationTask: Task<Void, Never>?
    private var ingredientRefreshToken = 0

    /// High-frequency ingredients shown at the top of the grid, populated from user history or DB.
    @Published var popularIngredients: [Ingredient] = []
    /// Recipes the user has recently cooked, shown in the homepage carousel.
    @Published var recentRecipes: [Recipe] = []
    /// Recipes the user has bookmarked/saved, shown in the homepage carousel.
    @Published var savedRecipes: [Recipe] = []
    /// Raw search results from `RecipeService`; filtered by `filteredRecipes` before display.
    @Published var searchResultRecipes: [Recipe] = []
    /// `true` while a multi-source recipe search is in flight.
    @Published var isSearching = false
    /// Non-`nil` when the recipe search partially or fully failed; drives an inline error banner.
    @Published var searchError: String? = nil
    /// Non-`nil` when loading home content failed; drives a top-of-screen error banner.
    @Published var homeLoadError: String? = nil
    /// `true` while initial ingredient data is being fetched from the database.
    @Published var isLoadingIngredients = false
    /// `true` when the screen is in the results state; `false` for ingredient-selection state.
    @Published var showResults = false
    /// When `true`, results are narrowed to recipes where no ingredients are missing.
    @Published var useItAllFilter = false
    /// AI-powered personalised recipe suggestions derived from the user's cooking history.
    @Published var suggestedRecipes: [Recipe] = []
    /// Human-readable explanation of why `suggestedRecipes` was chosen.
    @Published var suggestionReason: String? = nil
    /// The set of dietary restrictions currently toggled on; used to post-filter recipe results.
    @Published var activeDietaryRestrictions: Set<DietaryRestriction> = []
    /// Curated weekly recipe collections shown on the homepage.
    @Published var collections: [CuratedCollection] = []
    /// ID of the collection currently being loaded; non-`nil` while a collection fetch is in progress.
    @Published var loadingCollectionID: String? = nil
    /// Controls visibility of the ingredient match info popover.
    @Published var isMatchInfoPopoverPresented = false

    // MARK: - Dependencies

    private let ingredientsService: IngredientsServiceProtocol
    private let recipeService: RecipeServiceProtocol
    private let userDataService: UserDataServiceProtocol
    private let subscriptionService: SubscriptionServiceProtocol
    private let databaseInitService: DatabaseInitializationServiceProtocol
    private let cameraScanTracker: CameraScanTrackerProtocol
    private let pantryService: PantryServiceProtocol
    private let recommendationService: RecipeRecommendationServiceProtocol
    private let analyticsService: AnalyticsServiceProtocol
    private let logger: any LoggerProtocol
    private let dietaryPreferences: DietaryPreferencesProtocol
    private let curatedCollectionService: CuratedCollectionServiceProtocol
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
        recommendationService: RecipeRecommendationServiceProtocol,
        analyticsService: AnalyticsServiceProtocol,
        logger: any LoggerProtocol,
        dietaryPreferences: DietaryPreferencesProtocol,
        curatedCollectionService: CuratedCollectionServiceProtocol,
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
        self.recommendationService = recommendationService
        self.analyticsService = analyticsService
        self.logger = logger
        self.dietaryPreferences = dietaryPreferences
        self.curatedCollectionService = curatedCollectionService
        self.initialIngredients = initialIngredients
        self.coordinator = coordinator
    }

    // MARK: - Computed

    /// `true` when at least one ingredient has been selected.
    var hasIngredients: Bool { !selectedIngredients.isEmpty }

    /// Explicit selected ingredients plus pantry staples, deduplicated case-insensitively.
    ///
    /// Discover requires at least one explicit selected ingredient to start a search, but pantry
    /// staples are included once a search is running so match scoring treats them as available.
    var effectiveSearchIngredients: [Ingredient] {
        Self.deduplicatedIngredients(selectedIngredients + pantryIngredients)
    }

    /// `true` when the homepage has no content to display (no recent, saved, or suggested recipes).
    var isDiscoverEmpty: Bool {
        !hasIngredients &&
        recentRecipes.isEmpty &&
        savedRecipes.isEmpty &&
        suggestedRecipes.isEmpty
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
    @Published var shownIngredients: [Ingredient] = [] {
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
        guard !searchResultRecipes.isEmpty else { return [] }

        let rankedRecipes = RecipeMatchRanker.rank(searchResultRecipes, mood: selectedMood)

        var filtered: [Recipe]
        if activeDietaryRestrictions.isEmpty {
            filtered = rankedRecipes
        } else {
            let blockedKeywords = activeDietaryRestrictions.flatMap { $0.filterKeywords }
            filtered = rankedRecipes.filter { recipe in
                let ingredients = recipe.cleanedIngredients.isEmpty ? recipe.ingredients : recipe.cleanedIngredients
                let ingredientText = ingredients.map { $0.name.lowercased() }.joined(separator: " ")
                return !blockedKeywords.contains { ingredientText.contains($0) }
            }
        }

        if let selectedCookTimeFilter {
            filtered = filtered.filter { recipe in
                guard let minutes = recipe.cookTimeMinutes else { return false }
                return selectedCookTimeFilter.includes(minutes)
            }
        }

        if let selectedComplexityFilter {
            filtered = filtered.filter { recipe in
                guard let complexity = recipe.firstComplexityLabel else { return false }
                return selectedComplexityFilter.matches(complexity)
            }
        }

        if useItAllFilter {
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

        let recipeIngredients = recipe.cleanedIngredients.isEmpty ? recipe.ingredients : recipe.cleanedIngredients
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

    /// The section header label for the ingredient grid — the selected category name or a generic label.
    var ingredientGridLabel: String {
        if let selectedCategory {
            return selectedCategory.rawValue.uppercased()
        }
        return Strings.Discover.allIngredients
    }

    /// Categories exposed in the Discover chip row, excluding the catch-all bucket.
    var visibleCategories: [IngredientCategory] {
        IngredientCategory.allCases.filter { $0 != .other }
    }

    /// Returns `true` when the category chip should render as selected.
    func isCategorySelected(_ category: IngredientCategory) -> Bool {
        selectedCategory == category
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

        let total = recipe.cleanedIngredients.isEmpty ? recipe.ingredients.count : recipe.cleanedIngredients.count
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

    /// Loads all homepage data concurrently: popular ingredients, recent/saved recipes, suggestions, and collections.
    /// Waits for database readiness when required, then pre-loads any `initialIngredients`.
    func loadInitialData() async {
        isLoadingIngredients = true
        homeLoadError = nil
        loadCollections()
        async let ingredientsTask: () = loadIngredients()
        async let pantryTask: () = loadPantryItems()
        async let recentTask: () = loadRecentRecipes()
        async let savedTask: () = loadSavedRecipes()
        _ = await (ingredientsTask, pantryTask, recentTask, savedTask)
        isLoadingIngredients = false
        if let initialIngredients, !initialIngredients.isEmpty {
            self.initialIngredients = nil
            preloadIngredients(initialIngredients)
        }
        Task { await loadSuggestions() }
        Task { await reloadOnDatabaseReady() }
    }

    /// Immediately selects the given ingredients and triggers a recipe search.
    ///
    /// Used when the Camera or Onboarding screen hands off detected ingredients to Discover.
    /// - Parameter ingredients: The ingredients to pre-select and search with.
    func preloadIngredients(_ ingredients: [Ingredient]) {
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

    /// Navigates to a curated collection's recipe list.
    /// Waits for the database to finish seeding before fetching recipes, and debounces concurrent taps.
    func showCollection(_ collection: CuratedCollection) {
        guard loadingCollectionID == nil else { return }
        loadingCollectionID = collection.id
        Task {
            defer { loadingCollectionID = nil }
            await databaseInitService.waitForRecipes()
            let recipes = (try? await curatedCollectionService.getRecipes(for: collection)) ?? []
            coordinator?.showRecipeList(title: collection.title, recipes: recipes)
        }
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

    /// Waits for the database to finish seeding, then refreshes all homepage content.
    /// No-op if the database is already ready at call time.
    private func reloadOnDatabaseReady() async {
        guard !databaseInitService.state.isRecipesReady else { return }
        await databaseInitService.waitForRecipes()
        homeLoadError = nil
        async let ingredientsTask: () = loadIngredients()
        async let pantryTask: () = loadPantryItems()
        async let recentTask: () = loadRecentRecipes()
        async let savedTask: () = loadSavedRecipes()
        async let suggestionsTask: () = loadSuggestions()
        _ = await (ingredientsTask, pantryTask, recentTask, savedTask, suggestionsTask)
    }

    /// Loads the curated collections appropriate for this week, filtered by subscription tier.
    private func loadCollections() {
        let isPremium = subscriptionService.canAccessFeature(.onlineRecipes)
        collections = curatedCollectionService.getCollectionsForThisWeek(isPremium: isPremium)
    }

    /// Fetches popular ingredients from `UserDataService` and fills in missing emoji via `IngredientEmojiProvider`.
    private func loadIngredients() async {
        do {
            var ingredients = try await userDataService.getPopularIngredients()
            IngredientEmojiProvider.fillIngredientsWithEmoji(&ingredients)
            popularIngredients = ingredients
            shownIngredients = ingredients
        } catch {
            logger.error("Failed to load discover ingredients: \(String(describing: error))")
            homeLoadError = Strings.Errors.loadFailed
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

    /// Fetches the most recently viewed/cooked recipes for the homepage carousel (capped at 6).
    private func loadRecentRecipes() async {
        do {
            recentRecipes = try await userDataService.getRecentRecipes(limit: 6)
        } catch {
            logger.error("Failed to load discover recent recipes: \(String(describing: error))")
            homeLoadError = Strings.Errors.loadFailed
        }
    }

    /// Fetches saved/bookmarked recipes for the homepage carousel.
    private func loadSavedRecipes() async {
        do {
            savedRecipes = try await userDataService.getSavedRecipes()
        } catch {
            logger.error("Failed to load discover saved recipes: \(String(describing: error))")
            homeLoadError = Strings.Errors.loadFailed
        }
    }

    /// Fetches personalised recipe suggestions from `RecipeRecommendationService`.
    private func loadSuggestions() async {
        do {
            let result = try await recommendationService.getSuggestions()
            suggestedRecipes = result.recipes
            suggestionReason = result.reason
        } catch {
            logger.error("Failed to load discover suggestions: \(String(describing: error))")
        }
    }

    /// Runs a multi-source recipe search for the currently selected ingredients.
    ///
    /// Annotates each result with missing-ingredient and match-reason data via `RecipeMatchExplainer`.
    /// Sets `searchError` for partial source failures; clears `searchResultRecipes` on total failure.
    private func searchRecipes() async {
        guard hasIngredients else { return }
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
            var results = rawResults
            for index in results.indices {
                let breakdown = RecipeMatchExplainer.ingredientBreakdown(
                    recipe: results[index],
                    selectedIngredients: ingredients
                )
                let missing = breakdown.missingIngredientNames
                results[index].missingIngredients = missing
                results[index].assumedPantryIngredients = breakdown.assumedPantryIngredientNames
                results[index].matchReason = RecipeMatchExplainer.explain(
                    recipe: results[index],
                    missingIngredients: missing
                )
            }
            searchResultRecipes = results
            if hadSourceFailures {
                searchError = rawResults.isEmpty
                    ? Strings.Discover.searchFailedMessage
                    : Strings.Discover.searchErrorMessage
            }
        } catch {
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
            if let category {
                if loadedCategory != category || categoryIngredients.isEmpty {
                    let fetchedIngredients = try await ingredientsService.getAllIngredients(category: category)
                    guard isCurrentRefresh(token) else { return }
                    categoryIngredients = fetchedIngredients
                    loadedCategory = category
                }

                guard isCurrentRefresh(token) else { return }
                shownIngredients = filterCategoryIngredients(categoryIngredients, query: query)
            } else {
                let fetchedIngredients = try await ingredientsService.searchFullIngredients(matching: query)
                guard isCurrentRefresh(token) else { return }
                loadedCategory = nil
                categoryIngredients = []
                shownIngredients = fetchedIngredients
            }
        } catch {
            guard isCurrentRefresh(token) else { return }
            logger.error("Failed to refresh discover ingredients: \(String(describing: error))")
        }
    }

    /// Filters a pre-fetched ingredient list by a search query (case-insensitive contains).
    private func filterCategoryIngredients(_ ingredients: [Ingredient], query: String) -> [Ingredient] {
        guard !query.isEmpty else { return ingredients }
        return ingredients.filter { ingredient in
            ingredient.name.localizedCaseInsensitiveContains(query)
        }
    }

    /// Returns `true` if the given token matches the live refresh token and the task has not been cancelled.
    private func isCurrentRefresh(_ token: Int) -> Bool {
        !Task.isCancelled && token == ingredientRefreshToken
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
