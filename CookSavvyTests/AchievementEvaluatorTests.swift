import XCTest
@testable import CookSavvy

final class AchievementEvaluatorTests: XCTestCase {

    private func metrics(
        recipesCooked: Int = 0,
        dayStreak: Int = 0,
        totalCookingHours: Double = 0,
        userRecipeCount: Int = 0,
        distinctRecipesCooked: Int = 0,
        highMatchRecipesCooked: Int = 0,
        uniqueIngredientsUsed: Int = 0,
        totalCameraScans: Int = 0
    ) -> AchievementMetrics {
        AchievementMetrics(
            recipesCooked: recipesCooked,
            dayStreak: dayStreak,
            totalCookingHours: totalCookingHours,
            userRecipeCount: userRecipeCount,
            distinctRecipesCooked: distinctRecipesCooked,
            highMatchRecipesCooked: highMatchRecipesCooked,
            uniqueIngredientsUsed: uniqueIngredientsUsed,
            totalCameraScans: totalCameraScans
        )
    }

    func testZeroMetricsAllLocked() {
        let results = AchievementEvaluator.evaluate(metrics: metrics())
        XCTAssertEqual(results.count, 10)
        XCTAssertTrue(results.allSatisfy { !$0.isUnlocked })
        XCTAssertTrue(results.allSatisfy { $0.currentProgress == 0 })
    }

    func testFirstCookUnlockedAtOne() {
        let results = AchievementEvaluator.evaluate(metrics: metrics(recipesCooked: 1))
        let firstCook = results.first { $0.id == "first_cook" }
        XCTAssertNotNil(firstCook)
        XCTAssertTrue(firstCook!.isUnlocked)
    }

    func testWeekStreakThresholdExact() {
        let locked = AchievementEvaluator.evaluate(metrics: metrics(dayStreak: 6))
        XCTAssertFalse(locked.first { $0.id == "week_streak" }!.isUnlocked)

        let unlocked = AchievementEvaluator.evaluate(metrics: metrics(dayStreak: 7))
        XCTAssertTrue(unlocked.first { $0.id == "week_streak" }!.isUnlocked)
    }

    func testRecipeCreatorAndFiveCreated() {
        let results = AchievementEvaluator.evaluate(metrics: metrics(userRecipeCount: 5))
        XCTAssertTrue(results.first { $0.id == "recipe_creator" }!.isUnlocked)
        XCTAssertTrue(results.first { $0.id == "five_created" }!.isUnlocked)
    }

    func testProgressCappedAtMaxProgress() {
        let results = AchievementEvaluator.evaluate(metrics: metrics(recipesCooked: 999))
        let firstCook = results.first { $0.id == "first_cook" }!
        XCTAssertEqual(firstCook.currentProgress, firstCook.maxProgress)
        XCTAssertEqual(firstCook.currentProgress, 1)
    }

    func testUnlockedAtDateSetForUnlockedOnly() {
        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let results = AchievementEvaluator.evaluate(
            metrics: metrics(recipesCooked: 1),
            referenceDate: fixedDate
        )
        let firstCook = results.first { $0.id == "first_cook" }!
        XCTAssertEqual(firstCook.unlockedAt, fixedDate)

        let weekStreak = results.first { $0.id == "week_streak" }!
        XCTAssertNil(weekStreak.unlockedAt)
    }

    func testAntiWasteAchievementsAreExplicitlyCategorized() {
        let antiWasteAchievements = Achievement.allAchievements.filter { $0.category == .antiWaste }

        XCTAssertEqual(antiWasteAchievements.map(\.id), [
            "fridge_cleaner",
            "ingredient_master",
            "scan_pro"
        ])
    }

    func testGenericAchievementsRemainCategorizedSeparately() {
        let generalAchievements = Achievement.allAchievements.filter { $0.category == .general }

        XCTAssertEqual(generalAchievements.count, 7)
        XCTAssertFalse(generalAchievements.contains { $0.id == "fridge_cleaner" })
    }
}
