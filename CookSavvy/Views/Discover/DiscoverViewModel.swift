import SwiftUI

@MainActor
final class DiscoverViewModel: ObservableObject {

    struct MoodOption: Identifiable {
        let id: Int
        let name: String
        let icon: String
        let color: Color
        let gradient: [Color]
    }

    // MARK: - Published State

    @Published var selectedIngredients: [Ingredient] = []
    @Published var selectedMoodID: Int? = nil
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
    private weak var coordinator: DiscoverCoordinator?

    // MARK: - Init

    init(
        ingredientsService: IngredientsService,
        recipeService: RecipeService,
        userDataService: UserDataService,
        subscriptionService: SubscriptionServiceProtocol,
        coordinator: DiscoverCoordinator
    ) {
        self.ingredientsService = ingredientsService
        self.recipeService = recipeService
        self.userDataService = userDataService
        self.subscriptionService = subscriptionService
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
        if let selectedMoodID, selectedMoodID < Self.moods.count {
            return searchResultRecipes
        }
        return searchResultRecipes
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

    static let moods: [MoodOption] = [
        .init(id: 0, name: Strings.MoodFilter.cozy, icon: Icons.Mood.cozy, color: Color(red: 1.0, green: 0.55, blue: 0.20),
              gradient: [Color(red: 1.0, green: 0.55, blue: 0.20), Color(red: 0.85, green: 0.30, blue: 0.15)]),
        .init(id: 1, name: Strings.MoodFilter.fresh, icon: Icons.Mood.fresh, color: Color(red: 0.30, green: 0.85, blue: 0.72),
              gradient: [Color(red: 0.30, green: 0.85, blue: 0.72), Color(red: 0.15, green: 0.65, blue: 0.55)]),
        .init(id: 2, name: Strings.MoodFilter.bold, icon: Icons.Mood.bold, color: Color(red: 0.95, green: 0.35, blue: 0.50),
              gradient: [Color(red: 0.95, green: 0.35, blue: 0.50), Color(red: 0.75, green: 0.20, blue: 0.40)]),
        .init(id: 3, name: Strings.MoodFilter.comfort, icon: Icons.Mood.comfort, color: Color(red: 0.65, green: 0.50, blue: 0.95),
              gradient: [Color(red: 0.65, green: 0.50, blue: 0.95), Color(red: 0.45, green: 0.30, blue: 0.80)]),
        .init(id: 4, name: Strings.MoodFilter.quick, icon: Icons.Mood.quick, color: Color(red: 0.35, green: 0.65, blue: 1.0),
              gradient: [Color(red: 0.35, green: 0.65, blue: 1.0), Color(red: 0.20, green: 0.45, blue: 0.85)]),
    ]

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
            selectedMoodID = nil
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
            selectedMoodID = nil
        }
    }

    func clearIngredients() {
        selectedIngredients.removeAll()
        searchResultRecipes = []
        selectedMoodID = nil
        showResults = false
    }

    func findRecipes() {
        guard hasIngredients else { return }
        showResults = true
        Task { await searchRecipes() }
    }

    func toggleMood(_ moodID: Int) {
        selectedMoodID = selectedMoodID == moodID ? nil : moodID
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
            savedRecipes = try await userDataService.getFavorites()
        } catch {}
    }

    private func searchRecipes() async {
        guard hasIngredients else { return }
        isSearching = true
        do {
            let enabledSources = userDataService.getEnabledSources()
            searchResultRecipes = try await recipeService.getRecipes(
                for: selectedIngredients,
                from: enabledSources
            )
        } catch {}
        isSearching = false
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
