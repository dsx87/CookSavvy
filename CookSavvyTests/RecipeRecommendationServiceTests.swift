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
        db = DBInterface(inMemory: true)
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
            cleanedIngredients: ingList,
            additionalInfo: .empty
        )
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

    func testFavoritesDriveSuggestions() async throws {
        // A favorite chicken recipe should cause the service to weight "chicken"
        // and return DB recipes containing chicken
        let chickenRecipe = makeRecipe(title: "Chicken Tikka", ingredients: ["chicken", "yogurt"])
        mockUserDataService.stubbedFavorites = [chickenRecipe]
        mockUserDataService.stubbedCookingSessions = []

        // Insert a chicken recipe into the DB so recommendations can find it
        try db.insertRecipes([makeRecipe(title: "Chicken Stir Fry", ingredients: ["chicken", "peppers"])])

        let result = try await service.getSuggestions()
        XCTAssertFalse(result.recipes.isEmpty, "Expected at least one chicken-based suggestion")
        XCTAssertTrue(
            result.recipes.contains { $0.title == "Chicken Stir Fry" },
            "Expected 'Chicken Stir Fry' to appear in suggestions driven by chicken favorite"
        )
    }

    func testHighlyRatedSessionsBoostWeight() async throws {
        // Three high-rated salmon sessions (rating 5) vs one low-rated tofu session (rating 2).
        // Salmon accumulates more weight so the service should pick salmon as top keyword.
        let highRated1 = makeCookingSession(recipeTitle: "Grilled Salmon", recipeId: 1, rating: 5)
        let highRated2 = makeCookingSession(recipeTitle: "Salmon Salad", recipeId: 2, rating: 5)
        let highRated3 = makeCookingSession(recipeTitle: "Salmon Soup", recipeId: 3, rating: 5)
        let lowRated = makeCookingSession(recipeTitle: "Tofu Stir Fry", recipeId: 4, rating: 2)
        mockUserDataService.stubbedCookingSessions = [highRated1, highRated2, highRated3, lowRated]
        mockUserDataService.stubbedFavorites = []

        // Insert a salmon recipe in the DB that isn't in the recent session list
        try db.insertRecipes([
            makeRecipe(title: "Pan-Seared Salmon", ingredients: ["salmon"]),
            makeRecipe(title: "Crispy Tofu Bowl", ingredients: ["tofu"])
        ])

        let result = try await service.getSuggestions()
        XCTAssertFalse(result.recipes.isEmpty, "Expected at least one suggestion from highly-rated salmon sessions")
        XCTAssertTrue(
            result.recipes.contains { $0.title == "Pan-Seared Salmon" },
            "Highly-rated salmon sessions should surface 'Pan-Seared Salmon'"
        )
    }

    func testRecentlyCookedFiltered() async throws {
        // Recently cooked recipe should be excluded from suggestions
        let session = makeCookingSession(recipeTitle: "Chicken Soup", recipeId: 1)
        mockUserDataService.stubbedCookingSessions = [session]
        mockUserDataService.stubbedFavorites = []

        // Insert the same recipe title into DB
        try db.insertRecipes([makeRecipe(title: "Chicken Soup", ingredients: ["chicken"])])

        let result = try await service.getSuggestions()
        // Chicken Soup should be filtered out as recently cooked
        XCTAssertFalse(result.recipes.contains { $0.title.lowercased() == "chicken soup" })
    }

    func testEmptyHistoryReturnsEmpty() async throws {
        mockUserDataService.stubbedFavorites = []
        mockUserDataService.stubbedCookingSessions = []

        let result = try await service.getSuggestions()
        XCTAssertTrue(result.recipes.isEmpty)
        XCTAssertNil(result.reason)
    }

    func testLimitParameterRespected() async throws {
        // Seed many chicken recipes in DB
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
}
