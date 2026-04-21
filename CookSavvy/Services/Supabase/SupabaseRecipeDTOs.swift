//
//  SupabaseRecipeDTOs.swift
//  CookSavvy
//

import Foundation
import Supabase

struct SupabaseRecipeFunctionRequest: Encodable {
    let ingredients: [String]
    let count: Int
}

struct SupabaseRecipeFunctionResponse: Decodable {
    let recipes: [SupabaseRecipeDTO]
}

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
    let matchPercentage: Double?
    let matchReason: String?
    let missingIngredients: [String]?

    var asRecipe: Recipe {
        let mappedIngredients = ingredients.map(Ingredient.init(name:))
        return Recipe(
            title: title,
            ingredients: mappedIngredients,
            instructions: instructions,
            image: image ?? "",
            cleanedIngredients: mappedIngredients,
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

enum SupabaseRecipeProviderSupport {
    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

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
