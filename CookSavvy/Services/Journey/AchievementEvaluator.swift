import Foundation

/// Aggregated statistics derived from a user's cooking history, used as input to `AchievementEvaluator`.
///
/// Callers (e.g. `JourneyViewModel`) are responsible for computing these values from
/// raw `[CookingSession]` data before passing them to the evaluator.
struct AchievementMetrics {
    /// Total number of cooking sessions completed, including repeats of the same recipe.
    let recipesCooked: Int
    /// Current consecutive-day cooking streak.
    let dayStreak: Int
    /// Cumulative time spent in cook mode, in hours.
    let totalCookingHours: Double
    /// Number of recipes the user has created themselves.
    let userRecipeCount: Int
    /// Number of *unique* recipes cooked, deduplicated by recipe ID.
    let distinctRecipesCooked: Int
    /// Number of sessions where the ingredient-match score was high (e.g. ≥ 80 %).
    let highMatchRecipesCooked: Int
    /// Total number of distinct ingredient names used across all sessions.
    let uniqueIngredientsUsed: Int
    /// Lifetime number of camera-based ingredient scans performed.
    let totalCameraScans: Int
}

/// Stateless evaluator that maps `AchievementMetrics` to a fully-populated array of `Achievement` values.
///
/// Using a caseless `enum` (rather than a class or struct) enforces that no instances are created —
/// the type is purely a namespace for the `evaluate` function.
enum AchievementEvaluator {
    /// Evaluates all known achievements against the provided metrics and returns an updated copy of each.
    ///
    /// For every achievement in `Achievement.allAchievements`, the function:
    /// 1. Looks up the relevant metric from `progressByID` using the achievement's `id`.
    /// 2. Clamps progress to `achievement.maxProgress`.
    /// 3. Sets `isUnlocked = true` and records `unlockedAt = referenceDate` when progress meets the target.
    ///
    /// The `progressByID` mapping ties each well-known achievement ID (e.g. `"first_cook"`,
    /// `"week_streak"`) to its corresponding metric field. Unknown IDs receive a progress of `0`.
    ///
    /// - Parameters:
    ///   - metrics: Aggregated cooking statistics to evaluate against.
    ///   - referenceDate: The date stamped on newly unlocked achievements; defaults to `Date()`.
    /// - Returns: Array of all achievements with `currentProgress`, `isUnlocked`, and `unlockedAt` populated.
    static func evaluate(
        metrics: AchievementMetrics,
        referenceDate: Date = Date()
    ) -> [Achievement] {
        let progressByID: [String: Int] = [
            "first_cook": metrics.recipesCooked,
            "week_streak": metrics.dayStreak,
            "recipe_creator": metrics.userRecipeCount,
            "ten_recipes": metrics.distinctRecipesCooked,
            "five_created": metrics.userRecipeCount,
            "fifty_recipes": metrics.distinctRecipesCooked,
            "hour_cooking": Int(metrics.totalCookingHours.rounded(.down)),
            "fridge_cleaner": metrics.highMatchRecipesCooked,
            "ingredient_master": metrics.uniqueIngredientsUsed,
            "scan_pro": metrics.totalCameraScans
        ]

        return Achievement.allAchievements.map { achievement in
            var updated = achievement
            let progress = min(progressByID[achievement.id] ?? 0, achievement.maxProgress)
            updated.currentProgress = progress
            updated.isUnlocked = progress >= achievement.maxProgress
            updated.unlockedAt = updated.isUnlocked ? referenceDate : nil
            return updated
        }
    }
}
