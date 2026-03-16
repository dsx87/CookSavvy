//
//  IngredientTests.swift
//  CookSavvyTests
//

import XCTest
@testable import CookSavvy

final class IngredientTests: XCTestCase {

    private func makeIngredient(foodGroup: String?) -> Ingredient {
        Ingredient(
            name: "Test",
            description: nil,
            pictureFileName: nil,
            foodGroup: foodGroup,
            foodSubgroup: nil
        )
    }

    func testKnownFoodGroupMappings() {
        XCTAssertEqual(makeIngredient(foodGroup: "Protein").category, .proteins)
        XCTAssertEqual(makeIngredient(foodGroup: "Poultry").category, .proteins)
        XCTAssertEqual(makeIngredient(foodGroup: "Fish").category, .proteins)
        XCTAssertEqual(makeIngredient(foodGroup: "Seafood").category, .proteins)
        XCTAssertEqual(makeIngredient(foodGroup: "Vegetables").category, .veggies)
        XCTAssertEqual(makeIngredient(foodGroup: "Legumes").category, .veggies)
        XCTAssertEqual(makeIngredient(foodGroup: "Dairy").category, .dairy)
        XCTAssertEqual(makeIngredient(foodGroup: "Cheese").category, .dairy)
        XCTAssertEqual(makeIngredient(foodGroup: "Grains").category, .grains)
        XCTAssertEqual(makeIngredient(foodGroup: "Cereal").category, .grains)
        XCTAssertEqual(makeIngredient(foodGroup: "Fruit").category, .fruits)
        XCTAssertEqual(makeIngredient(foodGroup: "Citrus").category, .fruits)
        XCTAssertEqual(makeIngredient(foodGroup: "Herbs & Spices").category, .spices)
        XCTAssertEqual(makeIngredient(foodGroup: "Seasoning").category, .spices)
    }

    func testNilFoodGroupDefaultsToOther() {
        XCTAssertEqual(makeIngredient(foodGroup: nil).category, .other)
    }

    func testUnknownFoodGroupDefaultsToOther() {
        XCTAssertEqual(makeIngredient(foodGroup: "Beverages").category, .other)
        XCTAssertEqual(makeIngredient(foodGroup: "Snacks").category, .other)
        XCTAssertEqual(makeIngredient(foodGroup: "").category, .other)
    }

    func testCaseInsensitive() {
        XCTAssertEqual(makeIngredient(foodGroup: "PROTEIN").category, .proteins)
        XCTAssertEqual(makeIngredient(foodGroup: "Dairy Products").category, .dairy)
        XCTAssertEqual(makeIngredient(foodGroup: "Fresh Fruit").category, .fruits)
    }
}
