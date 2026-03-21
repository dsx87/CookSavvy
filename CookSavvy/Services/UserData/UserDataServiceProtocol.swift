import Foundation

protocol UserDataServiceProtocol: AnyObject {
    func getRecentIngredients(limit: Int) async throws -> [Ingredient]
    func getPopularIngredients(limit: Int) async throws -> [Ingredient]
    func recordIngredientUsage(_ ingredients: [Ingredient]) async throws
    func getRecentRecipes(limit: Int) async throws -> [Recipe]
    func recordRecipeView(_ recipe: Recipe) async throws
    func getFavorites() async throws -> [Recipe]
    func getSavedRecipes() async throws -> [Recipe]
    func toggleFavorite(_ recipe: Recipe) async throws -> Bool
    func isFavorite(_ recipe: Recipe) async throws -> Bool
    func getRecentSearches(limit: Int) async throws -> [[Ingredient]]
    func recordSearch(ingredients: [Ingredient]) async throws
    func markAsCooked(recipe: Recipe, duration: TimeInterval?, rating: Int?) async throws
    func getCookingSessions(limit: Int) async throws -> [CookingSession]
    func getWeekCookingDates() async throws -> [Date]
    func currentStreak() async throws -> Int
    func totalCookingTime() async throws -> TimeInterval
    func recipesCooked() async throws -> Int
    func getUserRecipes() async throws -> [Recipe]
    func getUserRecipeCount() async throws -> Int
    func getDistinctIngredientsUsedCount() async throws -> Int
    func monthlyRecipesCooked() async throws -> Int
    func monthlyIngredientsRescued() async throws -> Int
    func getThemePreference() -> ThemePreference
    func setThemePreference(_ themePreference: ThemePreference)
    func saveUserRecipe(_ recipe: Recipe) async throws
    func updateUserRecipe(_ recipe: Recipe) async throws
    func deleteUserRecipe(recipe: Recipe) async throws
    func clearRecentData() async throws
    func clearFavorites() async throws
    func getEnabledSources() -> Set<RecipeSourceType>
    func setEnabledSources(_ sources: Set<RecipeSourceType>)
    func isSourceEnabled(_ source: RecipeSourceType) -> Bool
    func toggleSource(_ source: RecipeSourceType) -> Bool
}

extension UserDataServiceProtocol {
    // Defaults must stay in sync with UserDataService.Constants
    func getRecentIngredients() async throws -> [Ingredient] {
        try await getRecentIngredients(limit: 10)
    }

    func getPopularIngredients() async throws -> [Ingredient] {
        try await getPopularIngredients(limit: 10)
    }

    func getRecentRecipes() async throws -> [Recipe] {
        try await getRecentRecipes(limit: 20)
    }

    func getRecentSearches() async throws -> [[Ingredient]] {
        try await getRecentSearches(limit: 10)
    }

    func getCookingSessions() async throws -> [CookingSession] {
        try await getCookingSessions(limit: 50)
    }

    func markAsCooked(recipe: Recipe, duration: TimeInterval?) async throws {
        try await markAsCooked(recipe: recipe, duration: duration, rating: nil)
    }
}
