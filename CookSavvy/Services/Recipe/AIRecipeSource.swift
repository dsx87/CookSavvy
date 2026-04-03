//
//  AIRecipeSource.swift
//  CookSavvy
//
//  Created by Cascade on 01/10/2025.
//

import Foundation

/// AI-powered recipe source that generates recipes using the AI service
final class AIRecipeSource: RecipeSourceProtocol {

    var sourceType: RecipeSourceType { .ai }

    private let aiService: AIServiceProtocol

    init(aiService: AIServiceProtocol) {
        self.aiService = aiService
    }

    func fetchRecipes(for ingredients: [Ingredient]) async throws -> [Recipe] {
        return try await aiService.generateRecipes(for: ingredients, count: 10)
    }

    func isAvailable() async -> Bool {
        return aiService.isAvailable
    }
}
