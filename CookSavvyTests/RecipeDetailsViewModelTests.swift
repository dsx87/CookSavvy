//
//  RecipeDetailsViewModelTests.swift
//  CookSavvyTests
//

import XCTest
@testable import CookSavvy

// MARK: - Spy coordinator

@MainActor
private final class SpyRecipeDetailsCoordinator: RecipeDetailsCoordinating {
    var showCookModeCallCount = 0
    var showShoppingListCallCount = 0
    var showUpgradeCallCount = 0

    func showCookMode(recipe: Recipe) { showCookModeCallCount += 1 }
    func showShoppingList() { showShoppingListCallCount += 1 }
    func showUpgrade() { showUpgradeCallCount += 1 }
}

@MainActor
final class RecipeDetailsViewModelTests: XCTestCase {

    var mockUserDataService: MockUserDataService!
    var mockShoppingListService: MockShoppingListService!
    var freeSubscription: MockSubscriptionService!
    var premiumSubscription: MockSubscriptionService!

    override func setUp() {
        super.setUp()
        mockUserDataService = MockUserDataService()
        mockShoppingListService = MockShoppingListService()
        freeSubscription = MockSubscriptionService(initialPlan: .free)
        premiumSubscription = MockSubscriptionService(initialPlan: .premium)
    }

    override func tearDown() {
        mockUserDataService = nil
        mockShoppingListService = nil
        freeSubscription = nil
        premiumSubscription = nil
        super.tearDown()
    }

    private func makeRecipe(
        title: String = "Test Recipe",
        ingredients: [Ingredient] = [Ingredient(name: "Garlic"), Ingredient(name: "Tomato")]
    ) -> Recipe {
        Recipe(
            title: title,
            ingredients: ingredients,
            instructions: ["Cook"],
            image: "",
            cleanedIngredients: ingredients,
            additionalInfo: .empty
        )
    }

    private func makeViewModel(
        recipe: Recipe? = nil,
        selectedIngredients: [Ingredient] = [],
        subscription: MockSubscriptionService? = nil
    ) -> RecipeDetailsViewModel {
        RecipeDetailsViewModel(
            recipe: recipe ?? makeRecipe(),
            selectedIngredients: selectedIngredients,
            userDataService: mockUserDataService,
            shoppingListService: mockShoppingListService,
            subscriptionService: subscription ?? freeSubscription,
            analyticsService: MockAnalyticsService(),
            coordinator: nil
        )
    }

    func testFavoriteToggle() async {
        mockUserDataService.stubbedToggleFavorite = true
        mockUserDataService.stubbedIsFavorite = false

        let vm = makeViewModel()
        // Yield to let the spawned loadData Task complete on the MainActor
        for _ in 0..<10 { await Task.yield() }

        await vm.toggleFavorite()

        XCTAssertFalse(mockUserDataService.toggleFavoriteCalls.isEmpty)
        XCTAssertTrue(vm.isFavorite)
    }

    func testMissingIngredientsCalculation() {
        let recipeIngredients = [Ingredient(name: "Garlic"), Ingredient(name: "Onion"), Ingredient(name: "Tomato")]
        let recipe = makeRecipe(ingredients: recipeIngredients)
        let selectedIngredients = [Ingredient(name: "Garlic")]

        let vm = makeViewModel(recipe: recipe, selectedIngredients: selectedIngredients)
        // Onion and Tomato are missing
        XCTAssertEqual(vm.missingIngredientNames.count, 2)
        XCTAssertTrue(vm.missingIngredientNames.contains("Onion"))
        XCTAssertTrue(vm.missingIngredientNames.contains("Tomato"))
    }

    func testMissingEmptyWhenNoSelection() {
        let recipe = makeRecipe(ingredients: [Ingredient(name: "Garlic"), Ingredient(name: "Onion")])
        let vm = makeViewModel(recipe: recipe, selectedIngredients: [])
        // No selected ingredients, no pre-computed missing — falls back to []
        XCTAssertTrue(vm.missingIngredientNames.isEmpty)
    }

    func testAddToListPremiumGate() async {
        let recipeIngredients = [Ingredient(name: "Garlic"), Ingredient(name: "Onion")]
        let recipe = makeRecipe(ingredients: recipeIngredients)
        // Only garlic is selected, so onion is missing
        let vm = makeViewModel(
            recipe: recipe,
            selectedIngredients: [Ingredient(name: "Garlic")],
            subscription: freeSubscription
        )

        await vm.addMissingToShoppingList()

        // Free user: addItems should NOT have been called (upgrade gated)
        XCTAssertTrue(mockShoppingListService.addItemsCalls.isEmpty)
    }

    func testAddToListForPremiumUser() async {
        let recipeIngredients = [Ingredient(name: "Garlic"), Ingredient(name: "Onion")]
        let recipe = makeRecipe(ingredients: recipeIngredients)
        let vm = makeViewModel(
            recipe: recipe,
            selectedIngredients: [Ingredient(name: "Garlic")],
            subscription: premiumSubscription
        )

        await vm.addMissingToShoppingList()

        XCTAssertFalse(mockShoppingListService.addItemsCalls.isEmpty)
        let call = mockShoppingListService.addItemsCalls[0]
        XCTAssertTrue(call.names.contains("Onion"))
        XCTAssertEqual(call.recipeTitle, "Test Recipe")
    }

    func testRecordRecipeViewOnInit() async {
        _ = makeViewModel()
        // Yield to let the init Task (loadData → recordView) complete
        for _ in 0..<10 { await Task.yield() }

        XCTAssertEqual(mockUserDataService.recordedRecipeViews.count, 1)
    }

    func testMissingFallsBackToPreComputedMissing() {
        let recipe = Recipe(
            title: "Pasta",
            ingredients: [Ingredient(name: "Pasta"), Ingredient(name: "Sauce")],
            instructions: ["Cook"],
            image: "",
            cleanedIngredients: [],
            additionalInfo: .empty,
            missingIngredients: ["Sauce"]
        )
        // No selected ingredients → falls back to recipe.missingIngredients
        let vm = makeViewModel(recipe: recipe, selectedIngredients: [])
        XCTAssertEqual(vm.missingIngredientNames, ["Sauce"])
    }

    func testCoordinatorRoutingAddToListShowsShoppingList() async {
        let spy = SpyRecipeDetailsCoordinator()
        let recipe = makeRecipe(ingredients: [Ingredient(name: "Garlic"), Ingredient(name: "Onion")])
        let vm = RecipeDetailsViewModel(
            recipe: recipe,
            selectedIngredients: [Ingredient(name: "Garlic")],
            userDataService: mockUserDataService,
            shoppingListService: mockShoppingListService,
            subscriptionService: premiumSubscription,
            analyticsService: MockAnalyticsService(),
            coordinator: spy
        )

        await vm.addMissingToShoppingList()

        XCTAssertEqual(spy.showShoppingListCallCount, 1)
        XCTAssertEqual(spy.showUpgradeCallCount, 0)
    }

    func testCoordinatorRoutingAddToListShowsUpgradeForFreeUser() async {
        let spy = SpyRecipeDetailsCoordinator()
        let recipe = makeRecipe(ingredients: [Ingredient(name: "Garlic"), Ingredient(name: "Onion")])
        let vm = RecipeDetailsViewModel(
            recipe: recipe,
            selectedIngredients: [Ingredient(name: "Garlic")],
            userDataService: mockUserDataService,
            shoppingListService: mockShoppingListService,
            subscriptionService: freeSubscription,
            analyticsService: MockAnalyticsService(),
            coordinator: spy
        )

        await vm.addMissingToShoppingList()

        XCTAssertEqual(spy.showUpgradeCallCount, 1)
        XCTAssertEqual(spy.showShoppingListCallCount, 0)
    }
}
