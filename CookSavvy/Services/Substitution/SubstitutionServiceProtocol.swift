import Foundation

/// Public interface for looking up curated ingredient substitutions.
///
/// The protocol keeps the app free to start with a bundled local catalog while preserving
/// the option to replace the implementation with a remote-backed service later.
protocol SubstitutionServiceProtocol: AnyObject {
    /// Returns substitution suggestions for the missing ingredients in a recipe.
    ///
    /// - Parameters:
    ///   - missingIngredientNames: Display-ready missing ingredient names from the current recipe.
    ///   - recipeIngredients: Full recipe ingredient list, used to recover more specific names when
    ///     the missing list contains a shortened form.
    ///   - availableIngredients: Ingredients the user already has and could use as substitutes.
    /// - Returns: Deterministic suggestions for the missing ingredients that are covered by the catalog.
    func suggestions(
        for missingIngredientNames: [String],
        recipeIngredients: [Ingredient],
        availableIngredients: [Ingredient]
    ) async throws -> [IngredientSubstitutionSuggestion]
}

/// One missing ingredient plus the curated substitutes available for it.
struct IngredientSubstitutionSuggestion: Equatable, Sendable {
    /// The missing ingredient shown to the user.
    let missingIngredientName: String
    /// Curated substitute options sorted with user-available matches first.
    let options: [IngredientSubstitutionOption]
}

/// A single curated substitute for a missing ingredient.
struct IngredientSubstitutionOption: Equatable, Sendable {
    /// The substitute ingredient to recommend.
    let ingredientName: String
    /// Human-readable ratio guidance such as `"3/4 amount"`.
    let ratio: String?
    /// Caveat or usage note that explains when the swap is safe.
    let note: String?
    /// `true` when the user already has this substitute in the current ingredient set.
    let isAvailableFromUserIngredients: Bool
}
