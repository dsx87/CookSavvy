import Foundation

enum RecipeMatchExplainer {
    struct IngredientAvailability: Equatable {
        let rescuedIngredientNames: [String]
        let missingIngredientNames: [String]
    }

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

    static func ingredientAvailability(
        recipe: Recipe,
        rescuedIngredients: [Ingredient]
    ) -> IngredientAvailability {
        ingredientAvailability(
            recipe: recipe,
            matchedIngredientNames: rescuedIngredients.map(\.name)
        )
    }

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

    static func normalizedIngredientName(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    // MARK: - Private

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
        recipe.cleanedIngredients.isEmpty ? recipe.ingredients : recipe.cleanedIngredients
    }

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
