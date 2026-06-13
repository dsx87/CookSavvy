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

    func testInsertionRecipes() async throws {
        let mockRecipes = Recipe.mocks(count: 10)
        try await dbInterface.insertRecipes(mockRecipes)
        let ingredients = mockRecipes.flatMap(\.ingredients)

        let result = try await dbInterface.getRecipes(byIngredients: ingredients, offset: 0, limit: 20)
        XCTAssertEqual(mockRecipes, result, "Not all recipes were extracted")
    }

    func testInsertionIngredients() async throws {
        let mockIngredients = Ingredient.mocks(count: 5)
        let names = mockIngredients.map(\.name)
        try await dbInterface.insertIngredients(mockIngredients)
        var result: [Ingredient] = []
        for name in names {
            let ingr = try await dbInterface.getIngredients(byName: name)
            XCTAssertEqual(ingr.count, 1, "Should be only one component")
            result.append(try XCTUnwrap(ingr.first, "Empty result"))
        }
        XCTAssertEqual(mockIngredients, result, "Not all ingredients were extracted")
    }
    
    func testGettingRecipes() async throws {
        let mockRecipes = Recipe.mocks(count: 5)
        try await dbInterface.insertRecipes(mockRecipes)
        let failableIngredients = [
            Ingredient(name: "Failable name 3"),
            Ingredient(name: "Failable name 2"),
            Ingredient(name: "Failable name 1"),
        ]
        let successfullIngredients = mockRecipes
            .flatMap(\.ingredients)
            .randomElements(count: 5)
        
        let failResult = try await dbInterface.getRecipes(byIngredients: failableIngredients, offset: 0, limit: 20)
        XCTAssertTrue(failResult.isEmpty, "Should not be results with failable ingredients")

        let success = try await dbInterface.getRecipes(byIngredients: successfullIngredients, offset: 0, limit: 20)
        XCTAssertFalse(success.isEmpty, "the result is empty")
        let allInMocks = Set(success).isSubset(of: Set(mockRecipes))
        XCTAssertTrue(allInMocks, "Some returned recipes were not among the inserted mocks")
    }
    
    func testPerformanceIngredientsInsertion() throws {
        let ingredients = Ingredient.mocks(count: 5000)
        let db = dbInterface!
        // `measure`'s closure is synchronous and `DBInterface` is now an actor, so the async
        // insertion is driven inside the closure via an expectation that awaits the actor hop.
        measure {
            let expectation = expectation(description: "insert ingredients")
            Task {
                try? await db.insertIngredients(ingredients)
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 60)
        }
    }

    func testPerformanceRecipesInsertion() throws {
        let recipes = Recipe.mocks(count: 5000)
        let db = dbInterface!
        measure {
            let expectation = expectation(description: "insert recipes")
            Task {
                try? await db.insertRecipes(recipes)
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 60)
        }
    }

    // MARK: - Additional robustness tests

    func testInitializationThrowsForInvalidDatabasePath() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CookSavvyInvalidDBPath_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        XCTAssertThrowsError(try DBInterface(databaseURL: directory))
    }

    func testConcurrentRecipeCacheAccessDoesNotCrash() async throws {
        let recipes = Recipe.mocks(count: 25)
        try await dbInterface.insertRecipes(recipes)
        let ingredients = Array(recipes.flatMap(\.ingredients).prefix(20))
        let db = dbInterface!

        // `DBInterface` is an actor, so its executor serialises cache access. Fan out 100
        // overlapping reads through a task group; each hops onto the actor for the read.
        // The group must complete without crashing or racing, and surface no errors.
        let errors: [Error] = await withTaskGroup(of: Error?.self) { group in
            for index in 0..<100 {
                group.addTask {
                    do {
                        if index.isMultiple(of: 3) {
                            _ = try await db.getAllRecipes(offset: 0, limit: 25)
                        } else if index.isMultiple(of: 5), let id = try await db.getRecipeId(byTitle: recipes[index % recipes.count].title) {
                            _ = try await db.getRecipe(byID: id)
                        } else {
                            _ = try await db.getRecipes(byIngredients: ingredients, offset: 0, limit: 25)
                        }
                        return nil
                    } catch {
                        return error
                    }
                }
            }
            var collected: [Error] = []
            for await result in group where result != nil {
                collected.append(result!)
            }
            return collected
        }

        XCTAssertTrue(errors.isEmpty)
    }

    func testGetRecipesWithEmptyIngredientsReturnsEmpty() async throws {
        let result = try await dbInterface.getRecipes(byIngredients: [], offset: 0, limit: 20)
        XCTAssertTrue(result.isEmpty, "Expected empty result for empty ingredient query")
    }

    func testDuplicateIngredientVariantsReturnInOrderAndClamp() async throws {
        // Same name, different metadata to ensure Equatable distinguishes them
        let v1 = Ingredient(name: "Garlic", description: "fresh garlic", pictureFileName: nil, foodGroup: "Vegetables", foodSubgroup: "Alliums")
        let v2 = Ingredient(name: "Garlic", description: "minced garlic", pictureFileName: "garlic.png", foodGroup: "Vegetables", foodSubgroup: "Alliums")
        try await dbInterface.insertIngredients([v1, v2])

        // Successive calls should walk through variants and then clamp to last
        let f1 = try await dbInterface.getIngredients(byName: "Garlic")
        XCTAssertEqual(f1, [v1])

        let f2 = try await dbInterface.getIngredients(byName: "Garlic")
        XCTAssertEqual(f2, [v2])

        let f3 = try await dbInterface.getIngredients(byName: "Garlic")
        XCTAssertEqual(f3, [v2])
    }

    func testGetIngredientsUnknownNameReturnsEmpty() async throws {
        let res = try await dbInterface.getIngredients(byName: "__unknown__")
        XCTAssertTrue(res.isEmpty)
    }

    func testGetRecipesFiltersByProvidedIngredients() async throws {
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

        try await dbInterface.insertRecipes([r1, r2])

        // Query by garlic -> only r1
        let resGarlic = try await dbInterface.getRecipes(byIngredients: [garlic], offset: 0, limit: 20)
        XCTAssertEqual(resGarlic.count, 1)
        XCTAssertEqual(resGarlic.first?.title, r1.title)

        // Query by onion -> only r2
        let resOnion = try await dbInterface.getRecipes(byIngredients: [onion], offset: 0, limit: 20)
        XCTAssertEqual(resOnion.count, 1)
        XCTAssertEqual(resOnion.first?.title, r2.title)
    }

    func testGetRecipesWithKnownAndUnknownIngredientsStillReturnsMatches() async throws {
        let known: Ingredient = "Basil"
        let r = Recipe(
            title: "Tomato Basil Pasta",
            ingredients: [known, "Tomato", "Pasta"],
            instructions: ["Cook pasta", "Make sauce", "Combine"],
            image: "tb_pasta",
            additionalInfo: .mock
        )
        try await dbInterface.insertRecipes([r])

        let unknown = Ingredient(name: "__does_not_exist__")
        let res = try await dbInterface.getRecipes(byIngredients: [unknown, known], offset: 0, limit: 20)
        XCTAssertFalse(res.isEmpty)
        XCTAssertTrue(res.contains { $0.title == r.title })
    }

    func testInsertRecipeWithDuplicateIngredientNames() async throws {
        // Duplicate "Lemon" appears twice; linking should deduplicate per recipe
        let lemon: Ingredient = "Lemon"
        let r = Recipe(
            title: "Lemon Lemonade",
            ingredients: [lemon, lemon, "Water", "Sugar"],
            instructions: ["Squeeze lemons", "Mix with water and sugar"],
            image: "lemonade",
            additionalInfo: .mock
        )
        try await dbInterface.insertRecipes([r])

        // Query by "Lemon" should find the recipe (and only once)
        let res = try await dbInterface.getRecipes(byIngredients: [lemon], offset: 0, limit: 20)
        XCTAssertEqual(res.count, 1)
        XCTAssertEqual(res.first?.title, r.title)
    }

    // MARK: - Pantry tests

    func testAddAndFetchPantryItems() async throws {
        let salt = Ingredient(name: "Salt", description: nil, pictureFileName: nil, foodGroup: "Spices", foodSubgroup: nil)
        let oliveOil = Ingredient(name: "Olive Oil", description: nil, pictureFileName: nil, foodGroup: "Pantry", foodSubgroup: nil)
        try await dbInterface.insertIngredients([salt, oliveOil])

        try await dbInterface.addPantryItem(salt)
        try await dbInterface.addPantryItem(oliveOil)

        let pantryItems = try await dbInterface.getPantryItems()
        XCTAssertEqual(Set(pantryItems.map(\.name)), Set(["Salt", "Olive Oil"]))
        let isSaltPantryItem = try await dbInterface.isPantryItem(salt)
        XCTAssertTrue(isSaltPantryItem)
    }

    func testAddPantryItemDedupesCaseInsensitively() async throws {
        let salt = Ingredient(name: "Salt", description: nil, pictureFileName: nil, foodGroup: "Spices", foodSubgroup: nil)
        try await dbInterface.insertIngredients([salt])

        try await dbInterface.addPantryItem(Ingredient(name: "salt"))
        try await dbInterface.addPantryItem(Ingredient(name: "SALT"))

        let pantryItems = try await dbInterface.getPantryItems()
        XCTAssertEqual(pantryItems.map(\.name), ["Salt"])
    }

    func testRemovePantryItem() async throws {
        let salt = Ingredient(name: "Salt")
        try await dbInterface.insertIngredients([salt])
        try await dbInterface.addPantryItem(salt)

        try await dbInterface.removePantryItem(Ingredient(name: "salt"))

        let isSaltPantryItem = try await dbInterface.isPantryItem(salt)
        XCTAssertFalse(isSaltPantryItem)
        let pantryItems = try await dbInterface.getPantryItems()
        XCTAssertTrue(pantryItems.isEmpty)
    }

    func testPantryItemsPersistWithinDatabaseInstance() async throws {
        let flour = Ingredient(name: "Flour", description: nil, pictureFileName: nil, foodGroup: "Grains", foodSubgroup: nil)
        try await dbInterface.insertIngredients([flour])
        try await dbInterface.addPantryItem(flour)

        let fetched = try await dbInterface.getPantryItems()

        XCTAssertEqual(fetched, [flour])
    }

    func testClearDatabaseRemovesPantryItems() async throws {
        let sugar = Ingredient(name: "Sugar")
        try await dbInterface.insertIngredients([sugar])
        try await dbInterface.addPantryItem(sugar)

        try await dbInterface.clearDatabase()

        let pantryItems = try await dbInterface.getPantryItems()
        XCTAssertTrue(pantryItems.isEmpty)
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

    func testRemoveSpecificIngredientByName() async throws {
        let garlic: Ingredient = "Garlic"
        let onion: Ingredient = "Onion"
        try await dbInterface.insertIngredients([garlic, onion])

        try await dbInterface.removeIngredient(named: garlic.name)

        let resGarlic = try await dbInterface.getIngredients(byName: garlic.name)
        XCTAssertTrue(resGarlic.isEmpty)

        let resOnion = try await dbInterface.getIngredients(byName: onion.name)
        XCTAssertEqual(resOnion, [onion])
    }

    func testRemoveAllIngredients() async throws {
        let ingredients = ["Basil", "Parsley", "Tomato"].map(Ingredient.init(stringLiteral:))
        try await dbInterface.insertIngredients(ingredients)

        try await dbInterface.removeAllIngredients()

        for ing in ingredients {
            let res = try await dbInterface.getIngredients(byName: ing.name)
            XCTAssertTrue(res.isEmpty)
        }
    }

    func testRemoveNonexistentIngredientIsNoop() async throws {
        let ingredients = ["Rice", "Quinoa"].map(Ingredient.init(stringLiteral:))
        try await dbInterface.insertIngredients(ingredients)

        try await dbInterface.removeIngredients(["__unknown__"])

        for ing in ingredients {
            let res = try await dbInterface.getIngredients(byName: ing.name)
            XCTAssertEqual(res, [ing])
        }
    }

    func testRemoveRecipeByTitleOrId() async throws {
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
        try await dbInterface.insertRecipes([r1, r2])

        try await dbInterface.removeRecipe(withTitle: r1.title)

        let resGarlic = try await dbInterface.getRecipes(byIngredients: [garlic], offset: 0, limit: 20)
        XCTAssertTrue(resGarlic.isEmpty)

        let resBasil = try await dbInterface.getRecipes(byIngredients: [basil], offset: 0, limit: 20)
        XCTAssertTrue(resBasil.contains { $0.title == r2.title })
    }

    func testRemoveAllRecipes() async throws {
        let r = Recipe.mocks(count: 5)
        try await dbInterface.insertRecipes(r)

        try await dbInterface.removeAllRecipes()

        let someIngredient = Ingredient(name: "Anything")
        let res = try await dbInterface.getRecipes(byIngredients: [someIngredient], offset: 0, limit: 20)
        XCTAssertTrue(res.isEmpty)
    }

    func testRemoveRecipesByIngredientsCascade() async throws {
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
        try await dbInterface.insertRecipes([r1, r2])

        try await dbInterface.removeRecipes(byIngredients: [garlic])

        let resGarlic = try await dbInterface.getRecipes(byIngredients: [garlic], offset: 0, limit: 20)
        XCTAssertTrue(resGarlic.isEmpty)

        let resTomato = try await dbInterface.getRecipes(byIngredients: [tomato], offset: 0, limit: 20)
        XCTAssertTrue(resTomato.contains { $0.title == r2.title })
    }

    // MARK: - New searchIngredients API tests

    func testSearchIngredientsReturnsSubstringMatchesCaseInsensitive() async throws {
        // Fresh DB from setUp
        let items: [Ingredient] = [
            "Chicken",
            "Chicken Breast",
            "chicken thigh",
            "Pasta",
            "Rice"
        ]
        try await dbInterface.insertIngredients(items)

        let res = try await dbInterface.searchIngredients(matching: "CHICKEN", limit: 10)

        let names = Set(res.map { $0.name })
        XCTAssertTrue(names.contains("Chicken"))
        XCTAssertTrue(names.contains("Chicken Breast"))
        XCTAssertTrue(names.contains("chicken thigh"))
        XCTAssertFalse(names.contains("Pasta"))
        XCTAssertFalse(names.contains("Rice"))
    }

    func testSearchIngredientsRespectsLimit() async throws {
        let many = (1...10).map { Ingredient(name: "Chicken \($0)") }
        try await dbInterface.insertIngredients(many)

        let res = try await dbInterface.searchIngredients(matching: "chicken", limit: 3)
        XCTAssertEqual(res.count, 3)
        // Ensure all results contain the query (case-insensitive)
        XCTAssertTrue(res.allSatisfy { $0.name.lowercased().contains("chicken") })
    }

    func testSearchIngredientsEmptyQueryReturnsEmpty() async throws {
        let res = try await dbInterface.searchIngredients(matching: "", limit: 5)
        XCTAssertTrue(res.isEmpty)
    }

    func testSearchIngredientsNoMatchesReturnsEmpty() async throws {
        try await dbInterface.insertIngredients(["Pasta", "Rice"])
        let res = try await dbInterface.searchIngredients(matching: "chicken", limit: 10)
        XCTAssertTrue(res.isEmpty)
    }

    func testGetIngredientsExactMatchIsCaseInsensitive() async throws {
        try await dbInterface.insertIngredients(["Chicken"]) // capitalized insert
        let resLower = try await dbInterface.getIngredients(byName: "chicken")
        XCTAssertEqual(resLower.count, 1)
        XCTAssertEqual(resLower.first?.name, "Chicken")
    }

    // MARK: - basicComponent-based recipe matching tests

    func testGetRecipesMatchesByBasicComponent() async throws {
        // "Chicken Breast" has basicComponent "chicken" — querying "chicken" should find it
        let chickenBreast = Ingredient(name: "Chicken Breast", description: nil, pictureFileName: nil,
                                       foodGroup: nil, foodSubgroup: nil, basicComponent: "chicken")
        let r = Recipe(
            title: "Grilled Chicken",
            ingredients: [chickenBreast, "Salt"],
            instructions: ["Grill"],
            image: "img",
            additionalInfo: .mock
        )
        try await dbInterface.insertRecipes([r])

        let results = try await dbInterface.getRecipes(byIngredients: [Ingredient(name: "chicken")], offset: 0, limit: 20)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Grilled Chicken")
    }

    func testGetRecipesExactBasicComponentMatch() async throws {
        // Querying a component not present in the recipe should return nothing
        let chickenBreast = Ingredient(name: "Chicken Breast", description: nil, pictureFileName: nil,
                                       foodGroup: nil, foodSubgroup: nil, basicComponent: "chicken")
        let r = Recipe(
            title: "Stuffed Breast",
            ingredients: [chickenBreast],
            instructions: ["Cook"],
            image: "img",
            additionalInfo: .mock
        )
        try await dbInterface.insertRecipes([r])

        // "breast" is not stored as basic_component — should return nothing
        let misses = try await dbInterface.getRecipes(byIngredients: [Ingredient(name: "breast")], offset: 0, limit: 20)
        XCTAssertTrue(misses.isEmpty)

        // "chicken" is the stored basic_component — should find the recipe
        let hits = try await dbInterface.getRecipes(byIngredients: [Ingredient(name: "chicken")], offset: 0, limit: 20)
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits.first?.title, "Stuffed Breast")
    }

    func testGetRecipesBasicComponentMatchIsCaseSensitiveToStoredValue() async throws {
        // basicComponent stored as-is; querying with the same value must match
        let ingredient = Ingredient(name: "CHICKEN BREAST", description: nil, pictureFileName: nil,
                                    foodGroup: nil, foodSubgroup: nil, basicComponent: "chicken")
        let r = Recipe(
            title: "Chicken Dish",
            ingredients: [ingredient],
            instructions: ["Cook"],
            image: "img",
            additionalInfo: .mock
        )
        try await dbInterface.insertRecipes([r])

        let results = try await dbInterface.getRecipes(byIngredients: [Ingredient(name: "chicken")], offset: 0, limit: 20)
        XCTAssertEqual(results.count, 1)
    }

    func testGetRecipesMatchesMultipleBasicComponents() async throws {
        let chicken = Ingredient(name: "Chicken Breast", description: nil, pictureFileName: nil,
                                 foodGroup: nil, foodSubgroup: nil, basicComponent: "chicken")
        let tomato = Ingredient(name: "Tomato Sauce", description: nil, pictureFileName: nil,
                                foodGroup: nil, foodSubgroup: nil, basicComponent: "tomato")
        let r = Recipe(
            title: "Chicken Tomato Pasta",
            ingredients: [chicken, tomato, "Pasta"],
            instructions: ["Cook"],
            image: "img",
            additionalInfo: .mock
        )
        try await dbInterface.insertRecipes([r])

        // Querying either basicComponent should find the recipe
        let results = try await dbInterface.getRecipes(
            byIngredients: [Ingredient(name: "chicken"), Ingredient(name: "tomato")],
            offset: 0, limit: 20
        )
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Chicken Tomato Pasta")
    }

    func testGetRecipesNoBasicComponentMatchReturnsEmpty() async throws {
        let chicken = Ingredient(name: "Chicken Breast", description: nil, pictureFileName: nil,
                                 foodGroup: nil, foodSubgroup: nil, basicComponent: "chicken")
        let r = Recipe(
            title: "Chicken Dish",
            ingredients: [chicken],
            instructions: ["Cook"],
            image: "img",
            additionalInfo: .mock
        )
        try await dbInterface.insertRecipes([r])

        // "beef" is not a basicComponent in this recipe — should return nothing
        let results = try await dbInterface.getRecipes(byIngredients: [Ingredient(name: "beef")], offset: 0, limit: 20)
        XCTAssertTrue(results.isEmpty)
    }

    func testGetRecipesDistinctResultsNoDuplicates() async throws {
        let chicken = Ingredient(name: "Chicken Breast", description: nil, pictureFileName: nil,
                                 foodGroup: nil, foodSubgroup: nil, basicComponent: "chicken")
        let pasta = Ingredient(name: "Pasta", description: nil, pictureFileName: nil,
                               foodGroup: nil, foodSubgroup: nil, basicComponent: "pasta")
        let r = Recipe(
            title: "Chicken Pasta",
            ingredients: [chicken, pasta],
            instructions: ["Cook"],
            image: "img",
            additionalInfo: .mock
        )
        try await dbInterface.insertRecipes([r])

        // Both basicComponents match — recipe should appear exactly once
        let results = try await dbInterface.getRecipes(
            byIngredients: [Ingredient(name: "chicken"), Ingredient(name: "pasta")],
            offset: 0, limit: 20
        )
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
