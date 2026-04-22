import Foundation

/// Constants that control recommendation sampling and scoring behaviour.
private enum RecommendationConstants {
    static let defaultLimit = 5
    static let sessionSampleLimit = 20
    static let recentSessionWindow = 10
    static let candidateLimit = 20
    static let favoriteWeight = 2
    static let highlyRatedThreshold = 4
    static let highlyRatedWeight = 2
    static let standardSessionWeight = 1
}

/// Generates personalised recipe suggestions based on the user's cooking history and favourites.
///
/// ## Algorithm
///
/// 1. Fetch up to `sessionSampleLimit` recent cooking sessions and all favourites in parallel.
/// 2. Build an `ingredientCounts` frequency map by scanning each recipe's ingredients and title
///    against a curated list of `knownIngredients` (protein and staple keywords).
///    - Ingredients in **favourites** contribute `favoriteWeight` (2) — stronger signal.
///    - Ingredients in **sessions** contribute `highlyRatedWeight` (2) if the session rating
///      is ≥ `highlyRatedThreshold` (4), otherwise `standardSessionWeight` (1).
/// 3. Identify the single top-scoring ingredient (`topIngredient`).
/// 4. Query the database for up to `candidateLimit` recipes containing `topIngredient`.
/// 5. Filter out recipes cooked in the most recent `recentSessionWindow` (10) sessions
///    to avoid repetition.
/// 6. Return up to `limit` recipes with a localised reason string explaining the suggestion.
final class RecipeRecommendationService: RecipeRecommendationServiceProtocol {
    /// Provides access to the user's cooking history and favourites.
    private let userDataService: UserDataServiceProtocol
    /// Database interface used to query candidate recipes.
    private let dbInterface: DBInterfaceProtocol
    /// Awaited before querying to ensure the bundled recipe dataset is loaded.
    private let databaseInitService: DatabaseInitializationServiceProtocol

    /// Protein and staple ingredient keywords scanned against recipe titles and ingredient names
    /// when building the frequency map. Kept small and high-signal to avoid noise.
    private static let knownIngredients = [
        "chicken", "beef", "pork", "lamb", "fish", "salmon", "tuna",
        "shrimp", "turkey", "tofu", "lentil", "pasta", "rice",
        "potato", "mushroom", "tomato", "egg", "noodle"
    ]

    /// - Parameters:
    ///   - userDataService: Source of cooking history and favourites.
    ///   - dbInterface: Database used to fetch candidate recipes.
    ///   - databaseInitService: Awaited to ensure recipe data is seeded before querying.
    init(
        userDataService: UserDataServiceProtocol,
        dbInterface: DBInterfaceProtocol,
        databaseInitService: DatabaseInitializationServiceProtocol
    ) {
        self.userDataService = userDataService
        self.dbInterface = dbInterface
        self.databaseInitService = databaseInitService
    }

    /// Returns personalised recipe suggestions with a human-readable reason string.
    ///
    /// Returns an empty result (not an error) when the user has no history or favourites,
    /// or when no known ingredient appears in their history.
    /// - Parameter limit: Maximum number of recipes to return (default: 5).
    /// - Returns: Up to `limit` suggested recipes and an optional localised reason string
    ///   such as "Suggested because you often cook with Chicken".
    /// - Throws: Errors from `UserDataService` or `DBInterface` reads.
    func getSuggestions(limit: Int = RecommendationConstants.defaultLimit) async throws -> (recipes: [Recipe], reason: String?) {
        await databaseInitService.waitForRecipes()

        async let favoritesTask = userDataService.getFavorites()
        async let sessionsTask = userDataService.getCookingSessions(limit: RecommendationConstants.sessionSampleLimit)
        let (favorites, sessions) = try await (favoritesTask, sessionsTask)

        guard !favorites.isEmpty || !sessions.isEmpty else { return ([], nil) }

        var ingredientCounts: [String: Int] = [:]

        for recipe in favorites {
            let ingredients = recipe.cleanedIngredients.isEmpty ? recipe.ingredients : recipe.cleanedIngredients
            for ingredient in ingredients {
                let nameLower = ingredient.name.lowercased()
                for keyword in Self.knownIngredients where nameLower.contains(keyword) {
                    ingredientCounts[keyword, default: 0] += RecommendationConstants.favoriteWeight
                    break
                }
            }
        }

        for session in sessions {
            let weight = (session.rating ?? 0) >= RecommendationConstants.highlyRatedThreshold
                ? RecommendationConstants.highlyRatedWeight
                : RecommendationConstants.standardSessionWeight
            let titleLower = session.recipeTitle.lowercased()
            for keyword in Self.knownIngredients where titleLower.contains(keyword) {
                ingredientCounts[keyword, default: 0] += weight
            }
        }

        guard let topIngredient = ingredientCounts.max(by: { $0.value < $1.value })?.key else {
            return ([], nil)
        }

        let recentlyCookedTitles = Set(sessions.prefix(RecommendationConstants.recentSessionWindow).map { $0.recipeTitle.lowercased() })
        let candidates = try dbInterface.getRecipes(
            byIngredients: [Ingredient(name: topIngredient)],
            offset: 0,
            limit: RecommendationConstants.candidateLimit
        )

        let fresh = candidates.filter { !recentlyCookedTitles.contains($0.title.lowercased()) }
        let reason = String(format: Strings.Discover.suggestedBecause, topIngredient.capitalized)
        return (Array(fresh.prefix(limit)), reason)
    }

}
