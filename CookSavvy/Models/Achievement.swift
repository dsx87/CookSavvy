import Foundation

struct Achievement: Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let emoji: String
    let isUnlocked: Bool
    let unlockedAt: Date?

    static let allAchievements: [Achievement] = [
        Achievement(
            id: "first_cook",
            title: "First Cook",
            description: "Cook your first recipe",
            emoji: "👨‍🍳",
            isUnlocked: false,
            unlockedAt: nil
        ),
        Achievement(
            id: "week_streak",
            title: "Week Warrior",
            description: "Cook 7 days in a row",
            emoji: "🔥",
            isUnlocked: false,
            unlockedAt: nil
        ),
        Achievement(
            id: "recipe_creator",
            title: "Recipe Creator",
            description: "Create your first recipe",
            emoji: "📝",
            isUnlocked: false,
            unlockedAt: nil
        ),
        Achievement(
            id: "ten_recipes",
            title: "Seasoned Chef",
            description: "Cook 10 different recipes",
            emoji: "⭐",
            isUnlocked: false,
            unlockedAt: nil
        ),
        Achievement(
            id: "five_created",
            title: "Cookbook Author",
            description: "Create 5 recipes",
            emoji: "📚",
            isUnlocked: false,
            unlockedAt: nil
        ),
    ]
}
