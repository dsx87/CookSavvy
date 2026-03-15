import Foundation

final class RecipeRecommendationService {
    private let userDataService: UserDataService
    private let dbInterface: DBInterfaceProtocol
    private let databaseInitService: DatabaseInitializationService

    private static let knownIngredients = [
        "chicken", "beef", "pork", "lamb", "fish", "salmon", "tuna",
        "shrimp", "turkey", "tofu", "lentil", "pasta", "rice",
        "potato", "mushroom", "tomato", "egg", "noodle"
    ]

    init(
        userDataService: UserDataService,
        dbInterface: DBInterfaceProtocol,
        databaseInitService: DatabaseInitializationService
    ) {
        self.userDataService = userDataService
        self.dbInterface = dbInterface
        self.databaseInitService = databaseInitService
    }

    func getSuggestions(limit: Int = 5) async throws -> (recipes: [Recipe], reason: String?) {
        await databaseInitService.waitForRecipes()

        async let favoritesTask = userDataService.getFavorites()
        async let sessionsTask = userDataService.getCookingSessions(limit: 20)
        let (favorites, sessions) = try await (favoritesTask, sessionsTask)

        guard !favorites.isEmpty || !sessions.isEmpty else { return ([], nil) }

        var ingredientCounts: [String: Int] = [:]

        for recipe in favorites {
            let ingredients = recipe.cleanedIngredients.isEmpty ? recipe.ingredients : recipe.cleanedIngredients
            for ingredient in ingredients {
                let nameLower = ingredient.name.lowercased()
                for keyword in Self.knownIngredients where nameLower.contains(keyword) {
                    ingredientCounts[keyword, default: 0] += 2
                    break
                }
            }
        }

        for session in sessions {
            let weight = (session.rating ?? 0) >= 4 ? 2 : 1
            let titleLower = session.recipeTitle.lowercased()
            for keyword in Self.knownIngredients where titleLower.contains(keyword) {
                ingredientCounts[keyword, default: 0] += weight
            }
        }

        guard let topIngredient = ingredientCounts.max(by: { $0.value < $1.value })?.key else {
            return ([], nil)
        }

        let recentlyCookedTitles = Set(sessions.prefix(10).map { $0.recipeTitle.lowercased() })
        let candidates = try dbInterface.getRecipes(
            byIngredients: [Ingredient(name: topIngredient)],
            offset: 0,
            limit: 20
        )

        let fresh = candidates.filter { !recentlyCookedTitles.contains($0.title.lowercased()) }
        let reason = String(format: Strings.Discover.suggestedBecause, topIngredient.capitalized)
        return (Array(fresh.prefix(limit)), reason)
    }

}
