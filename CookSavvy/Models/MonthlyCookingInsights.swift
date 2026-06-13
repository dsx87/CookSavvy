import Foundation

/// Premium monthly cooking summary shown on My Kitchen.
///
/// The savings amount is an approximate product estimate, not a personal finance
/// calculation. It is derived from monthly cooked meals and must stay labelled
/// as approximate wherever displayed.
nonisolated struct MonthlyCookingInsights: Equatable {
    /// Number of cooking sessions recorded during the current calendar month.
    let mealsCooked: Int
    /// Number of distinct ingredients used across current-month cooking sessions.
    let uniqueIngredientsUsed: Int
    /// Approximate whole-currency savings estimate for the current month.
    let estimatedSavingsAmount: Int
    /// ISO currency code for the savings estimate.
    let currencyCode: String
    /// Whether the savings estimate is approximate and should be displayed with caveat copy.
    let isApproximate: Bool
}
