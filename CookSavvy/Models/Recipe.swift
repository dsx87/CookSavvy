//
//  Recipe.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 30/04/2025.
//

import Foundation

struct Recipe {

    struct Step: Codable, Hashable {
        let text: String
        let timerMinutes: Int?

        init(text: String, timerMinutes: Int? = nil) {
            self.text = text
            self.timerMinutes = timerMinutes
        }

        init(plainText string: String) {
            self.text = string
            self.timerMinutes = nil
        }
    }

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
    let instructions: [Step]
    let image: String
    let cleanedIngredients: [Ingredient]
    let additionalInfo: AdditionalInfo
    var source: RecipeSourceType?
    var tagline: String?
    var userRating: Double?
    var apiRating: Double?
    var author: String?
    var isUserCreated: Bool
    var emoji: String?
    var cuisine: String?
    var matchPercentage: Double?
    var matchReason: String?

    init(
        title: String,
        ingredients: [Ingredient],
        instructions: [Step],
        image: String,
        cleanedIngredients: [Ingredient],
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
        matchReason: String? = nil
    ) {
        self.title = title
        self.ingredients = ingredients
        self.instructions = instructions
        self.image = image
        self.cleanedIngredients = cleanedIngredients
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
    }
    
    init(
        title: String,
        ingredients: [Ingredient],
        instructions: [String],
        image: String,
        cleanedIngredients: [Ingredient],
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
        matchReason: String? = nil
    ) {
        self.init(
            title: title,
            ingredients: ingredients,
            instructions: instructions.map(Step.init(plainText:)),
            image: image,
            cleanedIngredients: cleanedIngredients,
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
            matchReason: matchReason
        )
    }

    // Mock init
    init() {
        self = Self.mockRandom()
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
        if let stepsArray = try? container.decode([Step].self, forKey: .instructions) {
            self.instructions = stepsArray
        } else if let stringsArray = try? container.decode([String].self, forKey: .instructions) {
            self.instructions = stringsArray.map(Step.init(plainText:))
        } else {
            let rawInstructions = try container.decode(String.self, forKey: .instructions)
            self.instructions = rawInstructions.components(separatedBy: "\n").map(Step.init(plainText:))
        }
        self.image = try container.decode(String.self, forKey: .image)
        let rawCleanedIngredients = try container.decode(String.self, forKey: .cleanedIngredients)
        self.cleanedIngredients = rawCleanedIngredients.separatedByQuotes.map(Ingredient.init(stringLiteral:))
        self.additionalInfo = try container.decodeIfPresent(AdditionalInfo.self, forKey: .additionalInfo) ?? .empty
        self.source = nil
        self.tagline = nil
        self.userRating = nil
        self.apiRating = nil
        self.author = nil
        self.isUserCreated = false
        self.emoji = nil
        self.cuisine = nil
        self.matchPercentage = nil
        self.matchReason = nil
    }
    
}

// MARK: - Mock Factories for Testing
extension Recipe {
    /// Creates a single mock `Recipe` with meaningful randomized values.
    /// - Parameter rng: Optional random number generator for deterministic tests.
    /// - Returns: A `Recipe` instance populated with sensible random content.
    static func mockRandom<R: RandomNumberGenerator>(rng: inout R) -> Recipe {
        let adjectives = ["Spicy", "Creamy", "Herbed", "Quick", "Roasted", "Zesty", "Smoky", "Fresh", "Garlic", "Citrus"]
        let mains = ["Chicken", "Pasta", "Salmon", "Tofu", "Veggie Stir-Fry", "Beef", "Quinoa Bowl", "Lentil Curry", "Shrimp", "Mushroom Risotto"]
        let methods = ["Baked", "Pan-Seared", "One-Pot", "Sheet-Pan", "Air-Fried", "Slow-Cooked", "Grilled"]

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

        // Create a simple cleaned list (unique, capitalized)
        let cleanedIngredients: [Ingredient] = Array(Set(ingredientNames.map { $0.capitalized })).sorted().map(Ingredient.init(stringLiteral:))

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
            cleanedIngredients: cleanedIngredients,
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
