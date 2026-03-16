import XCTest
@testable import CookSavvy

// MARK: - JourneyViewModelTests (ViewModel behavior)

@MainActor
final class JourneyViewModelTests: XCTestCase {

    var mockUserDataService: MockUserDataService!

    override func setUp() {
        super.setUp()
        mockUserDataService = MockUserDataService()
    }

    override func tearDown() {
        mockUserDataService = nil
        super.tearDown()
    }

    private func makeViewModel() -> JourneyViewModel {
        JourneyViewModel(userDataService: mockUserDataService, coordinator: nil)
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

    func testAchievementsEvaluated() async {
        mockUserDataService.stubbedRecipesCooked = 1
        mockUserDataService.stubbedCurrentStreak = 1

        let vm = makeViewModel()
        await vm.loadData()

        let firstCook = vm.achievements.first { $0.id == "first_cook" }
        XCTAssertTrue(firstCook?.isUnlocked ?? false)
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
        XCTAssertTrue(vm.userRecipes.isEmpty)
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
                distinctRecipesCooked: 12
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
                distinctRecipesCooked: 4
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
