//
//  OnlineRecipeSource.swift
//  CookSavvy
//
//  Created by Cascade on 01/10/2025.
//

import Foundation

/// Online recipe source that fetches recipes from a remote API via a pluggable provider.
///
/// Delegates all network work to a `RecipeAPIProviderProtocol` implementation (currently
/// `SupabaseRecipeAPIProvider`). When no provider is injected the source reports itself
/// as unavailable, allowing graceful degradation. Requires a Premium subscription.
final class OnlineRecipeSource: RecipeSourceProtocol {

    /// Identifies this as the `.online` source type.
    var sourceType: RecipeSourceType { .online }

    /// The backend provider that executes the actual network request. `nil` means unavailable.
    private let provider: RecipeAPIProviderProtocol?
    /// Maximum number of recipes to request from the provider per fetch.
    private let resultCount: Int
    
    /// Initializes the online source with a recipe API provider
    /// - Parameters:
    ///   - provider: The recipe API provider to use (nil = unavailable)
    ///   - resultCount: Maximum number of recipes to fetch (default: 20)
    init(provider: RecipeAPIProviderProtocol? = nil, resultCount: Int = 20) {
        self.provider = provider
        self.resultCount = resultCount
    }
    
    /// Fetches recipes from the remote provider and maps provider-specific errors to `RecipeSourceError`.
    /// - Parameter ingredients: Ingredients to pass to the backend search endpoint.
    /// - Returns: Recipes returned by the remote provider.
    /// - Throws: `RecipeSourceError` wrapping the underlying network or provider error.
    func fetchRecipes(for ingredients: [Ingredient]) async throws -> [Recipe] {
        guard let provider else {
            throw RecipeSourceError.sourceUnavailable(.online)
        }
        
        guard !ingredients.isEmpty else {
            throw RecipeSourceError.noRecipesFound
        }
        
        do {
            return try await provider.fetchRecipes(for: ingredients, count: resultCount)
        } catch let error as RecipeAPIProviderError {
            switch error {
            case .noResults:
                throw RecipeSourceError.noRecipesFound
            case .invalidResponse:
                throw RecipeSourceError.invalidData
            case .networkError(let underlyingError):
                throw RecipeSourceError.networkError(underlyingError)
            case .invalidAPIKey, .notAuthenticated, .rateLimitExceeded:
                throw RecipeSourceError.networkError(error)
            }
        } catch {
            throw RecipeSourceError.networkError(error)
        }
    }
    
    /// Returns `true` only when a provider is configured and reports itself as available.
    func isAvailable() async -> Bool {
        guard let provider else { return false }
        return await provider.isAvailable()
    }
}
