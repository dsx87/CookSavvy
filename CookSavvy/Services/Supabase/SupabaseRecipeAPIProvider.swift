//
//  SupabaseRecipeAPIProvider.swift
//  CookSavvy
//

import Foundation

/// `RecipeAPIProviderProtocol` implementation that calls the `search-recipes` Supabase Edge Function,
/// enabling AI-powered online recipe search for premium users without exposing backend API keys on device.
final class SupabaseRecipeAPIProvider: RecipeAPIProviderProtocol {
    /// Identifies this provider in logs and error messages.
    var name: String { "Supabase" }

    /// Edge function name constant used by this provider.
    private enum FunctionName {
        static let searchRecipes = "search-recipes"
    }

    private let clientProvider: SupabaseClientProviderProtocol
    private let configuration: SupabaseConfiguration

    /// - Parameters:
    ///   - clientProvider: Supabase client used to invoke edge functions.
    ///   - configuration: Used by `isAvailable()` to check whether Supabase credentials are present.
    init(
        clientProvider: SupabaseClientProviderProtocol,
        configuration: SupabaseConfiguration = SupabaseConfiguration()
    ) {
        self.clientProvider = clientProvider
        self.configuration = configuration
    }

    /// Fetches AI-matched recipes from the `search-recipes` edge function for the given ingredients.
    ///
    /// The function receives a list of ingredient names and a desired result count. It returns
    /// a ranked list of recipes with match metadata (`matchPercentage`, `matchReason`, `missingIngredients`).
    /// - Parameters:
    ///   - ingredients: The ingredients the user has selected; must be non-empty.
    ///   - count: Maximum number of recipes to return.
    /// - Returns: An array of `Recipe` values mapped from the API response DTOs.
    /// - Throws: `RecipeAPIProviderError.noResults` if ingredients is empty or the response is empty;
    ///   `RecipeAPIProviderError.networkError` or `.notAuthenticated` on transport/auth failure;
    ///   `RecipeAPIProviderError.invalidResponse` if decoding fails.
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

        // Decoder created locally (not stored) so the provider holds only Sendable state.
        return try SupabaseRecipeProviderSupport.decodeRecipes(from: data, using: SupabaseRecipeProviderSupport.makeDecoder())
    }

    /// Returns `true` when Supabase is fully configured (URL + anon key present).
    func isAvailable() async -> Bool {
        configuration.isConfigured
    }
}
