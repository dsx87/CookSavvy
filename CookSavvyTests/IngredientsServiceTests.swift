//
//  IngredientsServiceTests.swift
//  CookSavvyTests
//
//  Created by Cascade on 01/10/2025.
//

import XCTest
@testable import CookSavvy

// MARK: - Mock DB Interface for Testing

final class MockDBInterfaceForIngredients: DBInterfaceProtocol {
    
    var storedIngredients: [Ingredient] = []
    var insertCallCount = 0
    var searchCallCount = 0
    var getCallCount = 0
    var shouldThrowError: Error?
    
    func insertIngredients(_ ingredients: [Ingredient]) throws {
        if let error = shouldThrowError {
            throw error
        }
        insertCallCount += 1
        storedIngredients.append(contentsOf: ingredients)
    }
    
    func searchIngredients(matching query: String, limit: Int) throws -> [Ingredient] {
        if let error = shouldThrowError {
            throw error
        }
        searchCallCount += 1
        
        let lowercaseQuery = query.lowercased()
        return storedIngredients
            .filter { $0.name.lowercased().contains(lowercaseQuery) }
            .prefix(limit)
            .map { $0 }
    }
    
    func getIngredients(byName name: String) throws -> [Ingredient] {
        if let error = shouldThrowError {
            throw error
        }
        getCallCount += 1
        
        return storedIngredients.filter { $0.name.lowercased() == name.lowercased() }
    }
    
    // Unused protocol methods
    func getRecipes(byIngredients: [Ingredient], offset: Int, limit: Int) throws -> [Recipe] { [] }
    func getAllRecipes(offset: Int, limit: Int) throws -> [Recipe] { [] }
    func getRecipeId(byTitle title: String) throws -> Int? { nil }
    func insertRecipes(_ recipes: [Recipe]) throws {}
    func removeIngredients(_ ingredients: [Ingredient]) throws {}
    func removeRecipes(_ recipes: [Recipe]) throws {}
    func clearDatabase() throws {
        storedIngredients.removeAll()
        insertCallCount = 0
        searchCallCount = 0
        getCallCount = 0
    }
    func getRecentIngredients(limit: Int) throws -> [Ingredient] { [] }
    func getPopularIngredients(limit: Int) throws -> [Ingredient] { [] }
    func recordIngredientUsage(_ ingredient: Ingredient) throws {}
    func getRecentRecipes(limit: Int) throws -> [Recipe] { [] }
    func recordRecipeView(_ recipeId: Int) throws {}
    func getFavoriteRecipes() throws -> [Recipe] { [] }
    func addFavorite(_ recipeId: Int) throws {}
    func removeFavorite(_ recipeId: Int) throws {}
    func isFavorite(_ recipeId: Int) throws -> Bool { false }
    func getRecentSearches(limit: Int) throws -> [[Ingredient]] { [] }
    func recordSearch(ingredients: [Ingredient]) throws {}
    func clearRecentData() throws {}
    func clearFavorites() throws {}
    func getRecipeCount() throws -> Int { 0 }
    func recordCookingSession(recipeId: Int, date: Date, duration: TimeInterval?, rating: Int?) throws {}
    func getCookingSessions(limit: Int) throws -> [CookingSession] { [] }
    func getCookingSessionDates(from startDate: Date, to endDate: Date) throws -> [Date] { [] }
    func getCookingSessionCount() throws -> Int { 0 }
    func getTotalCookingDuration() throws -> TimeInterval { 0 }
    func getCookingSessionCount(from startDate: Date, to endDate: Date) throws -> Int { 0 }
    func getDistinctCookedIngredientCount(from startDate: Date, to endDate: Date) throws -> Int { 0 }
    func getUserCreatedRecipes() throws -> [Recipe] { [] }
    func getUserCreatedRecipeCount() throws -> Int { 0 }
    func insertUserRecipe(_ recipe: Recipe) throws {}
    func updateUserRecipe(_ recipe: Recipe) throws {}
    func deleteUserRecipe(recipeId: Int) throws {}
    func getAllIngredients(inGroup foodGroup: String?, limit: Int) throws -> [Ingredient] { storedIngredients }
    func getDistinctFoodGroups() throws -> [String] { [] }
    func getShoppingItems() throws -> [ShoppingItem] { [] }
    func addShoppingItems(_ names: [String], recipeTitle: String?) throws -> [ShoppingItem] { [] }
    func toggleShoppingItem(id: Int) throws -> Bool { false }
    func removeShoppingItem(id: Int) throws {}
    func clearCheckedShoppingItems() throws {}
    func getDistinctCookedIngredientCount() throws -> Int { 0 }
}

// MARK: - IngredientsService Tests

final class IngredientsServiceTests: XCTestCase {
    
    var mockDB: MockDBInterfaceForIngredients!
    var ingredientsService: IngredientsService!
    
    override func setUpWithError() throws {
        mockDB = MockDBInterfaceForIngredients()
    }
    
    override func tearDownWithError() throws {
        mockDB = nil
        ingredientsService = nil
    }
    
    // MARK: - Initialization Tests
    
    func testDefaultInitialization() {
        ingredientsService = IngredientsService()
        XCTAssertNotNil(ingredientsService)
    }
    
    func testCustomInitialization() {
        ingredientsService = IngredientsService(
            dbInterface: mockDB,
            ingredientsFileName: "CustomFood",
            ingredientsFileExtension: "json"
        )
        XCTAssertNotNil(ingredientsService)
    }
    
    // MARK: - Ensure Ingredients Loaded Tests
    
    func testEnsureIngredientsLoadedWhenDatabaseIsEmpty() async throws {
        ingredientsService = IngredientsService(
            dbInterface: mockDB,
            ingredientsFileName: "Food",
            ingredientsFileExtension: "json"
        )
        
        try await ingredientsService.ensureIngredientsLoaded()
        
        // Should have imported ingredients
        XCTAssertGreaterThan(mockDB.insertCallCount, 0)
        XCTAssertFalse(mockDB.storedIngredients.isEmpty)
    }
    
    func testEnsureIngredientsLoadedWhenDatabaseHasData() async throws {
        // Pre-populate database
        mockDB.storedIngredients = [
            Ingredient(name: "Chicken"),
            Ingredient(name: "Tomato")
        ]
        
        ingredientsService = IngredientsService(
            dbInterface: mockDB,
            ingredientsFileName: "Food",
            ingredientsFileExtension: "json"
        )
        
        let initialCount = mockDB.storedIngredients.count
        try await ingredientsService.ensureIngredientsLoaded()
        
        // Should NOT import again
        XCTAssertEqual(mockDB.insertCallCount, 0)
        XCTAssertEqual(mockDB.storedIngredients.count, initialCount)
    }
    
    func testEnsureIngredientsLoadedOnlyImportsOnce() async throws {
        ingredientsService = IngredientsService(
            dbInterface: mockDB,
            ingredientsFileName: "Food",
            ingredientsFileExtension: "json"
        )
        
        try await ingredientsService.ensureIngredientsLoaded()
        let firstInsertCount = mockDB.insertCallCount
        
        try await ingredientsService.ensureIngredientsLoaded()
        
        // Should not import again
        XCTAssertEqual(mockDB.insertCallCount, firstInsertCount)
    }
    
    // MARK: - Search Ingredients Tests
    
    func testSearchIngredientsWithValidQuery() async throws {
        // Pre-populate with test data
        mockDB.storedIngredients = [
            Ingredient(name: "Chicken"),
            Ingredient(name: "Chicken Breast"),
            Ingredient(name: "Chimichurri"),
            Ingredient(name: "Tomato")
        ]
        
        ingredientsService = IngredientsService(dbInterface: mockDB)
        
        let results = try await ingredientsService.searchIngredients(matching: "chi")
        
        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(results.contains("Chicken"))
        XCTAssertTrue(results.contains("Chicken Breast"))
        XCTAssertTrue(results.contains("Chimichurri"))
        XCTAssertFalse(results.contains("Tomato"))
    }
    
    func testSearchIngredientsWithEmptyQuery() async throws {
        mockDB.storedIngredients = [Ingredient(name: "Chicken")]
        ingredientsService = IngredientsService(dbInterface: mockDB)
        
        // Pre-load to avoid auto-loading during search
        try await ingredientsService.ensureIngredientsLoaded()
        let initialSearchCount = mockDB.searchCallCount
        
        let results = try await ingredientsService.searchIngredients(matching: "")
        
        XCTAssertTrue(results.isEmpty)
        XCTAssertEqual(mockDB.searchCallCount, initialSearchCount) // Should not call DB for empty query
    }
    
    func testSearchIngredientsWithNoMatches() async throws {
        mockDB.storedIngredients = [
            Ingredient(name: "Chicken"),
            Ingredient(name: "Tomato")
        ]
        
        ingredientsService = IngredientsService(dbInterface: mockDB)
        
        let results = try await ingredientsService.searchIngredients(matching: "xyz")
        
        XCTAssertTrue(results.isEmpty)
    }
    
    func testSearchIngredientsRespectsLimit() async throws {
        mockDB.storedIngredients = (1...20).map { Ingredient(name: "Chicken \($0)") }
        ingredientsService = IngredientsService(dbInterface: mockDB)
        
        let results = try await ingredientsService.searchIngredients(matching: "chicken", limit: 5)
        
        XCTAssertEqual(results.count, 5)
    }
    
    func testSearchIngredientsIsCaseInsensitive() async throws {
        mockDB.storedIngredients = [
            Ingredient(name: "Chicken"),
            Ingredient(name: "CHIMICHURRI")
        ]
        
        ingredientsService = IngredientsService(dbInterface: mockDB)
        
        let results = try await ingredientsService.searchIngredients(matching: "CHI")
        
        XCTAssertGreaterThanOrEqual(results.count, 2)
        XCTAssertTrue(results.contains("Chicken"))
        XCTAssertTrue(results.contains("CHIMICHURRI"))
    }
    
    func testSearchIngredientsAutoLoadsIfNotImported() async throws {
        ingredientsService = IngredientsService(
            dbInterface: mockDB,
            ingredientsFileName: "Food",
            ingredientsFileExtension: "json"
        )
        
        // Search without calling ensureIngredientsLoaded first
        let results = try await ingredientsService.searchIngredients(matching: "chicken")
        
        // Should have auto-loaded
        XCTAssertGreaterThan(mockDB.insertCallCount, 0)
        XCTAssertFalse(results.isEmpty)
    }
    
    // MARK: - Search Full Ingredients Tests
    
    func testSearchFullIngredientsReturnsCompleteObjects() async throws {
        mockDB.storedIngredients = [
            Ingredient(
                name: "Chicken",
                description: "Fresh chicken",
                pictureFileName: "chicken.png",
                foodGroup: "Protein",
                foodSubgroup: "Poultry"
            ),
            Ingredient(name: "Tomato")
        ]
        
        ingredientsService = IngredientsService(dbInterface: mockDB)
        
        let results = try await ingredientsService.searchFullIngredients(matching: "chicken")
        
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.name, "Chicken")
        XCTAssertEqual(results.first?.description, "Fresh chicken")
        XCTAssertEqual(results.first?.foodGroup, "Protein")
    }
    
    func testSearchFullIngredientsWithEmptyQuery() async throws {
        mockDB.storedIngredients = [Ingredient(name: "Chicken")]
        ingredientsService = IngredientsService(dbInterface: mockDB)
        
        let results = try await ingredientsService.searchFullIngredients(matching: "")
        
        XCTAssertTrue(results.isEmpty)
    }
    
    // MARK: - Get Ingredient By Name Tests
    
    func testGetIngredientByNameWithExactMatch() async throws {
        mockDB.storedIngredients = [
            Ingredient(name: "Chicken"),
            Ingredient(name: "Chicken Breast")
        ]
        
        ingredientsService = IngredientsService(dbInterface: mockDB)
        
        let result = try await ingredientsService.getIngredient(byName: "Chicken")
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "Chicken")
    }
    
    func testGetIngredientByNameWithNoMatch() async throws {
        mockDB.storedIngredients = [Ingredient(name: "Chicken")]
        ingredientsService = IngredientsService(dbInterface: mockDB)
        
        let result = try await ingredientsService.getIngredient(byName: "Tomato")
        
        XCTAssertNil(result)
    }
    
    func testGetIngredientByNameIsCaseInsensitive() async throws {
        mockDB.storedIngredients = [Ingredient(name: "Chicken")]
        ingredientsService = IngredientsService(dbInterface: mockDB)
        
        let result = try await ingredientsService.getIngredient(byName: "chicken")
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "Chicken")
    }
    
    // MARK: - Force Reimport Tests
    
    func testForceReimport() async throws {
        ingredientsService = IngredientsService(
            dbInterface: mockDB,
            ingredientsFileName: "Food",
            ingredientsFileExtension: "json"
        )
        
        try await ingredientsService.forceReimport()
        
        XCTAssertGreaterThan(mockDB.insertCallCount, 0)
        XCTAssertFalse(mockDB.storedIngredients.isEmpty)
    }
    
    func testForceReimportOverwritesExisting() async throws {
        mockDB.storedIngredients = [Ingredient(name: "Old")]
        
        ingredientsService = IngredientsService(
            dbInterface: mockDB,
            ingredientsFileName: "Food",
            ingredientsFileExtension: "json"
        )
        
        try await ingredientsService.forceReimport()
        
        // Should have added new ingredients
        XCTAssertGreaterThan(mockDB.storedIngredients.count, 1)
    }
    
    // MARK: - Error Handling Tests
    
    func testSearchIngredientsThrowsErrorOnDatabaseFailure() async {
        // Pre-populate so ensureIngredientsLoaded doesn't fail
        mockDB.storedIngredients = [Ingredient(name: "Test")]
        ingredientsService = IngredientsService(dbInterface: mockDB)
        
        // Load first without error
        try? await ingredientsService.ensureIngredientsLoaded()
        
        // Now set error for search
        mockDB.shouldThrowError = NSError(domain: "TestError", code: 1)
        
        do {
            _ = try await ingredientsService.searchIngredients(matching: "chicken")
            XCTFail("Should throw error")
        } catch let error as IngredientsServiceError {
            if case .searchFailed = error {
                // Expected
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testGetIngredientThrowsErrorOnDatabaseFailure() async {
        // Pre-populate so ensureIngredientsLoaded doesn't fail
        mockDB.storedIngredients = [Ingredient(name: "Test")]
        ingredientsService = IngredientsService(dbInterface: mockDB)
        
        // Load first without error
        try? await ingredientsService.ensureIngredientsLoaded()
        
        // Now set error for retrieval
        mockDB.shouldThrowError = NSError(domain: "TestError", code: 1)
        
        do {
            _ = try await ingredientsService.getIngredient(byName: "chicken")
            XCTFail("Should throw error")
        } catch let error as IngredientsServiceError {
            if case .retrievalFailed = error {
                // Expected
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testEnsureIngredientsLoadedWithInvalidFileName() async {
        ingredientsService = IngredientsService(
            dbInterface: mockDB,
            ingredientsFileName: "NonExistentFile",
            ingredientsFileExtension: "json"
        )
        
        do {
            try await ingredientsService.ensureIngredientsLoaded()
            XCTFail("Should throw file not found error")
        } catch let error as IngredientsServiceError {
            if case .fileNotFound(let fileName) = error {
                XCTAssertEqual(fileName, "NonExistentFile")
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Integration Tests with Real DB
    
    func testIntegrationWithRealDatabase() async throws {
        let realDB = DBInterface(inMemory: true)
        ingredientsService = IngredientsService(
            dbInterface: realDB,
            ingredientsFileName: "Food",
            ingredientsFileExtension: "json"
        )
        
        // Ensure ingredients are loaded
        try await ingredientsService.ensureIngredientsLoaded()
        
        // Search for ingredients
        let results = try await ingredientsService.searchIngredients(matching: "chicken")
        
        // Verify results
        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.allSatisfy { $0.lowercased().contains("chicken") })
        
        // Clean up
        try realDB.clearDatabase()
    }
    
    func testIntegrationSearchPerformance() throws {
        let realDB = DBInterface(inMemory: true)
        ingredientsService = IngredientsService(dbInterface: realDB)
        
        // Pre-load ingredients
        Task {
            try await ingredientsService.ensureIngredientsLoaded()
        }
        
        // Wait a bit for loading
        Thread.sleep(forTimeInterval: 1.0)
        
        measure {
            Task {
                _ = try? await ingredientsService.searchIngredients(matching: "chi")
            }
        }
        
        try? realDB.clearDatabase()
    }
    
    // MARK: - Error Description Tests
    
    func testErrorDescriptions() {
        let fileNotFoundError = IngredientsServiceError.fileNotFound("TestFile")
        XCTAssertEqual(fileNotFoundError.errorDescription, "Ingredients file 'TestFile' not found in bundle")
        
        let emptyFileError = IngredientsServiceError.emptyFile
        XCTAssertEqual(emptyFileError.errorDescription, "Ingredients file is empty")
        
        let underlyingError = NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        let importError = IngredientsServiceError.importFailed(underlyingError)
        XCTAssertNotNil(importError.errorDescription)
        XCTAssertTrue(importError.errorDescription?.contains("Failed to import") ?? false)
    }
}
