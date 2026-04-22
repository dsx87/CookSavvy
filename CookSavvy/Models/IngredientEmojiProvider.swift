import Foundation

/// A stateless namespace that resolves an emoji for any ingredient name or food group.
///
/// Resolution uses a four-stage fallback chain:
/// 1. **Exact match** — direct lookup of the lowercased name in `emojiMap`.
/// 2. **Contains match** — keys sorted longest-first so `"chicken breast"` wins over `"chicken"`.
/// 3. **Word match** — each whitespace-separated word is checked individually.
/// 4. **Food group fallback** — `emojiForFoodGroup(_:)` when a `foodGroup` is available.
/// 5. **Default** — returns `"🍽️"` when all stages fail.
enum IngredientEmojiProvider {

    /// Static lookup table mapping common ingredient names to their representative emoji.
    private static let emojiMap: [String: String] = [
        "chicken": "🍗",
        "chicken breast": "🍗",
        "beef": "🥩",
        "beef strips": "🥩",
        "pork": "🥩",
        "salmon": "🐟",
        "salmon fillet": "🐟",
        "shrimp": "🦐",
        "fish": "🐟",
        "tofu": "🧈",
        "egg": "🥚",
        "eggs": "🥚",
        "milk": "🥛",
        "cheese": "🧀",
        "butter": "🧈",
        "yogurt": "🥛",
        "cream": "🥛",
        "rice": "🍚",
        "pasta": "🍝",
        "bread": "🍞",
        "quinoa": "🌾",
        "oats": "🌾",
        "flour": "🌾",
        "tomato": "🍅",
        "onion": "🧅",
        "garlic": "🧄",
        "carrot": "🥕",
        "potato": "🥔",
        "bell pepper": "🫑",
        "broccoli": "🥦",
        "spinach": "🥬",
        "lettuce": "🥬",
        "corn": "🌽",
        "mushroom": "🍄",
        "cucumber": "🥒",
        "avocado": "🥑",
        "celery": "🥬",
        "apple": "🍎",
        "banana": "🍌",
        "lemon": "🍋",
        "lime": "🍋",
        "orange": "🍊",
        "strawberry": "🍓",
        "blueberry": "🫐",
        "grape": "🍇",
        "coconut": "🥥",
        "coconut milk": "🥥",
        "pineapple": "🍍",
        "mango": "🥭",
        "peach": "🍑",
        "watermelon": "🍉",
        "salt": "🧂",
        "pepper": "🌶️",
        "black pepper": "🫚",
        "chili": "🌶️",
        "chili flakes": "🌶️",
        "ginger": "🫚",
        "basil": "🌿",
        "parsley": "🌿",
        "cilantro": "🌿",
        "mint": "🌿",
        "cumin": "🫙",
        "paprika": "🫙",
        "cinnamon": "🫙",
        "olive oil": "🫒",
        "soy sauce": "🫙",
        "honey": "🍯",
        "sugar": "🍬",
        "chocolate": "🍫",
        "coffee": "☕",
        "tea": "🍵",
        "water": "💧",
        "wine": "🍷",
        "parmesan": "🧀",
    ]
    
    /// The fallback emoji used when no match is found in the lookup chain.
    private static let defaultIcon = "🍽️"

    /// Resolves an emoji for `ingredientName` using a three-stage name-based fallback chain.
    ///
    /// Stages applied in order:
    /// 1. **Exact match** — looks up the lowercased name directly.
    /// 2. **Contains match** — iterates keys sorted longest-first to prefer specific matches.
    /// 3. **Word match** — splits on whitespace and checks each word individually.
    ///
    /// Returns ``defaultIcon`` when all stages fail.
    /// - Parameter ingredientName: The ingredient name to resolve an emoji for.
    /// - Returns: A single emoji character string, or `"🍽️"` as the default.
    static func emoji(for ingredientName: String) -> String {
        let lowered = ingredientName.lowercased().trimmingCharacters(in: .whitespaces)
        if let exact = emojiMap[lowered] {
            return exact
        }
        let sortedKeys = emojiMap.keys.sorted { $0.count > $1.count }
        for key in sortedKeys where lowered.contains(key) {
            return emojiMap[key]!
        }
        let words = lowered.components(separatedBy: .whitespaces)
        for word in words {
            if let match = emojiMap[word] {
                return match
            }
        }
        return defaultIcon
    }

    /// Resolves an emoji for `ingredientName`, falling back to a food-group emoji when the
    /// name-based lookup returns the default icon and a `foodGroup` string is available.
    /// - Parameters:
    ///   - ingredientName: The ingredient name to resolve an emoji for.
    ///   - foodGroup: Optional food group string used as a secondary fallback.
    /// - Returns: A single emoji character string.
    static func emoji(for ingredientName: String, foodGroup: String?) -> String {
        
        let emoji = emoji(for: ingredientName)
        
        if let group = foodGroup, emoji == defaultIcon {
            return emojiForFoodGroup(group)
        }
        
        return emoji
    }

    /// Fills any `nil` emoji fields in `ingredients` in place using ``emoji(for:foodGroup:)``.
    ///
    /// Ingredients that already have an emoji assigned are skipped.
    /// - Parameter ingredients: The ingredient array to mutate.
    static func fillIngredientsWithEmoji(_ ingredients: inout [Ingredient]) {
        for (i, ingredient) in ingredients.enumerated() {
            let name = ingredient.name
            let group = ingredient.foodGroup
            
            guard ingredient.emoji == nil else { continue }
            ingredients[i].emoji = emoji(for: name, foodGroup: group)
        }
    }
    
    /// Maps a raw food group string to a representative emoji based on broad category keywords.
    /// - Parameter group: The food group string (e.g. `"Herbs & Spices"`, `"Dairy"`).
    /// - Returns: An emoji string, or ``defaultIcon`` for unrecognised groups.
    private static func emojiForFoodGroup(_ group: String) -> String {
        let g = group.lowercased()
        if g.contains("herb") || g.contains("spice") { return "🌿" }
        if g.contains("vegetable") || g.contains("legume") { return "🥬" }
        if g.contains("fruit") { return "🍎" }
        if g.contains("nut") || g.contains("seed") { return "🥜" }
        if g.contains("cereal") || g.contains("grain") { return "🌾" }
        if g.contains("animal") || g.contains("meat") || g.contains("poultry") { return "🍖" }
        if g.contains("fish") || g.contains("seafood") { return "🐟" }
        if g.contains("milk") || g.contains("dairy") { return "🧀" }
        if g.contains("fat") || g.contains("oil") { return "🫒" }
        if g.contains("beverage") { return "🥤" }
        return defaultIcon
    }

    /// Returns the representative emoji for a given ``IngredientCategory``.
    /// - Parameter category: The category to resolve an emoji for.
    /// - Returns: A single emoji character string.
    static func emoji(for category: IngredientCategory) -> String {
        switch category {
        case .proteins: return "🥩"
        case .veggies: return "🥬"
        case .dairy: return "🧀"
        case .grains: return "🌾"
        case .fruits: return "🍎"
        case .spices: return "🌶️"
        case .other: return defaultIcon
        }
    }
}
