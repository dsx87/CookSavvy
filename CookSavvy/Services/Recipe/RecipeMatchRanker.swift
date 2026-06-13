import Foundation

/// Stateless comparator that ranks recipes by ingredient match quality and user-friendly tie-breakers.
///
/// Ingredient coverage stays primary, while mood only refines otherwise comparable matches.
///
/// `nonisolated` (not pinned to the main actor by default isolation): a pure value-in/value-out
/// utility. Its entry points are synchronous because they are consumed from synchronous contexts —
/// `DiscoverViewModel.filteredRecipes` (a computed property) and `sorted(by:)` comparators — that
/// cannot `await`. The ranked sets are small (search results), so the work is negligible.
nonisolated enum RecipeMatchRanker {
    private struct SortKey {
        let coverageRatio: Double
        let missingCount: Int
        let moodScore: Int?
        let weightedRating: Double
        let cookTimeMinutes: Int?
        let complexityRank: Int
        let title: String
    }

    static func rank(_ recipes: [Recipe], mood: RecipeMood? = nil) -> [Recipe] {
        recipes.sorted { compare($0, $1, mood: mood) }
    }

    static func compare(_ lhs: Recipe, _ rhs: Recipe, mood: RecipeMood? = nil) -> Bool {
        let lhsKey = sortKey(for: lhs, mood: mood)
        let rhsKey = sortKey(for: rhs, mood: mood)

        if lhsKey.coverageRatio != rhsKey.coverageRatio {
            return lhsKey.coverageRatio > rhsKey.coverageRatio
        }

        if lhsKey.missingCount != rhsKey.missingCount {
            return lhsKey.missingCount < rhsKey.missingCount
        }

        if let lhsMoodScore = lhsKey.moodScore, let rhsMoodScore = rhsKey.moodScore, lhsMoodScore != rhsMoodScore {
            return lhsMoodScore > rhsMoodScore
        }

        if lhsKey.weightedRating != rhsKey.weightedRating {
            return lhsKey.weightedRating > rhsKey.weightedRating
        }

        switch (lhsKey.cookTimeMinutes, rhsKey.cookTimeMinutes) {
        case let (lhsTime?, rhsTime?) where lhsTime != rhsTime:
            return lhsTime < rhsTime
        case (.some, nil):
            return true
        case (nil, .some):
            return false
        default:
            break
        }

        if lhsKey.complexityRank != rhsKey.complexityRank {
            return lhsKey.complexityRank < rhsKey.complexityRank
        }

        return lhsKey.title.localizedCaseInsensitiveCompare(rhsKey.title) == .orderedAscending
    }

    private static func sortKey(for recipe: Recipe, mood: RecipeMood?) -> SortKey {
        let totalIngredients = ingredientCount(for: recipe)
        let missingCount = recipe.missingIngredients?.count ?? totalIngredients
        let matchedCount = max(totalIngredients - missingCount, 0)
        let coverageRatio = totalIngredients > 0 ? Double(matchedCount) / Double(totalIngredients) : 0

        return SortKey(
            coverageRatio: coverageRatio,
            missingCount: missingCount,
            moodScore: mood.map { RecipeMoodRanker.score(for: recipe, mood: $0) },
            weightedRating: weightedRating(for: recipe),
            cookTimeMinutes: cookTimeMinutes(for: recipe),
            complexityRank: complexityRank(for: recipe),
            title: recipe.title
        )
    }

    private static func ingredientCount(for recipe: Recipe) -> Int {
        return recipe.cleanedIngredients.count
    }

    private static func weightedRating(for recipe: Recipe) -> Double {
        if let userRating = recipe.userRating {
            return userRating * 2
        }
        return recipe.apiRating ?? 0
    }

    private static func cookTimeMinutes(for recipe: Recipe) -> Int? {
        recipe.cookTimeMinutes
    }

    private static func complexityRank(for recipe: Recipe) -> Int {
        let complexity = recipe.additionalInfo.infos.compactMap { info -> String? in
            guard case let .complexity(value) = info else { return nil }
            return value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }.first

        switch complexity {
        case "easy":
            return 0
        case "medium":
            return 1
        case "hard":
            return 2
        default:
            return 3
        }
    }
}
