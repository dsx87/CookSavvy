//
//  SupabaseRecipeDTOs.swift
//  CookSavvy
//

import Foundation
import Supabase

/// JSON request body sent to the `search-recipes` Supabase Edge Function.
struct SupabaseRecipeFunctionRequest: Encodable {
    /// Ingredient names to search with.
    let ingredients: [String]
    /// Maximum number of recipes to return.
    let count: Int
}

/// Top-level decoded response from the `search-recipes` edge function.
struct SupabaseRecipeFunctionResponse: Decodable {
    let recipes: [SupabaseRecipeDTO]
}

/// A single recipe returned by the `search-recipes` edge function.
///
/// Kept separate from the app's `Recipe` model to insulate the domain layer from API contract changes.
/// The `asRecipe` computed property handles the translation, supplying defaults for optional fields.
struct SupabaseRecipeDTO: Decodable {
    let title: String
    let ingredients: [String]
    let instructions: [String]
    let image: String?
    let time: String?
    let servings: Int?
    let complexity: String?
    let calories: Int?
    let tagline: String?
    let author: String?
    let cuisine: String?
    /// 0–100 match score computed server-side based on how many provided ingredients align with the recipe.
    let matchPercentage: Double?
    /// Human-readable explanation of why this recipe was matched.
    let matchReason: String?
    /// Ingredient names the user did not provide that are required by the recipe.
    let missingIngredients: [String]?

    /// Maps this DTO to the app's `Recipe` domain model.
    /// Missing optional fields receive safe defaults (e.g. empty string for `image`).
    var asRecipe: Recipe {
        let mappedIngredients = ingredients.map(Ingredient.init(name:))
        return Recipe(
            title: title,
            ingredients: mappedIngredients,
            instructions: instructions,
            image: image ?? "",
            additionalInfo: Recipe.AdditionalInfo(
                time: time,
                servings: servings,
                complexity: complexity,
                calories: calories
            ),
            source: .online,
            tagline: tagline,
            author: author,
            cuisine: cuisine,
            matchPercentage: matchPercentage,
            matchReason: matchReason,
            missingIngredients: missingIngredients
        )
    }
}

/// Shared decoding and error-mapping utilities used by `SupabaseRecipeAPIProvider`.
/// Extracted as a caseless enum to allow reuse from tests without instantiation.
enum SupabaseRecipeProviderSupport {
    /// Creates a `JSONDecoder` pre-configured with `.convertFromSnakeCase` for Supabase API responses.
    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    /// Decodes the raw edge function response `Data` into an array of `Recipe` values.
    /// - Parameters:
    ///   - data: Raw JSON bytes from the edge function.
    ///   - decoder: A configured `JSONDecoder`.
    /// - Returns: Non-empty array of mapped `Recipe` values.
    /// - Throws: `RecipeAPIProviderError.invalidResponse` if decoding fails;
    ///   `RecipeAPIProviderError.noResults` if the decoded recipes array is empty.
    static func decodeRecipes(from data: Data, using decoder: JSONDecoder) throws -> [Recipe] {
        let response: SupabaseRecipeFunctionResponse
        do {
            response = try decoder.decode(SupabaseRecipeFunctionResponse.self, from: data)
        } catch {
            throw RecipeAPIProviderError.invalidResponse
        }

        let recipes = response.recipes.map(\.asRecipe)
        guard !recipes.isEmpty else {
            throw RecipeAPIProviderError.noResults
        }

        return recipes
    }

    /// Maps a Supabase SDK `FunctionsError` to a typed `RecipeAPIProviderError`.
    /// HTTP 401/403 → `.notAuthenticated`; 429 → `.rateLimitExceeded`; others → `.networkError`.
    static func mapError(_ error: Error) -> RecipeAPIProviderError {
        if let functionsError = error as? FunctionsError {
            switch functionsError {
            case .httpError(let code, _):
                switch code {
                case 401, 403:
                    return .notAuthenticated
                case 429:
                    return .rateLimitExceeded
                default:
                    return .networkError(functionsError)
                }
            default:
                return .networkError(functionsError)
            }
        }

        return .networkError(error)
    }
}
