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
