import SwiftUI

struct CuratedCollection: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let emoji: String
    let gradientColors: (Color, Color)
    let filterCriteria: FilterCriteria
}

struct FilterCriteria {
    let maxCookTime: Int?
    let maxIngredientCount: Int?
    let cuisineKeywords: [String]?
    let ingredientKeywords: [String]?
    let complexityLevel: String?

    init(
        maxCookTime: Int? = nil,
        maxIngredientCount: Int? = nil,
        cuisineKeywords: [String]? = nil,
        ingredientKeywords: [String]? = nil,
        complexityLevel: String? = nil
    ) {
        self.maxCookTime = maxCookTime
        self.maxIngredientCount = maxIngredientCount
        self.cuisineKeywords = cuisineKeywords
        self.ingredientKeywords = ingredientKeywords
        self.complexityLevel = complexityLevel
    }
}
