//
//  Ingredient.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 30/06/2025.
//

import Foundation

struct Ingredient: Hashable, Codable, Identifiable {
    
    static let empty: Ingredient = ""
    
    var id: String { emoji + name }
    let name: String
    let emoji: String
    
    init(name: String, emoji: String) {
        self.name = name
        self.emoji = emoji
    }
}

extension Ingredient: ExpressibleByStringLiteral {
    init(extendedGraphemeClusterLiteral value: String) {
        if let emoji = value.firstCharAsEmoji {
            self.emoji = String(emoji)
            self.name = String(value.dropFirst())
        } else {
            self.emoji = ""
            self.name = value
        }
    }
    
    init(stringLiteral value: StringLiteralType) {
        if let emoji = value.firstCharAsEmoji {
            self.emoji = String(emoji)
            self.name = String(value.dropFirst())
        } else {
            self.emoji = ""
            self.name = value
        }
    }
}

