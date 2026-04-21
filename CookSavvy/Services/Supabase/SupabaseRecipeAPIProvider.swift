//
//  SupabaseRecipeAPIProvider.swift
//  CookSavvy
//

import Foundation

/// Calls the `search-recipes` edge function used for the app's online recipe flow.
final class SupabaseRecipeAPIProvider: RecipeAPIProviderProtocol, @unchecked Sendable {
    var name: String { "Supabase" }

    private enum FunctionName {
        static let searchRecipes = "search-recipes"
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
            data = try await clientProvider.invokeFunction(FunctionName.searchRecipes, body: request)
        } catch {
            throw SupabaseRecipeProviderSupport.mapError(error)
        }

        return try SupabaseRecipeProviderSupport.decodeRecipes(from: data, using: decoder)
    }

    func isAvailable() async -> Bool {
        configuration.isConfigured
    }
}
