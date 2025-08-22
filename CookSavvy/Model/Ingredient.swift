//
//  Ingredient.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 30/06/2025.
//

import Foundation

import Foundation

struct Ingredient: Codable, Identifiable {
    
    static let empty: Ingredient = ""
    
    var id: String { name }
    let name: String
    let description: String?
    let pictureFileName: String?
    let foodGroup: String?
    let foodSubgroup: String?
    
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case pictureFileName = "picture_file_name"
        case foodGroup = "food_group"
        case foodSubgroup = "food_subgroup"
    }
    
    init(name: String) {
        self.name = name
        self.foodGroup = ""
        self.description = ""
        self.pictureFileName = ""
        self.foodSubgroup = ""
    }
}

extension Ingredient: Hashable {}

extension Ingredient: ExpressibleByStringLiteral {
    init(extendedGraphemeClusterLiteral value: String) {
        self.init(name: value)
    }
    
    init(stringLiteral value: StringLiteralType) {
        self.init(name: value)
    }
}

