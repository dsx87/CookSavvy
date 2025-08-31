//
//  CookSavvyTests.swift
//  CookSavvyTests
//
//  Created by Igor Pivnyk on 29/08/2025.
//

import XCTest
@testable import CookSavvy

final class DBInterfaceTests: XCTestCase {

    var dbInterface: DBInterfaceClass!
//    var mockRecipes: [Recipe] = []
    override func setUpWithError() throws {
        dbInterface = DBInterfaceClass()
    }

    override func tearDownWithError() throws {
        dbInterface = nil
//        mockRecipes.removeAll()
    }

    func testInsertionRecipes() throws {
        let mockRecipes = Recipe.mocks(count: 10)
        try dbInterface.insertRecipes(mockRecipes)
        let ingredients = mockRecipes.flatMap(\.ingredients)
        
        let result = try dbInterface.getRecipes(byIngredients: ingredients)
        XCTAssertEqual(mockRecipes, result, "Not all recipes were extracted")
    }

    func testInsertionIngredients() throws {
        let mockIngredients = Ingredient.mocks(count: 5)
        let names = mockIngredients.map(\.name)
        try dbInterface.insertIngredients(mockIngredients)
        let result = try names.map { name in
            let ingr = try dbInterface.getIngredients(byName: name)
            XCTAssertEqual(ingr.count, 1, "Should be only one component")
            return try XCTUnwrap(ingr.first, "Empty result")
        }
        XCTAssertEqual(mockIngredients, result, "Not all ingredients were extracted")
    }
    
    func testGettingRecipes() throws {
        let mockRecipes = Recipe.mocks(count: 5)
        try dbInterface.insertRecipes(mockRecipes)
        let failableIngredients = [
            Ingredient(name: "Failable name 3"),
            Ingredient(name: "Failable name 2"),
            Ingredient(name: "Failable name 1"),
        ]
        let successfullIngredients = mockRecipes
            .flatMap(\.ingredients)
            .randomElements(count: 5)
        
        let failResult = try dbInterface.getRecipes(byIngredients: failableIngredients)
        XCTAssertTrue(failResult.isEmpty, "Should not be results with failable ingredients")
        
        let success = try dbInterface.getRecipes(byIngredients: successfullIngredients)
        XCTAssertFalse(success.isEmpty, "the result is empty")
        let allInMocks = Set(success).isSubset(of: Set(mockRecipes))
        XCTAssertTrue(allInMocks, "Some returned recipes were not among the inserted mocks")
    }
    
    func testPerformanceIngredientsInsertion() throws {
        let ingredients = Ingredient.mocks(count: 5000)
        measure {
            try? dbInterface.insertIngredients(ingredients)
        }
    }

    func testPerformanceRecipesInsertion() throws {
        let recipes = Recipe.mocks(count: 5000)
        measure {
            try? dbInterface.insertRecipes(recipes)
        }
    }

    // MARK: - Additional robustness tests

    func testGetRecipesWithEmptyIngredientsReturnsEmpty() throws {
        let result = try dbInterface.getRecipes(byIngredients: [])
        XCTAssertTrue(result.isEmpty, "Expected empty result for empty ingredient query")
    }

    func testDuplicateIngredientVariantsReturnInOrderAndClamp() throws {
        // Same name, different metadata to ensure Equatable distinguishes them
        let v1 = Ingredient(name: "Garlic", description: "fresh garlic", pictureFileName: nil, foodGroup: "Vegetables", foodSubgroup: "Alliums")
        let v2 = Ingredient(name: "Garlic", description: "minced garlic", pictureFileName: "garlic.png", foodGroup: "Vegetables", foodSubgroup: "Alliums")
        try dbInterface.insertIngredients([v1, v2])

        // Successive calls should walk through variants and then clamp to last
        let f1 = try dbInterface.getIngredients(byName: "Garlic")
        XCTAssertEqual(f1, [v1])

        let f2 = try dbInterface.getIngredients(byName: "Garlic")
        XCTAssertEqual(f2, [v2])

        let f3 = try dbInterface.getIngredients(byName: "Garlic")
        XCTAssertEqual(f3, [v2])
    }

    func testGetIngredientsUnknownNameReturnsEmpty() throws {
        let res = try dbInterface.getIngredients(byName: "__unknown__")
        XCTAssertTrue(res.isEmpty)
    }

    func testGetRecipesFiltersByProvidedIngredients() throws {
        // Build two distinct recipes
        let garlic: Ingredient = "Garlic"
        let onion: Ingredient = "Onion"

        let r1 = Recipe(
            title: "Garlic Pasta",
            ingredients: [garlic, "Pasta", "Olive Oil"],
            instructions: ["Boil pasta", "Sauté garlic", "Combine"],
            image: "garlic_pasta",
            cleanedIngredients: ["Garlic", "Pasta", "Olive Oil"],
            additionalInfo: .mock
        )
        let r2 = Recipe(
            title: "Onion Soup",
            ingredients: [onion, "Butter", "Stock"],
            instructions: ["Caramelize onions", "Add stock", "Simmer"],
            image: "onion_soup",
            cleanedIngredients: ["Onion", "Butter", "Stock"],
            additionalInfo: .mock
        )

        try dbInterface.insertRecipes([r1, r2])

        // Query by garlic -> only r1
        let resGarlic = try dbInterface.getRecipes(byIngredients: [garlic])
        XCTAssertEqual(resGarlic.count, 1)
        XCTAssertEqual(resGarlic.first?.title, r1.title)

        // Query by onion -> only r2
        let resOnion = try dbInterface.getRecipes(byIngredients: [onion])
        XCTAssertEqual(resOnion.count, 1)
        XCTAssertEqual(resOnion.first?.title, r2.title)
    }

    func testGetRecipesWithKnownAndUnknownIngredientsStillReturnsMatches() throws {
        let known: Ingredient = "Basil"
        let r = Recipe(
            title: "Tomato Basil Pasta",
            ingredients: [known, "Tomato", "Pasta"],
            instructions: ["Cook pasta", "Make sauce", "Combine"],
            image: "tb_pasta",
            cleanedIngredients: ["Basil", "Tomato", "Pasta"],
            additionalInfo: .mock
        )
        try dbInterface.insertRecipes([r])

        let unknown = Ingredient(name: "__does_not_exist__")
        let res = try dbInterface.getRecipes(byIngredients: [unknown, known])
        XCTAssertFalse(res.isEmpty)
        XCTAssertTrue(res.contains { $0.title == r.title })
    }

    func testInsertRecipeWithDuplicateIngredientNames() throws {
        // Duplicate "Lemon" appears twice; linking should deduplicate per recipe
        let lemon: Ingredient = "Lemon"
        let r = Recipe(
            title: "Lemon Lemonade",
            ingredients: [lemon, lemon, "Water", "Sugar"],
            instructions: ["Squeeze lemons", "Mix with water and sugar"],
            image: "lemonade",
            cleanedIngredients: ["Lemon", "Water", "Sugar"],
            additionalInfo: .mock
        )
        try dbInterface.insertRecipes([r])

        // Query by "Lemon" should find the recipe (and only once)
        let res = try dbInterface.getRecipes(byIngredients: [lemon])
        XCTAssertEqual(res.count, 1)
        XCTAssertEqual(res.first?.title, r.title)
    }

    // MARK: - Removal tests (pending implementation)

    func testRemoveSpecificIngredientByName() throws {
        let garlic: Ingredient = "Garlic"
        let onion: Ingredient = "Onion"
        try dbInterface.insertIngredients([garlic, onion])

        try dbInterface.removeIngredient(named: garlic.name)

        let resGarlic = try dbInterface.getIngredients(byName: garlic.name)
        XCTAssertTrue(resGarlic.isEmpty)

        let resOnion = try dbInterface.getIngredients(byName: onion.name)
        XCTAssertEqual(resOnion, [onion])
    }

    func testRemoveAllIngredients() throws {
        let ingredients = ["Basil", "Parsley", "Tomato"].map(Ingredient.init(stringLiteral:))
        try dbInterface.insertIngredients(ingredients)

        try dbInterface.removeAllIngredients()

        for ing in ingredients {
            let res = try dbInterface.getIngredients(byName: ing.name)
            XCTAssertTrue(res.isEmpty)
        }
    }

    func testRemoveNonexistentIngredientIsNoop() throws {
        let ingredients = ["Rice", "Quinoa"].map(Ingredient.init(stringLiteral:))
        try dbInterface.insertIngredients(ingredients)

        try dbInterface.removeIngredients(["__unknown__"])

        for ing in ingredients {
            let res = try dbInterface.getIngredients(byName: ing.name)
            XCTAssertEqual(res, [ing])
        }
    }

    func testRemoveRecipeByTitleOrId() throws {
        let garlic: Ingredient = "Garlic"
        let basil: Ingredient = "Basil"
        let r1 = Recipe(
            title: "Garlic Pasta",
            ingredients: [garlic, "Pasta"],
            instructions: ["Boil", "Mix"],
            image: "img1",
            cleanedIngredients: ["Garlic", "Pasta"],
            additionalInfo: .mock
        )
        let r2 = Recipe(
            title: "Basil Pasta",
            ingredients: [basil, "Pasta"],
            instructions: ["Boil", "Mix"],
            image: "img2",
            cleanedIngredients: ["Basil", "Pasta"],
            additionalInfo: .mock
        )
        try dbInterface.insertRecipes([r1, r2])

        try dbInterface.removeRecipe(withTitle: r1.title)

        let resGarlic = try dbInterface.getRecipes(byIngredients: [garlic])
        XCTAssertTrue(resGarlic.isEmpty)

        let resBasil = try dbInterface.getRecipes(byIngredients: [basil])
        XCTAssertTrue(resBasil.contains { $0.title == r2.title })
    }

    func testRemoveAllRecipes() throws {
        let r = Recipe.mocks(count: 5)
        try dbInterface.insertRecipes(r)

        try dbInterface.removeAllRecipes()

        let someIngredient = Ingredient(name: "Anything")
        let res = try dbInterface.getRecipes(byIngredients: [someIngredient])
        XCTAssertTrue(res.isEmpty)
    }

    func testRemoveRecipesByIngredientsCascade() throws {
        let garlic: Ingredient = "Garlic"
        let tomato: Ingredient = "Tomato"
        let r1 = Recipe(
            title: "Garlic Chicken",
            ingredients: [garlic, "Chicken"],
            instructions: ["Cook"],
            image: "img",
            cleanedIngredients: ["Garlic", "Chicken"],
            additionalInfo: .mock
        )
        let r2 = Recipe(
            title: "Tomato Soup",
            ingredients: [tomato, "Stock"],
            instructions: ["Simmer"],
            image: "img",
            cleanedIngredients: ["Tomato", "Stock"],
            additionalInfo: .mock
        )
        try dbInterface.insertRecipes([r1, r2])

        try dbInterface.removeRecipes(byIngredients: [garlic])

        let resGarlic = try dbInterface.getRecipes(byIngredients: [garlic])
        XCTAssertTrue(resGarlic.isEmpty)

        let resTomato = try dbInterface.getRecipes(byIngredients: [tomato])
        XCTAssertTrue(resTomato.contains { $0.title == r2.title })
    }
}


extension Array where Element: Hashable {
    func randomElements(count: Int) -> [Element] {
        guard !isEmpty else { return [] }
        let unique = Array(Set(self))
        let k = Swift.min(count, unique.count)
        var rng = SystemRandomNumberGenerator()
        return Array(unique.shuffled(using: &rng).prefix(k))
    }
}
