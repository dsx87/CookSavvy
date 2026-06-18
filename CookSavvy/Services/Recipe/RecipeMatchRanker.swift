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
        /// Coarse coverage band derived from `coverageRatio`. Used only when a mood is active so that
        /// recipes with *similar* match quality share a tier and the mood score can reorder within it
        /// — without a tier, the continuous `coverageRatio` almost never ties and mood never surfaces.
        let coverageTier: Int
        let missingCount: Int
        let moodScore: Int?
        let weightedRating: Double
        let cookTimeMinutes: Int?
        let complexityRank: Int
        let title: String
    }

    /// Number of coarse coverage bands. Higher = finer tiers (mood reorders less); lower = coarser
    /// (mood reorders more). Four bands groups e.g. ~0-12%, ~13-37%, ~38-62%, ~63-87%, ~88-100% match
    /// quality together. Tunable.
    private static let coverageTierBands = 4

    static func rank(_ recipes: [Recipe], mood: RecipeMood? = nil) -> [Recipe] {
        // Precompute each recipe's SortKey once (O(n)) rather than rebuilding both operands' keys on
        // every comparison — each key allocates the cleaned-ingredient set, parses cook time, and
        // scores mood, so the old `sorted { compare(...) }` did that work ~O(n log n) times.
        recipes
            .map { (recipe: $0, key: sortKey(for: $0, mood: mood)) }
            .sorted { precedes($0.key, $1.key) }
            .map(\.recipe)
    }

    static func compare(_ lhs: Recipe, _ rhs: Recipe, mood: RecipeMood? = nil) -> Bool {
        precedes(sortKey(for: lhs, mood: mood), sortKey(for: rhs, mood: mood))
    }

    /// Total ordering over two precomputed `SortKey`s. Field order and tie-breaks are identical to
    /// the previous inline `compare` logic, so ranking output is unchanged; both `rank` and
    /// `compare` (and thus `RecipeRecommendationService`) delegate here to avoid duplicated logic.
    private static func precedes(_ lhsKey: SortKey, _ rhsKey: SortKey) -> Bool {
        // When a mood is active (both keys carry a mood score), coverage stays primary but only as a
        // coarse *tier*, so mood becomes a strong second signal that visibly reorders recipes of
        // similar match quality. When no mood is active the ordering below is identical to before:
        // full-resolution coverage → missing count → rating → … (no behavioural change).
        if let lhsMoodScore = lhsKey.moodScore, let rhsMoodScore = rhsKey.moodScore {
            if lhsKey.coverageTier != rhsKey.coverageTier {
                return lhsKey.coverageTier > rhsKey.coverageTier
            }
            if lhsMoodScore != rhsMoodScore {
                return lhsMoodScore > rhsMoodScore
            }
            if lhsKey.missingCount != rhsKey.missingCount {
                return lhsKey.missingCount < rhsKey.missingCount
            }
        } else {
            if lhsKey.coverageRatio != rhsKey.coverageRatio {
                return lhsKey.coverageRatio > rhsKey.coverageRatio
            }
            if lhsKey.missingCount != rhsKey.missingCount {
                return lhsKey.missingCount < rhsKey.missingCount
            }
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
            coverageTier: Int((coverageRatio * Double(coverageTierBands)).rounded()),
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
