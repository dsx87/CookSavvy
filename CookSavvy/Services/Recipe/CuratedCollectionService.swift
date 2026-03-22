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
    var complexityLevel: String? {
        for info in additionalInfo.infos {
            if case .complexity(let level) = info { return level }
        }
        return nil
    }
}
