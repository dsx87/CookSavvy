//
//  UserDataServiceTests.swift
//  CookSavvyTests
//

import XCTest
@testable import CookSavvy

final class UserDataServiceTests: XCTestCase {

    var db: DBInterface!
    var service: UserDataService!
    var testDefaults: UserDefaults!
    private let defaultsSuiteName = "test.userdata.\(UUID().uuidString)"

    override func setUp() async throws {
        try await super.setUp()
        db = try DBInterface(inMemory: true)
        testDefaults = UserDefaults(suiteName: defaultsSuiteName)!
        service = UserDataService(dbInterface: db, defaults: testDefaults)
    }

    override func tearDown() async throws {
        service = nil
        db = nil
        testDefaults.removePersistentDomain(forName: defaultsSuiteName)
        testDefaults = nil
        try await super.tearDown()
    }

    // MARK: - Helper

    private func insertRecipe(_ recipe: Recipe) throws {
        try db.insertRecipes([recipe])
    }

    private func makeRecipe(title: String) -> Recipe {
        Recipe(
            title: title,
            ingredients: [Ingredient(name: "Garlic")],
            instructions: ["Step 1"],
            image: "",
            cleanedIngredients: [Ingredient(name: "Garlic")],
            additionalInfo: .empty
        )
    }

    // MARK: - Tests

    func testRecentIngredients() async throws {
        // Ingredient must exist in the ingredients table first
        try db.insertIngredients([Ingredient(name: "Onion")])
        try db.recordIngredientUsage(Ingredient(name: "Onion"))
        let ingredients = try await service.getRecentIngredients()
        XCTAssertTrue(ingredients.contains { $0.name == "Onion" })
    }

    func testRecentRecipes() async throws {
        let recipe = makeRecipe(title: "Chicken Soup")
        try insertRecipe(recipe)
        let id = try db.getRecipeId(byTitle: "Chicken Soup")!
        try db.recordRecipeView(id)

        let recents = try await service.getRecentRecipes()
        XCTAssertTrue(recents.contains { $0.title == "Chicken Soup" })
    }

    func testFavoriteToggle() async throws {
        let recipe = makeRecipe(title: "Tomato Pasta")
        try insertRecipe(recipe)

        let wasFavorited = try await service.toggleFavorite(recipe)
        XCTAssertTrue(wasFavorited)

        let isNowFavorite = try await service.isFavorite(recipe)
        XCTAssertTrue(isNowFavorite)

        let unfavorited = try await service.toggleFavorite(recipe)
        XCTAssertFalse(unfavorited)
    }

    func testFavoriteList() async throws {
        let recipe = makeRecipe(title: "Salmon Bowl")
        try insertRecipe(recipe)
        _ = try await service.toggleFavorite(recipe)

        let favorites = try await service.getFavorites()
        XCTAssertTrue(favorites.contains { $0.title == "Salmon Bowl" })
    }

    func testCookingSessionRecording() async throws {
        let recipe = makeRecipe(title: "Beef Stew")
        try insertRecipe(recipe)

        try await service.markAsCooked(recipe: recipe, duration: 1800, rating: 5)

        let sessions = try await service.getCookingSessions()
        XCTAssertTrue(sessions.contains { $0.recipeTitle == "Beef Stew" })
    }

    func testCookingSessionsRestoreRescuedIngredients() async throws {
        let recipe = Recipe(
            title: "Garlic Onion Pasta",
            ingredients: [Ingredient(name: "Garlic"), Ingredient(name: "Onion"), Ingredient(name: "Pasta")],
            instructions: ["Step 1"],
            image: "",
            cleanedIngredients: [Ingredient(name: "Garlic"), Ingredient(name: "Onion"), Ingredient(name: "Pasta")],
            additionalInfo: .empty,
            missingIngredients: ["Pasta"]
        )
        try insertRecipe(recipe)

        try await service.markAsCooked(recipe: recipe, duration: nil, rating: nil)

        let sessions = try await service.getCookingSessions()
        let session = try XCTUnwrap(sessions.first)
        XCTAssertEqual(session.rescuedIngredients.map(\.name), ["Garlic", "Onion"])
    }

    func testGetRecipeByIDReturnsStoredRecipe() async throws {
        let recipe = makeRecipe(title: "Replay Soup")
        try insertRecipe(recipe)
        let recipeID = try XCTUnwrap(db.getRecipeId(byTitle: recipe.title))

        let loadedRecipe = try await service.getRecipe(byID: recipeID)

        XCTAssertEqual(loadedRecipe?.title, recipe.title)
    }

    func testMarkAsCookedUsesSharedReplayAvailabilityLogic() async throws {
        let recipe = Recipe(
            title: "Replay Logic Pasta",
            ingredients: [Ingredient(name: "Garlic"), Ingredient(name: "Onion"), Ingredient(name: "Pasta")],
            instructions: ["Step 1"],
            image: "",
            cleanedIngredients: [Ingredient(name: "Garlic"), Ingredient(name: "Onion"), Ingredient(name: "Pasta")],
            additionalInfo: .empty,
            missingIngredients: ["Onion"]
        )
        try insertRecipe(recipe)

        try await service.markAsCooked(recipe: recipe, duration: nil, rating: nil)

        let sessions = try await service.getCookingSessions()
        let session = try XCTUnwrap(sessions.first)
        XCTAssertEqual(session.rescuedIngredients.map(\.name), ["Garlic", "Pasta"])
    }

    func testRecipesCooked() async throws {
        let recipe1 = makeRecipe(title: "Lemon Chicken")
        let recipe2 = makeRecipe(title: "Rice Bowl")
        try insertRecipe(recipe1)
        try insertRecipe(recipe2)

        try await service.markAsCooked(recipe: recipe1, duration: nil, rating: nil)
        try await service.markAsCooked(recipe: recipe2, duration: nil, rating: nil)

        let count = try await service.recipesCooked()
        XCTAssertEqual(count, 2)
    }

    func testHighMatchRecipesCookedCountDefaultsToZero() {
        XCTAssertEqual(service.getHighMatchRecipesCookedCount(), 0)
    }

    func testMarkAsCookedIncrementsHighMatchRecipesCookedCountForPerfectMatch() async throws {
        let recipe = Recipe(
            title: "Perfect Match Pasta",
            ingredients: [Ingredient(name: "Garlic"), Ingredient(name: "Pasta")],
            instructions: ["Step 1"],
            image: "",
            cleanedIngredients: [Ingredient(name: "Garlic"), Ingredient(name: "Pasta")],
            additionalInfo: .empty,
            missingIngredients: []
        )
        try insertRecipe(recipe)

        try await service.markAsCooked(recipe: recipe, duration: nil, rating: nil)

        XCTAssertEqual(service.getHighMatchRecipesCookedCount(), 1)
    }

    func testMarkAsCookedDoesNotIncrementHighMatchRecipesCookedCountWhenRecipeHasMissingIngredients() async throws {
        let recipe = Recipe(
            title: "Almost Match Pasta",
            ingredients: [Ingredient(name: "Garlic"), Ingredient(name: "Pasta")],
            instructions: ["Step 1"],
            image: "",
            cleanedIngredients: [Ingredient(name: "Garlic"), Ingredient(name: "Pasta")],
            additionalInfo: .empty,
            missingIngredients: ["Pasta"]
        )
        try insertRecipe(recipe)

        try await service.markAsCooked(recipe: recipe, duration: nil, rating: nil)

        XCTAssertEqual(service.getHighMatchRecipesCookedCount(), 0)
    }

    func testUserRecipeCRUD() async throws {
        let recipe = makeRecipe(title: "My Custom Dish")
        try await service.saveUserRecipe(recipe)

        let recipes = try await service.getUserRecipes()
        XCTAssertTrue(recipes.contains { $0.title == "My Custom Dish" })

        let count = try await service.getUserRecipeCount()
        XCTAssertEqual(count, 1)
    }

    func testMonthlyRecipesCooked() async throws {
        let recipe1 = makeRecipe(title: "Monthly Pasta")
        let recipe2 = makeRecipe(title: "Monthly Chicken")
        try insertRecipe(recipe1)
        try insertRecipe(recipe2)

        try await service.markAsCooked(recipe: recipe1, duration: nil, rating: nil)
        try await service.markAsCooked(recipe: recipe2, duration: nil, rating: nil)

        let count = try await service.monthlyRecipesCooked()
        XCTAssertEqual(count, 2)
    }

    func testMonthlyRecipesCookedExcludesOtherMonths() async throws {
        let recipe = makeRecipe(title: "Old Stew")
        try insertRecipe(recipe)
        let recipeId = try db.getRecipeId(byTitle: "Old Stew")!

        let pastDate = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
        try db.recordCookingSession(recipeId: recipeId, date: pastDate, duration: nil, rating: nil)

        let count = try await service.monthlyRecipesCooked()
        XCTAssertEqual(count, 0)
    }

    func testMonthlyIngredientsRescued() async throws {
        let recipe = Recipe(
            title: "Ingredient Test",
            ingredients: [Ingredient(name: "Garlic"), Ingredient(name: "Onion")],
            instructions: ["Step 1"],
            image: "",
            cleanedIngredients: [Ingredient(name: "Garlic"), Ingredient(name: "Onion")],
            additionalInfo: .empty
        )
        try db.insertIngredients([Ingredient(name: "Garlic"), Ingredient(name: "Onion")])
        try insertRecipe(recipe)

        try await service.markAsCooked(recipe: recipe, duration: nil, rating: nil)

        let count = try await service.monthlyIngredientsRescued()
        XCTAssertEqual(count, 2)
    }

    func testMonthlyCookingInsightsReturnsZerosWhenNoSessionsExist() async throws {
        let insights = try await service.monthlyCookingInsights()

        XCTAssertEqual(insights.mealsCooked, 0)
        XCTAssertEqual(insights.uniqueIngredientsUsed, 0)
        XCTAssertEqual(insights.estimatedSavingsAmount, 0)
        XCTAssertEqual(insights.currencyCode, "USD")
        XCTAssertTrue(insights.isApproximate)
    }

    func testMonthlyCookingInsightsEstimatesFourDollarsPerCurrentMonthMeal() async throws {
        let recipe1 = makeRecipe(title: "Monthly Savings Pasta")
        let recipe2 = makeRecipe(title: "Monthly Savings Chicken")
        try insertRecipe(recipe1)
        try insertRecipe(recipe2)

        try await service.markAsCooked(recipe: recipe1, duration: nil, rating: nil)
        try await service.markAsCooked(recipe: recipe2, duration: nil, rating: nil)

        let insights = try await service.monthlyCookingInsights()

        XCTAssertEqual(insights.mealsCooked, 2)
        XCTAssertEqual(insights.estimatedSavingsAmount, 8)
        XCTAssertTrue(insights.isApproximate)
    }

    func testMonthlyCookingInsightsExcludesPreviousMonthSessions() async throws {
        let currentRecipe = makeRecipe(title: "Current Month Soup")
        let previousRecipe = makeRecipe(title: "Previous Month Stew")
        try insertRecipe(currentRecipe)
        try insertRecipe(previousRecipe)
        let previousRecipeId = try XCTUnwrap(db.getRecipeId(byTitle: previousRecipe.title))
        let previousMonthDate = try XCTUnwrap(Calendar.current.date(byAdding: .month, value: -1, to: Date()))

        try await service.markAsCooked(recipe: currentRecipe, duration: nil, rating: nil)
        try db.recordCookingSession(recipeId: previousRecipeId, date: previousMonthDate, duration: nil, rating: nil)

        let insights = try await service.monthlyCookingInsights()

        XCTAssertEqual(insights.mealsCooked, 1)
        XCTAssertEqual(insights.estimatedSavingsAmount, 4)
    }

    func testMonthlyCookingInsightsDeduplicatesCurrentMonthIngredients() async throws {
        let recipe1 = Recipe(
            title: "Garlic Onion Pasta",
            ingredients: [Ingredient(name: "Garlic"), Ingredient(name: "Onion")],
            instructions: ["Step 1"],
            image: "",
            cleanedIngredients: [Ingredient(name: "Garlic"), Ingredient(name: "Onion")],
            additionalInfo: .empty
        )
        let recipe2 = Recipe(
            title: "Garlic Soup",
            ingredients: [Ingredient(name: "Garlic")],
            instructions: ["Step 1"],
            image: "",
            cleanedIngredients: [Ingredient(name: "Garlic")],
            additionalInfo: .empty
        )
        try insertRecipe(recipe1)
        try insertRecipe(recipe2)

        try await service.markAsCooked(recipe: recipe1, duration: nil, rating: nil)
        try await service.markAsCooked(recipe: recipe2, duration: nil, rating: nil)

        let insights = try await service.monthlyCookingInsights()

        XCTAssertEqual(insights.mealsCooked, 2)
        XCTAssertEqual(insights.uniqueIngredientsUsed, 2)
        XCTAssertEqual(insights.estimatedSavingsAmount, 8)
    }

    func testClearRecentPreservesFavorites() async throws {
        let recipe = makeRecipe(title: "Garlic Bread")
        try insertRecipe(recipe)
        _ = try await service.toggleFavorite(recipe)

        try await service.clearRecentData()

        let favorites = try await service.getFavorites()
        XCTAssertTrue(favorites.contains { $0.title == "Garlic Bread" })
    }

    func testThemePreference() {
        service.setThemePreference(.dark)
        XCTAssertEqual(service.getThemePreference(), .dark)

        service.setThemePreference(.light)
        XCTAssertEqual(service.getThemePreference(), .light)
    }

}
