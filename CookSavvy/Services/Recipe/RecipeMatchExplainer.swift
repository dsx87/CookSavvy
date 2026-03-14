import Foundation

enum RecipeMatchExplainer {

    static func explain(
        recipe: Recipe,
        selectedIngredients: [Ingredient],
        matchingNames: [String]
    ) -> String {
        let totalSelected = selectedIngredients.count
        let matchCount = matchingNames.count

        var reason: String
        if totalSelected > 0 && matchCount >= totalSelected {
            reason = "Uses all your ingredients!"
        } else {
            reason = "Uses \(matchCount) of \(totalSelected) ingredients"
        }

        if let minutes = cookTimeMinutes(recipe), minutes > 0 && minutes < 30 {
            reason += " · Quick \(minutes)-min meal"
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
