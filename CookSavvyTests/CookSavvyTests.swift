//
//  CookSavvyTests.swift
//  CookSavvyTests
//
//  Created by Igor Pivnyk on 29/08/2025.
//

import XCTest
@testable import CookSavvy

final class DBInterfaceTests: XCTestCase {

    var dbInterface: DBInterface!
//    var mockRecipes: [Recipe] = []
    override func setUpWithError() throws {
        dbInterface = try DBInterface(inMemory: true)
    }

    override func tearDownWithError() throws {
        dbInterface = nil
//        mockRecipes.removeAll()
    }

    func testInsertionRecipes() throws {
        let mockRecipes = Recipe.mocks(count: 10)
        try dbInterface.insertRecipes(mockRecipes)
        let ingredients = mockRecipes.flatMap(\.ingredients)
        
        let result = try dbInterface.getRecipes(byIngredients: ingredients, offset: 0, limit: 20)
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
        
        let failResult = try dbInterface.getRecipes(byIngredients: failableIngredients, offset: 0, limit: 20)
        XCTAssertTrue(failResult.isEmpty, "Should not be results with failable ingredients")
        
        let success = try dbInterface.getRecipes(byIngredients: successfullIngredients, offset: 0, limit: 20)
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

    func testInitializationThrowsForInvalidDatabasePath() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CookSavvyInvalidDBPath_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        XCTAssertThrowsError(try DBInterface(databaseURL: directory))
    }

    func testConcurrentRecipeCacheAccessDoesNotCrash() throws {
        let recipes = Recipe.mocks(count: 25)
        try dbInterface.insertRecipes(recipes)
        let ingredients = Array(recipes.flatMap(\.ingredients).prefix(20))
        let lock = NSLock()
        var errors: [Error] = []

        DispatchQueue.concurrentPerform(iterations: 100) { index in
            do {
                if index.isMultiple(of: 3) {
                    _ = try dbInterface.getAllRecipes(offset: 0, limit: 25)
                } else if index.isMultiple(of: 5), let id = try dbInterface.getRecipeId(byTitle: recipes[index % recipes.count].title) {
                    _ = try dbInterface.getRecipe(byID: id)
                } else {
                    _ = try dbInterface.getRecipes(byIngredients: ingredients, offset: 0, limit: 25)
                }
            } catch {
                lock.lock()
                errors.append(error)
                lock.unlock()
            }
        }

        XCTAssertTrue(errors.isEmpty)
    }

    func testGetRecipesWithEmptyIngredientsReturnsEmpty() throws {
        let result = try dbInterface.getRecipes(byIngredients: [], offset: 0, limit: 20)
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
            additionalInfo: .mock
        )
        let r2 = Recipe(
            title: "Onion Soup",
            ingredients: [onion, "Butter", "Stock"],
            instructions: ["Caramelize onions", "Add stock", "Simmer"],
            image: "onion_soup",
            additionalInfo: .mock
        )

        try dbInterface.insertRecipes([r1, r2])

        // Query by garlic -> only r1
        let resGarlic = try dbInterface.getRecipes(byIngredients: [garlic], offset: 0, limit: 20)
        XCTAssertEqual(resGarlic.count, 1)
        XCTAssertEqual(resGarlic.first?.title, r1.title)

        // Query by onion -> only r2
        let resOnion = try dbInterface.getRecipes(byIngredients: [onion], offset: 0, limit: 20)
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
            additionalInfo: .mock
        )
        try dbInterface.insertRecipes([r])

        let unknown = Ingredient(name: "__does_not_exist__")
        let res = try dbInterface.getRecipes(byIngredients: [unknown, known], offset: 0, limit: 20)
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
            additionalInfo: .mock
        )
        try dbInterface.insertRecipes([r])

        // Query by "Lemon" should find the recipe (and only once)
        let res = try dbInterface.getRecipes(byIngredients: [lemon], offset: 0, limit: 20)
        XCTAssertEqual(res.count, 1)
        XCTAssertEqual(res.first?.title, r.title)
    }

    // MARK: - Pantry tests

    func testAddAndFetchPantryItems() throws {
        let salt = Ingredient(name: "Salt", description: nil, pictureFileName: nil, foodGroup: "Spices", foodSubgroup: nil)
        let oliveOil = Ingredient(name: "Olive Oil", description: nil, pictureFileName: nil, foodGroup: "Pantry", foodSubgroup: nil)
        try dbInterface.insertIngredients([salt, oliveOil])

        try dbInterface.addPantryItem(salt)
        try dbInterface.addPantryItem(oliveOil)

        let pantryItems = try dbInterface.getPantryItems()
        XCTAssertEqual(Set(pantryItems.map(\.name)), Set(["Salt", "Olive Oil"]))
        XCTAssertTrue(try dbInterface.isPantryItem(salt))
    }

    func testAddPantryItemDedupesCaseInsensitively() throws {
        let salt = Ingredient(name: "Salt", description: nil, pictureFileName: nil, foodGroup: "Spices", foodSubgroup: nil)
        try dbInterface.insertIngredients([salt])

        try dbInterface.addPantryItem(Ingredient(name: "salt"))
        try dbInterface.addPantryItem(Ingredient(name: "SALT"))

        let pantryItems = try dbInterface.getPantryItems()
        XCTAssertEqual(pantryItems.map(\.name), ["Salt"])
    }

    func testRemovePantryItem() throws {
        let salt = Ingredient(name: "Salt")
        try dbInterface.insertIngredients([salt])
        try dbInterface.addPantryItem(salt)

        try dbInterface.removePantryItem(Ingredient(name: "salt"))

        XCTAssertFalse(try dbInterface.isPantryItem(salt))
        XCTAssertTrue(try dbInterface.getPantryItems().isEmpty)
    }

    func testPantryItemsPersistWithinDatabaseInstance() throws {
        let flour = Ingredient(name: "Flour", description: nil, pictureFileName: nil, foodGroup: "Grains", foodSubgroup: nil)
        try dbInterface.insertIngredients([flour])
        try dbInterface.addPantryItem(flour)

        let fetched = try dbInterface.getPantryItems()

        XCTAssertEqual(fetched, [flour])
    }

    func testClearDatabaseRemovesPantryItems() throws {
        let sugar = Ingredient(name: "Sugar")
        try dbInterface.insertIngredients([sugar])
        try dbInterface.addPantryItem(sugar)

        try dbInterface.clearDatabase()

        XCTAssertTrue(try dbInterface.getPantryItems().isEmpty)
    }

    func testPantryServicePersistsThroughDatabase() async throws {
        let pepper = Ingredient(name: "Pepper")
        try dbInterface.insertIngredients([pepper])
        let service = PantryService(dbInterface: dbInterface)

        try await service.addItem(pepper)
        let containsPepper = try await service.contains(Ingredient(name: "pepper"))
        XCTAssertTrue(containsPepper)

        try await service.removeItem(pepper)
        let remainingItems = try await service.getItems()
        XCTAssertTrue(remainingItems.isEmpty)
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
            additionalInfo: .mock
        )
        let r2 = Recipe(
            title: "Basil Pasta",
            ingredients: [basil, "Pasta"],
            instructions: ["Boil", "Mix"],
            image: "img2",
            additionalInfo: .mock
        )
        try dbInterface.insertRecipes([r1, r2])

        try dbInterface.removeRecipe(withTitle: r1.title)

        let resGarlic = try dbInterface.getRecipes(byIngredients: [garlic], offset: 0, limit: 20)
        XCTAssertTrue(resGarlic.isEmpty)

        let resBasil = try dbInterface.getRecipes(byIngredients: [basil], offset: 0, limit: 20)
        XCTAssertTrue(resBasil.contains { $0.title == r2.title })
    }

    func testRemoveAllRecipes() throws {
        let r = Recipe.mocks(count: 5)
        try dbInterface.insertRecipes(r)

        try dbInterface.removeAllRecipes()

        let someIngredient = Ingredient(name: "Anything")
        let res = try dbInterface.getRecipes(byIngredients: [someIngredient], offset: 0, limit: 20)
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
            additionalInfo: .mock
        )
        let r2 = Recipe(
            title: "Tomato Soup",
            ingredients: [tomato, "Stock"],
            instructions: ["Simmer"],
            image: "img",
            additionalInfo: .mock
        )
        try dbInterface.insertRecipes([r1, r2])

        try dbInterface.removeRecipes(byIngredients: [garlic])

        let resGarlic = try dbInterface.getRecipes(byIngredients: [garlic], offset: 0, limit: 20)
        XCTAssertTrue(resGarlic.isEmpty)

        let resTomato = try dbInterface.getRecipes(byIngredients: [tomato], offset: 0, limit: 20)
        XCTAssertTrue(resTomato.contains { $0.title == r2.title })
    }

    // MARK: - New searchIngredients API tests

    func testSearchIngredientsReturnsSubstringMatchesCaseInsensitive() throws {
        // Fresh DB from setUp
        let items: [Ingredient] = [
            "Chicken",
            "Chicken Breast",
            "chicken thigh",
            "Pasta",
            "Rice"
        ]
        try dbInterface.insertIngredients(items)

        let res = try dbInterface.searchIngredients(matching: "CHICKEN", limit: 10)

        let names = Set(res.map { $0.name })
        XCTAssertTrue(names.contains("Chicken"))
        XCTAssertTrue(names.contains("Chicken Breast"))
        XCTAssertTrue(names.contains("chicken thigh"))
        XCTAssertFalse(names.contains("Pasta"))
        XCTAssertFalse(names.contains("Rice"))
    }

    func testSearchIngredientsRespectsLimit() throws {
        let many = (1...10).map { Ingredient(name: "Chicken \($0)") }
        try dbInterface.insertIngredients(many)

        let res = try dbInterface.searchIngredients(matching: "chicken", limit: 3)
        XCTAssertEqual(res.count, 3)
        // Ensure all results contain the query (case-insensitive)
        XCTAssertTrue(res.allSatisfy { $0.name.lowercased().contains("chicken") })
    }

    func testSearchIngredientsEmptyQueryReturnsEmpty() throws {
        let res = try dbInterface.searchIngredients(matching: "", limit: 5)
        XCTAssertTrue(res.isEmpty)
    }

    func testSearchIngredientsNoMatchesReturnsEmpty() throws {
        try dbInterface.insertIngredients(["Pasta", "Rice"])
        let res = try dbInterface.searchIngredients(matching: "chicken", limit: 10)
        XCTAssertTrue(res.isEmpty)
    }

    func testGetIngredientsExactMatchIsCaseInsensitive() throws {
        try dbInterface.insertIngredients(["Chicken"]) // capitalized insert
        let resLower = try dbInterface.getIngredients(byName: "chicken")
        XCTAssertEqual(resLower.count, 1)
        XCTAssertEqual(resLower.first?.name, "Chicken")
    }

    // MARK: - Word-based recipe matching tests

    func testGetRecipesMatchesSingleWordFromMultiWordIngredient() throws {
        let chickenBreast: Ingredient = "Chicken Breast"
        let r = Recipe(
            title: "Grilled Chicken",
            ingredients: [chickenBreast, "Salt"],
            instructions: ["Grill"],
            image: "img",
            additionalInfo: .mock
        )
        try dbInterface.insertRecipes([r])
        
        // Query with just "chicken" should match "Chicken Breast"
        let results = try dbInterface.getRecipes(byIngredients: ["chicken"], offset: 0, limit: 20)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Grilled Chicken")
    }

    func testGetRecipesMatchesSecondWordFromMultiWordIngredient() throws {
        let chickenBreast: Ingredient = "Chicken Breast"
        let r = Recipe(
            title: "Stuffed Breast",
            ingredients: [chickenBreast],
            instructions: ["Cook"],
            image: "img",
            additionalInfo: .mock
        )
        try dbInterface.insertRecipes([r])
        
        // Query with just "breast" should match "Chicken Breast"
        let results = try dbInterface.getRecipes(byIngredients: ["breast"], offset: 0, limit: 20)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Stuffed Breast")
    }

    func testGetRecipesWordMatchingIsCaseInsensitive() throws {
        let ingredient: Ingredient = "CHICKEN BREAST"
        let r = Recipe(
            title: "Chicken Dish",
            ingredients: [ingredient],
            instructions: ["Cook"],
            image: "img",
            additionalInfo: .mock
        )
        try dbInterface.insertRecipes([r])
        
        let results = try dbInterface.getRecipes(byIngredients: ["chicken"], offset: 0, limit: 20)
        XCTAssertEqual(results.count, 1)
    }

    func testGetRecipesMatchesMultipleWordsFromDifferentIngredients() throws {
        let chicken: Ingredient = "Chicken Breast"
        let tomato: Ingredient = "Tomato Sauce"
        let r = Recipe(
            title: "Chicken Tomato Pasta",
            ingredients: [chicken, tomato, "Pasta"],
            instructions: ["Cook"],
            image: "img",
            additionalInfo: .mock
        )
        try dbInterface.insertRecipes([r])
        
        // Query with "chicken" and "sauce" should match
        let results = try dbInterface.getRecipes(byIngredients: ["chicken", "sauce"], offset: 0, limit: 20)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Chicken Tomato Pasta")
    }

    func testGetRecipesNoWordMatchReturnsEmpty() throws {
        let chicken: Ingredient = "Chicken Breast"
        let r = Recipe(
            title: "Chicken Dish",
            ingredients: [chicken],
            instructions: ["Cook"],
            image: "img",
            additionalInfo: .mock
        )
        try dbInterface.insertRecipes([r])
        
        // Query with "beef" should not match "Chicken Breast"
        let results = try dbInterface.getRecipes(byIngredients: ["beef"], offset: 0, limit: 20)
        XCTAssertTrue(results.isEmpty)
    }

    func testGetRecipesDistinctResultsNoDuplicates() throws {
        let chicken: Ingredient = "Chicken Breast"
        let r = Recipe(
            title: "Chicken Pasta",
            ingredients: [chicken, "Pasta"],
            instructions: ["Cook"],
            image: "img",
            additionalInfo: .mock
        )
        try dbInterface.insertRecipes([r])
        
        // Query with both "chicken" and "breast" should return recipe only once
        let results = try dbInterface.getRecipes(byIngredients: ["chicken", "breast"], offset: 0, limit: 20)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Chicken Pasta")
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
