import Foundation

enum IngredientEmojiProvider {

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
        return "🍽️"
    }

    static func emoji(for ingredientName: String, foodGroup: String?) -> String {
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
        if let group = foodGroup {
            return emojiForFoodGroup(group)
        }
        return "🍽️"
    }

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
        return "🍽️"
    }

    static func emoji(for category: IngredientCategory) -> String {
        switch category {
        case .proteins: return "🥩"
        case .veggies: return "🥬"
        case .dairy: return "🧀"
        case .grains: return "🌾"
        case .fruits: return "🍎"
        case .spices: return "🌶️"
        case .other: return "🍽️"
        }
    }
}
