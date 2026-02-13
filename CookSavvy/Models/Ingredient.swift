//
//  Ingredient.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 30/06/2025.
//

import Foundation

enum IngredientCategory: String, CaseIterable {
    case proteins
    case veggies
    case dairy
    case grains
    case fruits
    case spices
    case other
}

struct Ingredient: Codable, Identifiable {
    
    static let empty: Ingredient = ""
    
    var id: String { name }
    let name: String
    let description: String?
    let pictureFileName: String?
    let foodGroup: String?
    let foodSubgroup: String?
    var emoji: String?
    
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case pictureFileName = "picture_file_name"
        case foodGroup = "food_group"
        case foodSubgroup = "food_subgroup"
    }
    
    var category: IngredientCategory {
        guard let group = foodGroup?.lowercased(), !group.isEmpty else { return .other }
        switch group {
        case let g where g.contains("protein") || g.contains("meat") || g.contains("poultry") || g.contains("fish") || g.contains("seafood") || g.contains("egg"):
            return .proteins
        case let g where g.contains("vegetable") || g.contains("legume"):
            return .veggies
        case let g where g.contains("dairy") || g.contains("milk") || g.contains("cheese"):
            return .dairy
        case let g where g.contains("grain") || g.contains("cereal") || g.contains("bread") || g.contains("pasta") || g.contains("rice"):
            return .grains
        case let g where g.contains("fruit") || g.contains("berry") || g.contains("citrus"):
            return .fruits
        case let g where g.contains("spice") || g.contains("herb") || g.contains("seasoning") || g.contains("condiment"):
            return .spices
        default:
            return .other
        }
    }
    
    init(name: String) {
        self.name = name
        self.foodGroup = nil
        self.description = nil
        self.pictureFileName = nil
        self.foodSubgroup = nil
        self.emoji = nil
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


// MARK: - Full initializer for richer mocks
extension Ingredient {
    init(name: String, description: String?, pictureFileName: String?, foodGroup: String?, foodSubgroup: String?, emoji: String? = nil) {
        self.name = name
        self.description = description
        self.pictureFileName = pictureFileName
        self.foodGroup = foodGroup
        self.foodSubgroup = foodSubgroup
        self.emoji = emoji
    }
}

// MARK: - Mock Factories for Testing
extension Ingredient {
    struct Entry { let name: String; let group: String; let subgroup: String; let picture: String? }

    /// Creates a single mock `Ingredient` with meaningful randomized values.
    static func mockRandom<R: RandomNumberGenerator>(rng: inout R) -> Ingredient {
        let entries: [Entry] = [
            .init(name: "Garlic", group: "Vegetables", subgroup: "Alliums", picture: "garlic.png"),
            .init(name: "Onion", group: "Vegetables", subgroup: "Alliums", picture: "onion.png"),
            .init(name: "Chicken Breast", group: "Protein", subgroup: "Poultry", picture: "chicken_breast.png"),
            .init(name: "Salmon Fillet", group: "Protein", subgroup: "Fish", picture: "salmon.png"),
            .init(name: "Tofu", group: "Protein", subgroup: "Soy", picture: "tofu.png"),
            .init(name: "Bell Pepper", group: "Vegetables", subgroup: "Peppers", picture: "bell_pepper.png"),
            .init(name: "Spinach", group: "Vegetables", subgroup: "Leafy Greens", picture: "spinach.png"),
            .init(name: "Tomato", group: "Vegetables", subgroup: "Fruit Vegetables", picture: "tomato.png"),
            .init(name: "Pasta", group: "Grains", subgroup: "Wheat", picture: "pasta.png"),
            .init(name: "Rice", group: "Grains", subgroup: "Cereal Grains", picture: "rice.png"),
            .init(name: "Quinoa", group: "Grains", subgroup: "Pseudocereals", picture: "quinoa.png"),
            .init(name: "Lemon", group: "Fruits", subgroup: "Citrus", picture: "lemon.png"),
            .init(name: "Basil", group: "Herbs & Spices", subgroup: "Herbs", picture: "basil.png"),
            .init(name: "Parsley", group: "Herbs & Spices", subgroup: "Herbs", picture: "parsley.png"),
            .init(name: "Coconut Milk", group: "Dairy Alternatives", subgroup: "Coconut", picture: "coconut_milk.png")
        ]

        let picked = entries.randomElement(using: &rng)!

        let descriptors = [
            "fresh", "organic", "ripe", "finely chopped", "minced", "diced", "grated", "zested"
        ]
        let uses = [
            "Perfect for sauces and marinades.",
            "Great in soups, stews and stir-fries.",
            "Adds brightness and aroma to dishes.",
            "Staple pantry ingredient.",
            "Complements pasta and grain bowls."
        ]
        let desc = "\(descriptors.randomElement(using: &rng)!) \(picked.name.lowercased()). \(uses.randomElement(using: &rng)!)"

        return Ingredient(
            name: picked.name,
            description: desc,
            pictureFileName: picked.picture,
            foodGroup: picked.group,
            foodSubgroup: picked.subgroup
        )
    }

    /// Convenience overload that uses the system RNG.
    static func mockRandom() -> Ingredient {
        var rng = SystemRandomNumberGenerator()
        return mockRandom(rng: &rng)
    }

    /// Creates multiple mock ingredients.
    static func mocks(count: Int) -> [Ingredient] {
        var rng = SystemRandomNumberGenerator()
        return (0..<max(0, count)).map { _ in mockRandom(rng: &rng) }
    }
}
