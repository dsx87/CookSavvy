import Foundation

/// Stateless utility that explains how well a recipe matches the user's selected ingredients.
///
/// Used in recipe result cards to surface human-readable explanations such as
/// "You have 4 of 6 ingredients · 20 min".
///
/// `nonisolated` so it is not pinned to the main actor, matching its stateless sibling rankers
/// `RecipeMatchRanker` / `RecipeMoodRanker`. Note `nonisolated` only removes actor isolation — it
/// does not move work off main: a `nonisolated` sync call runs on its caller's executor (the main
/// thread when `DiscoverViewModel` invokes it after a search). Being nonisolated simply leaves it
/// callable from a future `@concurrent` hop without an actor bounce should profiling ever warrant it.
nonisolated enum RecipeMatchExplainer {

    /// Snapshot of which recipe ingredients the user has versus which are missing.
    struct IngredientAvailability: Equatable {
        /// Recipe ingredient names the user already has.
        let rescuedIngredientNames: [String]
        /// Recipe ingredient names not present in the user's selection.
        let missingIngredientNames: [String]
    }

    /// Ingredient-level match split used to keep pantry assumptions separate from shopping gaps.
    struct IngredientMatchBreakdown: Equatable {
        /// Recipe ingredient names covered by explicit selected ingredients or saved pantry items.
        let availableIngredientNames: [String]
        /// Common staples assumed to be available even when the user has not saved them.
        let assumedPantryIngredientNames: [String]
        /// Recipe ingredient names still missing after explicit and assumed availability are applied.
        let missingIngredientNames: [String]
    }

    /// Builds a one-line explanation string for a recipe card.
    ///
    /// The explanation covers ingredient coverage and, when the cook time is under 30 minutes
    /// and only minutes are involved (no hour component), appends a quick-meal suffix.
    ///
    /// Examples:
    /// - `"You have all the ingredients · 15 min"`
    /// - `"You have 3 of 5 ingredients"`
    /// - Parameter recipe: The recipe being explained.
    /// - Parameter missingIngredients: Ingredient names absent from the user's selection.
    /// - Returns: A localised, human-readable match explanation.
    static func explain(
        recipe: Recipe,
        missingIngredients: [String]
    ) -> String {
        let recipeIngredients = recipe.cleanedIngredients
        let total = recipeIngredients.count
        let matched = max(0, total - missingIngredients.count)

        var reason: String
        if missingIngredients.isEmpty {
            reason = Strings.Discover.matchLabelAll
        } else {
            reason = String(format: Strings.Discover.matchLabel, Int64(matched), Int64(total))
        }

        if let minutes = cookTimeMinutes(recipe), minutes > 0 && minutes < 30 {
            reason += String(format: Strings.Discover.quickMealSuffix, Int64(minutes))
        }

        return reason
    }

    /// Returns the recipe ingredient names that are NOT covered by `selectedIngredients`.
    ///
    /// Matching uses a bidirectional substring check after normalisation, so "cherry tomato"
    /// is considered matched by a selection containing "tomato", and vice-versa.
    /// - Parameters:
    ///   - recipe: The recipe whose ingredients are checked.
    ///   - selectedIngredients: The user's current ingredient selection.
    /// - Returns: Display-ready ingredient names absent from the user's selection, deduplicated.
    static func missingIngredients(recipe: Recipe, selectedIngredients: [Ingredient]) -> [String] {
        guard !selectedIngredients.isEmpty else { return [] }
        return ingredientBreakdown(recipe: recipe, selectedIngredients: selectedIngredients).missingIngredientNames
    }

    /// Splits recipe ingredients into explicit matches, assumed staples, and true shopping gaps.
    ///
    /// Explicit matches are checked first so saved pantry items such as "Salt" remain user-provided
    /// availability, while built-in assumptions only cover unsaved staples like water, pepper, and oil.
    /// Matching explicit ingredients keeps the app's existing bidirectional partial-match behavior.
    /// Pantry assumptions are intentionally exact-name based to avoid treating ingredients such as
    /// bell pepper as a built-in seasoning staple.
    /// - Parameters:
    ///   - recipe: The recipe whose ingredient list is being classified.
    ///   - selectedIngredients: Explicit selected ingredients plus saved pantry ingredients.
    /// - Returns: A deduplicated, display-ready ingredient split.
    static func ingredientBreakdown(
        recipe: Recipe,
        selectedIngredients: [Ingredient]
    ) -> IngredientMatchBreakdown {
        let queryNames = Set(selectedIngredients.map { normalizedIngredientName($0.name) }.filter { !$0.isEmpty })
        var available: [String] = []
        var assumed: [String] = []
        var missing: [String] = []
        var seen = Set<String>()
        for ingredient in availableIngredients(for: recipe) {
            let recipeName = normalizedIngredientName(ingredient.name)
            guard !recipeName.isEmpty else { continue }
            let isMatch = queryNames.contains(where: { recipeName.contains($0) || $0.contains(recipeName) })
            let displayName = ingredient.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !displayName.isEmpty else { continue }
            guard seen.insert(displayName.lowercased()).inserted else { continue }

            if isMatch {
                available.append(displayName)
            } else if isAssumedPantryStaple(recipeName) {
                assumed.append(displayName)
            } else {
                missing.append(displayName)
            }
        }
        return IngredientMatchBreakdown(
            availableIngredientNames: available,
            assumedPantryIngredientNames: assumed,
            missingIngredientNames: missing
        )
    }

    /// Computes ingredient availability from a list of already-matched (rescued) ingredient names.
    /// - Parameters:
    ///   - recipe: The recipe to analyse.
    ///   - rescuedIngredients: Ingredients the user has that are used by the recipe.
    /// - Returns: An `IngredientAvailability` split into rescued and missing names.
    static func ingredientAvailability(
        recipe: Recipe,
        rescuedIngredients: [Ingredient]
    ) -> IngredientAvailability {
        ingredientAvailability(
            recipe: recipe,
            matchedIngredientNames: rescuedIngredients.map(\.name)
        )
    }

    /// Computes ingredient availability from a list of known-missing ingredient names.
    /// - Parameters:
    ///   - recipe: The recipe to analyse.
    ///   - missingIngredientNames: Raw names of ingredients the user does not have.
    /// - Returns: An `IngredientAvailability` split into rescued and missing names.
    static func ingredientAvailability(
        recipe: Recipe,
        missingIngredientNames: [String]
    ) -> IngredientAvailability {
        let missingSet = Set(missingIngredientNames.map(normalizedIngredientName).filter { !$0.isEmpty })
        let availableIngredientNames = availableIngredients(for: recipe).map(\.name)
        let rescuedIngredientNames = availableIngredientNames.filter { !missingSet.contains(normalizedIngredientName($0)) }
        return IngredientAvailability(
            rescuedIngredientNames: rescuedIngredientNames,
            missingIngredientNames: availableIngredientNames.filter { missingSet.contains(normalizedIngredientName($0)) }
        )
    }

    /// Trims and lowercases an ingredient name for consistent comparison.
    static func normalizedIngredientName(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    // MARK: - Private

    /// Internal overload that computes availability from a set of already-matched names.
    private static func ingredientAvailability(
        recipe: Recipe,
        matchedIngredientNames: [String]
    ) -> IngredientAvailability {
        let matchedSet = Set(matchedIngredientNames.map(normalizedIngredientName).filter { !$0.isEmpty })
        let availableIngredientNames = availableIngredients(for: recipe).map(\.name)
        return IngredientAvailability(
            rescuedIngredientNames: availableIngredientNames.filter { matchedSet.contains(normalizedIngredientName($0)) },
            missingIngredientNames: availableIngredientNames.filter { !matchedSet.contains(normalizedIngredientName($0)) }
        )
    }

    private static func availableIngredients(for recipe: Recipe) -> [Ingredient] {
        recipe.cleanedIngredients
    }

    /// Returns true for shared pantry-staple names (see `PantryStaples`), after normalisation.
    ///
    /// `PantryStaples` is the single source of truth shared with the ingredient picker, so anything
    /// hidden from selection is also assumed available here and never counted as missing.
    private static func isAssumedPantryStaple(_ normalizedName: String) -> Bool {
        PantryStaples.isStaple(normalizedName)
    }

    /// Parses a numeric cook-time in minutes from the recipe's time `AdditionalInfo`.
    /// Returns `nil` when the time string contains "hr" or "hour" (to avoid misleading
    /// quick-meal suffixes for hour-long recipes), or when no time info exists.
    private static func cookTimeMinutes(_ recipe: Recipe) -> Int? {
        for info in recipe.additionalInfo.infos {
            if case .time(let timeString) = info {
                let lower = timeString.lowercased()
                if lower.contains("hr") || lower.contains("hour") { return nil }
                let numbers = lower.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }
                if let first = numbers.first { return Int(first) }
            }
        }
        return nil
    }
}
