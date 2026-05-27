//
//  SupabaseAIRecipeAPIProvider.swift
//  CookSavvy
//

import Foundation

/// `RecipeAPIProviderProtocol` implementation that calls the `generate-recipes` Supabase Edge Function,
/// delivering AI-generated recipes for premium users without exposing backend API keys on device.
final class SupabaseAIRecipeAPIProvider: RecipeAPIProviderProtocol, @unchecked Sendable {
    var name: String { "SupabaseAI" }

    private enum FunctionName {
        static let generateRecipes = "generate-recipes"
    }

    private let clientProvider: SupabaseClientProviderProtocol
    private let configuration: SupabaseConfiguration
    private let decoder: JSONDecoder

    init(
        clientProvider: SupabaseClientProviderProtocol,
        configuration: SupabaseConfiguration = SupabaseConfiguration(),
        decoder: JSONDecoder = SupabaseRecipeProviderSupport.makeDecoder()
    ) {
        self.clientProvider = clientProvider
        self.configuration = configuration
        self.decoder = decoder
    }

    func fetchRecipes(for ingredients: [Ingredient], count: Int) async throws -> [Recipe] {
        guard !ingredients.isEmpty else {
            throw RecipeAPIProviderError.noResults
        }

        let request = SupabaseRecipeFunctionRequest(
            ingredients: ingredients.map(\.name),
            count: count
        )

        let data: Data
        do {
            data = try await clientProvider.invokeFunction(FunctionName.generateRecipes, body: request)
        } catch {
            throw SupabaseRecipeProviderSupport.mapError(error)
        }

        let recipes = try SupabaseRecipeProviderSupport.decodeRecipes(from: data, using: decoder)
        return recipes.map { var r = $0; r.source = .ai; return r }
    }

    func isAvailable() async -> Bool {
        configuration.isConfigured
    }
}
