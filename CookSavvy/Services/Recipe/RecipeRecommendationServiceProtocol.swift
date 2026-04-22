import Foundation

/// Interface for generating personalised recipe suggestions from the user's cooking history.
protocol RecipeRecommendationServiceProtocol: AnyObject {

    /// Returns up to `limit` suggested recipes and an optional reason explaining the recommendation.
    /// - Parameter limit: Maximum number of recipes to return.
    /// - Returns: A tuple of suggested recipes and a localised reason string, or `nil` if no
    ///   meaningful reason can be determined (e.g., insufficient history).
    /// - Throws: Errors from underlying data or database services.
    func getSuggestions(limit: Int) async throws -> (recipes: [Recipe], reason: String?)
}

/// Default helper implementations for ``RecipeRecommendationServiceProtocol``.
extension RecipeRecommendationServiceProtocol {
    /// Convenience overload that uses the default limit of 5.
    // Default must stay in sync with RecipeRecommendationService.Constants
    func getSuggestions() async throws -> (recipes: [Recipe], reason: String?) {
        try await getSuggestions(limit: 5)
    }
}
