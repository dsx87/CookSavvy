import Foundation

protocol RecipeRecommendationServiceProtocol: AnyObject {
    func getSuggestions(limit: Int) async throws -> (recipes: [Recipe], reason: String?)
}

extension RecipeRecommendationServiceProtocol {
    // Default must stay in sync with RecipeRecommendationService.Constants
    func getSuggestions() async throws -> (recipes: [Recipe], reason: String?) {
        try await getSuggestions(limit: 5)
    }
}
