import Foundation
import SwiftUI

// MARK: - Protocol

/// Interface for retrieving curated recipe collections shown on the Discover screen.
protocol CuratedCollectionServiceProtocol {

    /// Returns the collections to display in the current calendar week.
    /// - Parameter isPremium: When `true`, returns 3 rotated collections; otherwise 1.
    func getCollectionsForThisWeek(isPremium: Bool) -> [CuratedCollection]

    /// Fetches recipes that satisfy the filter criteria of `collection`.
    /// - Parameter collection: The curated collection whose criteria define the query.
    /// - Returns: Recipes matching all of the collection's filter constraints.
    /// - Throws: `RecipeSourceError.databaseError` on read failures.
    func getRecipes(for collection: CuratedCollection) async throws -> [Recipe]
}

// MARK: - Implementation

/// Manages the catalogue of curated recipe collections and fetches their recipes from the database.
///
/// Collections are statically defined and surfaced to users via a weekly rotation driven by
/// `Calendar.current.weekOfYear`, so the featured collections change automatically each week
/// without any server-side configuration.
final class CuratedCollectionService: CuratedCollectionServiceProtocol {

    /// Database interface used to query recipes matching collection criteria.
    private let dbInterface: RecipeStoreProtocol

    /// - Parameter dbInterface: Database interface for recipe queries.
    init(dbInterface: RecipeStoreProtocol) {
        self.dbInterface = dbInterface
    }

    // MARK: - All Collections

    /// The complete catalogue of curated collections. Add new collections here; the weekly
    /// rotation selects 3 from this list using the current `weekOfYear` as an offset.
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

    /// Returns the collections to show in the current calendar week.
    ///
    /// The starting index into `allCollections` is derived from `weekOfYear % count`, cycling
    /// through the catalogue so each week features a different set. Free users see only the
    /// first collection from the rotated set; Premium users see all three.
    /// - Parameter isPremium: Controls how many collections are returned (1 vs. 3).
    func getCollectionsForThisWeek(isPremium: Bool) -> [CuratedCollection] {
        let weekOfYear = Calendar.current.component(.weekOfYear, from: Date())
        let all = Self.allCollections
        let startIndex = weekOfYear % all.count
        let rotated = (0..<3).map { all[(startIndex + $0) % all.count] }
        return isPremium ? rotated : Array(rotated.prefix(1))
    }

    // MARK: - Recipe Fetching

    /// Fetches and filters recipes that satisfy the collection's `FilterCriteria`.
    ///
    /// If the criteria include ingredient or cuisine keywords, the database is queried with
    /// those keywords as synthetic ingredients. When no keywords are present, all recipes are
    /// loaded and then filtered in-memory by `maxIngredientCount`, `maxCookTime`, and
    /// `complexityLevel`.
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
                let count = recipe.cleanedIngredients.count
                guard count <= maxCount else { return false }
            }
            if let maxTime = criteria.maxCookTime {
                if let cookMinutes = recipe.cookTimeMinutes {
                    guard cookMinutes <= maxTime else { return false }
                }
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

/// Recipe-level helpers local to curated collection filtering.
private extension Recipe {
    /// Extracts the recipe's complexity level string from its `AdditionalInfo`, or `nil` if absent.
    var complexityLevel: String? {
        for info in additionalInfo.infos {
            if case .complexity(let level) = info { return level }
        }
        return nil
    }
}
