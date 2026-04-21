import XCTest
@testable import CookSavvy

// MARK: - JourneyViewModelTests (ViewModel behavior)

@MainActor
private final class SpyJourneyCoordinator: JourneyCoordinating {
    var showCookModeCallCount = 0
    var showRecipeDetailCallCount = 0
    var lastRecipeDetailRecipe: Recipe?
    var lastRecipeDetailSelectedIngredients: [Ingredient] = []
    var showRecipeListCallCount = 0
    var showCreateRecipeCallCount = 0
    var showSettingsCallCount = 0
    var showShoppingListCallCount = 0
    var showUpgradeCallCount = 0

    func showCookMode(recipe: Recipe) { showCookModeCallCount += 1 }
    func showRecipeDetail(recipe: Recipe, selectedIngredients: [Ingredient]) {
        showRecipeDetailCallCount += 1
        lastRecipeDetailRecipe = recipe
        lastRecipeDetailSelectedIngredients = selectedIngredients
    }
    func showRecipeList(title: String, recipes: [Recipe]) { showRecipeListCallCount += 1 }
    func showCreateRecipe() { showCreateRecipeCallCount += 1 }
    func showSettings() { showSettingsCallCount += 1 }
    func showShoppingList() { showShoppingListCallCount += 1 }
    func showUpgrade() { showUpgradeCallCount += 1 }
}

@MainActor
final class JourneyViewModelTests: XCTestCase {

    var mockUserDataService: MockUserDataService!
    var subscriptionService: MockSubscriptionService!
    var mockAuthService: MockAuthService!
    var mockAnalytics: MockAnalyticsService!

    override func setUp() {
        super.setUp()
        mockUserDataService = MockUserDataService()
        subscriptionService = MockSubscriptionService(initialPlan: .free)
        mockAuthService = MockAuthService(initialState: .signedIn(userId: "mock-anonymous-user"), isAnonymous: true)
        mockAnalytics = MockAnalyticsService()
    }

    override func tearDown() {
        mockUserDataService = nil
        subscriptionService = nil
        mockAuthService = nil
        mockAnalytics = nil
        super.tearDown()
    }

    private func makeViewModel(
        coordinator: (any JourneyCoordinating)? = nil,
        authService: MockAuthService? = nil
    ) -> JourneyViewModel {
        JourneyViewModel(
            userDataService: mockUserDataService,
            subscriptionService: subscriptionService,
            cameraScanTracker: MockCameraScanTracker(),
            authService: authService ?? mockAuthService,
            signInWithAppleAction: SignInWithAppleAction(
                authService: authService ?? mockAuthService,
                analyticsService: mockAnalytics,
                logger: MockLogger(),
                appleSignInManager: MockAppleSignInManager()
            ),
            logger: MockLogger(),
            coordinator: coordinator
        )
    }

    func testStatsLoadedFromService() async {
        mockUserDataService.stubbedRecipesCooked = 7
        mockUserDataService.stubbedCurrentStreak = 3
        mockUserDataService.stubbedTotalCookingTime = 3600 * 2

        let vm = makeViewModel()
        await vm.loadData()

        XCTAssertEqual(vm.recipesCooked, 7)
        XCTAssertEqual(vm.dayStreak, 3)
        XCTAssertEqual(vm.hoursCooking, 2.0, accuracy: 0.01)
    }

    func testUserRecipesLoaded() async {
        let recipes = Recipe.mocks(count: 3)
        mockUserDataService.stubbedUserRecipes = recipes

        let vm = makeViewModel()
        await vm.loadData()

        XCTAssertEqual(vm.userRecipes.count, 3)
    }

    func testSavedRecipesLoaded() async {
        let recipes = Recipe.mocks(count: 2)
        mockUserDataService.stubbedFavorites = recipes

        let vm = makeViewModel()
        await vm.loadData()

        XCTAssertEqual(vm.savedRecipes.count, 2)
    }

    func testAchievementsEvaluated() async {
        mockUserDataService.stubbedRecipesCooked = 1
        mockUserDataService.stubbedCurrentStreak = 1

        let vm = makeViewModel()
        await vm.loadData()

        let firstCook = vm.achievements.first { $0.id == "first_cook" }
        XCTAssertTrue(firstCook?.isUnlocked ?? false)
    }

    func testAchievementsUseHighMatchRecipesCookedCountFromUserDataService() async {
        mockUserDataService.stubbedHighMatchRecipesCookedCount = 5

        let vm = makeViewModel()
        await vm.loadData()

        let fridgeCleaner = vm.achievements.first { $0.id == "fridge_cleaner" }
        XCTAssertEqual(fridgeCleaner?.currentProgress, 5)
        XCTAssertTrue(fridgeCleaner?.isUnlocked ?? false)
    }

    func testWeekCookingDates() async {
        let today = Date()
        let weekday = Calendar.current.component(.weekday, from: today)
        let expectedDayIndex = (weekday + 5) % 7
        mockUserDataService.stubbedWeekCookingDates = [today]

        let vm = makeViewModel()
        await vm.loadData()

        XCTAssertEqual(vm.weekCookingDates.count, 1)
        XCTAssertTrue(vm.weekCookingDates.contains(expectedDayIndex))
    }

    func testEmptyStateNoCrash() async {
        // All stubs return empty/zero values (defaults)
        let vm = makeViewModel()
        await vm.loadData()

        XCTAssertEqual(vm.recipesCooked, 0)
        XCTAssertEqual(vm.dayStreak, 0)
        XCTAssertTrue(vm.savedRecipes.isEmpty)
        XCTAssertTrue(vm.userRecipes.isEmpty)
    }

    func testShowShoppingListRoutesPremiumUsersToShoppingList() {
        let coordinator = SpyJourneyCoordinator()
        subscriptionService.setPlan(.premium)
        let vm = makeViewModel(coordinator: coordinator)

        vm.showShoppingList()

        XCTAssertEqual(coordinator.showShoppingListCallCount, 1)
        XCTAssertEqual(coordinator.showUpgradeCallCount, 0)
    }

    func testShowShoppingListRoutesFreeUsersToUpgrade() {
        let coordinator = SpyJourneyCoordinator()
        subscriptionService.setPlan(.free)
        let vm = makeViewModel(coordinator: coordinator)

        vm.showShoppingList()

        XCTAssertEqual(coordinator.showShoppingListCallCount, 0)
        XCTAssertEqual(coordinator.showUpgradeCallCount, 1)
    }

    func testCookAgainLoadsRecipeAndNavigatesWithoutHistoricalIngredientState() async {
        let coordinator = SpyJourneyCoordinator()
        let recipe = Recipe(
            title: "Replay Pasta",
            ingredients: [Ingredient(name: "Garlic"), Ingredient(name: "Onion"), Ingredient(name: "Pasta")],
            instructions: ["Step 1"],
            image: "",
            cleanedIngredients: [Ingredient(name: "Garlic"), Ingredient(name: "Onion"), Ingredient(name: "Pasta")],
            additionalInfo: .empty
        )
        let rescued = [Ingredient(name: "Garlic"), Ingredient(name: "Onion")]
        mockUserDataService.stubbedRecipesByID[42] = recipe
        let vm = makeViewModel(coordinator: coordinator)
        let session = CookingSession(
            id: 1,
            recipeId: 42,
            recipeTitle: recipe.title,
            cookedAt: Date(),
            durationSeconds: nil,
            rating: nil,
            rescuedIngredients: rescued
        )

        await vm.cookAgain(session: session)

        XCTAssertEqual(mockUserDataService.requestedRecipeIDs, [42])
        XCTAssertEqual(coordinator.showRecipeDetailCallCount, 1)
        XCTAssertEqual(coordinator.lastRecipeDetailRecipe?.title, recipe.title)
        XCTAssertTrue(coordinator.lastRecipeDetailSelectedIngredients.isEmpty)
        XCTAssertNil(coordinator.lastRecipeDetailRecipe?.missingIngredients)
        XCTAssertNil(vm.cookAgainErrorMessage)
    }

    func testCookAgainNavigatesWithEmptySelectedIngredientsWhenSessionHasNone() async {
        let coordinator = SpyJourneyCoordinator()
        let recipe = Recipe.mocks(count: 1).first!
        mockUserDataService.stubbedRecipesByID[42] = recipe
        let vm = makeViewModel(coordinator: coordinator)
        let session = CookingSession(
            id: 2,
            recipeId: 42,
            recipeTitle: recipe.title,
            cookedAt: Date(),
            durationSeconds: nil,
            rating: nil,
            rescuedIngredients: []
        )

        await vm.cookAgain(session: session)

        XCTAssertEqual(coordinator.showRecipeDetailCallCount, 1)
        XCTAssertTrue(coordinator.lastRecipeDetailSelectedIngredients.isEmpty)
    }

    func testCookAgainDoesNotNavigateWhenRecipeCannotBeLoaded() async {
        let coordinator = SpyJourneyCoordinator()
        let vm = makeViewModel(coordinator: coordinator)
        let session = CookingSession(
            id: 3,
            recipeId: 99,
            recipeTitle: "Missing Recipe",
            cookedAt: Date(),
            durationSeconds: nil,
            rating: nil,
            rescuedIngredients: [Ingredient(name: "Garlic")]
        )

        await vm.cookAgain(session: session)

        XCTAssertEqual(mockUserDataService.requestedRecipeIDs, [99])
        XCTAssertEqual(coordinator.showRecipeDetailCallCount, 0)
        XCTAssertEqual(vm.cookAgainErrorMessage, Strings.Journey.cookAgainErrorMessage)
    }

    func testCookAgainShowsErrorWhenLoadingRecipeThrows() async {
        let coordinator = SpyJourneyCoordinator()
        mockUserDataService.shouldThrow = TestError.stub
        let vm = makeViewModel(coordinator: coordinator)
        let session = CookingSession(
            id: 4,
            recipeId: 77,
            recipeTitle: "Broken Recipe",
            cookedAt: Date(),
            durationSeconds: nil,
            rating: nil,
            rescuedIngredients: []
        )

        await vm.cookAgain(session: session)

        XCTAssertEqual(coordinator.showRecipeDetailCallCount, 0)
        XCTAssertEqual(vm.cookAgainErrorMessage, Strings.Journey.cookAgainErrorMessage)
    }

    func testLoadDataSetsErrorMessageWhenPrimaryJourneyLoadFails() async {
        mockUserDataService.shouldThrow = TestError.stub

        let vm = makeViewModel()
        await vm.loadData()

        XCTAssertEqual(vm.errorMessage, Strings.Errors.journeyLoadFailed)
    }

    // MARK: - Auth

    func testIsAnonymousTrueForGuestUser() {
        let vm = makeViewModel()
        XCTAssertTrue(vm.isAnonymous)
        XCTAssertFalse(vm.isSignedInWithApple)
    }

    func testIsSignedInWithAppleWhenNotAnonymous() {
        let auth = MockAuthService(initialState: .signedIn(userId: "apple-user"), isAnonymous: false)
        let vm = makeViewModel(authService: auth)
        XCTAssertFalse(vm.isAnonymous)
        XCTAssertTrue(vm.isSignedInWithApple)
    }

    func testIsAuthAvailableReflectsAuthService() {
        let vm = makeViewModel()
        XCTAssertTrue(vm.isAuthAvailable)
    }

    func testSignInWithAppleUpdatesAnonymousState() async {
        let vm = makeViewModel()
        XCTAssertTrue(vm.isAnonymous)

        await vm.signInWithApple()

        XCTAssertFalse(vm.isAnonymous)
        XCTAssertTrue(vm.isSignedInWithApple)
        XCTAssertEqual(mockAuthService.signInWithAppleCallCount, 1)
    }

    func testSignInWithAppleSetsErrorOnFailure() async {
        mockAuthService.signInWithAppleError = AuthError.signInFailed
        let vm = makeViewModel()

        await vm.signInWithApple()

        XCTAssertTrue(vm.isAnonymous)
        XCTAssertNotNil(vm.errorMessage)
    }
}

// MARK: - JourneyAchievementIntegrationTests (formerly inline achievement tests)

@MainActor
final class JourneyAchievementIntegrationTests: XCTestCase {

    func testBuildAchievementsUsesLoadedJourneyMetrics() {
        let achievements = AchievementEvaluator.evaluate(
            metrics: AchievementMetrics(
                recipesCooked: 12,
                dayStreak: 7,
                totalCookingHours: 10.4,
                userRecipeCount: 5,
                distinctRecipesCooked: 12,
                highMatchRecipesCooked: 0,
                uniqueIngredientsUsed: 0,
                totalCameraScans: 0
            ),
            referenceDate: Date(timeIntervalSince1970: 123)
        )

        XCTAssertEqual(achievement(withID: "first_cook", in: achievements)?.currentProgress, 1)
        XCTAssertTrue(achievement(withID: "first_cook", in: achievements)?.isUnlocked ?? false)
        XCTAssertEqual(achievement(withID: "week_streak", in: achievements)?.currentProgress, 7)
        XCTAssertTrue(achievement(withID: "week_streak", in: achievements)?.isUnlocked ?? false)
        XCTAssertEqual(achievement(withID: "recipe_creator", in: achievements)?.currentProgress, 1)
        XCTAssertEqual(achievement(withID: "five_created", in: achievements)?.currentProgress, 5)
        XCTAssertEqual(achievement(withID: "ten_recipes", in: achievements)?.currentProgress, 10)
        XCTAssertEqual(achievement(withID: "fifty_recipes", in: achievements)?.currentProgress, 12)
        XCTAssertEqual(achievement(withID: "hour_cooking", in: achievements)?.currentProgress, 10)
        XCTAssertTrue(achievement(withID: "hour_cooking", in: achievements)?.isUnlocked ?? false)
    }

    func testBuildAchievementsLeavesIncompleteMilestonesLocked() {
        let achievements = AchievementEvaluator.evaluate(
            metrics: AchievementMetrics(
                recipesCooked: 0,
                dayStreak: 3,
                totalCookingHours: 2.9,
                userRecipeCount: 1,
                distinctRecipesCooked: 4,
                highMatchRecipesCooked: 0,
                uniqueIngredientsUsed: 0,
                totalCameraScans: 0
            ),
            referenceDate: Date(timeIntervalSince1970: 123)
        )

        XCTAssertFalse(achievement(withID: "first_cook", in: achievements)?.isUnlocked ?? true)
        XCTAssertEqual(achievement(withID: "week_streak", in: achievements)?.currentProgress, 3)
        XCTAssertFalse(achievement(withID: "week_streak", in: achievements)?.isUnlocked ?? true)
        XCTAssertEqual(achievement(withID: "ten_recipes", in: achievements)?.currentProgress, 4)
        XCTAssertFalse(achievement(withID: "ten_recipes", in: achievements)?.isUnlocked ?? true)
        XCTAssertEqual(achievement(withID: "hour_cooking", in: achievements)?.currentProgress, 2)
        XCTAssertFalse(achievement(withID: "hour_cooking", in: achievements)?.isUnlocked ?? true)
    }

    private func achievement(withID id: String, in achievements: [Achievement]) -> Achievement? {
        achievements.first { $0.id == id }
    }
}

private enum TestError: Error {
    case stub
}
