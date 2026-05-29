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
private final class SpyRecipeShareCardGenerator: RecipeShareCardGenerating {
    var makeShareCardCallCount = 0
    var requestedRecipes: [Recipe] = []
    let stubbedCard = RecipeShareCard(title: "Stub", pngData: Data([0x89, 0x50, 0x4E, 0x47]))

    func makeShareCard(for recipe: Recipe) async -> RecipeShareCard {
        makeShareCardCallCount += 1
        requestedRecipes.append(recipe)
        return stubbedCard
    }
}

@MainActor
final class RecipeDetailsViewModelTests: XCTestCase {

    var mockUserDataService: MockUserDataService!
    var mockShoppingListService: MockShoppingListService!
    var freeSubscription: MockSubscriptionService!
    var premiumSubscription: MockSubscriptionService!
    private var shareCardGenerator: SpyRecipeShareCardGenerator!

    override func setUp() {
        super.setUp()
        mockUserDataService = MockUserDataService()
        mockShoppingListService = MockShoppingListService()
        freeSubscription = MockSubscriptionService(initialPlan: .free)
        premiumSubscription = MockSubscriptionService(initialPlan: .premium)
        shareCardGenerator = SpyRecipeShareCardGenerator()
    }

    override func tearDown() {
        mockUserDataService = nil
        mockShoppingListService = nil
        freeSubscription = nil
        premiumSubscription = nil
        shareCardGenerator = nil
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
            shareCardGenerator: shareCardGenerator,
            analyticsService: MockAnalyticsService(),
            logger: MockLogger(),
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

    func testMissingIngredientsExcludeAssumedStaplesInDetails() {
        let recipeIngredients = ["Garlic", "Salt", "Oil", "Onion"].map(Ingredient.init(name:))
        let recipe = makeRecipe(ingredients: recipeIngredients)

        let vm = makeViewModel(recipe: recipe, selectedIngredients: [Ingredient(name: "Garlic")])

        XCTAssertEqual(vm.missingIngredientNames, ["Onion"])
        XCTAssertEqual(vm.ingredientStatus(Ingredient(name: "Salt")), .available)
        XCTAssertEqual(vm.ingredientStatus(Ingredient(name: "Oil")), .available)
        XCTAssertEqual(vm.ingredientStatus(Ingredient(name: "Onion")), .missing)
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

    func testAddToListForPremiumUserSkipsAssumedStaples() async {
        let recipeIngredients = ["Garlic", "Salt", "Oil", "Onion"].map(Ingredient.init(name:))
        let recipe = makeRecipe(ingredients: recipeIngredients)
        let vm = makeViewModel(
            recipe: recipe,
            selectedIngredients: [Ingredient(name: "Garlic")],
            subscription: premiumSubscription
        )

        await vm.addMissingToShoppingList()

        XCTAssertEqual(mockShoppingListService.addItemsCalls.first?.names, ["Onion"])
        XCTAssertEqual(mockShoppingListService.addItemsCalls.first?.recipeTitle, "Test Recipe")
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
            shareCardGenerator: shareCardGenerator,
            analyticsService: MockAnalyticsService(),
            logger: MockLogger(),
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
            shareCardGenerator: shareCardGenerator,
            analyticsService: MockAnalyticsService(),
            logger: MockLogger(),
            coordinator: spy
        )

        await vm.addMissingToShoppingList()

        XCTAssertEqual(spy.showUpgradeCallCount, 1)
        XCTAssertEqual(spy.showShoppingListCallCount, 0)
    }

    func testToggleFavoriteSetsErrorMessageWhenServiceThrows() async {
        mockUserDataService.shouldThrow = TestError.stub

        let vm = makeViewModel()
        for _ in 0..<10 { await Task.yield() }

        await vm.toggleFavorite()

        XCTAssertEqual(vm.errorMessage, Strings.Errors.favoriteFailed)
    }

    func testAddToShoppingListSetsErrorMessageWhenServiceThrows() async {
        mockShoppingListService.shouldThrow = TestError.stub
        let recipe = makeRecipe(ingredients: [Ingredient(name: "Garlic"), Ingredient(name: "Onion")])
        let vm = makeViewModel(
            recipe: recipe,
            selectedIngredients: [Ingredient(name: "Garlic")],
            subscription: premiumSubscription
        )

        await vm.addMissingToShoppingList()

        XCTAssertEqual(vm.errorMessage, Strings.Errors.shoppingListAddFailed)
    }

    func testShareCardPreparationCallsGenerator() async {
        let recipe = makeRecipe(title: "Shareable Pasta")
        let vm = makeViewModel(recipe: recipe)

        for _ in 0..<10 { await Task.yield() }

        XCTAssertEqual(shareCardGenerator.makeShareCardCallCount, 1)
        XCTAssertEqual(shareCardGenerator.requestedRecipes.first?.title, "Shareable Pasta")
        XCTAssertEqual(vm.shareCard, shareCardGenerator.stubbedCard)
        XCTAssertFalse(vm.isPreparingShareCard)
    }
}

private enum TestError: Error {
    case stub
}
