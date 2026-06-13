import Foundation

/// The structured output of a smart-search parse: concrete filter values extracted from a
/// natural-language query. Field values map 1:1 to the corresponding `DiscoverViewModel` filter state.
nonisolated struct SmartSearchIntent {
    /// Free-text ingredient names returned by the LLM. Each name must be resolved against the
    /// local ingredient database before being added to `selectedIngredients`.
    let ingredientNames: [String]
    let mood: RecipeMood?
    let cookTime: RecipeCookTimeFilter?
    let complexity: RecipeComplexityFilter?
    /// Dietary restrictions parsed from the query. Applied to `activeDietaryRestrictions`.
    let dietary: [DietaryRestriction]
}
