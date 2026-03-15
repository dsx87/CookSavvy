import Foundation

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

final class RecipeRecommendationService: RecipeRecommendationServiceProtocol {
    private let userDataService: UserDataServiceProtocol
    private let dbInterface: DBInterfaceProtocol
    private let databaseInitService: DatabaseInitializationServiceProtocol

    private static let knownIngredients = [
        "chicken", "beef", "pork", "lamb", "fish", "salmon", "tuna",
        "shrimp", "turkey", "tofu", "lentil", "pasta", "rice",
        "potato", "mushroom", "tomato", "egg", "noodle"
    ]

    init(
        userDataService: UserDataServiceProtocol,
        dbInterface: DBInterfaceProtocol,
        databaseInitService: DatabaseInitializationServiceProtocol
    ) {
        self.userDataService = userDataService
        self.dbInterface = dbInterface
        self.databaseInitService = databaseInitService
    }

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
