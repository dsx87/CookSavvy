import Foundation

struct AchievementMetrics {
    let recipesCooked: Int
    let dayStreak: Int
    let totalCookingHours: Double
    let userRecipeCount: Int
    let distinctRecipesCooked: Int
    let highMatchRecipesCooked: Int
    let uniqueIngredientsUsed: Int
    let totalCameraScans: Int
}

enum AchievementEvaluator {
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
