//
//  AIRecipeSource.swift
//  CookSavvy
//
//  Created by Cascade on 01/10/2025.
//

import Foundation

/// AI-powered recipe source that generates novel recipes using the AI service.
///
/// Delegates to `AIServiceProtocol.generateRecipes`, which sends the ingredient list to
/// an LLM (via `SupabaseLLMProvider` at runtime). Requires a Premium subscription.
final class AIRecipeSource: RecipeSourceProtocol {

    /// Identifies this as the `.ai` source type.
    var sourceType: RecipeSourceType { .ai }

    /// The AI service used to generate recipes from ingredients.
    private let aiService: AIServiceProtocol
    /// Number of recipes to request from the AI service per fetch. Kept modest to bound
    /// backend generation cost (output tokens scale with recipe count); the backend clamps to 1–10.
    private let recipeCount: Int

    /// - Parameters:
    ///   - aiService: The AI service to use for recipe generation.
    ///   - recipeCount: Number of recipes to generate per fetch (default: 5).
    init(aiService: AIServiceProtocol, recipeCount: Int = 5) {
        self.aiService = aiService
        self.recipeCount = recipeCount
    }

    /// Asks the AI service to generate `recipeCount` recipes for the provided ingredients.
    /// - Parameter ingredients: Ingredients to incorporate into generated recipes.
    /// - Returns: AI-generated recipes.
    /// - Throws: Errors from `AIServiceProtocol.generateRecipes` (e.g., network or parsing failures).
    func fetchRecipes(for ingredients: [Ingredient]) async throws -> [Recipe] {
        return try await aiService.generateRecipes(for: ingredients, count: recipeCount)
    }

    /// Returns `true` when the underlying AI service has a configured, reachable provider.
    func isAvailable() async -> Bool {
        return aiService.isAvailable
    }
}
