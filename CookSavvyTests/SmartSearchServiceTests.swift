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
            analyticsService: MockAnalyticsService(),
            logger: MockLogger(),
            dietaryPreferences: DietaryPreferences(defaults: UserDefaults()),
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
        // Stub the provider before building the view model: makeViewModel captures the
        // current mockSmartSearch at construction time, so it must be set up first.
        mockSmartSearch = MockSmartSearchProvider(result: .success(
            SmartSearchIntent(ingredientNames: [], mood: nil, cookTime: .quick, complexity: .easy, dietary: [])
        ))
        let vm = makeViewModel(includeSmartSearch: true)
        vm.selectedIngredients = [chicken]
        // User is already viewing results; a filter-only query re-runs the search in place
        // (runSmartSearch only re-runs when showResults is already true).
        vm.showResults = true
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

// MARK: - SupabaseSmartSearchProvider Tests

final class SupabaseSmartSearchProviderTests: XCTestCase {

    private var mockClient: MockSupabaseClientProvider!
    private var provider: SupabaseSmartSearchProvider!

    override func setUp() {
        super.setUp()
        mockClient = MockSupabaseClientProvider()
        provider = SupabaseSmartSearchProvider(clientProvider: mockClient)
    }

    override func tearDown() {
        mockClient = nil
        provider = nil
        super.tearDown()
    }

    private func stub(_ json: String) {
        mockClient.stubbedResponses["parse-search-query"] = Data(json.utf8)
    }

    func testParse_decodesSnakeCaseAndMapsEnums() async throws {
        stub("""
        {"ingredients":["tomato","pasta"],"mood":"quick","cook_time":"quick","complexity":"easy","dietary":["vegetarian"]}
        """)

        let intent = try await provider.parse(query: "quick easy vegetarian tomato pasta")

        XCTAssertEqual(mockClient.invokedFunctionNames, ["parse-search-query"])
        XCTAssertEqual(intent.ingredientNames, ["tomato", "pasta"])
        XCTAssertEqual(intent.mood, .quick)
        XCTAssertEqual(intent.cookTime, .quick)   // snake_case cook_time decoded
        XCTAssertEqual(intent.complexity, .easy)
        XCTAssertEqual(intent.dietary, [.vegetarian])
    }

    func testParse_mapsMixedCasingAndDietaryCaseInsensitively() async throws {
        // Model may capitalise enum values and dietary spellings; mapping must tolerate it.
        stub("""
        {"ingredients":["Egg"],"mood":"Cozy","cook_time":"LONG","complexity":"Hard","dietary":["GlutenFree","kosher"]}
        """)

        let intent = try await provider.parse(query: "anything")

        XCTAssertEqual(intent.mood, .cozy)
        XCTAssertEqual(intent.cookTime, .long)
        XCTAssertEqual(intent.complexity, .hard)
        XCTAssertEqual(intent.dietary, [.glutenFree, .kosher])
    }

    func testParse_dropsUnknownEnumAndDietaryValues() async throws {
        stub("""
        {"ingredients":[],"mood":"sparkly","cook_time":null,"complexity":"impossible","dietary":["vegetarian","made_up"]}
        """)

        let intent = try await provider.parse(query: "anything")

        XCTAssertTrue(intent.ingredientNames.isEmpty)
        XCTAssertNil(intent.mood)         // unknown mood → nil
        XCTAssertNil(intent.cookTime)     // explicit null → nil
        XCTAssertNil(intent.complexity)   // unknown complexity → nil
        XCTAssertEqual(intent.dietary, [.vegetarian]) // unknown dietary dropped
    }

    func testParse_wrapsInvokeErrorAsNetworkError() async {
        mockClient.invokedError = URLError(.notConnectedToInternet)

        do {
            _ = try await provider.parse(query: "anything")
            XCTFail("Expected error")
        } catch let SmartSearchError.networkError(underlying) {
            XCTAssertTrue(underlying is URLError)
        } catch {
            XCTFail("Expected SmartSearchError.networkError, got \(error)")
        }
    }

    func testParse_malformedJSONThrowsParsingFailed() async {
        stub("not json at all")

        do {
            _ = try await provider.parse(query: "anything")
            XCTFail("Expected error")
        } catch SmartSearchError.parsingFailed {
            // expected
        } catch {
            XCTFail("Expected SmartSearchError.parsingFailed, got \(error)")
        }
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
