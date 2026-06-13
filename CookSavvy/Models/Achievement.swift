import Foundation

/// Groups achievements by theme for display and filtering purposes.
nonisolated enum AchievementCategory: String, Hashable {
    /// General cooking milestones such as streaks, recipe counts, and cumulative cooking time.
    case general
    /// Milestones that reward minimising ingredient waste.
    case antiWaste
}

/// A cooking milestone that the user can earn through consistent app usage.
///
/// Each achievement tracks progress toward a numeric goal (`maxProgress`) and transitions
/// to an unlocked state once `currentProgress` reaches that goal.
/// The complete catalogue is defined in `allAchievements`.
nonisolated struct Achievement: Identifiable, Hashable {
    /// Stable identifier used for persistence and equality checks.
    let id: String
    /// Short display name shown on the achievement card (e.g. `"First Cook"`).
    let title: String
    /// Human-readable description of the milestone required to earn the achievement.
    let description: String
    /// Representative emoji displayed on the achievement card.
    let emoji: String
    /// Hex colour string (e.g. `"#FF9500"`) used as the card's accent colour.
    let colorHex: String
    /// The thematic group this achievement belongs to.
    let category: AchievementCategory
    /// Total number of progress units required to unlock this achievement.
    let maxProgress: Int
    /// The user's current progress toward `maxProgress`.
    var currentProgress: Int
    /// Whether the user has fully completed this achievement.
    var isUnlocked: Bool
    /// The timestamp when the achievement was unlocked, or `nil` if still locked.
    var unlockedAt: Date?

    /// Equality is based solely on `id`, allowing mutable progress fields to change freely.
    static func == (lhs: Achievement, rhs: Achievement) -> Bool {
        lhs.id == rhs.id
    }

    /// Hashes only `id` for consistency with the custom `==` implementation.
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    /// A VoiceOver-friendly label describing whether the achievement is unlocked or in progress.
    var accessibilityLabel: String {
        if isUnlocked {
            return String(format: Strings.Accessibility.achievementUnlocked, title)
        } else {
            return String(format: Strings.Accessibility.achievementProgress, title, currentProgress, maxProgress)
        }
    }

    /// The user's progress expressed as a fraction between `0.0` and `1.0`, clamped at `1.0` when complete.
    var progressFraction: Double {
        guard maxProgress > 0 else { return 0 }
        return min(Double(currentProgress) / Double(maxProgress), 1.0)
    }

    /// The complete catalogue of achievements shipped with the app, each initialised with zero progress.
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
