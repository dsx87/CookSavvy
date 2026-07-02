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

    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        db = try DBInterface(inMemory: true)
        testDefaults = UserDefaults(suiteName: defaultsSuiteName)!
        service = UserDataService(dbInterface: db, defaults: testDefaults)
    }

    @MainActor
    override func tearDown() async throws {
        service = nil
        db = nil
        testDefaults.removePersistentDomain(forName: defaultsSuiteName)
        testDefaults = nil
        try await super.tearDown()
    }

    // MARK: - Helper

    @MainActor
    private func insertRecipe(_ recipe: Recipe) async throws {
        try await db.insertRecipes([recipe])
    }

    @MainActor
    private func makeRecipe(title: String) -> Recipe {
        Recipe(
            title: title,
            ingredients: [Ingredient(name: "Garlic")],
            instructions: ["Step 1"],
            image: "",
            additionalInfo: .empty
        )
    }

    // MARK: - Tests

    @MainActor
    func testRecentIngredients() async throws {
        // Ingredient must exist in the ingredients table first
        try await db.insertIngredients([Ingredient(name: "Onion")])
        try await db.recordIngredientUsage(Ingredient(name: "Onion"))
        let ingredients = try await service.getRecentIngredients()
        XCTAssertTrue(ingredients.contains { $0.name == "Onion" })
    }

    @MainActor
    func testGetPopularIngredientsReturnsCuratedSeedWhenNoUsageHistory() async throws {
        // With an empty recent_ingredients table, the curated seed is returned (not the alphabetical
        // catalogue, which the old fallback used).
        let popular = try await service.getPopularIngredients(limit: UI.Discover.popularIngredientCount)
        let expected = PantryStaples.excludingStaples(PopularIngredients.seed())

        XCTAssertEqual(popular.map(\.name), expected.map(\.name))
        XCTAssertEqual(popular.first?.name, "Chicken", "Seed is curated/ordered, not alphabetical")
        XCTAssertFalse(popular.isEmpty)
    }

    @MainActor
    func testGetPopularIngredientsLeadsWithUsageHistoryThenFillsWithCuratedSeed() async throws {
        // A recorded pick leads the grid, and the curated seed fills the remaining slots beneath it
        // (a blend, not a replacement) — so previously-selected and remaining-popular show together.
        try await db.insertIngredients([Ingredient(name: "Kale")])
        try await db.recordIngredientUsage(Ingredient(name: "Kale"))

        let popular = try await service.getPopularIngredients(limit: UI.Discover.popularIngredientCount)

        XCTAssertEqual(popular.first?.name, "Kale", "Recently-used ingredient leads the grid")
        XCTAssertTrue(
            popular.contains { $0.name == "Chicken" },
            "Curated seed fills the remaining slots beneath the recent pick"
        )
        XCTAssertEqual(popular.count, UI.Discover.popularIngredientCount, "Grid stays capped at its size")
        XCTAssertEqual(
            popular.filter { $0.name.lowercased() == "kale" }.count, 1,
            "Recent pick appears once — not duplicated by the fill"
        )
    }

    @MainActor
    func testGetPopularIngredientsDeduplicatesRecentPickAlreadyInCuratedSeed() async throws {
        // "Chicken" is both a recorded pick and the first curated seed: it must appear once, at the
        // front, with the curated duplicate dropped.
        try await db.insertIngredients([Ingredient(name: "Chicken")])
        try await db.recordIngredientUsage(Ingredient(name: "Chicken"))

        let popular = try await service.getPopularIngredients(limit: UI.Discover.popularIngredientCount)

        XCTAssertEqual(popular.first?.name, "Chicken")
        XCTAssertEqual(
            popular.filter { $0.name.lowercased() == "chicken" }.count, 1,
            "The curated duplicate of a recent pick is dropped"
        )
        XCTAssertEqual(popular.count, UI.Discover.popularIngredientCount)
    }

    @MainActor
    func testGetPopularIngredientsExcludesStapleHeavyRecentHistoryAndFillsFromCuratedSeed() async throws {
        // Staples are hidden from the picker but can still dominate recent history (recorded before the
        // rule, or via detection flows). Even when the most-recent picks are mostly staples, filtering
        // them out must not collapse the grid: non-staple recents lead and the curated seed always fills
        // the remaining slots back up to `limit`.
        let staples = ["Salt", "Black Pepper", "Olive Oil"]
        let reals = ["Apple", "Banana", "Carrot", "Chicken", "Egg", "Garlic",
                     "Onion", "Pasta", "Rice", "Tomato", "Yogurt", "Zucchini"]
        try await db.insertIngredients((staples + reals).map(Ingredient.init(name:)))

        // Staples are used most; only two real ingredients have recorded usage.
        for _ in 0..<5 { for name in staples { try await db.recordIngredientUsage(Ingredient(name: name)) } }
        for _ in 0..<3 { try await db.recordIngredientUsage(Ingredient(name: "Garlic")) }
        for _ in 0..<2 { try await db.recordIngredientUsage(Ingredient(name: "Onion")) }

        let popular = try await service.getPopularIngredients(limit: 10)

        for name in staples {
            XCTAssertFalse(popular.contains { $0.name == name }, "\(name) should be filtered from the popular grid")
        }
        // Non-staple recents lead and the curated seed fills to the requested limit — the grid never
        // shrinks to just the two recorded non-staples.
        XCTAssertEqual(popular.count, 10)
        XCTAssertTrue(popular.contains { $0.name == "Garlic" })
        XCTAssertTrue(popular.contains { $0.name == "Onion" })
    }

    @MainActor
    func testRecentRecipes() async throws {
        let recipe = makeRecipe(title: "Chicken Soup")
        try await insertRecipe(recipe)
        let id = try await db.getRecipeId(byTitle: "Chicken Soup")!
        try await db.recordRecipeView(id)

        let recents = try await service.getRecentRecipes()
        XCTAssertTrue(recents.contains { $0.title == "Chicken Soup" })
    }

    @MainActor
    func testFavoriteToggle() async throws {
        let recipe = makeRecipe(title: "Tomato Pasta")
        try await insertRecipe(recipe)

        let wasFavorited = try await service.toggleFavorite(recipe)
        XCTAssertTrue(wasFavorited)

        let isNowFavorite = try await service.isFavorite(recipe)
        XCTAssertTrue(isNowFavorite)

        let unfavorited = try await service.toggleFavorite(recipe)
        XCTAssertFalse(unfavorited)
    }

    @MainActor
    func testFavoriteList() async throws {
        let recipe = makeRecipe(title: "Salmon Bowl")
        try await insertRecipe(recipe)
        _ = try await service.toggleFavorite(recipe)

        let favorites = try await service.getFavorites()
        XCTAssertTrue(favorites.contains { $0.title == "Salmon Bowl" })
    }

    @MainActor
    func testCookingSessionRecording() async throws {
        let recipe = makeRecipe(title: "Beef Stew")
        try await insertRecipe(recipe)

        try await service.markAsCooked(recipe: recipe, duration: 1800, rating: 5)

        let sessions = try await service.getCookingSessions()
        XCTAssertTrue(sessions.contains { $0.recipeTitle == "Beef Stew" })
    }

    @MainActor
    func testCookingSessionsRestoreRescuedIngredients() async throws {
        let recipe = Recipe(
            title: "Garlic Onion Pasta",
            ingredients: [Ingredient(name: "Garlic"), Ingredient(name: "Onion"), Ingredient(name: "Pasta")],
            instructions: ["Step 1"],
            image: "",
            additionalInfo: .empty,
            missingIngredients: ["Pasta"]
        )
        try await insertRecipe(recipe)

        try await service.markAsCooked(recipe: recipe, duration: nil, rating: nil)

        let sessions = try await service.getCookingSessions()
        let session = try XCTUnwrap(sessions.first)
        XCTAssertEqual(session.rescuedIngredients.map(\.name), ["Garlic", "Onion"])
    }

    @MainActor
    func testGetRecipeByIDReturnsStoredRecipe() async throws {
        let recipe = makeRecipe(title: "Replay Soup")
        try await insertRecipe(recipe)
        let fetchedRecipeID = try await db.getRecipeId(byTitle: recipe.title)
        let recipeID = try XCTUnwrap(fetchedRecipeID)

        let loadedRecipe = try await service.getRecipe(byID: recipeID)

        XCTAssertEqual(loadedRecipe?.title, recipe.title)
    }

    @MainActor
    func testMarkAsCookedUsesSharedReplayAvailabilityLogic() async throws {
        let recipe = Recipe(
            title: "Replay Logic Pasta",
            ingredients: [Ingredient(name: "Garlic"), Ingredient(name: "Onion"), Ingredient(name: "Pasta")],
            instructions: ["Step 1"],
            image: "",
            additionalInfo: .empty,
            missingIngredients: ["Onion"]
        )
        try await insertRecipe(recipe)

        try await service.markAsCooked(recipe: recipe, duration: nil, rating: nil)

        let sessions = try await service.getCookingSessions()
        let session = try XCTUnwrap(sessions.first)
        XCTAssertEqual(session.rescuedIngredients.map(\.name), ["Garlic", "Pasta"])
    }

    @MainActor
    func testRecipesCooked() async throws {
        let recipe1 = makeRecipe(title: "Lemon Chicken")
        let recipe2 = makeRecipe(title: "Rice Bowl")
        try await insertRecipe(recipe1)
        try await insertRecipe(recipe2)

        try await service.markAsCooked(recipe: recipe1, duration: nil, rating: nil)
        try await service.markAsCooked(recipe: recipe2, duration: nil, rating: nil)

        let count = try await service.recipesCooked()
        XCTAssertEqual(count, 2)
    }

    @MainActor
    func testHighMatchRecipesCookedCountDefaultsToZero() async {
        XCTAssertEqual(service.getHighMatchRecipesCookedCount(), 0)
    }

    @MainActor
    func testMarkAsCookedIncrementsHighMatchRecipesCookedCountForPerfectMatch() async throws {
        let recipe = Recipe(
            title: "Perfect Match Pasta",
            ingredients: [Ingredient(name: "Garlic"), Ingredient(name: "Pasta")],
            instructions: ["Step 1"],
            image: "",
            additionalInfo: .empty,
            missingIngredients: []
        )
        try await insertRecipe(recipe)

        try await service.markAsCooked(recipe: recipe, duration: nil, rating: nil)

        XCTAssertEqual(service.getHighMatchRecipesCookedCount(), 1)
    }

    @MainActor
    func testMarkAsCookedDoesNotIncrementHighMatchRecipesCookedCountWhenRecipeHasMissingIngredients() async throws {
        let recipe = Recipe(
            title: "Almost Match Pasta",
            ingredients: [Ingredient(name: "Garlic"), Ingredient(name: "Pasta")],
            instructions: ["Step 1"],
            image: "",
            additionalInfo: .empty,
            missingIngredients: ["Pasta"]
        )
        try await insertRecipe(recipe)

        try await service.markAsCooked(recipe: recipe, duration: nil, rating: nil)

        XCTAssertEqual(service.getHighMatchRecipesCookedCount(), 0)
    }

    @MainActor
    func testUserRecipeCRUD() async throws {
        let recipe = makeRecipe(title: "My Custom Dish")
        try await service.saveUserRecipe(recipe)

        let recipes = try await service.getUserRecipes()
        XCTAssertTrue(recipes.contains { $0.title == "My Custom Dish" })

        let count = try await service.getUserRecipeCount()
        XCTAssertEqual(count, 1)
    }

    @MainActor
    func testMonthlyRecipesCooked() async throws {
        let recipe1 = makeRecipe(title: "Monthly Pasta")
        let recipe2 = makeRecipe(title: "Monthly Chicken")
        try await insertRecipe(recipe1)
        try await insertRecipe(recipe2)

        try await service.markAsCooked(recipe: recipe1, duration: nil, rating: nil)
        try await service.markAsCooked(recipe: recipe2, duration: nil, rating: nil)

        let count = try await service.monthlyRecipesCooked()
        XCTAssertEqual(count, 2)
    }

    @MainActor
    func testMonthlyRecipesCookedExcludesOtherMonths() async throws {
        let recipe = makeRecipe(title: "Old Stew")
        try await insertRecipe(recipe)
        let recipeId = try await db.getRecipeId(byTitle: "Old Stew")!

        let pastDate = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
        try await db.recordCookingSession(recipeId: recipeId, date: pastDate, duration: nil, rating: nil)

        let count = try await service.monthlyRecipesCooked()
        XCTAssertEqual(count, 0)
    }

    @MainActor
    func testMonthlyIngredientsRescued() async throws {
        let recipe = Recipe(
            title: "Ingredient Test",
            ingredients: [Ingredient(name: "Garlic"), Ingredient(name: "Onion")],
            instructions: ["Step 1"],
            image: "",
            additionalInfo: .empty
        )
        try await db.insertIngredients([Ingredient(name: "Garlic"), Ingredient(name: "Onion")])
        try await insertRecipe(recipe)

        try await service.markAsCooked(recipe: recipe, duration: nil, rating: nil)

        let count = try await service.monthlyIngredientsRescued()
        XCTAssertEqual(count, 2)
    }

    @MainActor
    func testMonthlyCookingInsightsReturnsZerosWhenNoSessionsExist() async throws {
        let insights = try await service.monthlyCookingInsights()

        XCTAssertEqual(insights.mealsCooked, 0)
        XCTAssertEqual(insights.uniqueIngredientsUsed, 0)
        XCTAssertEqual(insights.estimatedSavingsAmount, 0)
        XCTAssertEqual(insights.currencyCode, "USD")
        XCTAssertTrue(insights.isApproximate)
    }

    @MainActor
    func testMonthlyCookingInsightsEstimatesFourDollarsPerCurrentMonthMeal() async throws {
        let recipe1 = makeRecipe(title: "Monthly Savings Pasta")
        let recipe2 = makeRecipe(title: "Monthly Savings Chicken")
        try await insertRecipe(recipe1)
        try await insertRecipe(recipe2)

        try await service.markAsCooked(recipe: recipe1, duration: nil, rating: nil)
        try await service.markAsCooked(recipe: recipe2, duration: nil, rating: nil)

        let insights = try await service.monthlyCookingInsights()

        XCTAssertEqual(insights.mealsCooked, 2)
        XCTAssertEqual(insights.estimatedSavingsAmount, 8)
        XCTAssertTrue(insights.isApproximate)
    }

    @MainActor
    func testMonthlyCookingInsightsExcludesPreviousMonthSessions() async throws {
        let currentRecipe = makeRecipe(title: "Current Month Soup")
        let previousRecipe = makeRecipe(title: "Previous Month Stew")
        try await insertRecipe(currentRecipe)
        try await insertRecipe(previousRecipe)
        let fetchedPreviousRecipeId = try await db.getRecipeId(byTitle: previousRecipe.title)
        let previousRecipeId = try XCTUnwrap(fetchedPreviousRecipeId)
        let previousMonthDate = try XCTUnwrap(Calendar.current.date(byAdding: .month, value: -1, to: Date()))

        try await service.markAsCooked(recipe: currentRecipe, duration: nil, rating: nil)
        try await db.recordCookingSession(recipeId: previousRecipeId, date: previousMonthDate, duration: nil, rating: nil)

        let insights = try await service.monthlyCookingInsights()

        XCTAssertEqual(insights.mealsCooked, 1)
        XCTAssertEqual(insights.estimatedSavingsAmount, 4)
    }

    @MainActor
    func testMonthlyCookingInsightsDeduplicatesCurrentMonthIngredients() async throws {
        let recipe1 = Recipe(
            title: "Garlic Onion Pasta",
            ingredients: [Ingredient(name: "Garlic"), Ingredient(name: "Onion")],
            instructions: ["Step 1"],
            image: "",
            additionalInfo: .empty
        )
        let recipe2 = Recipe(
            title: "Garlic Soup",
            ingredients: [Ingredient(name: "Garlic")],
            instructions: ["Step 1"],
            image: "",
            additionalInfo: .empty
        )
        try await insertRecipe(recipe1)
        try await insertRecipe(recipe2)

        try await service.markAsCooked(recipe: recipe1, duration: nil, rating: nil)
        try await service.markAsCooked(recipe: recipe2, duration: nil, rating: nil)

        let insights = try await service.monthlyCookingInsights()

        XCTAssertEqual(insights.mealsCooked, 2)
        XCTAssertEqual(insights.uniqueIngredientsUsed, 2)
        XCTAssertEqual(insights.estimatedSavingsAmount, 8)
    }

    @MainActor
    func testClearRecentPreservesFavorites() async throws {
        let recipe = makeRecipe(title: "Garlic Bread")
        try await insertRecipe(recipe)
        _ = try await service.toggleFavorite(recipe)

        try await service.clearRecentData()

        let favorites = try await service.getFavorites()
        XCTAssertTrue(favorites.contains { $0.title == "Garlic Bread" })
    }

    @MainActor
    func testThemePreference() async {
        service.setThemePreference(.dark)
        XCTAssertEqual(service.getThemePreference(), .dark)

        service.setThemePreference(.light)
        XCTAssertEqual(service.getThemePreference(), .light)
    }

}
