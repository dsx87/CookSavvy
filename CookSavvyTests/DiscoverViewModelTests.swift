import XCTest
@testable import CookSavvy

// MARK: - DiscoverViewModelTests

@MainActor
final class DiscoverViewModelTests: XCTestCase {

    var mockIngredientsService: MockIngredientsService!
    var mockRecipeService: MockRecipeService!
    var mockUserDataService: MockUserDataService!
    var mockSubscriptionService: MockSubscriptionService!
    var mockDBInitService: MockDatabaseInitService!
    var mockCameraScanTracker: MockCameraScanTracker!
    var mockRecommendationService: MockRecommendationService!

    override func setUp() {
        super.setUp()
        mockIngredientsService = MockIngredientsService()
        mockRecipeService = MockRecipeService()
        mockUserDataService = MockUserDataService()
        mockSubscriptionService = MockSubscriptionService(initialPlan: .free)
        mockDBInitService = MockDatabaseInitService()
        mockCameraScanTracker = MockCameraScanTracker()
        mockRecommendationService = MockRecommendationService()
    }

    override func tearDown() {
        mockIngredientsService = nil
        mockRecipeService = nil
        mockUserDataService = nil
        mockSubscriptionService = nil
        mockDBInitService = nil
        mockCameraScanTracker = nil
        mockRecommendationService = nil
        super.tearDown()
    }

    private func makeViewModel() -> DiscoverViewModel {
        DiscoverViewModel(
            ingredientsService: mockIngredientsService,
            recipeService: mockRecipeService,
            userDataService: mockUserDataService,
            subscriptionService: mockSubscriptionService,
            databaseInitService: mockDBInitService,
            cameraScanTracker: mockCameraScanTracker,
            recommendationService: mockRecommendationService,
            coordinator: nil
        )
    }

    func testToggleIngredient() {
        let vm = makeViewModel()
        let ingredient = Ingredient(name: "Tomato")

        vm.toggleIngredient(ingredient)
        XCTAssertTrue(vm.selectedIngredients.contains { $0.id == ingredient.id })

        vm.toggleIngredient(ingredient)
        XCTAssertFalse(vm.selectedIngredients.contains { $0.id == ingredient.id })
    }

    func testFindRecipesPopulatesResults() async {
        let recipe = Recipe.mockRandom()
        mockRecipeService.stubbedRecipes = [recipe]

        let vm = makeViewModel()
        vm.selectedIngredients = [Ingredient(name: "Chicken")]
        vm.findRecipes()

        // Yield to let the spawned Task complete on the MainActor
        for _ in 0..<10 { await Task.yield() }

        XCTAssertFalse(vm.searchResultRecipes.isEmpty)
        XCTAssertTrue(vm.showResults)
        XCTAssertEqual(vm.searchResultRecipes.first?.title, recipe.title)
    }

    func testMoodFilterRanking() {
        let vm = makeViewModel()
        let soupRecipe = Recipe(
            title: "Warm Chicken Soup",
            ingredients: [],
            instructions: [Recipe.Step](),
            image: "",
            cleanedIngredients: [],
            additionalInfo: .empty,
            tagline: "cozy warm comfort"
        )
        let saladRecipe = Recipe(
            title: "Fresh Avocado Salad",
            ingredients: [],
            instructions: [Recipe.Step](),
            image: "",
            cleanedIngredients: [],
            additionalInfo: .empty
        )
        vm.searchResultRecipes = [saladRecipe, soupRecipe]
        vm.selectedMood = .cozy

        XCTAssertEqual(vm.filteredRecipes.first?.title, "Warm Chicken Soup")
    }

    func testClearIngredientsResets() {
        let vm = makeViewModel()
        vm.selectedIngredients = [Ingredient(name: "Onion")]
        vm.searchResultRecipes = [Recipe.mockRandom()]
        vm.showResults = true

        vm.clearIngredients()

        XCTAssertTrue(vm.selectedIngredients.isEmpty)
        XCTAssertTrue(vm.searchResultRecipes.isEmpty)
        XCTAssertFalse(vm.showResults)
        XCTAssertNil(vm.selectedMood)
    }

    func testShowCameraFreeUserWithScans() {
        mockCameraScanTracker.stubbedCanScan = true
        mockSubscriptionService.setPlan(.free)

        let vm = makeViewModel()
        vm.showCamera()

        // Camera should be opened (scan recorded)
        XCTAssertEqual(mockCameraScanTracker.recordScanCallCount, 1)
    }

    func testShowCameraFreeUserNoScans() {
        mockCameraScanTracker.stubbedCanScan = false
        mockSubscriptionService.setPlan(.free)

        let vm = makeViewModel()
        vm.showCamera()

        // No scan recorded when limit is reached
        XCTAssertEqual(mockCameraScanTracker.recordScanCallCount, 0)
    }
}

// MARK: - RecipeSourceTypeTests

final class RecipeSourceTypeTests: XCTestCase {

    func testAccessibleRemovesPremiumSourcesWithoutAccess() {
        let result = RecipeSourceType.accessible(
            from: [.offline, .online, .ai],
            canAccessOnline: false,
            canAccessAI: false
        )

        XCTAssertEqual(result, [.offline])
    }

    func testAccessibleKeepsGrantedPremiumSources() {
        let result = RecipeSourceType.accessible(
            from: [.offline, .online, .ai],
            canAccessOnline: true,
            canAccessAI: false
        )

        XCTAssertEqual(result, [.offline, .online])
    }

    func testRequiresDatabaseReadyOnlyForOfflineOnly() {
        XCTAssertTrue(RecipeSourceType.requiresDatabaseReady([.offline]))
        XCTAssertFalse(RecipeSourceType.requiresDatabaseReady([.offline, .online]))
        XCTAssertFalse(RecipeSourceType.requiresDatabaseReady([.online]))
    }
}
