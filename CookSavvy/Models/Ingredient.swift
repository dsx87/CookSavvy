//
//  Ingredient.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 30/06/2025.
//

import Foundation

/// Broad food-group categories used to organise ingredients in the UI.
enum IngredientCategory: String, CaseIterable {
    /// Meat, poultry, fish, seafood, eggs, and plant-based proteins.
    case proteins
    /// Vegetables and legumes.
    case veggies
    /// Milk, cheese, butter, yogurt, and other dairy products.
    case dairy
    /// Grains, cereals, bread, pasta, and rice.
    case grains
    /// Fresh and dried fruits.
    case fruits
    /// Herbs, spices, seasonings, and condiments.
    case spices
    /// Anything that does not fit a more specific category.
    case other
}

/// A single food ingredient identified by name.
///
/// Ingredients are stored in the database and referenced by recipes. The `emoji`
/// property is populated lazily by ``IngredientEmojiProvider`` before display.
struct Ingredient: Codable, Identifiable {
    
    /// A placeholder ingredient with an empty name, used as a safe default value.
    static let empty: Ingredient = ""
    
    /// The unique identifier for this ingredient, derived from its `name`.
    var id: String { name }
    /// The canonical name of the ingredient (e.g. `"Chicken Breast"`).
    let name: String
    /// Optional freeform description of the ingredient.
    let description: String?
    /// Optional filename of the ingredient's photo asset.
    let pictureFileName: String?
    /// Broad food group from the dataset (e.g. `"Protein"`, `"Vegetables"`).
    let foodGroup: String?
    /// More specific subgroup within `foodGroup` (e.g. `"Poultry"`, `"Leafy Greens"`).
    let foodSubgroup: String?
    /// Resolved emoji for display, populated by ``IngredientEmojiProvider``.
    var emoji: String?
    
    /// Maps model property names to dataset field keys.
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case pictureFileName = "picture_file_name"
        case foodGroup = "food_group"
        case foodSubgroup = "food_subgroup"
    }
    
    /// Derives a broad ``IngredientCategory`` by matching `foodGroup` against known keyword patterns.
    ///
    /// The mapping is intentionally liberal — any `foodGroup` containing `"protein"` or `"meat"`
    /// resolves to `.proteins`, for example. Falls back to `.other` for unrecognised groups.
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
    
    /// Creates a minimal ingredient with only a name; all other fields are `nil`.
    init(name: String) {
        self.name = name
        self.foodGroup = nil
        self.description = nil
        self.pictureFileName = nil
        self.foodSubgroup = nil
        self.emoji = nil
    }
}

/// Hashability allows ingredient values to be de-duplicated in sets and diffable collections.
extension Ingredient: Hashable {}
/// `Sendable` enables safe transfer of ingredient values across concurrency boundaries.
extension Ingredient: Sendable {}
/// `Sendable` conformance for category values used in async view-model code.
extension IngredientCategory: Sendable {}

/// String-literal conveniences for concise ingredient construction in tests and mocks.
extension Ingredient: ExpressibleByStringLiteral {
    /// Creates an ingredient from a grapheme-cluster string literal.
    init(extendedGraphemeClusterLiteral value: String) {
        self.init(name: value)
    }
    
    /// Creates an ingredient from a regular string literal.
    init(stringLiteral value: StringLiteralType) {
        self.init(name: value)
    }
}


// MARK: - Full initializer for richer mocks
/// Additional initializers used by previews and richer mock fixtures.
extension Ingredient {
    /// Creates an ingredient with all fields populated; used by test helpers and mock factories.
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
/// Randomized mock factory helpers for design-time previews and tests.
extension Ingredient {
    /// Internal helper used by `mockRandom` to bundle name, group, and asset info.
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
