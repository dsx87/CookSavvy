//
//  ShoppingItem.swift
//  CookSavvy
//

import Foundation

/// A single row in the premium shopping list.
struct ShoppingItem: Identifiable, Equatable {
    /// Unique database row identifier.
    let id: Int
    /// Display name of the ingredient to purchase.
    var name: String
    /// Whether the user has checked off this item.
    var isChecked: Bool
    /// The date the item was added to the list.
    var addedAt: Date
    /// The recipe that triggered adding this item, if any.
    var recipeTitle: String?
}
