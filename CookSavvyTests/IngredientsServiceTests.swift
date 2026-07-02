//
//  IngredientsServiceTests.swift
//  CookSavvyTests
//
//  Created by Cascade on 01/10/2025.
//

import XCTest
@testable import CookSavvy

// MARK: - Mock DB Interface for Testing

/// `@unchecked Sendable` because `IngredientsService` is an `actor` and stores its injected store as
/// actor-isolated state, so this mock must cross into the actor's isolation domain. The mock has
/// mutable stubs/counters, but every test drives it sequentially — it configures the stubs, `await`s a
/// single `IngredientsService` call, then asserts on the counters — so there is never concurrent
/// access. The unchecked conformance encodes that test-driven serialisation invariant.
final class MockDBInterfaceForIngredients: IngredientStoreProtocol, @unchecked Sendable {

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

    // Remaining IngredientStoreProtocol members — unused by these tests.
    func removeIngredients(_ ingredients: [Ingredient]) throws {}
    func getAllIngredients(inGroup foodGroup: String?, limit: Int) throws -> [Ingredient] { storedIngredients }
    func getDistinctFoodGroups() throws -> [String] { [] }
}

// MARK: - IngredientsService Tests

final class IngredientsServiceTests: XCTestCase {

    var mockDB: MockDBInterfaceForIngredients!
    var ingredientsService: IngredientsService!

    @MainActor
    override func setUp() async throws {
        mockDB = MockDBInterfaceForIngredients()
    }

    @MainActor
    override func tearDown() async throws {
        mockDB = nil
        ingredientsService = nil
    }

    // MARK: - Initialization Tests

    @MainActor
    func testDefaultInitialization() async throws {
        ingredientsService = try IngredientsService()
        XCTAssertNotNil(ingredientsService)
    }

    // MARK: - Ensure Ingredients Loaded Tests

    @MainActor
    func testEnsureIngredientsLoadedWhenDatabaseHasData() async throws {
        // Pre-populate database
        mockDB.storedIngredients = [
            Ingredient(name: "Chicken"),
            Ingredient(name: "Tomato")
        ]

        ingredientsService = IngredientsService(dbInterface: mockDB)

        let initialCount = mockDB.storedIngredients.count
        try await ingredientsService.ensureIngredientsLoaded()

        // Should NOT insert — catalog is seeded by DataImportService, not IngredientsService
        XCTAssertEqual(mockDB.insertCallCount, 0)
        XCTAssertEqual(mockDB.storedIngredients.count, initialCount)
    }

    // MARK: - Search Ingredients Tests

    @MainActor
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

    @MainActor
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

    @MainActor
    func testSearchIngredientsWithNoMatches() async throws {
        mockDB.storedIngredients = [
            Ingredient(name: "Chicken"),
            Ingredient(name: "Tomato")
        ]

        ingredientsService = IngredientsService(dbInterface: mockDB)

        let results = try await ingredientsService.searchIngredients(matching: "xyz")

        XCTAssertTrue(results.isEmpty)
    }

    @MainActor
    func testSearchIngredientsRespectsLimit() async throws {
        mockDB.storedIngredients = (1...20).map { Ingredient(name: "Chicken \($0)") }
        ingredientsService = IngredientsService(dbInterface: mockDB)

        let results = try await ingredientsService.searchIngredients(matching: "chicken", limit: 5)

        XCTAssertEqual(results.count, 5)
    }

    @MainActor
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

    // MARK: - Search Full Ingredients Tests

    @MainActor
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

    @MainActor
    func testSearchFullIngredientsWithEmptyQuery() async throws {
        mockDB.storedIngredients = [Ingredient(name: "Chicken")]
        ingredientsService = IngredientsService(dbInterface: mockDB)

        let results = try await ingredientsService.searchFullIngredients(matching: "")

        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - Get Ingredient By Name Tests

    @MainActor
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

    @MainActor
    func testGetIngredientByNameWithNoMatch() async throws {
        mockDB.storedIngredients = [Ingredient(name: "Chicken")]
        ingredientsService = IngredientsService(dbInterface: mockDB)

        let result = try await ingredientsService.getIngredient(byName: "Tomato")

        XCTAssertNil(result)
    }

    @MainActor
    func testGetIngredientByNameIsCaseInsensitive() async throws {
        mockDB.storedIngredients = [Ingredient(name: "Chicken")]
        ingredientsService = IngredientsService(dbInterface: mockDB)

        let result = try await ingredientsService.getIngredient(byName: "chicken")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "Chicken")
    }

    // MARK: - Error Handling Tests

    @MainActor
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

    @MainActor
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

    // MARK: - Category Filtering Tests

    @MainActor
    func testGetAllIngredientsByCategoryFiltersByName() async throws {
        // The dataset has no food_group data, so categories are derived from ingredient names.
        mockDB.storedIngredients = [
            Ingredient(name: "Chicken"),
            Ingredient(name: "Salmon"),
            Ingredient(name: "Tofu"),
            Ingredient(name: "Tomato"),
            Ingredient(name: "Cheddar"),
            Ingredient(name: "Rice")
        ]
        ingredientsService = IngredientsService(dbInterface: mockDB)

        let proteins = try await ingredientsService.getAllIngredients(category: .proteins)
        let proteinNames = Set(proteins.map(\.name))

        XCTAssertEqual(proteinNames, ["Chicken", "Salmon", "Tofu"])
        XCTAssertFalse(proteinNames.contains("Tomato"))
        XCTAssertFalse(proteinNames.contains("Rice"))
    }

    @MainActor
    func testGetCategoriesReturnsOnlyPresentCategoriesInCanonicalOrder() async throws {
        mockDB.storedIngredients = [
            Ingredient(name: "Chicken"),  // proteins
            Ingredient(name: "Tomato"),   // veggies
            Ingredient(name: "Rice")      // grains
        ]
        ingredientsService = IngredientsService(dbInterface: mockDB)

        let categories = try await ingredientsService.getCategories()

        // Canonical declaration order: proteins, veggies, dairy, grains, ...
        XCTAssertEqual(categories, [.proteins, .veggies, .grains])
    }

    @MainActor
    func testPantryStaplesAreExcludedFromBrowseSearchAndCategories() async throws {
        // Salt + Cumin are pantry staples (hidden from the picker); Basil/Soy Sauce stay selectable.
        mockDB.storedIngredients = [
            Ingredient(name: "Chicken"),
            Ingredient(name: "Salt"),
            Ingredient(name: "Cumin"),
            Ingredient(name: "Basil"),
            Ingredient(name: "Tomato")
        ]
        ingredientsService = IngredientsService(dbInterface: mockDB)

        let all = try await ingredientsService.getAllIngredients()
        XCTAssertFalse(Set(all.map(\.name)).contains("Salt"))
        XCTAssertFalse(Set(all.map(\.name)).contains("Cumin"))

        // Search must not surface staples either.
        let saltSearch = try await ingredientsService.searchFullIngredients(matching: "salt")
        XCTAssertTrue(saltSearch.isEmpty)

        // The Spices category retains the kept herbs/sauces but not the staples.
        let spices = Set(try await ingredientsService.getAllIngredients(category: .spices).map(\.name))
        XCTAssertTrue(spices.contains("Basil"))
        XCTAssertFalse(spices.contains("Salt"))
        XCTAssertFalse(spices.contains("Cumin"))
    }

    // MARK: - Error Description Tests

    @MainActor
    func testErrorDescriptions() async {
        let underlyingError = NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])

        let searchError = IngredientsServiceError.searchFailed(underlyingError)
        XCTAssertNotNil(searchError.errorDescription)
        XCTAssertTrue(searchError.errorDescription?.contains("Failed to search") ?? false)

        let retrievalError = IngredientsServiceError.retrievalFailed(underlyingError)
        XCTAssertNotNil(retrievalError.errorDescription)
        XCTAssertTrue(retrievalError.errorDescription?.contains("Failed to retrieve") ?? false)

        let dbError = IngredientsServiceError.databaseError(underlyingError)
        XCTAssertNotNil(dbError.errorDescription)
        XCTAssertTrue(dbError.errorDescription?.contains("Database error") ?? false)
    }
}
