//
//  SpoonacularMapperTests.swift
//  CookSavvyTests
//

import XCTest
@testable import CookSavvy

final class SpoonacularMapperTests: XCTestCase {

    private func makeFullDTO() -> SpoonacularRecipe {
        SpoonacularRecipe(
            id: 42,
            title: "Garlic Chicken",
            image: "https://example.com/chicken.jpg",
            servings: 4,
            readyInMinutes: 30,
            extendedIngredients: [
                SpoonacularIngredient(id: 1, name: "chicken", original: "2 chicken breasts"),
                SpoonacularIngredient(id: 2, name: "garlic", original: "3 cloves garlic")
            ],
            analyzedInstructions: [
                SpoonacularInstructionGroup(
                    name: nil,
                    steps: [
                        SpoonacularStep(number: 1, step: "Season the chicken."),
                        SpoonacularStep(number: 2, step: "Cook until golden.")
                    ]
                )
            ]
        )
    }

    func testFullDTOMapping() {
        let dto = makeFullDTO()
        let recipe = SpoonacularMapper.mapRecipe(dto)

        XCTAssertEqual(recipe.title, "Garlic Chicken")
        XCTAssertEqual(recipe.ingredients.count, 2)
        XCTAssertEqual(recipe.ingredients[0].name, "2 chicken breasts")
        XCTAssertEqual(recipe.cleanedIngredients[0].name, "chicken")
        XCTAssertEqual(recipe.instructions.count, 2)
        XCTAssertEqual(recipe.instructions[0].text, "Season the chicken.")
        XCTAssertEqual(recipe.image, "https://example.com/chicken.jpg")

        let servings = recipe.additionalInfo.infos.first { if case .servings = $0 { return true }; return false }
        XCTAssertNotNil(servings)
    }

    func testMissingOptionalFields() {
        let dto = SpoonacularRecipe(
            id: 1,
            title: "Plain Recipe",
            image: nil,
            servings: nil,
            readyInMinutes: nil,
            extendedIngredients: nil,
            analyzedInstructions: nil
        )
        let recipe = SpoonacularMapper.mapRecipe(dto)

        XCTAssertEqual(recipe.title, "Plain Recipe")
        XCTAssertTrue(recipe.image.isEmpty)
        XCTAssertTrue(recipe.ingredients.isEmpty)
        XCTAssertTrue(recipe.instructions.isEmpty)
    }

    func testComplexityMapping() {
        let easyDTO = SpoonacularRecipe(id: 1, title: "Easy", image: nil, servings: nil, readyInMinutes: 20, extendedIngredients: nil, analyzedInstructions: nil)
        let mediumDTO = SpoonacularRecipe(id: 2, title: "Medium", image: nil, servings: nil, readyInMinutes: 35, extendedIngredients: nil, analyzedInstructions: nil)
        let hardDTO = SpoonacularRecipe(id: 3, title: "Hard", image: nil, servings: nil, readyInMinutes: 60, extendedIngredients: nil, analyzedInstructions: nil)

        let easyRecipe = SpoonacularMapper.mapRecipe(easyDTO)
        let mediumRecipe = SpoonacularMapper.mapRecipe(mediumDTO)
        let hardRecipe = SpoonacularMapper.mapRecipe(hardDTO)

        XCTAssertEqual(complexityString(from: easyRecipe), "Easy")
        XCTAssertEqual(complexityString(from: mediumRecipe), "Medium")
        XCTAssertEqual(complexityString(from: hardRecipe), "Hard")
    }

    func testEmptyResults() {
        let recipes = SpoonacularMapper.mapRecipes([])
        XCTAssertTrue(recipes.isEmpty)
    }

    // MARK: - Helper

    private func complexityString(from recipe: Recipe) -> String? {
        for info in recipe.additionalInfo.infos {
            if case .complexity(let c) = info { return c }
        }
        return nil
    }
}
