import SwiftUI

/// A named grouping of recipes shown on the Discover screen.
///
/// Each collection has a visual identity (emoji, gradient) and a ``FilterCriteria``
/// instance used to select matching recipes from the local or remote catalogue.
struct CuratedCollection: Identifiable {
    /// Stable identifier for the collection.
    let id: String
    /// Headline shown on the collection card (e.g. `"Quick Weeknight Dinners"`).
    let title: String
    /// Supporting text displayed beneath the title.
    let subtitle: String
    /// Emoji icon representing the collection's theme.
    let emoji: String
    /// Pair of colours used to render the card's gradient background.
    let gradientColors: (Color, Color)
    /// Recipe-matching rules applied when the collection is opened.
    let filterCriteria: FilterCriteria
}

/// Defines the recipe-matching rules for a ``CuratedCollection``.
///
/// All non-`nil` fields act as AND-combined filters; `nil` means no constraint on that axis.
struct FilterCriteria {
    /// Maximum total cook time in minutes a recipe may have to qualify.
    let maxCookTime: Int?
    /// Maximum ingredient count a recipe may have to qualify.
    let maxIngredientCount: Int?
    /// Keywords that must appear in the recipe's cuisine or title (case-insensitive).
    let cuisineKeywords: [String]?
    /// Keywords that must appear in at least one ingredient name (case-insensitive).
    let ingredientKeywords: [String]?
    /// Complexity level a recipe must match (e.g. `"Easy"`).
    let complexityLevel: String?

    /// Creates filter criteria with any combination of constraints; all parameters default to `nil` (unconstrained).
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
