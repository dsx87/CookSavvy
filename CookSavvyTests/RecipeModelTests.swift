//
//  RecipeModelTests.swift
//  CookSavvyTests
//

import XCTest
@testable import CookSavvy

final class RecipeModelTests: XCTestCase {

    func testStepTimerMinutes() {
        let stepWithTimer = Recipe.Step(text: "Simmer the sauce", timerMinutes: 15)
        let stepWithoutTimer = Recipe.Step(text: "Season to taste")

        XCTAssertEqual(stepWithTimer.timerMinutes, 15)
        XCTAssertNil(stepWithoutTimer.timerMinutes)
        XCTAssertEqual(stepWithTimer.text, "Simmer the sauce")
    }

    func testAdditionalInfoConstruction() {
        let info = Recipe.AdditionalInfo(time: "30 min", servings: 4, complexity: "Medium", calories: 500)

        let timeInfo = info.infos.first { if case .time = $0 { return true }; return false }
        let servingsInfo = info.infos.first { if case .servings = $0 { return true }; return false }
        let complexityInfo = info.infos.first { if case .complexity = $0 { return true }; return false }
        let caloriesInfo = info.infos.first { if case .calories = $0 { return true }; return false }

        XCTAssertNotNil(timeInfo)
        XCTAssertNotNil(servingsInfo)
        XCTAssertNotNil(complexityInfo)
        XCTAssertNotNil(caloriesInfo)

        if case .time(let t) = timeInfo { XCTAssertEqual(t, "30 min") }
        if case .servings(let s) = servingsInfo { XCTAssertEqual(s, 4) }
        if case .complexity(let c) = complexityInfo { XCTAssertEqual(c, "Medium") }
        if case .calories(let cal) = caloriesInfo { XCTAssertEqual(cal, 500) }
    }

    func testIngredientStringLiteralInit() {
        let ingredient: Ingredient = "Basil"
        XCTAssertEqual(ingredient.name, "Basil")
        XCTAssertNil(ingredient.foodGroup)
        XCTAssertNil(ingredient.description)
    }

    func testIngredientEqualityByName() {
        let a = Ingredient(name: "Garlic")
        let b = Ingredient(name: "Garlic")
        let c = Ingredient(name: "Onion")

        XCTAssertEqual(a, b, "Ingredients with the same name should be equal")
        XCTAssertNotEqual(a, c, "Ingredients with different names should not be equal")
    }

    func testCookTimeMinutesParsesHourFormat() {
        let recipe = Recipe(
            title: "Slow Braise",
            ingredients: [],
            instructions: [Recipe.Step](),
            image: "",
            cleanedIngredients: [],
            additionalInfo: Recipe.AdditionalInfo(time: "1 hr 30 min", servings: nil, complexity: nil, calories: nil)
        )

        XCTAssertEqual(recipe.cookTimeMinutes, 90)
    }

    func testCookTimeMinutesParsesBareMinsAfterHour() {
        let recipe = Recipe(
            title: "Slow Braise",
            ingredients: [],
            instructions: [Recipe.Step](),
            image: "",
            cleanedIngredients: [],
            additionalInfo: Recipe.AdditionalInfo(time: "1h30", servings: nil, complexity: nil, calories: nil)
        )

        XCTAssertEqual(recipe.cookTimeMinutes, 90)
    }

    func testCookTimeMinutesUsesUpperBoundForRanges() {
        let recipe = Recipe(
            title: "Roasted Veg",
            ingredients: [],
            instructions: [Recipe.Step](),
            image: "",
            cleanedIngredients: [],
            additionalInfo: Recipe.AdditionalInfo(time: "25-30 min", servings: nil, complexity: nil, calories: nil)
        )

        XCTAssertEqual(recipe.cookTimeMinutes, 30)
    }
}
