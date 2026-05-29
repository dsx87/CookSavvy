//
//  Ingredient.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 30/06/2025.
//

import Foundation

// MARK: - IngredientAmount

/// A measured quantity paired with a unit of measurement.
///
/// `value` is optional to represent uncountable amounts such as "to taste" or "as needed".
/// Use `formatted(as:)` to render the amount in the user's preferred display style, including
/// automatic unit conversions between metric and imperial.
struct IngredientAmount: Codable, Hashable, Sendable {

    fileprivate enum ConversionDimension {
        case volume
        case mass
    }

    /// The unit of measurement for an ingredient quantity.
    enum Unit: String, Codable, CaseIterable, Sendable {
        // Volume – US
        case teaspoon    = "tsp"
        case tablespoon  = "tbsp"
        case cup         = "cup"
        case fluidOunce  = "fl oz"
        // Volume – metric
        case milliliter  = "ml"
        case liter       = "l"
        // Weight – US
        case ounce       = "oz"
        case pound       = "lb"
        // Weight – metric
        case gram        = "g"
        case kilogram    = "kg"
        // Count / pack
        case whole       = "whole"
        case clove       = "clove"
        case can         = "can"
        // Informal
        case pinch       = "pinch"
        case dash        = "dash"
        case handful     = "handful"
        // Uncountable
        case toTaste     = "to taste"
        case asNeeded    = "as needed"

        /// Broad conversion family for units with fixed culinary conversion factors.
        fileprivate var conversionDimension: ConversionDimension? {
            switch self {
            case .teaspoon, .tablespoon, .cup, .fluidOunce, .milliliter, .liter:
                return .volume
            case .ounce, .pound, .gram, .kilogram:
                return .mass
            default: return nil
            }
        }

        /// Multiplier from this unit into the dimension's base unit: milliliters for volume, grams for mass.
        fileprivate var baseUnitValue: Double? {
            switch self {
            case .teaspoon: return Conversion.tspToMl
            case .tablespoon: return Conversion.tbspToMl
            case .cup: return Conversion.cupToMl
            case .fluidOunce: return Conversion.flOzToMl
            case .milliliter: return 1
            case .liter: return 1_000
            case .ounce: return Conversion.ozToG
            case .pound: return Conversion.lbToG
            case .gram: return 1
            case .kilogram: return 1_000
            default: return nil
            }
        }
    }

    /// User-facing format for rendering a quantity.
    enum DisplayFormat {
        /// Renders the value as a Unicode fraction where possible (e.g. `¼ cup`); falls back to decimal.
        case fraction
        /// Renders the value as a decimal number (e.g. `0.25 cup`).
        case decimal
        /// Converts volume to ml / l and weight to g / kg.
        case metric
        /// Converts volume to tsp / tbsp / cup and weight to oz / lb.
        case imperial
    }

    /// Numeric quantity; `nil` for units like `.toTaste` and `.asNeeded` that carry no numeric value.
    let value: Double?
    /// The unit of measurement.
    let unit: Unit

    // MARK: - Unit conversions

    private enum Conversion {
        static let tspToMl: Double = 4.929
        static let tbspToMl: Double = 14.787
        static let cupToMl: Double = 236.588
        static let flOzToMl: Double = 29.574
        static let ozToG: Double = 28.350
        static let lbToG: Double = 453.592
    }

    /// Converts this amount to another compatible unit.
    ///
    /// Volume units can convert to other volume units, and mass units can convert to other mass
    /// units. Count, informal, and uncountable units only convert to the same unit because values
    /// such as "1 cup flour" -> "grams" require ingredient-specific density data.
    func converted(to targetUnit: Unit) -> IngredientAmount? {
        if targetUnit == unit { return self }
        guard let value,
              let sourceDimension = unit.conversionDimension,
              sourceDimension == targetUnit.conversionDimension,
              let sourceBaseUnitValue = unit.baseUnitValue,
              let targetBaseUnitValue = targetUnit.baseUnitValue else { return nil }

        return IngredientAmount(value: value * sourceBaseUnitValue / targetBaseUnitValue, unit: targetUnit)
    }

    /// Numeric value converted into another compatible unit.
    func value(in targetUnit: Unit) -> Double? {
        converted(to: targetUnit)?.value
    }

    /// Volume in millilitres; `nil` for non-volume units or when `value` is absent.
    var milliliters: Double? {
        value(in: .milliliter)
    }

    /// Mass in grams; `nil` for non-weight units or when `value` is absent.
    var grams: Double? {
        value(in: .gram)
    }

    // MARK: - Formatting

    /// Returns a human-readable representation of this amount in the requested display format.
    func formatted(as format: DisplayFormat) -> String {
        switch format {
        case .fraction:  return fractionString(value: value, unitLabel: unit.rawValue)
        case .decimal:   return decimalString()
        case .metric:    return metricString()
        case .imperial:  return imperialString()
        }
    }

    private func decimalString() -> String {
        guard let v = value else { return unit.rawValue }
        return "\(Self.formatDecimal(v)) \(unit.rawValue)"
    }

    private func metricString() -> String {
        if let ml = milliliters {
            return ml >= 1_000
                ? "\(Self.formatDecimal(ml / 1_000)) l"
                : "\(Self.formatDecimal(ml)) ml"
        }
        if let g = grams {
            return g >= 1_000
                ? "\(Self.formatDecimal(g / 1_000)) kg"
                : "\(Self.formatDecimal(g)) g"
        }
        return fractionString(value: value, unitLabel: unit.rawValue)
    }

    private func imperialString() -> String {
        if let ml = milliliters {
            let cups = IngredientAmount(value: ml, unit: .milliliter).value(in: .cup) ?? 0
            if cups >= 1 { return fractionString(value: cups, unitLabel: "cup") }
            let tbsp = IngredientAmount(value: ml, unit: .milliliter).value(in: .tablespoon) ?? 0
            if tbsp >= 1 { return fractionString(value: tbsp, unitLabel: "tbsp") }
            return fractionString(value: IngredientAmount(value: ml, unit: .milliliter).value(in: .teaspoon), unitLabel: "tsp")
        }
        if let g = grams {
            let lb = IngredientAmount(value: g, unit: .gram).value(in: .pound) ?? 0
            if lb >= 1 { return fractionString(value: lb, unitLabel: "lb") }
            return fractionString(value: IngredientAmount(value: g, unit: .gram).value(in: .ounce), unitLabel: "oz")
        }
        return fractionString(value: value, unitLabel: unit.rawValue)
    }

    private func fractionString(value: Double?, unitLabel: String) -> String {
        guard let v = value else { return unitLabel }
        let whole = Int(v)
        let frac = v - Double(whole)
        let symbol = Self.unicodeFraction(for: frac)
        let valueString: String
        if symbol.isEmpty {
            valueString = Self.formatDecimal(v)
        } else if whole == 0 {
            valueString = symbol
        } else {
            valueString = "\(whole)\(symbol)"
        }
        return "\(valueString) \(unitLabel)"
    }

    // Maps a fractional part (0.0–1.0) to the nearest Unicode fraction glyph within ±0.02 tolerance.
    private static func unicodeFraction(for fraction: Double) -> String {
        let table: [(Double, String)] = [
            (1.0/8, "⅛"), (1.0/4, "¼"), (1.0/3, "⅓"),
            (3.0/8, "⅜"), (1.0/2, "½"), (5.0/8, "⅝"),
            (2.0/3, "⅔"), (3.0/4, "¾"), (7.0/8, "⅞"),
        ]
        let tolerance = 0.02
        for (v, symbol) in table where abs(fraction - v) < tolerance { return symbol }
        return ""
    }

    private static func formatDecimal(_ value: Double) -> String {
        if value == Double(Int(value)) { return String(Int(value)) }
        return String(format: "%g", (value * 100).rounded() / 100)
    }
}

// MARK: - IngredientCategory

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
    /// Measured quantity for this ingredient (e.g. `1½ cups`); `nil` when no amount is specified.
    var amount: IngredientAmount?
    /// Preparation context or qualifier (e.g. `"finely chopped"`, `"at room temperature"`); `nil` when absent.
    var notes: String?

    /// Maps model property names to dataset field keys.
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case pictureFileName = "picture_file_name"
        case foodGroup       = "food_group"
        case foodSubgroup    = "food_subgroup"
        case amount
        case notes
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
        self.amount = nil
        self.notes = nil
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
    init(name: String, description: String?, pictureFileName: String?, foodGroup: String?, foodSubgroup: String?, emoji: String? = nil, amount: IngredientAmount? = nil, notes: String? = nil) {
        self.name = name
        self.description = description
        self.pictureFileName = pictureFileName
        self.foodGroup = foodGroup
        self.foodSubgroup = foodSubgroup
        self.emoji = emoji
        self.amount = amount
        self.notes = notes
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
