import SwiftUI

@MainActor
final class DiscoverViewModel: ObservableObject {

    // MARK: - Published State

    @Published var selectedIngredients: [Ingredient] = []
    @Published var selectedMood: RecipeMood? = nil
    @Published var searchText = "" {
        didSet {
            guard searchText != oldValue else { return }
            scheduleIngredientRefresh()
        }
    }
    @Published var selectedCategory: IngredientCategory? = nil {
        didSet {
            guard selectedCategory != oldValue else { return }
            scheduleIngredientRefresh()
        }
    }
    private var categoryIngredients: [Ingredient] = []
    private var loadedCategory: IngredientCategory?
    private var ingredientRefreshTask: Task<Void, Never>?
    private var ingredientRefreshToken = 0

    @Published var popularIngredients: [Ingredient] = []
    @Published var recentRecipes: [Recipe] = []
    @Published var savedRecipes: [Recipe] = []
    @Published var searchResultRecipes: [Recipe] = []
    @Published var isSearching = false
    @Published var isLoadingIngredients = false
    @Published var showResults = false

    // MARK: - Dependencies

    private let ingredientsService: IngredientsService
    private let recipeService: RecipeService
    private let userDataService: UserDataService
    private let subscriptionService: SubscriptionServiceProtocol
    private let databaseInitService: DatabaseInitializationService
    private weak var coordinator: DiscoverCoordinator?

    // MARK: - Init

    init(
        ingredientsService: IngredientsService,
        recipeService: RecipeService,
        userDataService: UserDataService,
        subscriptionService: SubscriptionServiceProtocol,
        databaseInitService: DatabaseInitializationService,
        coordinator: DiscoverCoordinator
    ) {
        self.ingredientsService = ingredientsService
        self.recipeService = recipeService
        self.userDataService = userDataService
        self.subscriptionService = subscriptionService
        self.databaseInitService = databaseInitService
        self.coordinator = coordinator
    }

    // MARK: - Computed

    var hasIngredients: Bool { !selectedIngredients.isEmpty }

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return Strings.Discover.greetingMorning
        case 12..<17: return Strings.Discover.greetingAfternoon
        case 17..<21: return Strings.Discover.greetingEvening
        default: return Strings.Discover.greetingLateNight
        }
    }
    @Published var shownIngredients: [Ingredient] = [] {
        didSet {
            if shownIngredients.isEmpty {
                shownIngredients = popularIngredients
            }
        }
    }

    var filteredRecipes: [Recipe] {
        guard !searchResultRecipes.isEmpty else { return [] }
        guard let selectedMood else {
            return searchResultRecipes
        }

        return RecipeMoodRanker.rank(searchResultRecipes, for: selectedMood)
    }

    var bestMatch: Recipe? {
        filteredRecipes.first
    }

    var moreRecipes: [Recipe] {
        Array(filteredRecipes.dropFirst())
    }

    func matchingIngredientNames(for recipe: Recipe) -> [String] {
        let queryNames = Set(selectedIngredients.map { Self.normalizedIngredientName($0.name) }.filter { !$0.isEmpty })
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

    var ingredientGridLabel: String {
        if let selectedCategory {
            return selectedCategory.rawValue.uppercased()
        }
        return Strings.Discover.allIngredients
    }

    // MARK: - Actions

    func loadInitialData() async {
        isLoadingIngredients = true
        async let ingredientsTask: () = loadIngredients()
        async let recentTask: () = loadRecentRecipes()
        async let savedTask: () = loadSavedRecipes()
        _ = await (ingredientsTask, recentTask, savedTask)
        isLoadingIngredients = false
    }

    func toggleIngredient(_ ingredient: Ingredient) {
        if let idx = selectedIngredients.firstIndex(where: { $0.id == ingredient.id }) {
            selectedIngredients.remove(at: idx)
        } else {
            selectedIngredients.append(ingredient)
        }
        
        if showResults {
            Task { await searchRecipes() }
        }
        
        if !hasIngredients {
            showResults = false
            searchResultRecipes = []
            selectedMood = nil
        }
        //searchText = ""
    }

    func removeIngredient(_ ingredient: Ingredient) {
        selectedIngredients.removeAll { $0.id == ingredient.id }
        
        if showResults {
            Task { await searchRecipes() }
        }
        
        if !hasIngredients {
            showResults = false
            searchResultRecipes = []
            selectedMood = nil
        }
    }

    func clearIngredients() {
        selectedIngredients.removeAll()
        searchResultRecipes = []
        selectedMood = nil
        showResults = false
    }

    func findRecipes() {
        guard hasIngredients else { return }
        showResults = true
        Task { await searchRecipes() }
    }

    func toggleMood(_ mood: RecipeMood) {
        selectedMood = selectedMood == mood ? nil : mood
    }

    func toggleCategory(_ category: IngredientCategory) {
        selectedCategory = selectedCategory == category ? nil : category
    }

    // MARK: - Navigation

    func showRecipeDetails(_ recipe: Recipe) {
        coordinator?.showRecipeDetails(recipe: recipe)
    }

    func showRecipeList(title: String, recipes: [Recipe]) {
        coordinator?.showRecipeList(title: title, recipes: recipes)
    }

    func showCreateRecipe() {
        coordinator?.showCreateRecipe()
    }

    func showCamera() {
        guard subscriptionService.canAccessFeature(.cameraIngredientDetection) else {
            coordinator?.showUpgrade()
            return
        }
        coordinator?.showCamera()
    }

    // MARK: - Private

    private func loadIngredients() async {
        do {
            popularIngredients = try await userDataService.getPopularIngredients()
            shownIngredients = popularIngredients
            IngredientEmojiProvider.fillIngredientsWithEmoji(&popularIngredients)
        } catch {}
    }

    private func loadRecentRecipes() async {
        do {
            recentRecipes = try await userDataService.getRecentRecipes(limit: 6)
        } catch {}
    }

    private func loadSavedRecipes() async {
        do {
            savedRecipes = try await userDataService.getSavedRecipes()
        } catch {}
    }

    private func searchRecipes() async {
        guard hasIngredients else { return }
        isSearching = true
        do {
            let enabledSources = accessibleEnabledSources()
            if shouldWaitForRecipeImport(for: enabledSources) {
                await databaseInitService.waitForRecipes()
            }
            searchResultRecipes = try await recipeService.getRecipes(
                for: selectedIngredients,
                from: enabledSources
            )
        } catch {}
        isSearching = false
    }

    func filteredEnabledSources(
        _ sources: Set<RecipeSourceType>,
        canAccessOnline: Bool,
        canAccessAI: Bool
    ) -> Set<RecipeSourceType> {
        var accessibleSources = sources
        if accessibleSources.contains(.online) && !canAccessOnline {
            accessibleSources.remove(.online)
        }
        if accessibleSources.contains(.ai) && !canAccessAI {
            accessibleSources.remove(.ai)
        }
        return accessibleSources.isEmpty ? [.offline] : accessibleSources
    }

    func shouldWaitForRecipeImport(for enabledSources: Set<RecipeSourceType>) -> Bool {
        enabledSources == [.offline]
    }
    
    private func scheduleIngredientRefresh() {
        ingredientRefreshTask?.cancel()
        ingredientRefreshToken += 1
        let token = ingredientRefreshToken

        ingredientRefreshTask = Task { [weak self] in
            await self?.refreshIngredients(token: token)
        }
    }

    private static func normalizedIngredientName(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func accessibleEnabledSources() -> Set<RecipeSourceType> {
        filteredEnabledSources(
            userDataService.getEnabledSources(),
            canAccessOnline: subscriptionService.canAccessFeature(.onlineRecipes),
            canAccessAI: subscriptionService.canAccessFeature(.aiRecipes)
        )
    }

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
        }
    }

    private func filterCategoryIngredients(_ ingredients: [Ingredient], query: String) -> [Ingredient] {
        guard !query.isEmpty else { return ingredients }
        return ingredients.filter { ingredient in
            ingredient.name.localizedCaseInsensitiveContains(query)
        }
    }

    private func isCurrentRefresh(_ token: Int) -> Bool {
        !Task.isCancelled && token == ingredientRefreshToken
    }
}
