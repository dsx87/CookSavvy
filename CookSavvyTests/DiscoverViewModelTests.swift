import XCTest
@testable import CookSavvy

// MARK: - DiscoverViewModelTests

final class DiscoverViewModelTests: XCTestCase {

    var mockIngredientsService: MockIngredientsService!
    var mockRecipeService: MockRecipeService!
    var mockUserDataService: MockUserDataService!
    var mockSubscriptionService: MockSubscriptionService!
    var mockDBInitService: MockDatabaseInitService!
    var mockCameraScanTracker: MockCameraScanTracker!
    var mockPantryService: MockPantryService!

    @MainActor
    override func setUp() async throws {
        mockIngredientsService = MockIngredientsService()
        mockRecipeService = MockRecipeService()
        mockUserDataService = MockUserDataService()
        mockSubscriptionService = MockSubscriptionService(initialPlan: .free)
        mockDBInitService = MockDatabaseInitService()
        mockCameraScanTracker = MockCameraScanTracker()
        mockPantryService = MockPantryService()
    }

    @MainActor
    override func tearDown() async throws {
        mockIngredientsService = nil
        mockRecipeService = nil
        mockUserDataService = nil
        mockSubscriptionService = nil
        mockDBInitService = nil
        mockCameraScanTracker = nil
        mockPantryService = nil
    }

    @MainActor
    private func makeViewModel() -> DiscoverViewModel {
        DiscoverViewModel(
            ingredientsService: mockIngredientsService,
            recipeService: mockRecipeService,
            userDataService: mockUserDataService,
            subscriptionService: mockSubscriptionService,
            databaseInitService: mockDBInitService,
            cameraScanTracker: mockCameraScanTracker,
            pantryService: mockPantryService,
            analyticsService: MockAnalyticsService(),
            logger: MockLogger(),
            dietaryPreferences: DietaryPreferences(defaults: UserDefaults()),
            coordinator: nil
        )
    }

    /// Spins the main-actor run loop until `condition` holds or the timeout elapses, so fire-and-forget
    /// work scheduled in an unstructured `Task` (e.g. usage recording) can be asserted deterministically.
    @MainActor
    private func waitUntil(timeout: TimeInterval = 1.0, _ condition: () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            await Task.yield()
        }
    }

    @MainActor
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
            additionalInfo: .empty,
            tagline: tagline,
            missingIngredients: missingIngredients
        )
    }

    @MainActor
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
            additionalInfo: .init(time: time, servings: nil, complexity: complexity, calories: nil),
            tagline: tagline,
            missingIngredients: []
        )
    }

    @MainActor
    func testToggleIngredient() async {
        let vm = makeViewModel()
        let ingredient = Ingredient(name: "Tomato")

        vm.toggleIngredient(ingredient)
        XCTAssertTrue(vm.selectedIngredients.contains { $0.id == ingredient.id })

        vm.toggleIngredient(ingredient)
        XCTAssertFalse(vm.selectedIngredients.contains { $0.id == ingredient.id })
    }

    @MainActor
    func testToggleIngredientPromotesSelectionToFrontOfPopularGridAndCaps() async {
        let vm = makeViewModel()
        let count = UI.Discover.popularIngredientCount
        // Seed a full grid so a new pick must drop the least-recent tail item.
        vm.popularIngredients = (0..<count).map { Ingredient(name: "Seed\($0)") }
        vm.shownIngredients = vm.popularIngredients

        vm.toggleIngredient(Ingredient(name: "Tomato"))

        XCTAssertEqual(vm.popularIngredients.first?.name, "Tomato", "Pick leads the popular grid")
        XCTAssertEqual(vm.popularIngredients.count, count, "List stays capped at the grid size")
        XCTAssertFalse(
            vm.popularIngredients.contains { $0.name == "Seed\(count - 1)" },
            "Least-recent tail item is dropped when a new pick is inserted"
        )
        // Default popular state (no search, no category) → the visible grid reorders live.
        XCTAssertEqual(vm.shownIngredients.first?.name, "Tomato")
    }

    @MainActor
    func testTogglingAnExistingPopularIngredientPromotesWithoutDuplicating() async {
        let vm = makeViewModel()
        vm.popularIngredients = [Ingredient(name: "Rice"), Ingredient(name: "Egg"), Ingredient(name: "Onion")]
        vm.shownIngredients = vm.popularIngredients

        // Case-insensitive re-pick of an item already in the grid.
        vm.toggleIngredient(Ingredient(name: "onion"))

        XCTAssertEqual(vm.popularIngredients.first?.name, "onion", "Re-pick is promoted to the front")
        XCTAssertEqual(vm.popularIngredients.count, 3, "Promotion reorders in place — no duplicate")
        XCTAssertEqual(
            vm.popularIngredients.filter { $0.name.lowercased() == "onion" }.count, 1,
            "Only one onion entry remains after promotion"
        )
    }

    @MainActor
    func testSelectingRecordsIngredientUsageAndDeselectingDoesNot() async {
        let vm = makeViewModel()
        let ingredient = Ingredient(name: "Tomato")

        vm.toggleIngredient(ingredient) // select
        // Recording is fire-and-forget in a detached Task; wait until it lands.
        await waitUntil { self.mockUserDataService.recordedIngredientUsages.count == 1 }
        XCTAssertEqual(mockUserDataService.recordedIngredientUsages.count, 1)
        XCTAssertEqual(mockUserDataService.recordedIngredientUsages.first?.first?.name, "Tomato")

        vm.toggleIngredient(ingredient) // deselect
        // Let any erroneous record task run, then confirm no additional usage was recorded.
        await Task.yield()
        XCTAssertEqual(
            mockUserDataService.recordedIngredientUsages.count, 1,
            "Deselecting an ingredient must not record usage"
        )
    }

    @MainActor
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

    /// A slower earlier search must not overwrite the results of a newer search that finished first.
    /// Drives two overlapping searches via the gated mock and resumes the newer one before the older.
    @MainActor
    func testStaleSearchDoesNotOverwriteNewerResults() async {
        let older = Recipe(title: "OlderSearchResult", ingredients: [Ingredient(name: "Chicken")],
                           instructions: ["Cook"], image: "", additionalInfo: .empty)
        let newer = Recipe(title: "NewerSearchResult", ingredients: [Ingredient(name: "Chicken")],
                           instructions: ["Cook"], image: "", additionalInfo: .empty)
        mockRecipeService.gateGetRecipes = true
        mockRecipeService.perCallStubbedRecipes = [[older], [newer]]

        let vm = makeViewModel()
        vm.selectedIngredients = [Ingredient(name: "Chicken")]
        vm.showResults = true

        // Launch search A (older); let it reach the gate so its token (1) is taken first.
        vm.findRecipes()
        await yield(until: { self.mockRecipeService.getRecipesCallCount >= 1 })

        // Launch search B (newer); let it reach the gate with the live token (2).
        vm.findRecipes()
        await yield(until: { self.mockRecipeService.getRecipesCallCount >= 2 })

        // Resume the newer search first — it should write its result.
        mockRecipeService.resumeGetRecipes(at: 1)
        await yield(until: { vm.searchResultRecipes.first?.title == newer.title })

        // Resume the stale older search — its token no longer matches, so it must be discarded.
        mockRecipeService.resumeGetRecipes(at: 0)
        for _ in 0..<30 { await Task.yield() }

        XCTAssertEqual(vm.searchResultRecipes.map(\.title), [newer.title],
                       "Stale search overwrote the newer search's results")
    }

    /// Yields the main actor until `condition` holds or a bounded iteration cap is hit (prevents hangs).
    @MainActor
    private func yield(until condition: () -> Bool, max iterations: Int = 200) async {
        var count = 0
        while !condition() && count < iterations {
            await Task.yield()
            count += 1
        }
    }

    @MainActor
    func testMoodFilterRanking() async {
        let vm = makeViewModel()
        let soupRecipe = Recipe(
            title: "Warm Chicken Soup",
            ingredients: [],
            instructions: [Recipe.Step](),
            image: "",
            additionalInfo: .empty,
            tagline: "cozy warm comfort"
        )
        let saladRecipe = Recipe(
            title: "Fresh Avocado Salad",
            ingredients: [],
            instructions: [Recipe.Step](),
            image: "",
            additionalInfo: .empty
        )
        vm.searchResultRecipes = [saladRecipe, soupRecipe]
        vm.selectedMood = .cozy

        XCTAssertEqual(vm.filteredRecipes.first?.title, "Warm Chicken Soup")
    }

    @MainActor
    func testDefaultSortingPrefersCoverageOverMissingCountAlone() async {
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

    @MainActor
    func testHasNoResultsWhenSearchCompletesEmpty() async {
        let vm = makeViewModel()
        vm.searchResultRecipes = []
        vm.showResults = true
        XCTAssertTrue(vm.hasNoResults)
    }

    @MainActor
    func testHasNoResultsIsFalseWhileSearching() async {
        let vm = makeViewModel()
        vm.searchResultRecipes = []
        vm.showResults = true
        vm.isSearching = true
        XCTAssertFalse(vm.hasNoResults)
    }

    @MainActor
    func testHasNoResultsIsFalseWhenResultsExist() async {
        let vm = makeViewModel()
        vm.searchResultRecipes = [Recipe.mockRandom()]
        vm.showResults = true
        XCTAssertFalse(vm.hasNoResults)
    }

    @MainActor
    func testDefaultSortingPutsNilMissingIngredientsLast() async {
        let vm = makeViewModel()
        var knownMissing = Recipe.mockRandom()
        knownMissing.missingIngredients = ["Salt"]
        var unknownMissing = Recipe.mockRandom()
        unknownMissing.missingIngredients = nil

        vm.searchResultRecipes = [unknownMissing, knownMissing]

        XCTAssertNotNil(vm.filteredRecipes.first?.missingIngredients)
        XCTAssertNil(vm.filteredRecipes.last?.missingIngredients)
    }

    @MainActor
    func testMoodScoreRefinesEqualQualityMatchesWithoutOverridingCoverage() async {
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

    @MainActor
    func testCookTimeQuickFilterIncludesUnderThirtyOnly() async {
        let vm = makeViewModel()
        let quick = makeFilterRecipe(title: "Fast Pasta", time: "29 min", complexity: nil)
        let boundary = makeFilterRecipe(title: "Thirty Minute Stew", time: "30 min", complexity: nil)
        let medium = makeFilterRecipe(title: "Weeknight Bake", time: "45 min", complexity: nil)

        vm.searchResultRecipes = [boundary, quick, medium]
        vm.selectedCookTimeFilter = .quick

        XCTAssertEqual(vm.filteredRecipes.map(\.title), [quick.title])
    }

    @MainActor
    func testCookTimeMediumFilterIncludesThirtyThroughSixty() async {
        let vm = makeViewModel()
        let short = makeFilterRecipe(title: "Short Salad", time: "29 min", complexity: nil)
        let lowerBoundary = makeFilterRecipe(title: "Thirty Minute Soup", time: "30 min", complexity: nil)
        let upperBoundary = makeFilterRecipe(title: "One Hour Roast", time: "60 min", complexity: nil)
        let long = makeFilterRecipe(title: "Slow Braise", time: "61 min", complexity: nil)

        vm.searchResultRecipes = [short, lowerBoundary, upperBoundary, long]
        vm.selectedCookTimeFilter = .medium

        XCTAssertEqual(vm.filteredRecipes.map(\.title), [lowerBoundary.title, upperBoundary.title])
    }

    @MainActor
    func testCookTimeLongFilterIncludesOverSixtyOnly() async {
        let vm = makeViewModel()
        let boundary = makeFilterRecipe(title: "One Hour Roast", time: "60 min", complexity: nil)
        let long = makeFilterRecipe(title: "Slow Braise", time: "1 hr 15 min", complexity: nil)

        vm.searchResultRecipes = [boundary, long]
        vm.selectedCookTimeFilter = .long

        XCTAssertEqual(vm.filteredRecipes.map(\.title), [long.title])
    }

    @MainActor
    func testCookTimeFilterExcludesUnknownTimesOnlyWhenActive() async {
        let vm = makeViewModel()
        let unknown = makeFilterRecipe(title: "Mystery Dinner", time: nil, complexity: nil)
        let unparseable = makeFilterRecipe(title: "Eventually Pasta", time: "eventually", complexity: nil)
        let quick = makeFilterRecipe(title: "Fast Pasta", time: "20 min", complexity: nil)

        vm.searchResultRecipes = [unknown, unparseable, quick]
        XCTAssertEqual(Set(vm.filteredRecipes.map(\.title)), Set([unknown.title, unparseable.title, quick.title]))

        vm.selectedCookTimeFilter = .quick

        XCTAssertEqual(vm.filteredRecipes.map(\.title), [quick.title])
    }

    @MainActor
    func testComplexityFiltersMatchCaseInsensitively() async {
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

    @MainActor
    func testCookTimeAndComplexityCombineWithMoodFiltering() async {
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

    @MainActor
    func testClearIngredientsResets() async {
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

    @MainActor
    func testLoadInitialDataLoadsPantryItems() async {
        mockPantryService.stubbedItems = [Ingredient(name: "Salt"), Ingredient(name: "Olive Oil")]

        let vm = makeViewModel()
        await vm.loadPantryItems()

        XCTAssertEqual(vm.pantryIngredients.map(\.name), ["Salt", "Olive Oil"])
    }

    @MainActor
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

    @MainActor
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

    @MainActor
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

    @MainActor
    func testSearchUsesSelectedAndPantryIngredients() async {
        mockRecipeService.stubbedRecipes = [Recipe.mockRandom()]
        let vm = makeViewModel()
        vm.pantryIngredients = [Ingredient(name: "Salt")]
        vm.selectedIngredients = [Ingredient(name: "Chicken")]

        vm.findRecipes()
        for _ in 0..<10 { await Task.yield() }

        XCTAssertEqual(mockRecipeService.requestedIngredients.map(\.name), ["Chicken", "Salt"])
    }

    @MainActor
    func testMissingIngredientsExcludePantryStaples() async {
        let ingredients = ["Chicken", "Salt", "Pepper"].map(Ingredient.init(name:))
        mockRecipeService.stubbedRecipes = [
            Recipe(
                title: "Seasoned Chicken",
                ingredients: ingredients,
                instructions: ["Cook"],
                image: "",
                additionalInfo: .empty
            )
        ]
        let vm = makeViewModel()
        vm.pantryIngredients = [Ingredient(name: "Salt")]
        vm.selectedIngredients = [Ingredient(name: "Chicken")]

        vm.findRecipes()
        for _ in 0..<10 { await Task.yield() }

        XCTAssertEqual(vm.searchResultRecipes.first?.missingIngredients, [])
        XCTAssertEqual(vm.searchResultRecipes.first?.assumedPantryIngredients, ["Pepper"])
    }

    @MainActor
    func testIngredientBreakdownSeparatesAssumedStaplesFromTrueMissingIngredients() async {
        let ingredients = ["Chicken", "Salt", "Oil", "Pepper", "Water", "Rice", "Bell Pepper"]
            .map(Ingredient.init(name:))
        let recipe = Recipe(
            title: "Pantry Plus Chicken",
            ingredients: ingredients,
            instructions: ["Cook"],
            image: "",
            additionalInfo: .empty
        )

        let breakdown = RecipeMatchExplainer.ingredientBreakdown(
            recipe: recipe,
            selectedIngredients: [Ingredient(name: "Chicken")]
        )

        XCTAssertEqual(breakdown.availableIngredientNames, ["Chicken"])
        XCTAssertEqual(breakdown.assumedPantryIngredientNames, ["Salt", "Oil", "Pepper", "Water"])
        XCTAssertEqual(breakdown.missingIngredientNames, ["Rice", "Bell Pepper"])
    }

    @MainActor
    func testAssumedStaplesImproveRankingOverTrueMissingIngredients() async {
        let assumedOnlyIngredients = ["Chicken", "Salt", "Oil"].map(Ingredient.init(name:))
        let trueMissingIngredients = ["Chicken", "Rice"].map(Ingredient.init(name:))
        mockRecipeService.stubbedRecipes = [
            Recipe(
                title: "Chicken Rice",
                ingredients: trueMissingIngredients,
                instructions: ["Cook"],
                image: "",
                additionalInfo: .empty
            ),
            Recipe(
                title: "Seasoned Chicken",
                ingredients: assumedOnlyIngredients,
                instructions: ["Cook"],
                image: "",
                additionalInfo: .empty
            )
        ]
        let vm = makeViewModel()
        vm.selectedIngredients = [Ingredient(name: "Chicken")]

        vm.findRecipes()
        for _ in 0..<10 { await Task.yield() }

        XCTAssertEqual(vm.searchResultRecipes.first { $0.title == "Seasoned Chicken" }?.missingIngredients, [])
        XCTAssertEqual(
            vm.searchResultRecipes.first { $0.title == "Seasoned Chicken" }?.assumedPantryIngredients,
            ["Salt", "Oil"]
        )
        XCTAssertEqual(vm.filteredRecipes.first?.title, "Seasoned Chicken")
    }

    @MainActor
    func testSearchKeepsSavedPantryItemsAvailableAndAssumesBuiltInStaples() async {
        let ingredients = ["Chicken", "Salt", "Oil", "Rice"].map(Ingredient.init(name:))
        mockRecipeService.stubbedRecipes = [
            Recipe(
                title: "Chicken Rice",
                ingredients: ingredients,
                instructions: ["Cook"],
                image: "",
                additionalInfo: .empty
            )
        ]
        let vm = makeViewModel()
        vm.pantryIngredients = [Ingredient(name: "Salt")]
        vm.selectedIngredients = [Ingredient(name: "Chicken")]

        vm.findRecipes()
        for _ in 0..<10 { await Task.yield() }

        XCTAssertEqual(vm.searchResultRecipes.first?.missingIngredients, ["Rice"])
        XCTAssertEqual(vm.searchResultRecipes.first?.assumedPantryIngredients, ["Oil"])
    }

    @MainActor
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

    @MainActor
    func testRemovingLastIngredientResetsResultFiltersAndExitsResults() async {
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

    @MainActor
    func testShowCameraFreeUserWithScans() async {
        mockCameraScanTracker.stubbedCanScan = true
        mockSubscriptionService.setPlan(.free)

        let vm = makeViewModel()
        vm.showCamera()

        // Camera should be opened (scan recorded)
        XCTAssertEqual(mockCameraScanTracker.recordScanCallCount, 1)
    }

    @MainActor
    func testShowCameraFreeUserNoScans() async {
        mockCameraScanTracker.stubbedCanScan = false
        mockSubscriptionService.setPlan(.free)

        let vm = makeViewModel()
        vm.showCamera()

        // No scan recorded when limit is reached
        XCTAssertEqual(mockCameraScanTracker.recordScanCallCount, 0)
    }

    @MainActor
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

    @MainActor
    func testLoadInitialDataSetsHomeLoadErrorWhenHomeDataFails() async {
        mockUserDataService.shouldThrow = TestError.stub

        let vm = makeViewModel()
        await vm.loadInitialData()

        XCTAssertEqual(vm.homeLoadError, Strings.Errors.loadFailed)
    }

    /// Typing a query while a category chip is selected must search the FULL catalogue, not just the
    /// category subset — otherwise an ingredient outside the category (e.g. garlic while "Grains" is
    /// selected) would never surface in the suggestions popup.
    @MainActor
    func testSearchWithCategorySelectedQueriesFullCatalogue() async {
        mockIngredientsService.stubbedAllIngredients = [Ingredient(name: "Rice"), Ingredient(name: "Oats")]
        mockIngredientsService.stubbedFullSearchResults = [Ingredient(name: "Garlic")]

        let vm = makeViewModel()
        vm.selectedCategory = .grains
        vm.searchText = "garlic"

        await yield(until: { vm.ingredientSuggestions.contains { $0.name == "Garlic" } })

        XCTAssertTrue(vm.ingredientSuggestions.contains { $0.name == "Garlic" },
                      "Search should query the full catalogue, ignoring the selected category")
        XCTAssertTrue(vm.isSearchBypassingCategory)
    }

    @MainActor
    func testIsSearchBypassingCategory() async {
        let vm = makeViewModel()
        XCTAssertFalse(vm.isSearchBypassingCategory)

        vm.selectedCategory = .grains
        XCTAssertFalse(vm.isSearchBypassingCategory, "A category alone (empty search box) is not a bypass")

        vm.searchText = "garlic"
        XCTAssertTrue(vm.isSearchBypassingCategory)

        vm.selectedCategory = nil
        XCTAssertFalse(vm.isSearchBypassingCategory)
    }

    @MainActor
    func testClearSelectedCategoryNilsCategory() async {
        let vm = makeViewModel()
        vm.selectedCategory = .grains

        vm.clearSelectedCategory()

        XCTAssertNil(vm.selectedCategory)
    }
}

// MARK: - RecipeSourceTypeTests

final class RecipeSourceTypeTests: XCTestCase {

    @MainActor
    func testAccessibleRemovesPremiumSourcesWithoutAccess() async {
        let result = RecipeSourceType.accessible(
            from: [.offline, .online, .ai],
            canAccessOnline: false,
            canAccessAI: false
        )

        XCTAssertEqual(result, [.offline])
    }

    @MainActor
    func testAccessibleKeepsGrantedPremiumSources() async {
        let result = RecipeSourceType.accessible(
            from: [.offline, .online, .ai],
            canAccessOnline: true,
            canAccessAI: false
        )

        XCTAssertEqual(result, [.offline, .online])
    }

    @MainActor
    func testRequiresDatabaseReadyOnlyForOfflineOnly() async {
        XCTAssertTrue(RecipeSourceType.requiresDatabaseReady([.offline]))
        XCTAssertFalse(RecipeSourceType.requiresDatabaseReady([.offline, .online]))
        XCTAssertFalse(RecipeSourceType.requiresDatabaseReady([.online]))
    }
}

private enum TestError: Error {
    case stub
}
