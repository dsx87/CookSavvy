//
//  OnlineRecipeSource.swift
//  CookSavvy
//
//  Created by Cascade on 01/10/2025.
//

import Foundation

/// Online recipe source that fetches recipes from a remote API
/// This is a placeholder implementation for future development
final class OnlineRecipeSource: RecipeSourceProtocol {
    
    var sourceType: RecipeSourceType { .online }
    
    private let apiEndpoint: String
    private let apiKey: String?
    
    /// Initializes the online source with API configuration
    /// - Parameters:
    ///   - apiEndpoint: The API endpoint URL
    ///   - apiKey: Optional API key for authentication
    init(apiEndpoint: String = "https://api.example.com/recipes", apiKey: String? = nil) {
        self.apiEndpoint = apiEndpoint
        self.apiKey = apiKey
    }
    
    func fetchRecipes(for ingredients: [Ingredient]) async throws -> [Recipe] {
        // TODO: Implement actual API call when online service is ready
        // For now, throw unavailable error
        throw RecipeSourceError.sourceUnavailable(.online)
    }
    
    func isAvailable() async -> Bool {
        // TODO: Implement actual availability check (e.g., network reachability)
        return false
    }
}
