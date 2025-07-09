//
//  Recipe.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 30/04/2025.
//

import Foundation

struct Recipe: Codable, Identifiable, Hashable {
    
    struct AdditionalInfo: Codable, Hashable {
        static let empty = AdditionalInfo(time: nil, servings: nil, complexity: nil)
        let time: String?
        let servings: Int?
        let complexity: String?
    }
    
    var id: String { title }
    let title: String
    let ingredients: [String]
    let instructions: [String]
    let image: String
    let cleanedIngredients: [String]
    let additionalInfo: AdditionalInfo
    
    enum CodingKeys: String, CodingKey {
        case title = "Title"
        case ingredients = "Ingredients"
        case instructions = "Instructions"
        case image = "Image_Name"
        case cleanedIngredients = "Cleaned_Ingredients"
        case additionalInfo = "additionalInfo"
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.title = try container.decode(String.self, forKey: .title)
        let rawIngredients = try container.decode(String.self, forKey: .ingredients)
        self.ingredients = rawIngredients.separatedByQuotes
        let rawInstructions = try container.decode(String.self, forKey: .instructions)
        self.instructions = rawInstructions.components(separatedBy: "\n")
        self.image = try container.decode(String.self, forKey: .image)
        let rawCleanedIngredients = try container.decode(String.self, forKey: .cleanedIngredients)
        self.cleanedIngredients = rawCleanedIngredients.separatedByQuotes
        self.additionalInfo = try container.decodeIfPresent(AdditionalInfo.self, forKey: .additionalInfo) ?? .empty
    }
    
    // Mock init
    init() {
        self.title = "Mock Title"
        self.ingredients = [
            "Some Ingredient",
            "Some Ingredient",
            "Some Ingredient",
            "Some Ingredient",
            "Some Ingredient",
        ]
        self.image = ""
        self.instructions = [
            "some instruction",
            "some instruction",
            "some instruction",
            "some instruction",
            "some instruction",
            "some instruction",
        ]
        self.cleanedIngredients = []
        self.additionalInfo = .init(time: "10 mins", servings: 3, complexity: "easy")
    }
}


