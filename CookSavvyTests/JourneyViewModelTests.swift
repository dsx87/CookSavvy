import XCTest
@testable import CookSavvy

@MainActor
final class JourneyViewModelTests: XCTestCase {

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
