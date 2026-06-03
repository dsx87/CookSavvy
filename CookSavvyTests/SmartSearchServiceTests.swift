import XCTest
@testable import CookSavvy

// MARK: - SmartSearchServiceTests

final class SmartSearchServiceTests: XCTestCase {

    func testParse_delegatesToProvider() async throws {
        let expected = SmartSearchIntent(
            ingredientNames: ["tomato", "chicken"],
            mood: .quick,
            cookTime: .quick,
            complexity: .easy,
            dietary: [.glutenFree]
        )
        let mock = MockSmartSearchProvider(result: .success(expected))
        let service = SmartSearchService(provider: mock)

        let result = try await service.parse(query: "quick easy meal with tomato and chicken, gluten free")

        XCTAssertEqual(result.ingredientNames, ["tomato", "chicken"])
        XCTAssertEqual(result.mood, .quick)
        XCTAssertEqual(result.cookTime, .quick)
        XCTAssertEqual(result.complexity, .easy)
        XCTAssertEqual(result.dietary, [.glutenFree])
    }

    func testParse_propagatesProviderError() async {
        let mock = MockSmartSearchProvider(result: .failure(SmartSearchError.parsingFailed(nil)))
        let service = SmartSearchService(provider: mock)

        do {
            _ = try await service.parse(query: "anything")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is SmartSearchError)
        }
    }

    func testParse_emptyIntentWhenProviderReturnsNoData() async throws {
        let empty = SmartSearchIntent(ingredientNames: [], mood: nil, cookTime: nil, complexity: nil, dietary: [])
        let mock = MockSmartSearchProvider(result: .success(empty))
        let service = SmartSearchService(provider: mock)

        let result = try await service.parse(query: "something")

        XCTAssertTrue(result.ingredientNames.isEmpty)
        XCTAssertNil(result.mood)
        XCTAssertNil(result.cookTime)
        XCTAssertNil(result.complexity)
        XCTAssertTrue(result.dietary.isEmpty)
    }
}

// MARK: - DiscoverViewModel + runSmartSearch Tests

@MainActor
final class DiscoverViewModelSmartSearchTests: XCTestCase {

    var mockIngredients: MockIngredientsService!
    var mockRecipeService: MockRecipeService!
    var mockUserDataService: MockUserDataService!
    var mockDBInit: MockDatabaseInitService!
    var mockSmartSearch: MockSmartSearchProvider!

    override func setUp() {
        super.setUp()
        mockIngredients = MockIngredientsService()
        mockRecipeService = MockRecipeService()
        mockUserDataService = MockUserDataService()
        mockDBInit = MockDatabaseInitService()
        mockSmartSearch = MockSmartSearchProvider(result: .success(
            SmartSearchIntent(ingredientNames: ["tomato"], mood: .quick, cookTime: .quick, complexity: .easy, dietary: [])
        ))
    }

    override func tearDown() {
        mockIngredients = nil
        mockRecipeService = nil
        mockUserDataService = nil
        mockDBInit = nil
        mockSmartSearch = nil
        super.tearDown()
    }

    private func makeViewModel(includeSmartSearch: Bool = true) -> DiscoverViewModel {
        let service: SmartSearchServiceProtocol? = includeSmartSearch
            ? SmartSearchService(provider: mockSmartSearch)
            : nil
        return DiscoverViewModel(
            ingredientsService: mockIngredients,
            recipeService: mockRecipeService,
            userDataService: mockUserDataService,
            subscriptionService: MockSubscriptionService(initialPlan: .free),
            databaseInitService: mockDBInit,
            cameraScanTracker: MockCameraScanTracker(),
            pantryService: MockPantryService(),
            recommendationService: MockRecommendationService(),
            analyticsService: MockAnalyticsService(),
            logger: MockLogger(),
            dietaryPreferences: DietaryPreferences(defaults: UserDefaults()),
            curatedCollectionService: MockCuratedCollectionService(),
            smartSearchService: service
        )
    }

    func testHasSmartSearch_trueWhenServiceProvided() {
        let vm = makeViewModel(includeSmartSearch: true)
        XCTAssertTrue(vm.hasSmartSearch)
    }

    func testHasSmartSearch_falseWhenServiceIsNil() {
        let vm = makeViewModel(includeSmartSearch: false)
        XCTAssertFalse(vm.hasSmartSearch)
    }

    func testRunSmartSearch_setsIngredientsFromResolvedNames() async {
        let tomato = Ingredient(name: "Tomato", description: nil, pictureFileName: nil, foodGroup: nil, foodSubgroup: nil, emoji: "🍅")
        mockIngredients.stubbedFullSearchResults = [tomato]
        mockSmartSearch = MockSmartSearchProvider(result: .success(
            SmartSearchIntent(ingredientNames: ["tomato"], mood: nil, cookTime: nil, complexity: nil, dietary: [])
        ))
        let vm = makeViewModel(includeSmartSearch: true)
        await vm.runSmartSearch("tomato recipes")

        XCTAssertEqual(vm.selectedIngredients.first?.name, "Tomato")
        XCTAssertTrue(vm.showResults)
    }

    func testRunSmartSearch_appliesFiltersFromIntent() async {
        let tomato = Ingredient(name: "Tomato", description: nil, pictureFileName: nil, foodGroup: nil, foodSubgroup: nil, emoji: "🍅")
        mockIngredients.stubbedFullSearchResults = [tomato]
        mockSmartSearch = MockSmartSearchProvider(result: .success(
            SmartSearchIntent(ingredientNames: ["tomato"], mood: .cozy, cookTime: .quick, complexity: .easy, dietary: [.vegetarian])
        ))
        let vm = makeViewModel(includeSmartSearch: true)
        await vm.runSmartSearch("cozy quick vegetarian tomato dish")

        XCTAssertEqual(vm.selectedMood, .cozy)
        XCTAssertEqual(vm.selectedCookTimeFilter, .quick)
        XCTAssertEqual(vm.selectedComplexityFilter, .easy)
        XCTAssertTrue(vm.activeDietaryRestrictions.contains(.vegetarian))
    }

    func testRunSmartSearch_browsesFallbackWhenNoIngredientsResolved() async {
        mockIngredients.stubbedFullSearchResults = []
        mockRecipeService.stubbedAllRecipes = [Recipe()]
        mockSmartSearch = MockSmartSearchProvider(result: .success(
            SmartSearchIntent(ingredientNames: ["unknownxyz123"], mood: nil, cookTime: nil, complexity: nil, dietary: [])
        ))
        let vm = makeViewModel(includeSmartSearch: true)
        await vm.runSmartSearch("unknownxyz123")

        // No error — browse mode activates and shows results.
        XCTAssertNil(vm.homeLoadError)
        XCTAssertTrue(vm.showResults)
        XCTAssertEqual(mockRecipeService.getAllRecipesCallCount, 1)
    }

    func testRunSmartSearch_appliesFiltersWithoutIngredientsAndRerunsSearch() async {
        // User has ingredients already selected; query adds only filters.
        let chicken = Ingredient(name: "Chicken", description: nil, pictureFileName: nil, foodGroup: nil, foodSubgroup: nil, emoji: "🍗")
        let vm = makeViewModel(includeSmartSearch: true)
        vm.selectedIngredients = [chicken]
        mockSmartSearch = MockSmartSearchProvider(result: .success(
            SmartSearchIntent(ingredientNames: [], mood: nil, cookTime: .quick, complexity: .easy, dietary: [])
        ))
        let initialCount = mockRecipeService.getRecipesCallCount
        await vm.runSmartSearch("make it quick and easy")

        XCTAssertEqual(vm.selectedCookTimeFilter, .quick)
        XCTAssertEqual(vm.selectedComplexityFilter, .easy)
        XCTAssertEqual(vm.selectedIngredients.first?.name, "Chicken") // selection preserved
        XCTAssertGreaterThan(mockRecipeService.getRecipesCallCount, initialCount)
    }

    func testRunSmartSearch_setsErrorOnParseFailure() async {
        mockSmartSearch = MockSmartSearchProvider(result: .failure(SmartSearchError.parsingFailed(nil)))
        let vm = makeViewModel(includeSmartSearch: true)
        await vm.runSmartSearch("something")

        XCTAssertNotNil(vm.homeLoadError)
    }
}

// MARK: - Mock

/// Mock smart-search provider that returns a canned `Result` for any query.
final class MockSmartSearchProvider: SmartSearchProviderProtocol {
    private let result: Result<SmartSearchIntent, Error>

    init(result: Result<SmartSearchIntent, Error>) {
        self.result = result
    }

    func parse(query: String) async throws -> SmartSearchIntent {
        try result.get()
    }
}
