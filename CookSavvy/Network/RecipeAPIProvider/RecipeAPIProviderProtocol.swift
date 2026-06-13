import Foundation

/// Abstraction over a remote recipe search backend.
///
/// Conforming types provide the app with recipe suggestions based on a set of ingredients.
/// The active runtime implementation is `SupabaseRecipeAPIProvider`, which calls the
/// `search-recipes` Supabase edge function. Tests and DEBUG builds can supply an alternative
/// conformance without touching the rest of the feature stack.
protocol RecipeAPIProviderProtocol: Sendable {
    /// A human-readable identifier for the backend (e.g. `"Supabase"`), used in logs and diagnostics.
    var name: String { get }
    /// Fetches recipes that best match the supplied ingredients.
    /// - Parameters:
    ///   - ingredients: The user's selected ingredients.
    ///   - count: The maximum number of recipes to return.
    /// - Returns: An array of ``Recipe`` values; may be shorter than `count` if the backend returns fewer results.
    /// - Throws: ``RecipeAPIProviderError`` on authentication, network, or response failures.
    func fetchRecipes(for ingredients: [Ingredient], count: Int) async throws -> [Recipe]
    /// Returns `true` when the provider is configured and reachable.
    ///
    /// Intended to be called before `fetchRecipes` to gate premium feature availability
    /// without surfacing a hard error to the user.
    func isAvailable() async -> Bool
}

/// Errors thrown by ``RecipeAPIProviderProtocol`` implementations.
enum RecipeAPIProviderError: Error, LocalizedError {
    /// The API key in `APIKeys.plist` is missing or was rejected by the backend.
    case invalidAPIKey
    /// The request was made without valid session credentials.
    case notAuthenticated
    /// The backend's request quota has been exceeded.
    case rateLimitExceeded
    /// The backend returned data that could not be interpreted as expected.
    case invalidResponse
    /// A lower-level network failure occurred.
    case networkError(Error)
    /// The backend returned a successful response but contained no matching recipes.
    case noResults

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Invalid API key for recipe provider"
        case .notAuthenticated:
            return "Authentication is required"
        case .rateLimitExceeded:
            return "API rate limit exceeded"
        case .invalidResponse:
            return "Invalid response from recipe API"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .noResults:
            return "No recipes found"
        }
    }
}
