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
    var mockCuratedCollectionService: MockCuratedCollectionService!

    override func setUp() {
        super.setUp()
        mockIngredientsService = MockIngredientsService()
        mockRecipeService = MockRecipeService()
        mockUserDataService = MockUserDataService()
        mockSubscriptionService = MockSubscriptionService(initialPlan: .free)
        mockDBInitService = MockDatabaseInitService()
        mockCameraScanTracker = MockCameraScanTracker()
        mockRecommendationService = MockRecommendationService()
        mockCuratedCollectionService = MockCuratedCollectionService()
    }

    override func tearDown() {
        mockIngredientsService = nil
        mockRecipeService = nil
        mockUserDataService = nil
        mockSubscriptionService = nil
        mockDBInitService = nil
        mockCameraScanTracker = nil
        mockRecommendationService = nil
        mockCuratedCollectionService = nil
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
            analyticsService: MockAnalyticsService(),
            logger: MockLogger(),
            dietaryPreferences: DietaryPreferences(defaults: UserDefaults()),
            curatedCollectionService: mockCuratedCollectionService,
            coordinator: nil
        )
    }

    private func makeRankedRecipe(
        title: String,
        ingredientNames: [String],
        missingIngredients: [String],
        tagline: String? = nil
    ) -> Recipe {
        let ingredients = ingredientNames.map(Ingredient.init(name:))
        return Recipe(
            title: title,
            ingredients: ingredients,
            instructions: ["Cook"],
            image: "",
            cleanedIngredients: ingredients,
            additionalInfo: .empty,
            tagline: tagline,
            missingIngredients: missingIngredients
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

    func testDefaultSortingPrefersCoverageOverMissingCountAlone() {
        let vm = makeViewModel()
        let betterCoverage = makeRankedRecipe(
            title: "Better Coverage",
            ingredientNames: ["chicken", "rice", "lemon"],
            missingIngredients: []
        )
        let worseCoverageButOneMissing = makeRankedRecipe(
            title: "One Missing",
            ingredientNames: ["chicken", "rice", "lemon", "herbs"],
            missingIngredients: ["herbs"]
        )

        vm.searchResultRecipes = [worseCoverageButOneMissing, betterCoverage]

        XCTAssertEqual(vm.filteredRecipes.first?.title, betterCoverage.title)
    }

    func testHasNoResultsWhenSearchCompletesEmpty() {
        let vm = makeViewModel()
        vm.searchResultRecipes = []
        vm.showResults = true
        XCTAssertTrue(vm.hasNoResults)
    }

    func testHasNoResultsIsFalseWhileSearching() {
        let vm = makeViewModel()
        vm.searchResultRecipes = []
        vm.showResults = true
        vm.isSearching = true
        XCTAssertFalse(vm.hasNoResults)
    }

    func testHasNoResultsIsFalseWhenResultsExist() {
        let vm = makeViewModel()
        vm.searchResultRecipes = [Recipe.mockRandom()]
        vm.showResults = true
        XCTAssertFalse(vm.hasNoResults)
    }

    func testDefaultSortingPutsNilMissingIngredientsLast() {
        let vm = makeViewModel()
        var knownMissing = Recipe.mockRandom()
        knownMissing.missingIngredients = ["Salt"]
        var unknownMissing = Recipe.mockRandom()
        unknownMissing.missingIngredients = nil

        vm.searchResultRecipes = [unknownMissing, knownMissing]

        XCTAssertNotNil(vm.filteredRecipes.first?.missingIngredients)
        XCTAssertNil(vm.filteredRecipes.last?.missingIngredients)
    }

    func testMoodScoreRefinesEqualQualityMatchesWithoutOverridingCoverage() {
        let vm = makeViewModel()
        let betterCoverage = makeRankedRecipe(
            title: "Better Coverage",
            ingredientNames: ["tomato", "basil", "mozzarella"],
            missingIngredients: []
        )
        let cozyTieBreaker = makeRankedRecipe(
            title: "Cozy Soup",
            ingredientNames: ["tomato", "basil", "mozzarella", "broth"],
            missingIngredients: ["broth"],
            tagline: "warm comfort bowl"
        )
        let neutralTie = makeRankedRecipe(
            title: "Neutral Pasta",
            ingredientNames: ["tomato", "basil", "mozzarella", "cream"],
            missingIngredients: ["cream"]
        )

        vm.searchResultRecipes = [neutralTie, cozyTieBreaker, betterCoverage]
        vm.selectedMood = .cozy

        XCTAssertEqual(vm.filteredRecipes.map(\.title), [betterCoverage.title, cozyTieBreaker.title, neutralTie.title])
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

    func testPreloadIngredientsShowsResultsAndSearches() async {
        let recipe = Recipe.mockRandom()
        mockRecipeService.stubbedRecipes = [recipe]
        let vm = makeViewModel()

        vm.preloadIngredients([Ingredient(name: "Tomato"), Ingredient(name: "Basil")])

        for _ in 0..<10 { await Task.yield() }

        XCTAssertEqual(vm.selectedIngredients.map(\.name), ["Tomato", "Basil"])
        XCTAssertTrue(vm.showResults)
        XCTAssertEqual(mockRecipeService.getRecipesCallCount, 1)
    }

    func testLoadInitialDataSetsHomeLoadErrorWhenHomeDataFails() async {
        mockUserDataService.shouldThrow = TestError.stub

        let vm = makeViewModel()
        await vm.loadInitialData()

        XCTAssertEqual(vm.homeLoadError, Strings.Errors.loadFailed)
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

private enum TestError: Error {
    case stub
}
