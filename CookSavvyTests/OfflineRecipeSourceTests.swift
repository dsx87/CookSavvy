//
//  OfflineRecipeSourceTests.swift
//  CookSavvyTests
//
//  Created by Cascade on 01/10/2025.
//

import XCTest
@testable import CookSavvy

final class OfflineRecipeSourceTests: XCTestCase {

    var dbInterface: DBInterface!
    var offlineSource: OfflineRecipeSource!

    @MainActor
    override func setUp() async throws {
        dbInterface = try DBInterface(inMemory: true)
        offlineSource = OfflineRecipeSource(dbInterface: dbInterface)
    }

    @MainActor
    override func tearDown() async throws {
        dbInterface = nil
        offlineSource = nil
    }

    // MARK: - Basic Properties Tests

    @MainActor
    func testSourceType() async {
        XCTAssertEqual(offlineSource.sourceType, .offline)
    }

    @MainActor
    func testIsAvailable() async {
        let available = await offlineSource.isAvailable()
        XCTAssertTrue(available, "Offline source should always be available")
    }
    
    // MARK: - Fetch Recipes Tests
    
    @MainActor
    func testFetchRecipesWithValidIngredients() async throws {
        // Setup: Insert test recipes
        let garlic: Ingredient = "Garlic"
        let pasta: Ingredient = "Pasta"
        let recipe = Recipe(
            title: "Garlic Pasta",
            ingredients: [garlic, pasta],
            instructions: ["Cook pasta", "Add garlic"],
            image: "garlic_pasta.jpg",
            additionalInfo: .mock
        )
        try await dbInterface.insertRecipes([recipe])
        
        // Test: Fetch recipes
        let results = try await offlineSource.fetchRecipes(for: [garlic])
        
        // Verify
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Garlic Pasta")
    }
    
    @MainActor
    func testFetchRecipesWithMultipleIngredients() async throws {
        // Setup: Insert multiple recipes
        let chicken: Ingredient = "Chicken"
        let tomato: Ingredient = "Tomato"
        let basil: Ingredient = "Basil"
        
        let recipe1 = Recipe(
            title: "Chicken Tomato",
            ingredients: [chicken, tomato],
            instructions: ["Cook"],
            image: "img1",
            additionalInfo: .mock
        )
        let recipe2 = Recipe(
            title: "Tomato Basil",
            ingredients: [tomato, basil],
            instructions: ["Mix"],
            image: "img2",
            additionalInfo: .mock
        )
        try await dbInterface.insertRecipes([recipe1, recipe2])
        
        // Test: Fetch with tomato (should get both)
        let results = try await offlineSource.fetchRecipes(for: [tomato])
        
        // Verify
        XCTAssertEqual(results.count, 2)
        let titles = Set(results.map { $0.title })
        XCTAssertTrue(titles.contains("Chicken Tomato"))
        XCTAssertTrue(titles.contains("Tomato Basil"))
    }
    
    @MainActor
    func testFetchRecipesWithEmptyIngredientsThrowsError() async {
        do {
            _ = try await offlineSource.fetchRecipes(for: [])
            XCTFail("Should throw error for empty ingredients")
        } catch let error as RecipeSourceError {
            if case .noRecipesFound = error {
                // Expected error
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    @MainActor
    func testFetchRecipesWithNoMatchesThrowsError() async throws {
        // Setup: Insert a recipe
        let garlic: Ingredient = "Garlic"
        let recipe = Recipe(
            title: "Garlic Bread",
            ingredients: [garlic],
            instructions: ["Toast"],
            image: "img",
            additionalInfo: .mock
        )
        try await dbInterface.insertRecipes([recipe])
        
        // Test: Search for non-existent ingredient
        let nonExistent: Ingredient = "NonExistentIngredient"
        
        do {
            _ = try await offlineSource.fetchRecipes(for: [nonExistent])
            XCTFail("Should throw error when no recipes found")
        } catch let error as RecipeSourceError {
            if case .noRecipesFound = error {
                // Expected error
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    @MainActor
    func testFetchRecipesWithMixedValidAndInvalidIngredients() async throws {
        // Setup: Insert recipe
        let chicken: Ingredient = "Chicken"
        let recipe = Recipe(
            title: "Chicken Dish",
            ingredients: [chicken],
            instructions: ["Cook"],
            image: "img",
            additionalInfo: .mock
        )
        try await dbInterface.insertRecipes([recipe])
        
        // Test: Mix valid and invalid ingredients
        let invalid: Ingredient = "InvalidIngredient"
        let results = try await offlineSource.fetchRecipes(for: [chicken, invalid])
        
        // Verify: Should still find the chicken recipe
        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.contains { $0.title == "Chicken Dish" })
    }
    
    @MainActor
    func testFetchRecipesWithMultipleRecipes() async throws {
        // Setup: Insert many recipes
        let recipes = Recipe.mocks(count: 10)
        try await dbInterface.insertRecipes(recipes)
        
        // Test: Fetch with ingredients from first recipe
        let ingredients = Array(recipes.first!.ingredients.prefix(2))
        let results = try await offlineSource.fetchRecipes(for: ingredients)
        
        // Verify: Should find at least the first recipe
        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.contains { $0.title == recipes.first!.title })
    }
    
    // MARK: - Convenience Initializer Test
    
    @MainActor
    func testConvenienceInitializer() async throws {
        let source = try OfflineRecipeSource()
        XCTAssertEqual(source.sourceType, .offline)
        
        let available = await source.isAvailable()
        XCTAssertTrue(available)
    }
    
    // MARK: - Performance Tests
    
    @MainActor
    func testFetchRecipesPerformance() throws {
        // This stays a *synchronous* test method on purpose: `measure`'s closure is synchronous
        // and `wait(for:)` must pump the run loop so the main-actor fetch `Task` can run. In an
        // `async` test method `wait(for:)` would block the main actor and deadlock the Task.
        let source = offlineSource!
        let db = dbInterface!
        let recipes = Recipe.mocks(count: 100)
        let ingredients = Array(recipes.first!.ingredients.prefix(3))

        // Setup: insert many recipes (awaited synchronously by pumping the run loop).
        let setup = expectation(description: "Seed recipes")
        Task {
            try? await db.insertRecipes(recipes)
            setup.fulfill()
        }
        wait(for: [setup], timeout: 30.0)

        measure {
            let fetched = expectation(description: "Fetch recipes")
            Task {
                _ = try? await source.fetchRecipes(for: ingredients)
                fetched.fulfill()
            }
            wait(for: [fetched], timeout: 5.0)
        }
    }
}
