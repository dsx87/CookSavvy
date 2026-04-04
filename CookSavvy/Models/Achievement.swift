import Foundation

enum AchievementCategory: String, Hashable {
    case general
    case antiWaste
}

struct Achievement: Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let emoji: String
    let colorHex: String
    let category: AchievementCategory
    let maxProgress: Int
    var currentProgress: Int
    var isUnlocked: Bool
    var unlockedAt: Date?

    static func == (lhs: Achievement, rhs: Achievement) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    var accessibilityLabel: String {
        if isUnlocked {
            return String(format: Strings.Accessibility.achievementUnlocked, title)
        } else {
            return String(format: Strings.Accessibility.achievementProgress, title, currentProgress, maxProgress)
        }
    }

    var progressFraction: Double {
        guard maxProgress > 0 else { return 0 }
        return min(Double(currentProgress) / Double(maxProgress), 1.0)
    }

    static let allAchievements: [Achievement] = [
        Achievement(
            id: "first_cook",
            title: "First Cook",
            description: "Cook your first recipe",
            emoji: "👨‍🍳",
            colorHex: "#FF9500",
            category: .general,
            maxProgress: 1,
            currentProgress: 0,
            isUnlocked: false
        ),
        Achievement(
            id: "week_streak",
            title: "Week Warrior",
            description: "Cook 7 days in a row",
            emoji: "🔥",
            colorHex: "#FF3B30",
            category: .general,
            maxProgress: 7,
            currentProgress: 0,
            isUnlocked: false
        ),
        Achievement(
            id: "recipe_creator",
            title: "Recipe Creator",
            description: "Create your first recipe",
            emoji: "📝",
            colorHex: "#007AFF",
            category: .general,
            maxProgress: 1,
            currentProgress: 0,
            isUnlocked: false
        ),
        Achievement(
            id: "ten_recipes",
            title: "Seasoned Chef",
            description: "Cook 10 different recipes",
            emoji: "⭐",
            colorHex: "#FFCC00",
            category: .general,
            maxProgress: 10,
            currentProgress: 0,
            isUnlocked: false
        ),
        Achievement(
            id: "five_created",
            title: "Cookbook Author",
            description: "Create 5 recipes",
            emoji: "📚",
            colorHex: "#AF52DE",
            category: .general,
            maxProgress: 5,
            currentProgress: 0,
            isUnlocked: false
        ),
        Achievement(
            id: "fifty_recipes",
            title: "Master Chef",
            description: "Cook 50 different recipes",
            emoji: "👑",
            colorHex: "#FFD14D",
            category: .general,
            maxProgress: 50,
            currentProgress: 0,
            isUnlocked: false
        ),
        Achievement(
            id: "hour_cooking",
            title: "Dedicated Chef",
            description: "Spend 10 hours cooking",
            emoji: "⏰",
            colorHex: "#00C7BE",
            category: .general,
            maxProgress: 10,
            currentProgress: 0,
            isUnlocked: false
        ),
        Achievement(
            id: "fridge_cleaner",
            title: "Fridge Cleaner",
            description: "Cook 5 recipes using 90%+ of your ingredients",
            emoji: "♻️",
            colorHex: "#34C759",
            category: .antiWaste,
            maxProgress: 5,
            currentProgress: 0,
            isUnlocked: false
        ),
        Achievement(
            id: "ingredient_master",
            title: "Ingredient Master",
            description: "Use 50 unique ingredients",
            emoji: "🧑‍🍳",
            colorHex: "#5856D6",
            category: .antiWaste,
            maxProgress: 50,
            currentProgress: 0,
            isUnlocked: false
        ),
        Achievement(
            id: "scan_pro",
            title: "Scan Pro",
            description: "Scan ingredients 20 times",
            emoji: "📸",
            colorHex: "#007AFF",
            category: .antiWaste,
            maxProgress: 20,
            currentProgress: 0,
            isUnlocked: false
        ),
    ]
}
