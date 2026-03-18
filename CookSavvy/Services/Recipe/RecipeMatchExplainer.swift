import Foundation

enum RecipeMatchExplainer {

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
        let recipeIngredients = recipe.cleanedIngredients.isEmpty ? recipe.ingredients : recipe.cleanedIngredients
        var missing: [String] = []
        var seen = Set<String>()
        for ingredient in recipeIngredients {
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

    static func normalizedIngredientName(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    // MARK: - Private

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
