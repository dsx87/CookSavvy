import Foundation
import SwiftUI

// MARK: - Protocol

protocol CuratedCollectionServiceProtocol {
    func getCollectionsForThisWeek(isPremium: Bool) -> [CuratedCollection]
    func getRecipes(for collection: CuratedCollection) async throws -> [Recipe]
}

// MARK: - Implementation

final class CuratedCollectionService: CuratedCollectionServiceProtocol {

    private let dbInterface: DBInterfaceProtocol

    init(dbInterface: DBInterfaceProtocol) {
        self.dbInterface = dbInterface
    }

    // MARK: - All Collections

    private static let allCollections: [CuratedCollection] = [
        CuratedCollection(
            id: "five_ingredient_dinners",
            title: Strings.Discover.collection5Ingredient,
            subtitle: Strings.Discover.collection5IngredientSubtitle,
            emoji: "🥘",
            gradientColors: (UI.Discover.Collection.mintStart, UI.Discover.Collection.mintEnd),
            filterCriteria: FilterCriteria(maxIngredientCount: 5)
        ),
        CuratedCollection(
            id: "thirty_minute_meals",
            title: Strings.Discover.collection30Min,
            subtitle: Strings.Discover.collection30MinSubtitle,
            emoji: "⚡",
            gradientColors: (UI.Discover.Collection.skyStart, UI.Discover.Collection.skyEnd),
            filterCriteria: FilterCriteria(maxCookTime: 30)
        ),
        CuratedCollection(
            id: "one_pot_wonders",
            title: Strings.Discover.collectionOnePot,
            subtitle: Strings.Discover.collectionOnePotSubtitle,
            emoji: "🍲",
            gradientColors: (UI.Discover.Collection.roseStart, UI.Discover.Collection.roseEnd),
            filterCriteria: FilterCriteria(ingredientKeywords: ["pot", "stew", "soup", "chili"])
        ),
        CuratedCollection(
            id: "budget_friendly",
            title: Strings.Discover.collectionBudget,
            subtitle: Strings.Discover.collectionBudgetSubtitle,
            emoji: "💰",
            gradientColors: (UI.Discover.Collection.goldStart, UI.Discover.Collection.goldEnd),
            filterCriteria: FilterCriteria(ingredientKeywords: ["rice", "beans", "pasta", "potato", "lentil"])
        ),
        CuratedCollection(
            id: "comfort_classics",
            title: Strings.Discover.collectionComfort,
            subtitle: Strings.Discover.collectionComfortSubtitle,
            emoji: "🫕",
            gradientColors: (UI.Discover.Collection.lavenderStart, UI.Discover.Collection.lavenderEnd),
            filterCriteria: FilterCriteria(ingredientKeywords: ["chicken", "pasta", "cheese", "cream", "potato"])
        ),
        CuratedCollection(
            id: "light_and_fresh",
            title: Strings.Discover.collectionLight,
            subtitle: Strings.Discover.collectionLightSubtitle,
            emoji: "🥗",
            gradientColors: (UI.Discover.Collection.freshStart, UI.Discover.Collection.freshEnd),
            filterCriteria: FilterCriteria(
                maxCookTime: 20,
                ingredientKeywords: ["salad", "spinach", "cucumber", "lettuce", "tomato"]
            )
        )
    ]

    // MARK: - Weekly Rotation

    func getCollectionsForThisWeek(isPremium: Bool) -> [CuratedCollection] {
        let weekOfYear = Calendar.current.component(.weekOfYear, from: Date())
        let all = Self.allCollections
        let startIndex = weekOfYear % all.count
        let rotated = (0..<3).map { all[(startIndex + $0) % all.count] }
        return isPremium ? rotated : Array(rotated.prefix(1))
    }

    // MARK: - Recipe Fetching

    func getRecipes(for collection: CuratedCollection) async throws -> [Recipe] {
        let criteria = collection.filterCriteria
        let keywords = criteria.ingredientKeywords ?? criteria.cuisineKeywords ?? []

        let rawRecipes: [Recipe]
        if keywords.isEmpty {
            rawRecipes = try dbInterface.getAllRecipes(offset: 0, limit: 100)
        } else {
            rawRecipes = try dbInterface.getRecipes(
                byIngredients: keywords.map { Ingredient(name: $0) },
                offset: 0,
                limit: 100
            )
        }

        return rawRecipes.filter { recipe in
            if let maxCount = criteria.maxIngredientCount {
                let count = recipe.cleanedIngredients.isEmpty ? recipe.ingredients.count : recipe.cleanedIngredients.count
                guard count <= maxCount else { return false }
            }
            if let maxTime = criteria.maxCookTime {
                guard let cookMinutes = recipe.cookTimeMinutes, cookMinutes <= maxTime else { return false }
            }
            if let complexity = criteria.complexityLevel {
                guard let recipeComplexity = recipe.complexityLevel else { return false }
                guard recipeComplexity.lowercased() == complexity.lowercased() else { return false }
            }
            return true
        }
    }
}

// MARK: - Recipe Cook Time Helper

private extension Recipe {
    var cookTimeMinutes: Int? {
        for info in additionalInfo.infos {
            if case .time(let timeString) = info {
                return parseMinutes(from: timeString)
            }
        }
        return nil
    }

    var complexityLevel: String? {
        for info in additionalInfo.infos {
            if case .complexity(let level) = info { return level }
        }
        return nil
    }

    /// Parses a cook-time string into total minutes.
    /// Handles formats like "30 min", "30m", "1 hr", "1 hr 30 min", "1h30m", "90", "25-30 min".
    /// For range strings like "25-30 min", uses the upper bound (most conservative for filtering).
    /// Returns nil when the format is unrecognisable to avoid false filtering.
    private func parseMinutes(from timeString: String) -> Int? {
        let s = timeString.lowercased()

        // Match hours and minutes separately using regex-free approach
        var totalMinutes = 0
        var matched = false

        // Extract hour component: look for a number before "h" or "hr" or "hour"
        let hourPattern = #"(\d+)\s*h"#
        if let range = s.range(of: hourPattern, options: .regularExpression),
           let numStr = s[range].components(separatedBy: CharacterSet.decimalDigits.inverted).first,
           let hours = Int(numStr) {
            totalMinutes += hours * 60
            matched = true
        }

        // Extract minute component: look for a number before "m" or "min"
        // Use last number before "m" to handle "1h30m" and "30 min"
        let minPattern = #"(\d+)\s*m(?:in)?"#
        // Find all matches and take the one that isn't part of the hour match
        var searchRange = s.startIndex..<s.endIndex
        while let range = s.range(of: minPattern, options: .regularExpression, range: searchRange) {
            let token = String(s[range])
            // Skip if this token contains "h" (i.e., it's the hour token, e.g. "1h")
            if !token.contains("h"),
               let numStr = token.components(separatedBy: CharacterSet.decimalDigits.inverted).first,
               let mins = Int(numStr) {
                totalMinutes += mins
                matched = true
                break
            }
            searchRange = range.upperBound..<s.endIndex
        }

        // Fallback: bare number with no unit (treat as minutes)
        if !matched {
            // Handle range like "25-30": take upper bound
            let numbers = s.components(separatedBy: CharacterSet.decimalDigits.inverted)
                .compactMap { Int($0) }
                .filter { $0 > 0 }
            guard let last = numbers.last else { return nil }
            return last
        }

        return totalMinutes > 0 ? totalMinutes : nil
    }
}
