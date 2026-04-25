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
    var mockPantryService: MockPantryService!
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
        mockPantryService = MockPantryService()
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
        mockPantryService = nil
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
            pantryService: mockPantryService,
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

    private func makeFilterRecipe(
        title: String,
        time: String?,
        complexity: String?,
        tagline: String? = nil
    ) -> Recipe {
        Recipe(
            title: title,
            ingredients: [Ingredient(name: "tomato")],
            instructions: ["Cook"],
            image: "",
            cleanedIngredients: [Ingredient(name: "tomato")],
            additionalInfo: .init(time: time, servings: nil, complexity: complexity, calories: nil),
            tagline: tagline,
            missingIngredients: []
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

    func testCookTimeQuickFilterIncludesUnderThirtyOnly() {
        let vm = makeViewModel()
        let quick = makeFilterRecipe(title: "Fast Pasta", time: "29 min", complexity: nil)
        let boundary = makeFilterRecipe(title: "Thirty Minute Stew", time: "30 min", complexity: nil)
        let medium = makeFilterRecipe(title: "Weeknight Bake", time: "45 min", complexity: nil)

        vm.searchResultRecipes = [boundary, quick, medium]
        vm.selectedCookTimeFilter = .quick

        XCTAssertEqual(vm.filteredRecipes.map(\.title), [quick.title])
    }

    func testCookTimeMediumFilterIncludesThirtyThroughSixty() {
        let vm = makeViewModel()
        let short = makeFilterRecipe(title: "Short Salad", time: "29 min", complexity: nil)
        let lowerBoundary = makeFilterRecipe(title: "Thirty Minute Soup", time: "30 min", complexity: nil)
        let upperBoundary = makeFilterRecipe(title: "One Hour Roast", time: "60 min", complexity: nil)
        let long = makeFilterRecipe(title: "Slow Braise", time: "61 min", complexity: nil)

        vm.searchResultRecipes = [short, lowerBoundary, upperBoundary, long]
        vm.selectedCookTimeFilter = .medium

        XCTAssertEqual(vm.filteredRecipes.map(\.title), [lowerBoundary.title, upperBoundary.title])
    }

    func testCookTimeLongFilterIncludesOverSixtyOnly() {
        let vm = makeViewModel()
        let boundary = makeFilterRecipe(title: "One Hour Roast", time: "60 min", complexity: nil)
        let long = makeFilterRecipe(title: "Slow Braise", time: "1 hr 15 min", complexity: nil)

        vm.searchResultRecipes = [boundary, long]
        vm.selectedCookTimeFilter = .long

        XCTAssertEqual(vm.filteredRecipes.map(\.title), [long.title])
    }

    func testCookTimeFilterExcludesUnknownTimesOnlyWhenActive() {
        let vm = makeViewModel()
        let unknown = makeFilterRecipe(title: "Mystery Dinner", time: nil, complexity: nil)
        let unparseable = makeFilterRecipe(title: "Eventually Pasta", time: "eventually", complexity: nil)
        let quick = makeFilterRecipe(title: "Fast Pasta", time: "20 min", complexity: nil)

        vm.searchResultRecipes = [unknown, unparseable, quick]
        XCTAssertEqual(Set(vm.filteredRecipes.map(\.title)), Set([unknown.title, unparseable.title, quick.title]))

        vm.selectedCookTimeFilter = .quick

        XCTAssertEqual(vm.filteredRecipes.map(\.title), [quick.title])
    }

    func testComplexityFiltersMatchCaseInsensitively() {
        let vm = makeViewModel()
        let easy = makeFilterRecipe(title: "Simple Bowl", time: nil, complexity: "EASY")
        let medium = makeFilterRecipe(title: "Balanced Curry", time: nil, complexity: "medium")
        let hard = makeFilterRecipe(title: "Project Lasagna", time: nil, complexity: "Hard")

        vm.searchResultRecipes = [easy, medium, hard]

        vm.selectedComplexityFilter = .easy
        XCTAssertEqual(vm.filteredRecipes.map(\.title), [easy.title])

        vm.selectedComplexityFilter = .medium
        XCTAssertEqual(vm.filteredRecipes.map(\.title), [medium.title])

        vm.selectedComplexityFilter = .hard
        XCTAssertEqual(vm.filteredRecipes.map(\.title), [hard.title])
    }

    func testCookTimeAndComplexityCombineWithMoodFiltering() {
        let vm = makeViewModel()
        let neutralQuickEasy = makeFilterRecipe(title: "Tomato Toast", time: "20 min", complexity: "Easy")
        let cozyMediumEasy = makeFilterRecipe(title: "Cozy Tomato Soup", time: "45 min", complexity: "Easy", tagline: "warm comfort bowl")
        let cozyQuickEasy = makeFilterRecipe(title: "Cozy Tomato Melt", time: "20 min", complexity: "Easy", tagline: "warm comfort")

        vm.searchResultRecipes = [neutralQuickEasy, cozyMediumEasy, cozyQuickEasy]
        vm.selectedMood = .cozy
        vm.selectedCookTimeFilter = .quick
        vm.selectedComplexityFilter = .easy

        XCTAssertEqual(vm.filteredRecipes.map(\.title), [cozyQuickEasy.title, neutralQuickEasy.title])
    }

    func testClearIngredientsResets() {
        let vm = makeViewModel()
        vm.selectedIngredients = [Ingredient(name: "Onion")]
        vm.searchResultRecipes = [Recipe.mockRandom()]
        vm.showResults = true
        vm.selectedMood = .cozy
        vm.selectedCookTimeFilter = .quick
        vm.selectedComplexityFilter = .easy

        vm.clearIngredients()

        XCTAssertTrue(vm.selectedIngredients.isEmpty)
        XCTAssertTrue(vm.searchResultRecipes.isEmpty)
        XCTAssertFalse(vm.showResults)
        XCTAssertNil(vm.selectedMood)
        XCTAssertNil(vm.selectedCookTimeFilter)
        XCTAssertNil(vm.selectedComplexityFilter)
    }

    func testLoadInitialDataLoadsPantryItems() async {
        mockPantryService.stubbedItems = [Ingredient(name: "Salt"), Ingredient(name: "Olive Oil")]

        let vm = makeViewModel()
        await vm.loadPantryItems()

        XCTAssertEqual(vm.pantryIngredients.map(\.name), ["Salt", "Olive Oil"])
    }

    func testTogglePantryItemDoesNotChangeSelectedIngredients() async {
        let tomato = Ingredient(name: "Tomato")
        let vm = makeViewModel()
        vm.selectedIngredients = [tomato]

        vm.togglePantryItem(Ingredient(name: "Salt"))
        for _ in 0..<10 { await Task.yield() }

        XCTAssertEqual(vm.selectedIngredients, [tomato])
        XCTAssertEqual(vm.pantryIngredients.map(\.name), ["Salt"])
        XCTAssertEqual(mockPantryService.addCalls.map(\.name), ["Salt"])

        vm.togglePantryItem(Ingredient(name: "salt"))
        for _ in 0..<10 { await Task.yield() }

        XCTAssertEqual(vm.selectedIngredients, [tomato])
        XCTAssertTrue(vm.pantryIngredients.isEmpty)
        XCTAssertEqual(mockPantryService.removeCalls.map(\.name), ["salt"])
    }

    func testRapidPantryToggleReplaysMutationsInTapOrder() async {
        mockPantryService.delayNanoseconds = 20_000_000
        let vm = makeViewModel()
        let salt = Ingredient(name: "Salt")

        vm.togglePantryItem(salt)
        XCTAssertEqual(vm.pantryIngredients.map(\.name), ["Salt"])

        vm.togglePantryItem(salt)
        XCTAssertTrue(vm.pantryIngredients.isEmpty)

        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(mockPantryService.addCalls.map(\.name), ["Salt"])
        XCTAssertEqual(mockPantryService.removeCalls.map(\.name), ["Salt"])
        XCTAssertTrue(mockPantryService.stubbedItems.isEmpty)
        XCTAssertTrue(vm.pantryIngredients.isEmpty)
    }

    func testPantryIngredientNotFoundRollsBackOptimisticStateBeforeReloadCompletes() async {
        mockPantryService.addError = DatabaseError.ingredientNotFound("Dragonfruit")
        mockPantryService.getItemsDelayNanoseconds = 200_000_000
        let vm = makeViewModel()

        vm.togglePantryItem(Ingredient(name: "Dragonfruit"))
        XCTAssertEqual(vm.pantryIngredients.map(\.name), ["Dragonfruit"])

        try? await Task.sleep(nanoseconds: 20_000_000)

        XCTAssertTrue(vm.pantryIngredients.isEmpty)
        XCTAssertEqual(vm.homeLoadError, Strings.Errors.actionFailed)
    }

    func testSearchUsesSelectedAndPantryIngredients() async {
        mockRecipeService.stubbedRecipes = [Recipe.mockRandom()]
        let vm = makeViewModel()
        vm.pantryIngredients = [Ingredient(name: "Salt")]
        vm.selectedIngredients = [Ingredient(name: "Chicken")]

        vm.findRecipes()
        for _ in 0..<10 { await Task.yield() }

        XCTAssertEqual(mockRecipeService.requestedIngredients.map(\.name), ["Chicken", "Salt"])
    }

    func testMissingIngredientsExcludePantryStaples() async {
        let ingredients = ["Chicken", "Salt", "Pepper"].map(Ingredient.init(name:))
        mockRecipeService.stubbedRecipes = [
            Recipe(
                title: "Seasoned Chicken",
                ingredients: ingredients,
                instructions: ["Cook"],
                image: "",
                cleanedIngredients: ingredients,
                additionalInfo: .empty
            )
        ]
        let vm = makeViewModel()
        vm.pantryIngredients = [Ingredient(name: "Salt")]
        vm.selectedIngredients = [Ingredient(name: "Chicken")]

        vm.findRecipes()
        for _ in 0..<10 { await Task.yield() }

        XCTAssertEqual(vm.searchResultRecipes.first?.missingIngredients, ["Pepper"])
    }

    func testClearIngredientsPreservesPantry() async {
        let vm = makeViewModel()
        vm.pantryIngredients = [Ingredient(name: "Salt")]
        vm.selectedIngredients = [Ingredient(name: "Onion")]
        vm.searchResultRecipes = [Recipe.mockRandom()]
        vm.showResults = true

        vm.clearIngredients()

        XCTAssertTrue(vm.selectedIngredients.isEmpty)
        XCTAssertEqual(vm.pantryIngredients.map(\.name), ["Salt"])
        XCTAssertFalse(vm.hasIngredients)
    }

    func testRemovingLastIngredientResetsResultFiltersAndExitsResults() {
        let vm = makeViewModel()
        let ingredient = Ingredient(name: "Onion")
        vm.selectedIngredients = [ingredient]
        vm.searchResultRecipes = [Recipe.mockRandom()]
        vm.showResults = true
        vm.selectedMood = .cozy
        vm.selectedCookTimeFilter = .medium
        vm.selectedComplexityFilter = .hard

        vm.removeIngredient(ingredient)

        XCTAssertTrue(vm.selectedIngredients.isEmpty)
        XCTAssertTrue(vm.searchResultRecipes.isEmpty)
        XCTAssertFalse(vm.showResults)
        XCTAssertNil(vm.selectedMood)
        XCTAssertNil(vm.selectedCookTimeFilter)
        XCTAssertNil(vm.selectedComplexityFilter)
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
