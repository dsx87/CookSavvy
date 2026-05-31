//
//  Recipe.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 30/04/2025.
//

import Foundation
import CoreTransferable

/// The core recipe model representing a dish with ingredients, steps, and metadata.
///
/// A `Recipe` may originate from the local SQLite database (`OfflineRecipeSource`),
/// the Supabase backend (`OnlineRecipeSource`), or be AI-generated (`AIRecipeSource`).
/// Optional fields such as `matchPercentage` and `missingIngredients` are populated
/// by the recommendation engine at query time and are not persisted.
struct Recipe {

    /// A single instruction step, optionally paired with a countdown timer.
    struct Step: Codable, Hashable {
        /// The instruction text shown to the user in Cook Mode.
        let text: String
        /// Optional timer duration in minutes suggested for this step.
        let timerMinutes: Int?

        /// Creates a step with instruction text and an optional timer.
        init(text: String, timerMinutes: Int? = nil) {
            self.text = text
            self.timerMinutes = timerMinutes
        }

        /// Creates a step from a plain text string with no timer.
        init(plainText string: String) {
            self.text = string
            self.timerMinutes = nil
        }

        private enum CodingKeys: CodingKey { case text, timerMinutes }

        /// Decodes from either a plain string (bundled JSON format) or a keyed object (DB storage format).
        init(from decoder: any Decoder) throws {
            if let text = try? decoder.singleValueContainer().decode(String.self) {
                self.text = text
                self.timerMinutes = nil
            } else {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                self.text = try container.decode(String.self, forKey: .text)
                self.timerMinutes = try container.decodeIfPresent(Int.self, forKey: .timerMinutes)
            }
        }

        /// Encodes as a keyed object so `timerMinutes` survives DB round-trips.
        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(text, forKey: .text)
            try container.encodeIfPresent(timerMinutes, forKey: .timerMinutes)
        }
    }

    /// A collection of structured metadata items shown in the recipe stats row.
    ///
    /// Holds any combination of time, servings, complexity, and calorie values.
    /// Only non-`nil` values passed to the designated initialiser are included.
    struct AdditionalInfo: Codable, Hashable {
        
        /// Discriminated union representing one piece of recipe metadata.
        enum InfoType: Codable, Hashable {
            /// Total cook time as a human-readable string (e.g. `"30 min"`).
            case time(String)
            /// Number of servings.
            case servings(Int)
            /// Difficulty label (e.g. `"Easy"`, `"Medium"`, `"Hard"`).
            case complexity(String)
            /// Approximate calorie count.
            case calories(Int)
            /// Sentinel value used when a slot in the stats row has no data.
            case empty
            
            /// Short label displayed above the value in the stats row.
            var title: String {
                switch self {
                case .time(_): "Time"
                case .servings(_): "Servings"
                case .complexity(_): "Complexity"
                case .calories(_): "Calories"
                case .empty: ""
                }
            }
            
            /// Emoji icon representing this info type in the stats row.
            var asEmoji: String {
                switch self {
                case .time(_): "⏱️"
                case .servings(_): "👥"
                case .complexity(_): "📊"
                case .calories(_): "⚡️"
                case .empty: ""
                }
            }
            
            /// The info's underlying value as a string, suitable for display in the stats row.
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
        
        /// An `AdditionalInfo` instance with no metadata, used as a safe default.
        static let empty = AdditionalInfo()
        /// A pre-populated instance used in SwiftUI previews and tests.
        static let mock = AdditionalInfo(time: "10 Min", servings: 2, complexity: "Low", calories: 250)
        /// The ordered list of info items to display in the stats row.
        let infos: [InfoType]
        
        /// Creates an empty `AdditionalInfo` with no metadata items.
        init() {
            self.infos = []
        }
        
        /// Creates an `AdditionalInfo` from optional metadata values; only non-`nil` values are included.
        init(time: String?, servings: Int?, complexity: String?, calories: Int?) {
            var infos: [InfoType] = []
            if let time { infos.append(.time(time)) }
            if let servings { infos.append(.servings(servings)) }
            if let complexity { infos.append(.complexity(complexity)) }
            if let calories { infos.append(.calories(calories)) }
            self.infos = infos
        }
        
        /// Creates an `AdditionalInfo` from a pre-built array of info items.
        init(availableInfos: [InfoType]) {
            self.infos = availableInfos
        }
    }
    
    /// The display title of the recipe.
    let title: String
    /// The full ingredient list as parsed from the data source, may include quantities and notes.
    let ingredients: [Ingredient]
    /// Ordered preparation steps.
    let instructions: [Step]
    /// Image asset name or URL string used to load the hero image.
    let image: String
    /// Structured metadata (time, servings, complexity, calories) shown in the stats row.
    let additionalInfo: AdditionalInfo
    /// The data source that produced this recipe (offline, online, or AI).
    var source: RecipeSourceType?
    /// Short marketing hook shown on recipe cards (e.g. `"Ready in 20 minutes"`).
    var tagline: String?
    /// User-assigned rating (0.0–5.0), persisted in the database.
    var userRating: Double?
    /// Rating sourced from the remote API, if available.
    var apiRating: Double?
    /// Author name, populated for user-created and API-sourced recipes.
    var author: String?
    /// `true` when the recipe was created by the user through the Create Recipe wizard.
    var isUserCreated: Bool
    /// Emoji representing the recipe's main ingredient or cuisine, used on cards.
    var emoji: String?
    /// Cuisine label (e.g. `"Italian"`, `"Mexican"`), sourced from the API or user input.
    var cuisine: String?
    /// How well this recipe matches the user's current ingredient selection (0.0–1.0).
    var matchPercentage: Double?
    /// Human-readable explanation of why this recipe was recommended.
    var matchReason: String?
    /// Ingredients required by the recipe that the user needs to buy.
    var missingIngredients: [String]?
    /// Runtime-only staples assumed to be available, but not saved in the user's pantry.
    var assumedPantryIngredients: [String]?

    /// Creates a recipe where instructions are provided as pre-structured `Step` values.
    init(
        title: String,
        ingredients: [Ingredient],
        instructions: [Step],
        image: String,
        additionalInfo: AdditionalInfo,
        source: RecipeSourceType? = nil,
        tagline: String? = nil,
        userRating: Double? = nil,
        apiRating: Double? = nil,
        author: String? = nil,
        isUserCreated: Bool = false,
        emoji: String? = nil,
        cuisine: String? = nil,
        matchPercentage: Double? = nil,
        matchReason: String? = nil,
        missingIngredients: [String]? = nil,
        assumedPantryIngredients: [String]? = nil
    ) {
        self.title = title
        self.ingredients = ingredients
        self.instructions = instructions
        self.image = image
        self.additionalInfo = additionalInfo
        self.source = source
        self.tagline = tagline
        self.userRating = userRating
        self.apiRating = apiRating
        self.author = author
        self.isUserCreated = isUserCreated
        self.emoji = emoji
        self.cuisine = cuisine
        self.matchPercentage = matchPercentage
        self.matchReason = matchReason
        self.missingIngredients = missingIngredients
        self.assumedPantryIngredients = assumedPantryIngredients
    }

    /// Creates a recipe where instructions are provided as plain strings; each string is wrapped in a `Step`.
    init(
        title: String,
        ingredients: [Ingredient],
        instructions: [String],
        image: String,
        additionalInfo: AdditionalInfo,
        source: RecipeSourceType? = nil,
        tagline: String? = nil,
        userRating: Double? = nil,
        apiRating: Double? = nil,
        author: String? = nil,
        isUserCreated: Bool = false,
        emoji: String? = nil,
        cuisine: String? = nil,
        matchPercentage: Double? = nil,
        matchReason: String? = nil,
        missingIngredients: [String]? = nil,
        assumedPantryIngredients: [String]? = nil
    ) {
        self.init(
            title: title,
            ingredients: ingredients,
            instructions: instructions.map(Step.init(plainText:)),
            image: image,
            additionalInfo: additionalInfo,
            source: source,
            tagline: tagline,
            userRating: userRating,
            apiRating: apiRating,
            author: author,
            isUserCreated: isUserCreated,
            emoji: emoji,
            cuisine: cuisine,
            matchPercentage: matchPercentage,
            matchReason: matchReason,
            missingIngredients: missingIngredients,
            assumedPantryIngredients: assumedPantryIngredients
        )
    }

    // Mock init
    /// Creates a recipe using ``mockRandom()``; used in SwiftUI previews.
    init() {
        self = Self.mockRandom()
    }
}

/// Identifiable conformance for SwiftUI lists and navigation.
extension Recipe: Identifiable {
    /// Uses `title` as the stable identifier; recipe titles are unique within the local dataset.
    var id: String { title }
}

/// Hashability enables recipe de-duplication and set operations.
extension Recipe: Hashable {}
/// `Sendable` conformance for recipe values transferred across task boundaries.
extension Recipe: Sendable {}
/// `Sendable` conformance for nested `Step` values.
extension Recipe.Step: Sendable {}
/// `Sendable` conformance for nested additional-info payloads.
extension Recipe.AdditionalInfo: Sendable {}
/// `Sendable` conformance for additional-info discriminated union cases.
extension Recipe.AdditionalInfo.InfoType: Sendable {}

/// Custom Codable for InfoType using flat single-key dicts: {"time": "30 min"}, {"servings": 4}.
/// This replaces the synthesised format which wraps values in {"_0": ...}.
extension Recipe.AdditionalInfo.InfoType {
    private enum CodingKeys: String, CodingKey {
        case time, servings, complexity, calories
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let v = try c.decodeIfPresent(String.self, forKey: .time)       { self = .time(v);       return }
        if let v = try c.decodeIfPresent(Int.self,    forKey: .servings)   { self = .servings(v);   return }
        if let v = try c.decodeIfPresent(String.self, forKey: .complexity) { self = .complexity(v); return }
        if let v = try c.decodeIfPresent(Int.self,    forKey: .calories)   { self = .calories(v);   return }
        self = .empty
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .time(let v):       try c.encode(v, forKey: .time)
        case .servings(let v):   try c.encode(v, forKey: .servings)
        case .complexity(let v): try c.encode(v, forKey: .complexity)
        case .calories(let v):   try c.encode(v, forKey: .calories)
        case .empty:             break
        }
    }
}

/// Computed helpers derived directly from stored recipe data.
extension Recipe {
    /// Deduplicated ingredient list used for recipe-ingredient matching.
    ///
    /// Previously stored as a separate field; now derived from `ingredients` so there is a single
    /// source of truth. Preserves first-occurrence order and de-duplicates by name.
    var cleanedIngredients: [Ingredient] {
        var seen = Set<String>()
        return ingredients.filter { seen.insert($0.name).inserted }
    }
}

/// Derived metadata helpers built from recipe content.
extension Recipe {
    /// The recipe's cook time in minutes, derived by parsing the `time` entry in `additionalInfo`.
    /// Returns `nil` when no time info is present or the format cannot be parsed.
    var cookTimeMinutes: Int? {
        for info in additionalInfo.infos {
            if case .time(let timeString) = info {
                return Self.parseCookTimeMinutes(from: timeString)
            }
        }
        return nil
    }

    /// Parses a cook-time string into total minutes.
    /// Handles formats like "30 min", "30m", "1 hr", "1 hr 30 min", "1h30m", "1h30", "90", "25-30 min".
    /// For range strings like "25-30 min", uses the upper bound (most conservative for filtering).
    /// Returns nil when the format is unrecognisable to avoid false filtering.
    private static func parseCookTimeMinutes(from timeString: String) -> Int? {
        let s = timeString.lowercased()

        // Combined hour + minute: "1h30m", "1 hr 30 min", "1h30" (bare minutes with no 'm' suffix)
        let combinedPattern = #"(\d+)\s*h(?:r|our|ours)?\s*(\d+)"#
        if let range = s.range(of: combinedPattern, options: .regularExpression) {
            let numbers = s[range]
                .components(separatedBy: CharacterSet.decimalDigits.inverted)
                .compactMap(Int.init)
            if numbers.count >= 2 {
                return numbers[0] * 60 + numbers[1]
            }
        }

        // Hours only: "1h", "1 hr", "2 hours"
        let hourPattern = #"(\d+)\s*h"#
        if let range = s.range(of: hourPattern, options: .regularExpression),
           let hours = s[range]
               .components(separatedBy: CharacterSet.decimalDigits.inverted)
               .compactMap(Int.init)
               .first {
            return hours * 60
        }

        // Minutes with explicit unit: "30 min", "30m", "25-30 min" (upper bound for ranges)
        let minutePattern = #"(\d+)\s*m(?:in)?"#
        var searchRange = s.startIndex..<s.endIndex
        while let range = s.range(of: minutePattern, options: .regularExpression, range: searchRange) {
            let token = String(s[range])
            if !token.contains("h"),
               let minutes = token
                   .components(separatedBy: CharacterSet.decimalDigits.inverted)
                   .compactMap(Int.init)
                   .first {
                return minutes
            }
            searchRange = range.upperBound..<s.endIndex
        }

        // Bare number fallback (treat as minutes): "90", "25-30" → upper bound
        let numbers = s.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap(Int.init)
            .filter { $0 > 0 }
        return numbers.last
    }
}

// MARK: - Transferable (Sharing)

/// Share-sheet integration using plain-text recipe representation.
extension Recipe: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation { $0.shareText }
    }

    /// A plaintext representation of the recipe used by the system share sheet.
    var shareText: String {
        var lines = [title, "", "Ingredients:"]
        lines += ingredients.map { "- \($0.name)" }
        lines += ["", "Steps:"]
        lines += instructions.enumerated().map { "\($0.offset + 1). \($0.element.text)" }
        lines += ["", "Shared from CookSavvy"]
        return lines.joined(separator: "\n")
    }
}

// MARK: - Mock Factories for Testing
/// Randomized mock recipe builders for previews and test fixtures.
extension Recipe {
    /// Creates a single mock `Recipe` with meaningful randomized values.
    /// - Parameter rng: Optional random number generator for deterministic tests.
    /// - Returns: A `Recipe` instance populated with sensible random content.
    static func mockRandom<R: RandomNumberGenerator>(rng: inout R) -> Recipe {
        let adjectives = ["Spicy", "Creamy", "Herbed", "Quick", "Roasted", "Zesty", "Smoky", "Fresh", "Garlic", "Citrus"]
        let mains = ["Chicken", "Pasta", "Salmon", "Tofu", "Veggie Stir-Fry", "Beef", "Quinoa Bowl", "Lentil Curry", "Shrimp", "Mushroom Risotto"]
        let methods = ["Baked", "Pan-Seared", "One-Pot", "Sheet-Pan", "Air-Fried", "Slow-Cooked", "Grilled"]

        /// Picks a random element from `array` using the supplied RNG.
        func pick<T>(_ array: [T]) -> T { array.randomElement(using: &rng)! }

        let title = "\(pick(methods)) \(pick(adjectives)) \(pick(mains))"

        let pantry = [
            "olive oil", "garlic", "onion", "lemon", "butter", "salt", "black pepper", "paprika", "cumin",
            "chili flakes", "basil", "parsley", "tomato", "bell pepper", "spinach", "carrot", "celery",
            "chicken breast", "salmon fillet", "tofu", "beef strips", "shrimp", "quinoa", "pasta", "rice",
            "coconut milk", "ginger", "soy sauce", "parmesan"
        ]
        let ingredientCount = Int.random(in: 5...10, using: &rng)
        let ingredientNames = Array(pantry.shuffled(using: &rng).prefix(ingredientCount))
        let ingredients: [Ingredient] = ingredientNames.map(Ingredient.init(stringLiteral:))

        // Build simple, readable instructions that reference ingredients/methods
        var steps: [Step] = []
        if ingredientNames.contains("garlic") || ingredientNames.contains("onion") {
            steps.append(Step(text: "Prep aromatics: mince garlic and chop onion."))
        }
        steps.append(Step(text: "Heat \(pick(["a skillet", "a pot", "a pan"])) over medium heat and add olive oil."))
        steps.append(Step(text: "Sauté key ingredients until fragrant, then add remaining items.", timerMinutes: 5))
        if ingredientNames.contains(where: { ["pasta", "rice", "quinoa"].contains($0) }) {
            steps.append(Step(text: "Cook base (pasta/rice/quinoa) per package directions.", timerMinutes: 12))
        }
        steps.append(Step(text: "Season with salt, pepper and spices to taste."))
        steps.append(Step(text: "Simmer until flavors meld, then finish with fresh herbs or lemon.", timerMinutes: 8))

        let imageName = "recipe_placeholder"

        // Additional info
        let minutes = Int.random(in: 10...75, using: &rng)
        let servings = Int.random(in: 1...6, using: &rng)
        let complexity = ["Easy", "Medium", "Hard"].randomElement(using: &rng)!
        let calories = Int.random(in: 200...800, using: &rng)

        let info = AdditionalInfo(time: "\(minutes) min", servings: servings, complexity: complexity, calories: calories)

        // Use memberwise initializer via decoding isn't available; construct via internal initializer
        // Create using the mock init pattern by directly setting stored properties via a private init alternative.
        // Since we don't have a public memberwise initializer, create through an internal struct builder.
        return Recipe(
            title: title,
            ingredients: ingredients,
            instructions: steps,
            image: imageName,
            additionalInfo: info
        )
    }

    /// Convenience overload that uses the system RNG.
    static func mockRandom() -> Recipe {
        var rng = SystemRandomNumberGenerator()
        return mockRandom(rng: &rng)
    }

    /// Creates multiple mock recipes.
    static func mocks(count: Int) -> [Recipe] {
        var rng = SystemRandomNumberGenerator()
        var uniqueRecipes: Set<Recipe> = []
        for _ in 0..<max(0, count) {
            var mock = mockRandom(rng: &rng)
            var wasInserted = uniqueRecipes.insert(mock).inserted
            while !wasInserted {
                mock = mockRandom(rng: &rng)
                wasInserted = uniqueRecipes.insert(mock).inserted
            }
        }
        return Array(uniqueRecipes)
    }
}
