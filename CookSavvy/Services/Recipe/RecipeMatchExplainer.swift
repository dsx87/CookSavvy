import Foundation

/// Stateless utility that explains how well a recipe matches the user's selected ingredients.
///
/// Used in recipe result cards to surface human-readable explanations such as
/// "You have 4 of 6 ingredients · 20 min".
enum RecipeMatchExplainer {

    /// Snapshot of which recipe ingredients the user has versus which are missing.
    struct IngredientAvailability: Equatable {
        /// Recipe ingredient names the user already has.
        let rescuedIngredientNames: [String]
        /// Recipe ingredient names not present in the user's selection.
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
        let recipeIngredients = recipe.cleanedIngredients.isEmpty ? recipe.ingredients : recipe.cleanedIngredients
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
        let queryNames = Set(selectedIngredients.map { normalizedIngredientName($0.name) }.filter { !$0.isEmpty })
        var missing: [String] = []
        var seen = Set<String>()
        for ingredient in availableIngredients(for: recipe) {
            let recipeName = normalizedIngredientName(ingredient.name)
            guard !recipeName.isEmpty else { continue }
            let isMatch = queryNames.contains(where: { recipeName.contains($0) || $0.contains(recipeName) })
            guard !isMatch else { continue }
            let displayName = ingredient.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !displayName.isEmpty else { continue }
            if seen.insert(displayName.lowercased()).inserted {
                missing.append(displayName)
            }
        }
        return missing
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

    /// Returns the effective ingredient list for a recipe, preferring `cleanedIngredients`.
    private static func availableIngredients(for recipe: Recipe) -> [Ingredient] {
        recipe.cleanedIngredients.isEmpty ? recipe.ingredients : recipe.cleanedIngredients
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
