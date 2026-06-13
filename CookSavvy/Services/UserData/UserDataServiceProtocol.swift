import Foundation

/// Protocol defining the contract for managing all user-specific data in CookSavvy.
///
/// Covers recent activity (ingredients, recipes, searches), favorites, cooking sessions,
/// user-created recipes, aggregate stats, and UI preferences. The concrete implementation
/// (`UserDataService`) stores session data in the GRDB SQLite database and persists
/// lightweight preferences in `UserDefaults`.
protocol UserDataServiceProtocol: AnyObject, Sendable {
    /// - SeeAlso: `UserDataService.getRecentIngredients(limit:)`
    func getRecentIngredients(limit: Int) async throws -> [Ingredient]
    /// - SeeAlso: `UserDataService.getPopularIngredients(limit:)`
    func getPopularIngredients(limit: Int) async throws -> [Ingredient]
    /// - SeeAlso: `UserDataService.recordIngredientUsage(_:)`
    func recordIngredientUsage(_ ingredients: [Ingredient]) async throws
    /// - SeeAlso: `UserDataService.getRecentRecipes(limit:)`
    func getRecentRecipes(limit: Int) async throws -> [Recipe]
    /// - SeeAlso: `UserDataService.getRecipe(byID:)`
    func getRecipe(byID id: Int) async throws -> Recipe?
    /// - SeeAlso: `UserDataService.recordRecipeView(_:)`
    func recordRecipeView(_ recipe: Recipe) async throws
    /// - SeeAlso: `UserDataService.getFavorites()`
    func getFavorites() async throws -> [Recipe]
    /// - SeeAlso: `UserDataService.getSavedRecipes()`
    func getSavedRecipes() async throws -> [Recipe]
    /// - SeeAlso: `UserDataService.toggleFavorite(_:)`
    func toggleFavorite(_ recipe: Recipe) async throws -> Bool
    /// - SeeAlso: `UserDataService.isFavorite(_:)`
    func isFavorite(_ recipe: Recipe) async throws -> Bool
    /// - SeeAlso: `UserDataService.getRecentSearches(limit:)`
    func getRecentSearches(limit: Int) async throws -> [[Ingredient]]
    /// - SeeAlso: `UserDataService.recordSearch(ingredients:)`
    func recordSearch(ingredients: [Ingredient]) async throws
    /// - SeeAlso: `UserDataService.markAsCooked(recipe:duration:rating:)`
    func markAsCooked(recipe: Recipe, duration: TimeInterval?, rating: Int?) async throws
    /// - SeeAlso: `UserDataService.getCookingSessions(limit:)`
    func getCookingSessions(limit: Int) async throws -> [CookingSession]
    /// - SeeAlso: `UserDataService.getWeekCookingDates()`
    func getWeekCookingDates() async throws -> [Date]
    /// - SeeAlso: `UserDataService.currentStreak()`
    func currentStreak() async throws -> Int
    /// - SeeAlso: `UserDataService.totalCookingTime()`
    func totalCookingTime() async throws -> TimeInterval
    /// - SeeAlso: `UserDataService.recipesCooked()`
    func recipesCooked() async throws -> Int
    /// - SeeAlso: `UserDataService.getUserRecipes()`
    func getUserRecipes() async throws -> [Recipe]
    /// - SeeAlso: `UserDataService.getUserRecipeCount()`
    func getUserRecipeCount() async throws -> Int
    /// - SeeAlso: `UserDataService.getDistinctIngredientsUsedCount()`
    func getDistinctIngredientsUsedCount() async throws -> Int
    /// - SeeAlso: `UserDataService.monthlyRecipesCooked()`
    func monthlyRecipesCooked() async throws -> Int
    /// - SeeAlso: `UserDataService.monthlyIngredientsRescued()`
    func monthlyIngredientsRescued() async throws -> Int
    /// - SeeAlso: `UserDataService.monthlyCookingInsights()`
    func monthlyCookingInsights() async throws -> MonthlyCookingInsights
    /// - SeeAlso: `UserDataService.getHighMatchRecipesCookedCount()`
    func getHighMatchRecipesCookedCount() -> Int
    /// - SeeAlso: `UserDataService.getThemePreference()`
    func getThemePreference() -> ThemePreference
    /// - SeeAlso: `UserDataService.setThemePreference(_:)`
    func setThemePreference(_ themePreference: ThemePreference)
    /// - SeeAlso: `UserDataService.saveUserRecipe(_:)`
    func saveUserRecipe(_ recipe: Recipe) async throws
    /// - SeeAlso: `UserDataService.updateUserRecipe(_:)`
    func updateUserRecipe(_ recipe: Recipe) async throws
    /// - SeeAlso: `UserDataService.deleteUserRecipe(recipe:)`
    func deleteUserRecipe(recipe: Recipe) async throws
    /// - SeeAlso: `UserDataService.clearRecentData()`
    func clearRecentData() async throws
    /// - SeeAlso: `UserDataService.clearFavorites()`
    func clearFavorites() async throws
}

/// Convenience overloads that supply the default limits documented in `UserDataServiceConstants`.
extension UserDataServiceProtocol {
    // Defaults must stay in sync with UserDataService.Constants
    /// Fetches recent ingredients using the default limit (10).
    func getRecentIngredients() async throws -> [Ingredient] {
        try await getRecentIngredients(limit: 10)
    }

    /// Fetches popular ingredients using the default limit (10).
    func getPopularIngredients() async throws -> [Ingredient] {
        try await getPopularIngredients(limit: 10)
    }

    /// Fetches recent recipes using the default limit (20).
    func getRecentRecipes() async throws -> [Recipe] {
        try await getRecentRecipes(limit: 20)
    }

    /// Fetches recent searches using the default limit (10).
    func getRecentSearches() async throws -> [[Ingredient]] {
        try await getRecentSearches(limit: 10)
    }

    /// Fetches cooking sessions using the default limit (50).
    func getCookingSessions() async throws -> [CookingSession] {
        try await getCookingSessions(limit: 50)
    }

    /// Records a recipe as cooked with a duration but no rating.
    func markAsCooked(recipe: Recipe, duration: TimeInterval?) async throws {
        try await markAsCooked(recipe: recipe, duration: duration, rating: nil)
    }
}
