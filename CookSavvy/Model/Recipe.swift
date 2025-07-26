//
//  Recipe.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 30/04/2025.
//

import Foundation

struct Recipe {
    
    struct AdditionalInfo: Codable, Hashable {
        
        enum InfoType: Codable, Hashable {
            case time(String)
            case servings(Int)
            case complexity(String)
            case calories(Int)
            case empty
            
            var title: String {
                switch self {
                case .time(_): "Time"
                case .servings(_): "Servings"
                case .complexity(_): "Complexity"
                case .calories(_): "Calories"
                case .empty: ""
                }
            }
            
            var asEmoji: String {
                switch self {
                case .time(_): "⏱️"
                case .servings(_): "👥"
                case .complexity(_): "📊"
                case .calories(_): "⚡️"
                case .empty: ""
                }
            }
            
            var stringValue: String {
                switch self {
                case .time(let string): string
                case .servings(let int): String(int)
                case .complexity(let string): string
                case .calories(let int): String(int)
                case .empty: ""
                }
            }
        }
        
        static let empty = AdditionalInfo()
        static let mock = AdditionalInfo(time: "10 Min", servings: 2, complexity: "Low", calories: 250)
        let infos: [InfoType]
        
        init() {
            self.infos = []
        }
        
        init(time: String?, servings: Int?, complexity: String?, calories: Int?) {
            var infos: [InfoType] = []
            if let time { infos.append(.time(time)) }
            if let servings { infos.append(.servings(servings)) }
            if let complexity { infos.append(.complexity(complexity)) }
            if let calories { infos.append(.calories(calories)) }
            self.infos = infos
        }
        
        init(availableInfos: [InfoType]) {
            self.infos = availableInfos
        }
    }
    
    let title: String
    let ingredients: [Ingredient]
    let instructions: [String]
    let image: String
    let cleanedIngredients: [Ingredient]
    let additionalInfo: AdditionalInfo
    
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
        self.additionalInfo = .init(time: "10 mins", servings: 3, complexity: "easy", calories: 250)
    }
}

extension Recipe: Identifiable {
    var id: String { title }
}

extension Recipe: Hashable {}

extension Recipe: Codable {
    
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
        self.ingredients = rawIngredients.separatedByQuotes.map(Ingredient.init(stringLiteral:))
        let rawInstructions = try container.decode(String.self, forKey: .instructions)
        self.instructions = rawInstructions.components(separatedBy: "\n")
        self.image = try container.decode(String.self, forKey: .image)
        let rawCleanedIngredients = try container.decode(String.self, forKey: .cleanedIngredients)
        self.cleanedIngredients = rawCleanedIngredients.separatedByQuotes.map(Ingredient.init(stringLiteral:))
        self.additionalInfo = try container.decodeIfPresent(AdditionalInfo.self, forKey: .additionalInfo) ?? .empty
    }
    
}
