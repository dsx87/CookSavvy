//
//  ShoppingItem.swift
//  CookSavvy
//

import Foundation

struct ShoppingItem: Identifiable, Equatable {
    let id: Int
    var name: String
    var isChecked: Bool
    var addedAt: Date
    var recipeTitle: String?
}
