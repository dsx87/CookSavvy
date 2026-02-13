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

    static func emoji(for ingredientName: String) -> String? {
        let lowered = ingredientName.lowercased().trimmingCharacters(in: .whitespaces)
        if let exact = emojiMap[lowered] {
            return exact
        }
        for (key, emoji) in emojiMap where lowered.contains(key) {
            return emoji
        }
        return nil
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
