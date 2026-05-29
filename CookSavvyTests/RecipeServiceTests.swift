//
//  RecipeServiceTests.swift
//  CookSavvyTests
//
//  Created by Cascade on 01/10/2025.
//

import XCTest
@testable import CookSavvy

// MARK: - Mock Recipe Source for Testing

final class MockRecipeSource: RecipeSourceProtocol {
    var sourceType: RecipeSourceType
    var isAvailableValue: Bool
    var recipesToReturn: [Recipe]
    var shouldThrowError: Error?
    var fetchCallCount = 0
    
    init(
        sourceType: RecipeSourceType,
        isAvailable: Bool = true,
        recipesToReturn: [Recipe] = [],
        shouldThrowError: Error? = nil
    ) {
        self.sourceType = sourceType
        self.isAvailableValue = isAvailable
        self.recipesToReturn = recipesToReturn
        self.shouldThrowError = shouldThrowError
    }
    
    func fetchRecipes(for ingredients: [Ingredient]) async throws -> [Recipe] {
        fetchCallCount += 1
        
        if let error = shouldThrowError {
            throw error
        }
        
        return recipesToReturn
    }
    
    func isAvailable() async -> Bool {
        return isAvailableValue
    }
}

// MARK: - RecipeService Tests

final class RecipeServiceTests: XCTestCase {
    
    var dbInterface: DBInterface!
    var recipeService: RecipeService!
    
    override func setUpWithError() throws {
        dbInterface = try DBInterface(inMemory: true)
    }
    
    override func tearDownWithError() throws {
        try dbInterface.clearDatabase()
        dbInterface = nil
        recipeService = nil
    }
    
    // MARK: - Initialization Tests
    
    func testDefaultInitialization() throws {
        recipeService = try RecipeService()
        XCTAssertNotNil(recipeService)
    }
    
    func testCustomInitialization() {
        let mockOffline = MockRecipeSource(sourceType: .offline)
        let sources: [RecipeSourceType: RecipeSourceProtocol] = [.offline: mockOffline]
        
        recipeService = RecipeService(
            dbInterface: dbInterface,
            sources: sources,
            shouldStoreRecipes: false
        )
        
        XCTAssertNotNil(recipeService)
    }
    
    // MARK: - Get Recipes Tests
    
    func testGetRecipesFromSpecificSource() async throws {
        let mockRecipes = Recipe.mocks(count: 3)
        let mockOnline = MockRecipeSource(
            sourceType: .online,
            isAvailable: true,
            recipesToReturn: mockRecipes
        )
        
        let sources: [RecipeSourceType: RecipeSourceProtocol] = [
            .offline: OfflineRecipeSource(dbInterface: dbInterface),
            .online: mockOnline
        ]
        
        recipeService = RecipeService(
            dbInterface: dbInterface,
            sources: sources,
            shouldStoreRecipes: false
        )
        
        let ingredients: [Ingredient] = ["Chicken"]
        let results = try await recipeService.getRecipes(for: ingredients, from: .online)
        
        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(mockOnline.fetchCallCount, 1)
    }
    
    func testGetRecipesFromUnavailableSpecificSourceThrowsError() async {
        let mockOnline = MockRecipeSource(sourceType: .online, isAvailable: false)
        let sources: [RecipeSourceType: RecipeSourceProtocol] = [
            .offline: OfflineRecipeSource(dbInterface: dbInterface),
            .online: mockOnline
        ]
        
        recipeService = RecipeService(
            dbInterface: dbInterface,
            sources: sources
        )
        
        do {
            _ = try await recipeService.getRecipes(for: ["Chicken"], from: .online)
            XCTFail("Should throw error for unavailable source")
        } catch let error as RecipeSourceError {
            if case .sourceUnavailable = error {
                // Expected
            } else {
                XCTFail("Wrong error type")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testGetRecipesStoresInDatabaseWhenEnabled() async throws {
        let mockRecipes = Recipe.mocks(count: 2)
        let mockOnline = MockRecipeSource(
            sourceType: .online,
            isAvailable: true,
            recipesToReturn: mockRecipes
        )
        
        let sources: [RecipeSourceType: RecipeSourceProtocol] = [
            .offline: OfflineRecipeSource(dbInterface: dbInterface),
            .online: mockOnline
        ]
        
        recipeService = RecipeService(
            dbInterface: dbInterface,
            sources: sources,
            shouldStoreRecipes: true
        )
        
        let ingredients: [Ingredient] = ["Chicken"]
        _ = try await recipeService.getRecipes(for: ingredients, from: .online)
        
        // Verify recipes were stored
        let storedRecipes = try recipeService.getStoredRecipes(for: mockRecipes.flatMap(\.ingredients))
        XCTAssertEqual(storedRecipes.count, 2)
    }
    
    func testGetRecipesDoesNotStoreWhenDisabled() async throws {
        let mockRecipes = Recipe.mocks(count: 2)
        let mockOnline = MockRecipeSource(
            sourceType: .online,
            isAvailable: true,
            recipesToReturn: mockRecipes
        )
        
        let sources: [RecipeSourceType: RecipeSourceProtocol] = [
            .offline: OfflineRecipeSource(dbInterface: dbInterface),
            .online: mockOnline
        ]
        
        recipeService = RecipeService(
            dbInterface: dbInterface,
            sources: sources,
            shouldStoreRecipes: false
        )
        
        let ingredients: [Ingredient] = ["Chicken"]
        _ = try await recipeService.getRecipes(for: ingredients, from: .online)
        
        // Verify recipes were NOT stored
        let storedRecipes = try recipeService.getStoredRecipes(for: mockRecipes.flatMap(\.ingredients))
        XCTAssertTrue(storedRecipes.isEmpty)
    }
    
    // MARK: - Source Availability Tests
    
    func testIsSourceAvailableForAvailableSource() async throws {
        recipeService = try RecipeService(dbInterface: dbInterface)
        
        let available = await recipeService.isSourceAvailable(.offline)
        XCTAssertTrue(available)
    }
    
    func testIsSourceAvailableForUnavailableSource() async {
        let mockOnline = MockRecipeSource(sourceType: .online, isAvailable: false)
        let sources: [RecipeSourceType: RecipeSourceProtocol] = [
            .offline: OfflineRecipeSource(dbInterface: dbInterface),
            .online: mockOnline
        ]
        
        recipeService = RecipeService(
            dbInterface: dbInterface,
            sources: sources
        )
        
        let available = await recipeService.isSourceAvailable(.online)
        XCTAssertFalse(available)
    }
    
    func testIsSourceAvailableForNonExistentSource() async {
        let sources: [RecipeSourceType: RecipeSourceProtocol] = [
            .offline: OfflineRecipeSource(dbInterface: dbInterface)
        ]
        
        recipeService = RecipeService(
            dbInterface: dbInterface,
            sources: sources
        )
        
        let available = await recipeService.isSourceAvailable(.ai)
        XCTAssertFalse(available)
    }
    
    func testGetAvailableSources() async {
        let mockOnline = MockRecipeSource(sourceType: .online, isAvailable: true)
        let mockAI = MockRecipeSource(sourceType: .ai, isAvailable: false)
        
        let sources: [RecipeSourceType: RecipeSourceProtocol] = [
            .offline: OfflineRecipeSource(dbInterface: dbInterface),
            .online: mockOnline,
            .ai: mockAI
        ]
        
        recipeService = RecipeService(
            dbInterface: dbInterface,
            sources: sources
        )
        
        let available = await recipeService.getAvailableSources()
        
        XCTAssertEqual(available.count, 2)
        XCTAssertTrue(available.contains(.offline))
        XCTAssertTrue(available.contains(.online))
        XCTAssertFalse(available.contains(.ai))
    }
    
    // MARK: - Store Recipes Tests
    
    func testStoreRecipesManually() throws {
        recipeService = try RecipeService(dbInterface: dbInterface)
        
        let recipes = Recipe.mocks(count: 3)
        try recipeService.storeRecipes(recipes)
        
        let stored = try recipeService.getStoredRecipes(for: recipes.flatMap(\.ingredients))
        XCTAssertEqual(stored.count, 3)
    }
    
    func testStoreEmptyRecipesIsNoop() throws {
        recipeService = try RecipeService(dbInterface: dbInterface)
        
        // Should not throw
        try recipeService.storeRecipes([])
    }
    
    func testGetStoredRecipes() throws {
        recipeService = try RecipeService(dbInterface: dbInterface)
        
        let chicken: Ingredient = "Chicken"
        let recipe = Recipe(
            title: "Chicken Dish",
            ingredients: [chicken],
            instructions: ["Cook"],
            image: "img",
            additionalInfo: .mock
        )
        
        try recipeService.storeRecipes([recipe])
        
        let stored = try recipeService.getStoredRecipes(for: [chicken])
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored.first?.title, "Chicken Dish")
    }
    
    func testGetStoredRecipesWithNoMatches() throws {
        recipeService = try RecipeService(dbInterface: dbInterface)
        
        let stored = try recipeService.getStoredRecipes(for: ["NonExistent"])
        XCTAssertTrue(stored.isEmpty)
    }
    
    // MARK: - Integration Tests
    
    func testFullWorkflowOfflineSource() async throws {
        recipeService = try RecipeService(dbInterface: dbInterface)
        
        // 1. Store recipes manually
        let chicken: Ingredient = "Chicken"
        let recipe = Recipe(
            title: "Chicken Pasta",
            ingredients: [chicken, "Pasta"],
            instructions: ["Cook pasta", "Add chicken"],
            image: "img",
            additionalInfo: .mock
        )
        try recipeService.storeRecipes([recipe])
        
        // 2. Fetch from offline source
        let results = try await recipeService.getRecipes(for: [chicken], from: .offline)
        
        // 3. Verify
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Chicken Pasta")
    }
    
    func testFetchFromMultipleSources() async throws {
        let mockOnlineRecipes = [
            Recipe(
                title: "Online Recipe",
                ingredients: ["Chicken"],
                instructions: ["Cook"],
                image: "img",
                additionalInfo: .mock
            )
        ]
        
        let mockOnline = MockRecipeSource(
            sourceType: .online,
            isAvailable: true,
            recipesToReturn: mockOnlineRecipes
        )
        
        let sources: [RecipeSourceType: RecipeSourceProtocol] = [
            .offline: OfflineRecipeSource(dbInterface: dbInterface),
            .online: mockOnline
        ]
        
        recipeService = RecipeService(
            dbInterface: dbInterface,
            sources: sources,
            shouldStoreRecipes: false
        )
        
        let results = try await recipeService.getRecipes(for: ["Chicken"], from: .online)
        XCTAssertEqual(results.first?.title, "Online Recipe")
        XCTAssertEqual(results.first?.source, .online)
    }
    
    // MARK: - Error Handling Tests
    
    func testGetRecipesHandlesSourceError() async {
        let mockSource = MockRecipeSource(
            sourceType: .online,
            isAvailable: true,
            shouldThrowError: RecipeSourceError.noRecipesFound
        )
        
        let sources: [RecipeSourceType: RecipeSourceProtocol] = [
            .online: mockSource
        ]
        
        recipeService = RecipeService(
            dbInterface: dbInterface,
            sources: sources
        )
        
        do {
            _ = try await recipeService.getRecipes(for: ["Chicken"], from: .online)
            XCTFail("Should propagate source error")
        } catch let error as RecipeSourceError {
            if case .noRecipesFound = error {
                // Expected
            } else {
                XCTFail("Wrong error type")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
