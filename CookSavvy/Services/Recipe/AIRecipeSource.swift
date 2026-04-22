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

    /// - Parameter aiService: The AI service to use for recipe generation.
    init(aiService: AIServiceProtocol) {
        self.aiService = aiService
    }

    /// Asks the AI service to generate up to 10 recipes for the provided ingredients.
    /// - Parameter ingredients: Ingredients to incorporate into generated recipes.
    /// - Returns: AI-generated recipes.
    /// - Throws: Errors from `AIServiceProtocol.generateRecipes` (e.g., network or parsing failures).
    func fetchRecipes(for ingredients: [Ingredient]) async throws -> [Recipe] {
        return try await aiService.generateRecipes(for: ingredients, count: 10)
    }

    /// Returns `true` when the underlying AI service has a configured, reachable provider.
    func isAvailable() async -> Bool {
        return aiService.isAvailable
    }
}
