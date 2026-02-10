//
//  OnlineRecipeSource.swift
//  CookSavvy
//
//  Created by Cascade on 01/10/2025.
//

import Foundation

/// Online recipe source that fetches recipes from a remote API via a pluggable provider
final class OnlineRecipeSource: RecipeSourceProtocol {
    
    var sourceType: RecipeSourceType { .online }
    
    private let provider: RecipeAPIProviderProtocol?
    private let resultCount: Int
    
    /// Initializes the online source with a recipe API provider
    /// - Parameters:
    ///   - provider: The recipe API provider to use (nil = unavailable)
    ///   - resultCount: Maximum number of recipes to fetch (default: 20)
    init(provider: RecipeAPIProviderProtocol? = nil, resultCount: Int = 20) {
        self.provider = provider
        self.resultCount = resultCount
    }
    
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
            case .invalidAPIKey, .rateLimitExceeded:
                throw RecipeSourceError.networkError(error)
            }
        } catch {
            throw RecipeSourceError.networkError(error)
        }
    }
    
    func isAvailable() async -> Bool {
        guard let provider else { return false }
        return await provider.isAvailable()
    }
}
