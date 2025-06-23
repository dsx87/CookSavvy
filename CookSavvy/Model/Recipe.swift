//
//  Recipe.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 30/04/2025.
//

import Foundation

struct Recipe: Codable, Identifiable, Hashable {
    var id: String { title }
    let title: String
    let ingredients: [String]
    let instructions: [String]
    let image: String
    let cleanedIngredients: [String]
    
    enum CodingKeys: String, CodingKey {
        case title = "Title"
        case ingredients = "Ingredients"
        case instructions = "Instructions"
        case image = "Image_Name"
        case cleanedIngredients = "Cleaned_Ingredients"
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
        
    }
}


