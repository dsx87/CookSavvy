import Foundation

struct SpoonacularSearchResponse: Decodable {
    let offset: Int
    let number: Int
    let results: [SpoonacularRecipe]
    let totalResults: Int
}

struct SpoonacularRecipe: Decodable {
    let id: Int
    let title: String
    let image: String?
    let servings: Int?
    let readyInMinutes: Int?
    let extendedIngredients: [SpoonacularIngredient]?
    let analyzedInstructions: [SpoonacularInstructionGroup]?
}

struct SpoonacularIngredient: Decodable {
    let id: Int?
    let name: String
    let original: String?
}

struct SpoonacularInstructionGroup: Decodable {
    let name: String?
    let steps: [SpoonacularStep]?
}

struct SpoonacularStep: Decodable {
    let number: Int
    let step: String
}

enum SpoonacularMapper {

    static func mapRecipes(_ spoonacularRecipes: [SpoonacularRecipe]) -> [Recipe] {
        spoonacularRecipes.compactMap(mapRecipe)
    }

    static func mapRecipe(_ sr: SpoonacularRecipe) -> Recipe {
        let ingredients: [Ingredient] = (sr.extendedIngredients ?? []).map { ext in
            Ingredient(name: ext.original ?? ext.name)
        }

        let cleanedIngredients: [Ingredient] = (sr.extendedIngredients ?? []).map { ext in
            Ingredient(name: ext.name)
        }

        let instructions: [Recipe.Step] = (sr.analyzedInstructions ?? [])
            .flatMap { $0.steps ?? [] }
            .sorted { $0.number < $1.number }
            .map { Recipe.Step(text: $0.step) }

        let imageURL = sr.image ?? ""

        let complexity = mapComplexity(readyInMinutes: sr.readyInMinutes)
        let timeString = sr.readyInMinutes.map { "\($0) min" }

        // TODO: Add calories when addRecipeNutrition=true is enabled
        let additionalInfo = Recipe.AdditionalInfo(
            time: timeString,
            servings: sr.servings,
            complexity: complexity,
            calories: nil
        )

        return Recipe(
            title: sr.title,
            ingredients: ingredients,
            instructions: instructions,
            image: imageURL,
            cleanedIngredients: cleanedIngredients,
            additionalInfo: additionalInfo
        )
    }

    private static func mapComplexity(readyInMinutes: Int?) -> String {
        guard let minutes = readyInMinutes else { return "Medium" }
        switch minutes {
        case ...20: return "Easy"
        case 21...45: return "Medium"
        default: return "Hard"
        }
    }
}
