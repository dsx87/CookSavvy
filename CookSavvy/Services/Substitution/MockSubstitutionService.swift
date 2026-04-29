import Foundation

#if DEBUG
/// DEBUG/test substitution service that returns caller-controlled canned results.
final class MockSubstitutionService: SubstitutionServiceProtocol {
    var stubbedSuggestions: [IngredientSubstitutionSuggestion] = []
    var shouldThrow: Error?
    private(set) var requests: [(missingIngredientNames: [String], recipeIngredients: [Ingredient], availableIngredients: [Ingredient])] = []

    func suggestions(
        for missingIngredientNames: [String],
        recipeIngredients: [Ingredient],
        availableIngredients: [Ingredient]
    ) async throws -> [IngredientSubstitutionSuggestion] {
        if let shouldThrow {
            throw shouldThrow
        }
        requests.append((missingIngredientNames, recipeIngredients, availableIngredients))
        return stubbedSuggestions
    }
}
#endif
