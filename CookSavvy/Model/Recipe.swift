//
//  Recipe.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 30/04/2025.
//

import Foundation

struct Recipe: Codable, Identifiable {
    let id: UUID = UUID()
    let title: String
    let ingredients: [String]
    let instructions: String
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
        self.instructions = try container.decode(String.self, forKey: .instructions)
        self.image = try container.decode(String.self, forKey: .image)
        let rawCleanedIngredients = try container.decode(String.self, forKey: .cleanedIngredients)
        self.cleanedIngredients = rawCleanedIngredients.separatedByQuotes
    }
}

extension String {
    var separatedByQuotes: [String] {
        var r = self.ranges(of: "'")
        if r.count % 2 != 0 {
            r.removeLast()
        }
        let res = stride(from: r.startIndex, to: r.endIndex, by: 2).map { idx in
            let start = r[idx]
            let finish = r[idx+1]
            return String(self[start.upperBound..<finish.lowerBound])
        }
        return res
    }
}
