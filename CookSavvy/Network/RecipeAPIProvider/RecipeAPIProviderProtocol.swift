import Foundation

protocol RecipeAPIProviderProtocol: Sendable {
    var name: String { get }
    func fetchRecipes(for ingredients: [Ingredient], count: Int) async throws -> [Recipe]
    func isAvailable() async -> Bool
}

enum RecipeAPIProviderError: Error, LocalizedError, @unchecked Sendable {
    case invalidAPIKey
    case notAuthenticated
    case rateLimitExceeded
    case invalidResponse
    case networkError(Error)
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
