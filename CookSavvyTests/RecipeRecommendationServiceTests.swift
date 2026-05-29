//
//  RecipeRecommendationServiceTests.swift
//  CookSavvyTests
//

import XCTest
@testable import CookSavvy

final class RecipeRecommendationServiceTests: XCTestCase {

    var mockUserDataService: MockUserDataService!
    var db: DBInterface!
    var mockDBInitService: MockDatabaseInitService!
    var service: RecipeRecommendationService!

    override func setUp() async throws {
        try await super.setUp()
        mockUserDataService = MockUserDataService()
        db = try DBInterface(inMemory: true)
        mockDBInitService = MockDatabaseInitService()
        service = RecipeRecommendationService(
            userDataService: mockUserDataService,
            dbInterface: db,
            databaseInitService: mockDBInitService
        )
    }

    override func tearDown() async throws {
        service = nil
        db = nil
        mockDBInitService = nil
        mockUserDataService = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func makeRecipe(title: String, ingredients: [String]) -> Recipe {
        let ingList = ingredients.map { Ingredient(name: $0) }
        return Recipe(
            title: title,
            ingredients: ingList,
            instructions: ["Cook"],
            image: "",
            additionalInfo: .empty
        )
    }

    private func insertRecipes(_ recipes: [Recipe]) throws -> [Int] {
        try db.insertRecipes(recipes)
        return try recipes.compactMap { try db.getRecipeId(byTitle: $0.title) }
    }

    private var sessionIdCounter = 1

    private func makeCookingSession(recipeTitle: String, recipeId: Int = 1, rating: Int? = nil) -> CookingSession {
        defer { sessionIdCounter += 1 }
        return CookingSession(
            id: sessionIdCounter,
            recipeId: recipeId,
            recipeTitle: recipeTitle,
            cookedAt: Date(),
            durationSeconds: nil,
            rating: rating
        )
    }

    // MARK: - Tests

    func testMultipleAffinityIngredientsAreUsed() async throws {
        mockUserDataService.stubbedFavorites = [
            makeRecipe(title: "Chicken Rice Bowl", ingredients: ["chicken", "rice"])
        ]
        mockUserDataService.stubbedCookingSessions = []

        try db.insertRecipes([
            makeRecipe(title: "Chicken Skillet", ingredients: ["chicken"]),
            makeRecipe(title: "Rice Pilaf", ingredients: ["rice"])
        ])

        let result = try await service.getSuggestions()
        XCTAssertTrue(result.recipes.contains { $0.title == "Chicken Skillet" })
        XCTAssertTrue(result.recipes.contains { $0.title == "Rice Pilaf" })
    }

    func testHighlyRatedSessionsBoostWeight() async throws {
        let recipeIDs = try insertRecipes([
            makeRecipe(title: "Salmon Plate", ingredients: ["salmon", "rice"]),
            makeRecipe(title: "Salmon Noodles", ingredients: ["salmon", "noodle"]),
            makeRecipe(title: "Tofu Bowl", ingredients: ["tofu", "rice"]),
            makeRecipe(title: "Pan-Seared Salmon", ingredients: ["salmon"]),
            makeRecipe(title: "Crispy Tofu Bowl", ingredients: ["tofu"])
        ])

        let highRated1 = makeCookingSession(recipeTitle: "Salmon Plate", recipeId: recipeIDs[0], rating: 5)
        let highRated2 = makeCookingSession(recipeTitle: "Salmon Noodles", recipeId: recipeIDs[1], rating: 5)
        let lowRated = makeCookingSession(recipeTitle: "Tofu Bowl", recipeId: recipeIDs[2], rating: 2)
        mockUserDataService.stubbedCookingSessions = [highRated1, highRated2, lowRated]
        mockUserDataService.stubbedFavorites = []

        let result = try await service.getSuggestions()
        XCTAssertEqual(result.recipes.first?.title, "Pan-Seared Salmon")
    }

    func testRecentlyCookedFiltered() async throws {
        let ids = try insertRecipes([
            makeRecipe(title: "Chicken Soup", ingredients: ["chicken"]),
            makeRecipe(title: "Chicken Salad", ingredients: ["chicken"])
        ])
        let session = makeCookingSession(recipeTitle: "Chicken Soup", recipeId: ids[0])
        mockUserDataService.stubbedCookingSessions = [session]
        mockUserDataService.stubbedFavorites = []

        let result = try await service.getSuggestions()
        XCTAssertFalse(result.recipes.contains { $0.title.lowercased() == "chicken soup" })
        XCTAssertTrue(result.recipes.contains { $0.title == "Chicken Salad" })
    }

    func testEmptyHistoryReturnsEmpty() async throws {
        mockUserDataService.stubbedFavorites = []
        mockUserDataService.stubbedCookingSessions = []

        let result = try await service.getSuggestions()
        XCTAssertTrue(result.recipes.isEmpty)
        XCTAssertNil(result.reason)
    }

    func testLimitParameterRespected() async throws {
        let recipes = (1...10).map { i in
            makeRecipe(title: "Chicken Dish \(i)", ingredients: ["chicken"])
        }
        try db.insertRecipes(recipes)

        let chickenFavorite = makeRecipe(title: "Chicken Tikka", ingredients: ["chicken"])
        mockUserDataService.stubbedFavorites = [chickenFavorite]
        mockUserDataService.stubbedCookingSessions = []

        let limit = 3
        let result = try await service.getSuggestions(limit: limit)
        XCTAssertLessThanOrEqual(result.recipes.count, limit)
    }

    func testFallsBackToSessionTitleWhenRecipeLookupFails() async throws {
        mockUserDataService.stubbedFavorites = []
        mockUserDataService.stubbedCookingSessions = [
            makeCookingSession(recipeTitle: "Mushroom Pasta", recipeId: 999, rating: 5)
        ]
        try db.insertRecipes([
            makeRecipe(title: "Creamy Mushroom Pasta", ingredients: ["mushroom", "pasta"])
        ])

        let result = try await service.getSuggestions()
        XCTAssertEqual(result.recipes.first?.title, "Creamy Mushroom Pasta")
        XCTAssertEqual(result.reason, String(format: Strings.Discover.suggestedBecause, "Mushroom"))
    }
}
