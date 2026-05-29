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

    func testIngredientAmountConvertsBetweenVolumeUnits() {
        let amount = IngredientAmount(value: 1, unit: .cup)

        let tablespoons = amount.converted(to: .tablespoon)

        XCTAssertEqual(tablespoons?.unit, .tablespoon)
        XCTAssertEqual(tablespoons?.value ?? 0, 16, accuracy: 0.001)
    }

    func testIngredientAmountConvertsBetweenMassUnits() {
        let amount = IngredientAmount(value: 1, unit: .pound)

        let grams = amount.converted(to: .gram)

        XCTAssertEqual(grams?.unit, .gram)
        XCTAssertEqual(grams?.value ?? 0, 453.592, accuracy: 0.001)
    }

    func testIngredientAmountDoesNotConvertIncompatibleUnits() {
        let amount = IngredientAmount(value: 1, unit: .cup)

        XCTAssertNil(amount.converted(to: .gram))
        XCTAssertNil(amount.value(in: .gram))
    }

    func testIngredientAmountPreservesMatchingUncountableUnit() {
        let amount = IngredientAmount(value: nil, unit: .toTaste)

        XCTAssertEqual(amount.converted(to: .toTaste), amount)
        XCTAssertNil(amount.converted(to: .asNeeded))
    }
}
