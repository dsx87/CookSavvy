import Foundation

/// Curated set of popular cooking ingredients seeded into the Discover quick-pick grid before any
/// personal usage history exists.
///
/// Single source of truth for the "popular" seed. `UserDataService.getPopularIngredients` *blends*
/// this list (pantry staples excluded) with the user's recently-selected ingredients: recents lead
/// (most-recent-first) and this curated seed fills the remaining slots. On a fresh install (empty
/// `recent_ingredients`) the grid is entirely this seed; as the user's picks accumulate they push to
/// the front while the seed keeps the grid full underneath, so the grid personalises over time.
///
/// Ordering is intentional: the most universally useful ingredients lead so the first rows are the
/// ones most users reach for. The list length matches `UI.Discover.popularIngredientCount`
/// (a multiple of the 4-column grid → whole rows), which is also the move-to-front (MRU) cap applied
/// when a freshly picked ingredient is promoted to the front of the grid.
///
/// Names are the short, canonical core nouns produced by the dataset's `basicComponent` extraction
/// (e.g. "Chicken", "Bell Pepper"), so selecting one both matches recipes and resolves in
/// `recordIngredientUsage`'s case-insensitive catalogue lookup — letting the pick persist. Emoji is
/// baked in so the seed renders on its own; the values agree with `IngredientEmojiProvider`, whose
/// `fillIngredientsWithEmoji` therefore leaves them untouched.
///
/// `nonisolated` (not pinned to the main actor): a pure, stateless value utility, sibling to
/// `PantryStaples`.
nonisolated enum PopularIngredients {

    /// A display name paired with its representative emoji for one seeded popular ingredient.
    private typealias Seed = (name: String, emoji: String)

    /// The curated popular ingredients, most broadly useful first. Length matches
    /// `UI.Discover.popularIngredientCount`.
    private static let seeds: [Seed] = [
        ("Chicken", "🍗"),
        ("Rice", "🍚"),
        ("Egg", "🥚"),
        ("Onion", "🧅"),
        ("Garlic", "🧄"),
        ("Tomato", "🍅"),
        ("Pasta", "🍝"),
        ("Cheese", "🧀"),
        ("Milk", "🥛"),
        ("Butter", "🧈"),
        ("Potato", "🥔"),
        ("Carrot", "🥕"),
        ("Beef", "🥩"),
        ("Bell Pepper", "🫑"),
        ("Mushroom", "🍄"),
        ("Lemon", "🍋"),
        ("Spinach", "🥬"),
        ("Flour", "🌾"),
        ("Broccoli", "🥦"),
        ("Shrimp", "🦐"),
    ]

    /// Materialises the curated seed into displayable `Ingredient` values with emoji pre-filled.
    static func seed() -> [Ingredient] {
        seeds.map {
            Ingredient(
                name: $0.name,
                description: nil,
                pictureFileName: nil,
                foodGroup: nil,
                foodSubgroup: nil,
                emoji: $0.emoji
            )
        }
    }
}
