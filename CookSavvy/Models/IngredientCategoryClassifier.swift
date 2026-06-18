import Foundation

/// Maps an ingredient's *name* to a broad ``IngredientCategory`` using curated keyword sets.
///
/// The bundled recipe dataset carries no food-group metadata (every ingredient's `foodGroup` is
/// `nil`), so the only signal available for categorising the ingredient grid is the canonical
/// `basicComponent` name (e.g. `"chicken"`, `"tomato"`, `"cheddar"`). Those names are clean core
/// nouns, which makes keyword matching reliable: a few hundred keywords plus prefix matching cover
/// the overwhelming majority of real ingredients, and anything unrecognised falls through to
/// `.other` (and is simply absent from the category chips, which exclude `.other`).
///
/// `nonisolated` (not pinned to the main actor): a pure, stateless value-in/value-out utility,
/// consumed from `Ingredient.category` and the `IngredientsService` actor without `await`.
nonisolated enum IngredientCategoryClassifier {

    /// Returns the best-fit ``IngredientCategory`` for an ingredient name, or `.other` when no
    /// keyword group matches.
    ///
    /// Matching is case-insensitive. Multi-word keywords ("bell pepper") match as a substring of the
    /// name; single-word keywords match a whole word in the name, or — for keywords of four or more
    /// letters — a word that *starts with* the keyword, so simple plurals ("tomatoes", "potatoes")
    /// and adjective forms still resolve. Groups are evaluated in priority order and the first match
    /// wins, which is how deliberate overlaps are resolved (e.g. "peanut butter" lands in `.proteins`
    /// because nuts are checked before dairy's "butter").
    static func category(forName rawName: String) -> IngredientCategory {
        let name = rawName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return .other }

        let words = Set(name.split(whereSeparator: { !$0.isLetter }).map(String.init))

        for group in orderedGroups {
            for keyword in group.keywords where matches(keyword, name: name, words: words) {
                return group.category
            }
        }
        return .other
    }

    /// `true` when `keyword` is present in `name`/`words` per the matching rules in `category(forName:)`.
    private static func matches(_ keyword: String, name: String, words: Set<String>) -> Bool {
        if keyword.contains(" ") {
            return name.contains(keyword)
        }
        if words.contains(keyword) {
            return true
        }
        // Allow a longer keyword to match a word it prefixes ("tomato" → "tomatoes") while avoiding
        // short-keyword false positives ("egg" must not match "eggplant").
        guard keyword.count >= 4 else { return false }
        return words.contains { $0.hasPrefix(keyword) }
    }

    /// A category paired with the keywords that resolve to it.
    private struct KeywordGroup {
        let category: IngredientCategory
        let keywords: [String]
    }

    /// Keyword groups in priority order. Earlier groups win ties, so place a category before another
    /// whenever a shared keyword should resolve to it (proteins before dairy for nut "butters",
    /// fruits before veggies for "tomato"-style edge cases that should stay produce, etc.).
    private static let orderedGroups: [KeywordGroup] = [
        // MARK: Proteins — meat, poultry, fish, seafood, eggs, soy, and nuts (plant proteins).
        KeywordGroup(category: .proteins, keywords: [
            "chicken", "beef", "steak", "pork", "bacon", "ham", "sausage", "prosciutto", "pancetta",
            "salami", "pepperoni", "chorizo", "turkey", "duck", "lamb", "veal", "venison", "rabbit",
            "goat", "brisket", "ribs", "rib", "tenderloin", "sirloin", "chuck", "ground beef",
            "ground pork", "ground turkey", "ground chicken", "meatball", "mince",
            "fish", "salmon", "tuna", "cod", "halibut", "tilapia", "trout", "snapper", "mackerel",
            "sardine", "anchovy", "anchovies", "haddock", "catfish", "sea bass", "swordfish",
            "shrimp", "prawn", "crab", "lobster", "clam", "mussel", "oyster", "scallop", "squid",
            "calamari", "octopus", "shellfish", "seafood",
            "egg", "eggs",
            "tofu", "tempeh", "seitan", "edamame",
            "almond", "peanut", "walnut", "cashew", "pecan", "pistachio", "hazelnut", "macadamia",
            "pine nut", "peanut butter", "almond butter"
        ]),
        // MARK: Dairy — milk, cheese, butter, yogurt, cream.
        KeywordGroup(category: .dairy, keywords: [
            "milk", "buttermilk", "cream", "creme", "half and half", "heavy cream", "sour cream",
            "whipping cream", "cream cheese", "ice cream",
            "cheese", "cheddar", "mozzarella", "parmesan", "parmigiano", "feta", "ricotta", "gouda",
            "brie", "gruyere", "provolone", "swiss cheese", "blue cheese", "goat cheese",
            "mascarpone", "halloumi", "queso", "cotija", "monterey jack", "pecorino",
            "yogurt", "yoghurt", "butter", "ghee", "custard", "kefir"
        ]),
        // MARK: Grains — grains, cereals, bread, pasta, rice.
        KeywordGroup(category: .grains, keywords: [
            "rice", "pasta", "spaghetti", "penne", "macaroni", "fettuccine", "linguine", "rigatoni",
            "lasagna", "lasagne", "ravioli", "gnocchi", "orzo", "noodle", "ramen", "udon", "soba",
            "vermicelli", "couscous", "quinoa", "barley", "bulgur", "farro", "millet", "buckwheat",
            "oat", "oats", "oatmeal", "cornmeal", "polenta", "grits", "semolina", "wheat",
            "flour", "bread", "baguette", "ciabatta", "brioche", "naan", "pita", "tortilla", "roll",
            "bun", "bagel", "croissant", "cracker", "breadcrumb", "panko", "crouton", "cereal",
            "granola", "cornstarch", "starch"
        ]),
        // MARK: Fruits — fresh and dried fruits.
        KeywordGroup(category: .fruits, keywords: [
            "apple", "banana", "orange", "lemon", "lime", "grapefruit", "clementine", "tangerine",
            "mango", "pineapple", "papaya", "guava", "passion fruit", "kiwi", "pomegranate", "fig",
            "date", "raisin", "prune", "apricot", "peach", "nectarine", "plum", "cherry", "cherries",
            "grape", "grapes", "melon", "watermelon", "cantaloupe", "honeydew", "pear", "persimmon",
            "strawberry", "strawberries", "blueberry", "blueberries", "raspberry", "raspberries",
            "blackberry", "blackberries", "cranberry", "cranberries", "berry", "berries", "currant",
            "coconut", "avocado"
        ]),
        // MARK: Veggies — vegetables and legumes.
        KeywordGroup(category: .veggies, keywords: [
            "tomato", "potato", "sweet potato", "yam", "onion", "shallot", "scallion", "leek",
            "carrot", "celery", "cucumber", "zucchini", "squash", "pumpkin", "eggplant", "aubergine",
            "bell pepper", "red pepper", "green pepper", "yellow pepper", "jalapeno", "jalapeño",
            "poblano", "serrano", "habanero", "chili pepper", "chile",
            "broccoli", "cauliflower", "cabbage", "kale", "spinach", "lettuce", "arugula", "chard",
            "collard", "bok choy", "brussels sprout", "asparagus", "artichoke", "okra", "radish",
            "turnip", "beet", "beetroot", "parsnip", "fennel", "mushroom", "corn", "green bean",
            "snap pea", "snow pea", "pea", "peas", "bean", "beans", "lentil", "lentils", "chickpea",
            "chickpeas", "garbanzo", "edamame", "soybean", "garlic", "ginger", "sprout",
            "cucumber", "watercress", "endive", "radicchio", "kohlrabi", "rutabaga", "plantain"
        ]),
        // MARK: Spices — herbs, spices, seasonings, condiments.
        KeywordGroup(category: .spices, keywords: [
            "salt", "pepper", "peppercorn", "cumin", "coriander", "cinnamon", "nutmeg", "clove",
            "cardamom", "paprika", "turmeric", "cayenne", "chili powder", "chili flakes",
            "red pepper flakes", "curry powder", "garam masala", "allspice", "fennel seed",
            "mustard seed", "saffron", "star anise", "anise", "bay leaf", "fenugreek", "sumac",
            "za'atar", "zaatar", "old bay", "seasoning", "spice",
            "basil", "oregano", "thyme", "rosemary", "sage", "parsley", "cilantro", "coriander",
            "mint", "dill", "chive", "tarragon", "marjoram", "lemongrass", "herb",
            "soy sauce", "fish sauce", "hoisin", "oyster sauce", "worcestershire", "sriracha",
            "tabasco", "hot sauce", "ketchup", "mustard", "mayonnaise", "mayo", "aioli", "relish",
            "vinegar", "miso", "tahini", "harissa", "pesto", "salsa", "chutney", "horseradish",
            "capers", "caper"
        ])
    ]
}
