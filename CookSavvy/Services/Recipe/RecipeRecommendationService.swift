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
/// 2. Build an `ingredientCounts` frequency map from favourite-recipe ingredients and ingredients
///    pulled from recent cooking sessions.
///    - Ingredients in **favourites** contribute `favoriteWeight` (2) — stronger signal.
///    - Ingredients in **sessions** contribute `highlyRatedWeight` (2) if the session rating
///      is ≥ `highlyRatedThreshold` (4), otherwise `standardSessionWeight` (1).
/// 3. Query the database for up to `candidateLimit` recipes containing the highest-affinity ingredients.
/// 4. Filter out recipes cooked in the most recent `recentSessionWindow` (10) sessions
///    to avoid repetition.
/// 5. Rank candidates with `RecipeMatchRanker` and return up to `limit` recipes with a localised
///    reason string explaining the strongest ingredient signal.
final class RecipeRecommendationService: RecipeRecommendationServiceProtocol {
    /// Provides access to the user's cooking history and favourites.
    private let userDataService: UserDataServiceProtocol
    /// Database interface used to query candidate recipes.
    private let dbInterface: RecipeStoreProtocol
    /// Awaited before querying to ensure the bundled recipe dataset is loaded.
    private let databaseInitService: DatabaseInitializationServiceProtocol

    /// - Parameters:
    ///   - userDataService: Source of cooking history and favourites.
    ///   - dbInterface: Database used to fetch candidate recipes.
    ///   - databaseInitService: Awaited to ensure recipe data is seeded before querying.
    init(
        userDataService: UserDataServiceProtocol,
        dbInterface: RecipeStoreProtocol,
        databaseInitService: DatabaseInitializationServiceProtocol
    ) {
        self.userDataService = userDataService
        self.dbInterface = dbInterface
        self.databaseInitService = databaseInitService
    }

    /// Returns personalised recipe suggestions with a human-readable reason string.
    ///
    /// Returns an empty result (not an error) when the user has no history or favourites,
    /// or when no affinity ingredients can be extracted from that history.
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
            for ingredient in affinityIngredients(from: recipe) {
                ingredientCounts[ingredient, default: 0] += RecommendationConstants.favoriteWeight
            }
        }

        for session in sessions {
            let weight = (session.rating ?? 0) >= RecommendationConstants.highlyRatedThreshold
                ? RecommendationConstants.highlyRatedWeight
                : RecommendationConstants.standardSessionWeight

            for ingredient in try await affinityIngredients(from: session) {
                ingredientCounts[ingredient, default: 0] += weight
            }
        }

        let rankedIngredients = ingredientCounts
            .sorted { lhs, rhs in
                if lhs.value != rhs.value {
                    return lhs.value > rhs.value
                }
                return lhs.key.localizedCaseInsensitiveCompare(rhs.key) == .orderedAscending
            }
            .map(\.key)

        guard let topIngredient = rankedIngredients.first else {
            return ([], nil)
        }

        let affinityKeywords = Array(rankedIngredients.prefix(max(limit, RecommendationConstants.defaultLimit)))
        let recentlyCookedTitles = Set(sessions.prefix(RecommendationConstants.recentSessionWindow).map { $0.recipeTitle.lowercased() })
        let candidates = try await dbInterface.getRecipes(
            byIngredients: affinityKeywords.map(Ingredient.init(name:)),
            offset: 0,
            limit: RecommendationConstants.candidateLimit
        )

        let fresh = candidates
            .filter { !recentlyCookedTitles.contains($0.title.lowercased()) }
            .map { recipe in
                var rankedRecipe = recipe
                let recipeIngredients = ingredientNames(for: recipe)
                // Reuse the shared match ranker by projecting affinity keywords into missing ingredients.
                let matchedKeywords = Set(affinityKeywords.filter { keyword in
                    recipeIngredients.contains { ingredient in
                        ingredient.contains(keyword) || keyword.contains(ingredient)
                    }
                })
                rankedRecipe.missingIngredients = affinityKeywords.filter { !matchedKeywords.contains($0) }
                return rankedRecipe
            }
        let ranked = fresh.sorted { lhs, rhs in
            let lhsScore = weightedAffinityScore(for: lhs, ingredientCounts: ingredientCounts)
            let rhsScore = weightedAffinityScore(for: rhs, ingredientCounts: ingredientCounts)
            if lhsScore != rhsScore {
                return lhsScore > rhsScore
            }
            return RecipeMatchRanker.compare(lhs, rhs)
        }
        let reason = String(format: Strings.Discover.suggestedBecause, topIngredient.capitalized)
        return (Array(ranked.prefix(limit)), reason)
    }

    /// Builds affinity keywords from favourited recipes and session-backed recipe ingredients.
    private func affinityIngredients(from recipe: Recipe) -> Set<String> {
        Set(ingredientNames(for: recipe))
    }

    /// Uses the session's recipe ingredients when the recipe still exists, falling back to title tokens otherwise.
    private func affinityIngredients(from session: CookingSession) async throws -> Set<String> {
        if let recipe = try await dbInterface.getRecipe(byID: session.recipeId) {
            return affinityIngredients(from: recipe)
        }

        return fallbackTitleIngredients(from: session.recipeTitle)
    }

    private func ingredientNames(for recipe: Recipe) -> [String] {
        return recipe.cleanedIngredients
            .map(\.name)
            .map(normalizeIngredientName)
            .filter { !$0.isEmpty }
    }

    private func fallbackTitleIngredients(from title: String) -> Set<String> {
        let stopWords: Set<String> = ["and", "with", "the", "a", "an", "of", "in", "for"]
        let tokens = title
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 3 && !stopWords.contains($0) }
        return Set(tokens)
    }

    /// Scores a candidate using the weighted affinity map so highly rated history beats weak matches.
    private func weightedAffinityScore(for recipe: Recipe, ingredientCounts: [String: Int]) -> Int {
        let recipeIngredients = ingredientNames(for: recipe)
        return ingredientCounts.reduce(0) { score, entry in
            let matches = recipeIngredients.contains { ingredient in
                ingredient.contains(entry.key) || entry.key.contains(ingredient)
            }
            return matches ? score + entry.value : score
        }
    }

    private func normalizeIngredientName(_ value: String) -> String {
        value
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
