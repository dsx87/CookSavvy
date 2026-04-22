import Foundation

/// Records a single instance of the user cooking a recipe.
///
/// Sessions are stored in the database and used to track cooking history,
/// cumulative cook time, and anti-waste achievement progress.
struct CookingSession: Identifiable, Hashable {
    /// Unique database row identifier.
    let id: Int
    /// Identifier of the recipe that was cooked.
    let recipeId: Int
    /// Snapshot of the recipe's title at the time of cooking.
    let recipeTitle: String
    /// Date and time the cooking session was recorded.
    let cookedAt: Date
    /// Total time spent in Cook Mode in seconds. `nil` if the user exited before finishing.
    let durationSeconds: TimeInterval?
    /// User-assigned star rating (1–5) for this session, or `nil` if unrated.
    let rating: Int?
    /// Ingredients from the user's selection that appear in this recipe.
    let rescuedIngredients: [Ingredient]

    /// Creates a new cooking session record.
    /// - Parameters:
    ///   - id: Database row identifier.
    ///   - recipeId: The ID of the cooked recipe.
    ///   - recipeTitle: Snapshot of the recipe title at cook time.
    ///   - cookedAt: When the session was recorded.
    ///   - durationSeconds: Optional Cook Mode duration in seconds.
    ///   - rating: Optional 1–5 star rating from the user.
    ///   - rescuedIngredients: Ingredients from the user's list used by this recipe.
    init(
        id: Int,
        recipeId: Int,
        recipeTitle: String,
        cookedAt: Date,
        durationSeconds: TimeInterval?,
        rating: Int?,
        rescuedIngredients: [Ingredient] = []
    ) {
        self.id = id
        self.recipeId = recipeId
        self.recipeTitle = recipeTitle
        self.cookedAt = cookedAt
        self.durationSeconds = durationSeconds
        self.rating = rating
        self.rescuedIngredients = rescuedIngredients
    }

    /// A human-readable duration string such as `"1h 30m"` or `"45m"`.
    /// Returns `nil` when `durationSeconds` is `nil`.
    var durationFormatted: String? {
        guard let duration = durationSeconds else { return nil }
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
